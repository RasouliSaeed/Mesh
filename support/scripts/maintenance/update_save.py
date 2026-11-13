import re

with open('packages/core/src/http/server/common/save.rs', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace FileTimestamps with import
content = content.replace(
    "pub(crate) struct FileTimestamps {",
    "// Replaced with crate::model::storage::FileTimestamps\n/* pub(crate) struct FileTimestamps {"
)
content = content.replace(
    "    fn is_empty(&self) -> bool {",
    "/*  fn is_empty(&self) -> bool {"
)
content = content.replace(
    "        self.modified.is_none() && self.accessed.is_none()\n    }\n}",
    "        self.modified.is_none() && self.accessed.is_none()\n    }\n} */"
)
content = content.replace(
    "    pub accessed: Option<std::time::SystemTime>,\n}",
    "    pub accessed: Option<std::time::SystemTime>,\n} */\nuse crate::model::storage::FileTimestamps;"
)

# Update FileUploadTarget
target_old = """    Path {
        /// The path to write the file to.
        path: PathBuf,

        /// Channel on which the server reports whether the file was saved
        /// successfully, including the checksum verification if one was given.
        result_tx: oneshot::Sender<Result<(), String>>,

        /// Optional channel on which the server reports the number of bytes
        /// written so far. Events are dropped when the channel is full.
        progress_tx: Option<mpsc::Sender<u64>>,
    },

    /// The server writes the file to this raw file descriptor (Android only)
    /// and reports the result on `result_tx`.
    ///
    /// Timestamps provided in the sender's file metadata are applied through
    /// the descriptor, which also covers SAF documents that have no path.
    #[cfg(target_os = "android")]
    Fd {
        /// The raw file descriptor to write the file to.
        /// Ownership is transferred; the descriptor is closed after writing.
        fd: std::os::fd::RawFd,

        /// Channel on which the server reports whether the file was saved
        /// successfully, including the checksum verification if one was given.
        result_tx: oneshot::Sender<Result<(), String>>,

        /// Optional channel on which the server reports the number of bytes
        /// written so far. Events are dropped when the channel is full.
        progress_tx: Option<mpsc::Sender<u64>>,
    },"""

target_new = """    Storage {
        /// The abstract storage handle to write chunks into.
        handle: Box<dyn crate::model::storage::StorageHandle>,

        /// Channel on which the server reports whether the file was saved
        /// successfully, including the checksum verification if one was given.
        result_tx: oneshot::Sender<Result<(), String>>,

        /// Optional channel on which the server reports the number of bytes
        /// written so far. Events are dropped when the channel is full.
        progress_tx: Option<mpsc::Sender<u64>>,
    },"""

content = content.replace(target_old, target_new)

# Update target matcher in save_req_to_target
match_old = """        FileUploadTarget::Path {
            path,
            result_tx,
            progress_tx,
        } => {
            let (binary_tx, result_rx) = spawn_file_writer(
                async move {
                    tokio::fs::File::create(&path)
                        .await
                        .map_err(|e| format!("Failed to create {}: {e}", path.display()))
                },
                file_size,
                progress_tx,
                timestamps,
            );
            (binary_tx, result_rx, Some(result_tx))
        }
        #[cfg(target_os = "android")]
        FileUploadTarget::Fd {
            fd,
            result_tx,
            progress_tx,
        } => {
            let (binary_tx, result_rx) = spawn_file_writer(
                async move {
                    use std::os::fd::FromRawFd;

                    // SAFETY: the descriptor is owned by this transfer; wrapping it in
                    // a File transfers that ownership so it is closed once writing finishes.
                    let std_file = unsafe { std::fs::File::from_raw_fd(fd) };
                    Ok(tokio::fs::File::from_std(std_file))
                },
                file_size,
                progress_tx,
                timestamps,
            );
            (binary_tx, result_rx, Some(result_tx))
        }"""

match_new = """        FileUploadTarget::Storage {
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
        }"""

content = content.replace(match_old, match_new)

# Update spawn_file_writer
spawn_old = """fn spawn_file_writer(
    open: impl Future<Output = Result<tokio::fs::File, String>> + Send + 'static,
    expected_size: u64,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> (mpsc::Sender<Bytes>, oneshot::Receiver<Result<(), String>>) {
    let (binary_tx, mut binary_rx) = mpsc::channel::<Bytes>(UPLOAD_CHANNEL_CAPACITY);
    let (internal_tx, internal_rx) = oneshot::channel::<Result<(), String>>();

    tokio::spawn(async move {
        let result =
            write_file_from_receiver(open, expected_size, &mut binary_rx, progress_tx, timestamps)
                .await;
        // Unblock the request handler if it is still sending chunks.
        binary_rx.close();
        let _ = internal_tx.send(result);
    });

    (binary_tx, internal_rx)
}"""

spawn_new = """fn spawn_file_writer(
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
}"""

content = content.replace(spawn_old, spawn_new)

# Update write_file_from_receiver
write_old = """async fn write_file_from_receiver(
    open: impl Future<Output = Result<tokio::fs::File, String>>,
    expected_size: u64,
    rx: &mut mpsc::Receiver<Bytes>,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> Result<(), String> {
    use tokio::io::AsyncWriteExt;

    let mut file = tokio::io::BufWriter::with_capacity(WRITE_BUFFER_SIZE, open.await?);
    let mut written: u64 = 0;
    while let Some(chunk) = rx.recv().await {
        written += chunk.len() as u64;
        if written > expected_size {
            return Err(format!(
                "Expected {expected_size} bytes, received at least {written}"
            ));
        }
        file.write_all(&chunk)
            .await
            .map_err(|e| format!("Failed to write file: {e}"))?;
        if let Some(progress_tx) = &progress_tx {
            // Progress is best-effort: drop the event when the consumer lags.
            let _ = progress_tx.try_send(written);
        }
    }
    file.flush()
        .await
        .map_err(|e| format!("Failed to flush file: {e}"))?;
    let file = file.into_inner();

    if written != expected_size {
        return Err(format!(
            "Expected {expected_size} bytes, received {written}"
        ));
    }

    // Drops content beyond the file that was just written, in case the target
    // pointed at a longer, pre-existing file: opening truncates for paths and
    // for descriptors opened with the SAF "wt" mode, but a document provider is
    // free to ignore that mode. Retries of the same upload are covered by the
    // exact size check above either way.
    //
    // Best-effort: a provider may back the descriptor by something that cannot
    // be truncated (e.g. a pipe), which must not fail the completed transfer.
    if let Err(e) = file.set_len(written).await {
        tracing::warn!("Could not truncate file to {written} bytes: {e}");
    }

    // The timestamps are applied last because the writes and the truncation
    // above update the modification time themselves.
    //
    // Best-effort: the provider backing an Android file descriptor may not
    // support changing timestamps, which must not fail the completed transfer.
    if !timestamps.is_empty() {
        let mut times = std::fs::FileTimes::new();
        if let Some(m) = timestamps.modified {
            times = times.set_modified(m);
        }
        if let Some(a) = timestamps.accessed {
            times = times.set_accessed(a);
        }
        let std_file = file.into_std().await;
        let _ = std_file.set_times(times);
    }

    Ok(())
}"""

write_new = """async fn write_file_from_receiver(
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
        if let Err(e) = handle.write_chunk(&chunk).await {
            let _ = handle.abort().await;
            return Err(format!("Failed to write file: {e}"));
        }
        if let Some(progress_tx) = &progress_tx {
            // Progress is best-effort: drop the event when the consumer lags.
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

    // Drops content beyond the file that was just written.
    if let Err(e) = handle.set_len(written).await {
        tracing::warn!("Could not truncate file to {written} bytes: {e}");
    }

    if let Err(e) = handle.commit(timestamps).await {
        return Err(format!("Failed to commit file: {e}"));
    }

    Ok(())
}"""

content = content.replace(write_old, write_new)

# PathBuf is no longer needed in FileUploadTarget (well, it's used elsewhere maybe? No)
content = content.replace("use std::path::PathBuf;\n", "")

with open('packages/core/src/http/server/common/save.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated save.rs")
