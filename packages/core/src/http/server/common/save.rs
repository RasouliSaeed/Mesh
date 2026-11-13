use crate::crypto;
use bytes::Bytes;
use futures_util::StreamExt;
use crate::model::transport::BoxedTransportStream;

use tokio::sync::{mpsc, oneshot};

/// Channel capacity for file upload chunks (provides backpressure).
const UPLOAD_CHANNEL_CAPACITY: usize = 16;

/// Size of the write buffer that coalesces incoming body chunks (typically one
/// TLS record, ~16 KiB) into larger file writes.
#[allow(dead_code)]
const WRITE_BUFFER_SIZE: usize = 512 * 1024;

/// Where the content of an uploaded file should go, decided by the application.
pub enum FileUploadTarget {
    /// The application consumes the binary chunks itself.
    ///
    /// The server forwards chunks into `binary_tx` and closes it at end of file.
    /// The application should compare the number of received bytes with `file.size`
    /// and report the result on the sender side of `result_rx` which determines
    /// the HTTP response (200 on `Ok`, 500 on `Err` or when the sender is dropped).
    ///
    /// Note: the checksum is only verified after the application reported its
    /// result, so a checksum mismatch is not observable by the application here
    /// (unlike [FileUploadTarget::Path] and [FileUploadTarget::Fd]).
    Stream {
        /// Channel the server sends the binary chunks of the file into.
        binary_tx: mpsc::Sender<Bytes>,

        /// Channel on which the application reports whether the file was
        /// processed successfully.
        result_rx: oneshot::Receiver<Result<(), String>>,
    },

    /// The server writes the file to this path (created or truncated)
    /// and reports the result on `result_tx`.
    ///
    /// Timestamps provided in the sender's file metadata are applied to the
    /// written file, so the application does not need to set them itself.
    Storage {
        /// The abstract storage handle to write chunks into.
        handle: Box<dyn crate::model::storage::StorageHandle>,

        /// Channel on which the server reports whether the file was saved
        /// successfully, including the checksum verification if one was given.
        result_tx: oneshot::Sender<Result<(), String>>,

        /// Optional channel on which the server reports the number of bytes
        /// written so far. Events are dropped when the channel is full.
        progress_tx: Option<mpsc::Sender<u64>>,
    },
}

impl std::fmt::Debug for FileUploadTarget {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Stream { binary_tx, result_rx } => f
                .debug_struct("Stream")
                .field("binary_tx", binary_tx)
                .field("result_rx", result_rx)
                .finish(),
            Self::Storage { handle: _, result_tx, progress_tx } => f
                .debug_struct("Storage")
                .field("handle", &"<StorageHandle>")
                .field("result_tx", result_tx)
                .field("progress_tx", progress_tx)
                .finish(),
        }
    }
}

/// The sender-provided timestamps of an uploaded file, applied to the written
/// file for [FileUploadTarget::Path] and [FileUploadTarget::Fd].
pub(crate) use crate::model::storage::FileTimestamps;

/// Outcome of receiving an uploaded file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum SaveResult {
    /// The file has been received and, if a checksum was given, it matched.
    Success,

    /// The body could not be read or the target failed to process it.
    Failed,

    /// The received bytes do not match the expected SHA-256 checksum.
    HashMismatch,
}

/// Forwards the body of `req` to `target`.
pub(crate) async fn save_req_to_target(
    mut stream: BoxedTransportStream,
    target: FileUploadTarget,
    file_size: u64,
    expected_sha256: Option<&str>,
    timestamps: FileTimestamps,
) -> SaveResult {
    use sha2::{Digest, Sha256};

    // Resolve the target into a chunk sender and a result receiver.
    // For [FileUploadTarget::Path] and [FileUploadTarget::Fd], the application's
    // result channel is answered by this function once the complete outcome
    // (including the checksum verification) is known.
    let (binary_tx, result_rx, app_result_tx) = match target {
        FileUploadTarget::Stream {
            binary_tx,
            result_rx,
        } => (binary_tx, result_rx, None),
        FileUploadTarget::Storage {
            handle,
            result_tx,
            progress_tx,
        } => {
            let (binary_tx, result_rx) = spawn_file_writer(
                handle,
                file_size,
                progress_tx,
                timestamps,
            );
            (binary_tx, result_rx, Some(result_tx))
        }
    };

    // Forward the request body to the target, hashing it on the way if requested.
    let mut hasher = expected_sha256.map(|_| Sha256::new());
    let mut stream_error = false;
    while let Some(chunk_result) = stream.next().await {
        match chunk_result {
            Ok(data) => {
                if data.is_empty() {
                    continue;
                }
                if let Some(hasher) = &mut hasher {
                    hasher.update(&data);
                }
                if binary_tx.send(data).await.is_err() {
                    // The receiver is gone (dropped by the application or
                    // closed by the file writer after an error).
                    stream_error = true;
                    break;
                }
            }
            Err(err) => {
                tracing::warn!("Error reading upload body of file: {err:#}");
                stream_error = true;
                break;
            }
        }
    }

    // Signal end of file to the receiving side.
    drop(binary_tx);

    // Determine the outcome; `error` carries the reason for the application.
    let (result, error): (SaveResult, Option<String>) = 'outcome: {
        if stream_error {
            // The file writer (if any) fails with a size mismatch or its own
            // write error once the channel is closed; collect that reason.
            let error = match app_result_tx.is_some() {
                true => match result_rx.await {
                    Ok(Err(err)) => Some(err),
                    _ => None,
                },
                false => None,
            };
            break 'outcome (
                SaveResult::Failed,
                error.or(Some("Upload aborted".to_string())),
            );
        }

        match result_rx.await {
            Ok(Ok(())) => (),
            Ok(Err(err)) => {
                tracing::warn!("Failed to process file: {err}");
                break 'outcome (SaveResult::Failed, Some(err));
            }
            Err(_) => break 'outcome (SaveResult::Failed, Some("Upload aborted".to_string())),
        }

        if let (Some(hasher), Some(expected)) = (hasher, expected_sha256) {
            let actual = crypto::hash::to_hex(&hasher.finalize());
            if !actual.eq_ignore_ascii_case(expected) {
                tracing::warn!("Checksum mismatch: expected {expected}, got {actual}");
                break 'outcome (
                    SaveResult::HashMismatch,
                    Some("Checksum mismatch".to_string()),
                );
            }
        }

        (SaveResult::Success, None)
    };

    if let Some(app_result_tx) = app_result_tx {
        let _ = app_result_tx.send(match error {
            None => Ok(()),
            Some(err) => Err(err),
        });
    }

    result
}

/// Spawns a task that writes incoming chunks to a file provided by `open`.
///
/// Returns the sender for the binary chunks and a receiver for the final result.
fn spawn_file_writer(
    handle: Box<dyn crate::model::storage::StorageHandle>,
    expected_size: u64,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> (mpsc::Sender<Bytes>, oneshot::Receiver<Result<(), String>>) {
    let (binary_tx, mut binary_rx) = mpsc::channel::<Bytes>(UPLOAD_CHANNEL_CAPACITY);
    let (internal_tx, internal_rx) = oneshot::channel::<Result<(), String>>();

    tokio::spawn(async move {
        let result =
            write_file_from_receiver(handle, expected_size, &mut binary_rx, progress_tx, timestamps)
                .await;
        // Unblock the request handler if it is still sending chunks.
        binary_rx.close();
        let _ = internal_tx.send(result);
    });

    (binary_tx, internal_rx)
}

/// Writes all chunks received on `rx` to the file provided by `open`.
///
/// Fails if the total number of written bytes does not match `expected_size`
/// (e.g. the sender disconnected mid-transfer).
///
/// The file is truncated to the written size, so that a target that pointed at
/// a longer, pre-existing file cannot keep a tail of the old content.
///
/// The sender-provided `timestamps` are applied to the completely written
/// file. This happens on the still-open handle: an Android file descriptor has
/// no path to address the file by afterwards.
async fn write_file_from_receiver(
    mut handle: Box<dyn crate::model::storage::StorageHandle>,
    expected_size: u64,
    rx: &mut mpsc::Receiver<Bytes>,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> Result<(), String> {
    let mut written: u64 = 0;
    while let Some(chunk) = rx.recv().await {
        written += chunk.len() as u64;
        if written > expected_size {
            let _ = handle.abort().await;
            return Err(format!(
                "Expected {expected_size} bytes, received at least {written}"
            ));
        }
        if let Err(e) = handle.write_data(&chunk).await {
            let _ = handle.abort().await;
            return Err(format!("Failed to write file: {e}"));
        }
        if let Some(progress_tx) = &progress_tx {
            let _ = progress_tx.try_send(written);
        }
    }
    
    if let Err(e) = handle.flush().await {
        let _ = handle.abort().await;
        return Err(format!("Failed to flush file: {e}"));
    }

    if written != expected_size {
        let _ = handle.abort().await;
        return Err(format!(
            "Expected {expected_size} bytes, received {written}"
        ));
    }

    if let Err(e) = handle.set_len(written).await {
        tracing::warn!("Could not truncate file to {written} bytes: {e}");
    }

    if let Err(e) = handle.commit(timestamps).await {
        return Err(format!("Failed to commit file: {e}"));
    }

    Ok(())
}
