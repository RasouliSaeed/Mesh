use crate::api::cancel::RsCancellationToken;
use crate::api::stream;
use crate::frb_generated::StreamSink;
use flutter_rust_bridge::frb;
pub use locara::http::client::{ClientError, LsHttpClientVersion};
pub use locara::http::dto::{
    PrepareUploadRequestDto, PrepareUploadResponseDto, PrepareUploadResult, RegisterDto,
    RegisterResponseDto,
};
use locara::model::discovery::ProtocolType;
use locara::util::error::ErrorChain;
use std::sync::Arc;
use std::time::Instant;

pub struct RsHttpClient {
    inner: locara::http::client::LsHttpClient,
}

/// Creates an HTTP client.
///
/// `expected_fingerprint` pins the peer to the certificate with that SHA-256
/// fingerprint (uppercase hex). It is enforced during the TLS handshake, so a
/// peer that does not present the expected certificate never receives the
/// request. Pass `None` only for discovery, where the peer is not known yet.
#[frb(sync)]
pub fn create_client(
    private_key: String,
    cert: String,
    version: LsHttpClientVersion,
    expected_fingerprint: Option<String>,
    timeout_ms: Option<u32>,
) -> Result<RsHttpClient, RsHttpClientError> {
    let inner = locara::http::client::LsHttpClient::new(
        &private_key,
        &cert,
        version,
        expected_fingerprint,
        timeout_ms.map(|ms| std::time::Duration::from_millis(ms as u64)),
    )
    .map_err(RsHttpClientError::from)?;

    Ok(RsHttpClient { inner })
}

impl RsHttpClient {
    pub async fn register(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        payload: RegisterDto,
    ) -> Result<ResultWithPublicKeyRegisterResponseDto, RsHttpClientError> {
        let response = self
            .inner
            .register(protocol, ip, port, payload)
            .await
            .map_err(RsHttpClientError::from)?;

        Ok(ResultWithPublicKeyRegisterResponseDto {
            public_key: response.public_key,
            body: response.body,
        })
    }

    pub async fn prepare_upload(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        payload: PrepareUploadRequestDto,
        public_key: Option<String>,
        pin: Option<String>,
        cancel_token: &RsCancellationToken,
    ) -> Result<PrepareUploadResult, RsHttpClientError> {
        let response = self
            .inner
            .prepare_upload(
                protocol,
                ip,
                port,
                public_key,
                payload,
                pin.as_deref(),
                cancel_token.inner.clone(),
            )
            .await
            .map_err(RsHttpClientError::from)?;

        Ok(response)
    }

    /// Uploads a single file, emitting [RsUploadEvent]s on [sink].
    ///
    /// Failures are emitted as [RsUploadEvent::Failed] instead of being
    /// returned: flutter_rust_bridge discards the returned `Result` of
    /// functions taking a [StreamSink], so a returned error would become an
    /// uncaught async error killing the calling isolate.
    pub async fn upload(
        &self,
        sink: StreamSink<RsUploadEvent>,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        session_id: &str,
        file_id: &str,
        token: &str,
        binary: Option<stream::Dart2RustStreamReceiver>,
        path: Option<String>,
        file_descriptor: Option<i32>,
        content_length: u64,
        cancel_token: &RsCancellationToken,
    ) {
        let result = async {
            let content = resolve_file_content(binary, path, file_descriptor)?;
            let last_emit = std::cell::Cell::new(None::<std::time::Instant>);
            let progress_sink = sink.clone();
            let progress = move |sent| {
                let now = std::time::Instant::now();
                let is_final = sent >= content_length;
                if !is_final {
                    if let Some(last) = last_emit.get() {
                        if now.duration_since(last) < std::time::Duration::from_millis(20) {
                            return;
                        }
                    }
                }
                last_emit.set(Some(now));
                let progress = if content_length == 0 {
                    1.0
                } else {
                    (sent as f64 / content_length as f64).min(1.0)
                };
                let _ = progress_sink.add(RsUploadEvent::Progress { progress });
            };

            self.inner
                .upload(
                    protocol,
                    ip,
                    port,
                    public_key,
                    session_id,
                    file_id,
                    token,
                    content,
                    progress,
                    cancel_token.inner.clone(),
                )
                .await
                .map_err(RsHttpClientError::from)?;

            Ok(())
        }
        .await;

        if let Err(error) = result {
            let _ = sink.add(RsUploadEvent::Failed { error });
        }
    }

    pub async fn cancel(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        session_id: &str,
    ) -> Result<(), RsHttpClientError> {
        self.inner
            .cancel(protocol, ip, port, session_id)
            .await
            .map_err(RsHttpClientError::from)?;

        Ok(())
    }

    #[frb(sync)]
    pub fn is_v3(&self) -> bool {
        self.inner.as_v3().is_some()
    }

    /// Orchestrates a V3 chunked transfer of a file, emitting [RsTransferEventV3]s on [sink].
    /// Progress events are throttled according to Master Spec Rule 34 (<= 10 updates/sec).
    pub async fn transfer_v3(
        &self,
        sink: StreamSink<RsTransferEventV3>,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        transfer_id: String,
        file_path: String,
        config: RsTransferConfigV3,
        cancel_token: &RsCancellationToken,
    ) {
        if file_path.starts_with("content://") {
            let _ = sink.add(RsTransferEventV3::Failed {
                error: RsTransferErrorV3::UnsupportedSource {
                    message: "Android Storage Access Framework content URIs are not yet supported for V3 direct chunk streaming".to_string(),
                },
            });
            return;
        }

        let client_v3 = match self.inner.as_v3() {
            Some(c) => c,
            None => {
                let _ = sink.add(RsTransferEventV3::Failed {
                    error: RsTransferErrorV3::InvalidConfiguration {
                        message: "HTTP client was not initialized for V3 protocol".to_string(),
                    },
                });
                return;
            }
        };

        let source_file = match locara::http::client::v3::SourceFileInfo::from_path(&file_path, false).await {
            Ok(s) => s,
            Err(e) => {
                let _ = sink.add(RsTransferEventV3::Failed {
                    error: map_client_error_v3(e),
                });
                return;
            }
        };

        let core_config = locara::http::client::v3::TransferConfigV3 {
            chunk_size: config.chunk_size,
            max_concurrency: config.max_concurrency as usize,
            max_retries: config.max_retries as usize,
            retry_base_delay: std::time::Duration::from_millis(config.retry_base_delay_ms as u64),
            retry_max_delay: std::time::Duration::from_millis(config.retry_max_delay_ms as u64),
            verify_chunk_hashes: config.verify_chunk_hashes,
        };

        // Master Spec Rule 34: Progress throttled to <= 10 updates/sec (100 ms min interval),
        // except 0% and 100% which emit immediately.
        let last_emit = std::sync::Arc::new(std::sync::Mutex::new(None::<Instant>));
        let progress_sink = sink.clone();
        let progress_cb = Arc::new(move |bytes_transferred: u64, total_bytes: u64| {
            let now = Instant::now();
            let is_boundary = bytes_transferred == 0 || bytes_transferred >= total_bytes;
            if !is_boundary {
                if let Ok(guard) = last_emit.lock() {
                    if let Some(last) = *guard {
                        if now.duration_since(last) < std::time::Duration::from_millis(100) {
                            return;
                        }
                    }
                }
            }
            if let Ok(mut guard) = last_emit.lock() {
                *guard = Some(now);
            }
            let progress = if total_bytes == 0 {
                1.0
            } else {
                (bytes_transferred as f64 / total_bytes as f64).min(1.0)
            };
            let _ = progress_sink.add(RsTransferEventV3::Progress {
                bytes_transferred,
                total_bytes,
                progress,
            });
        });

        let result = client_v3
            .transfer_file(
                protocol,
                ip,
                port,
                public_key,
                &source_file,
                &transfer_id,
                &core_config,
                Some(cancel_token.inner.clone()),
                Some(progress_cb),
            )
            .await;

        match result {
            Ok(res) => {
                let _ = sink.add(RsTransferEventV3::Success {
                    result: RsTransferResultV3 {
                        transfer_id: res.transfer_id,
                        file_name: res.file_name,
                        file_size: res.file_size,
                        total_chunks: res.total_chunks,
                        chunks_uploaded: res.chunks_uploaded,
                        chunks_resumed: res.chunks_resumed,
                    },
                });
            }
            Err(err) => {
                let _ = sink.add(RsTransferEventV3::Failed {
                    error: map_client_error_v3(err),
                });
            }
        }
    }
}

fn resolve_file_content(
    binary: Option<stream::Dart2RustStreamReceiver>,
    path: Option<String>,
    file_descriptor: Option<i32>,
) -> Result<locara::model::transfer::FileContent, RsHttpClientError> {
    match (binary, path, file_descriptor) {
        (Some(binary), None, None) => Ok(locara::model::transfer::FileContent::Stream(
            binary.receiver,
        )),
        (None, Some(path), None) => Ok(locara::model::transfer::FileContent::Path(path.into())),
        (None, None, Some(file_descriptor)) => {
            #[cfg(target_os = "android")]
            {
                Ok(locara::model::transfer::FileContent::Fd(file_descriptor))
            }
            #[cfg(not(target_os = "android"))]
            {
                let _ = file_descriptor;
                Err(RsHttpClientError::Other(
                    "File descriptors are only supported on Android".into(),
                ))
            }
        }
        _ => Err(RsHttpClientError::Other(
            "Exactly one upload content source must be provided".into(),
        )),
    }
}

/// An event emitted while a file is being uploaded by [RsHttpClient::upload].
#[derive(Clone)]
pub enum RsUploadEvent {
    /// The upload progress as a fraction (0.0 to 1.0). Throttled.
    Progress { progress: f64 },

    /// The upload failed. Always the last event of the stream.
    Failed { error: RsHttpClientError },
}

#[derive(Clone)]
pub enum RsHttpClientError {
    StatusCode {
        status: u16,
        message: Option<String>,
    },
    Reqwest(String),
    Json(String),
    Io(String),
    Other(String),
}

impl From<ClientError> for RsHttpClientError {
    fn from(e: ClientError) -> Self {
        match e {
            ClientError::StatusCode(e) => RsHttpClientError::StatusCode {
                status: e.status,
                message: e.message,
            },
            ClientError::Reqwest(e) => RsHttpClientError::Reqwest(ErrorChain(&e).to_string()),
            ClientError::Json(e) => RsHttpClientError::Json(e.to_string()),
            ClientError::Io(e) => RsHttpClientError::Io(e.to_string()),
            ClientError::Other(e) => RsHttpClientError::Other(e.to_string()),
            ClientError::Cancelled => RsHttpClientError::Other("Upload cancelled".to_string()),
        }
    }
}

#[frb(mirror(LsHttpClientVersion))]
pub enum _LsHttpClientVersion {
    V2,
    V3,
}

#[frb(mirror(PrepareUploadResult))]
pub struct _PrepareUploadResult {
    pub status_code: u16,
    pub response: Option<PrepareUploadResponseDto>,
}

pub struct ResultWithPublicKeyRegisterResponseDto {
    pub public_key: Option<String>,
    pub body: RegisterResponseDto,
}

#[frb(sync)]
pub fn validate_source_file_v3(file_path: String) -> Result<RsSourceFileInfoV3, RsTransferErrorV3> {
    if file_path.starts_with("content://") {
        return Err(RsTransferErrorV3::UnsupportedSource {
            message: "Android Storage Access Framework content URIs are not yet supported for V3 direct chunk streaming".to_string(),
        });
    }

    let path = std::path::Path::new(&file_path);
    if !path.is_file() {
        return Err(RsTransferErrorV3::UnsupportedSource {
            message: format!("Source path is not a regular file: {}", file_path),
        });
    }

    let file_name = path
        .file_name()
        .and_then(|n| n.to_str())
        .ok_or_else(|| RsTransferErrorV3::InvalidConfiguration {
            message: format!("Invalid file name for path: {}", file_path),
        })?
        .to_string();

    locara::model::dto_v3::validate_filename(&file_name).map_err(|e| {
        RsTransferErrorV3::InvalidConfiguration {
            message: format!("Invalid file name '{}': {}", file_name, e),
        }
    })?;

    let meta = std::fs::metadata(path).map_err(|e| RsTransferErrorV3::Unexpected {
        message: format!("Failed to stat source file: {}", e),
    })?;

    let file_size = meta.len();
    if file_size > locara::model::dto_v3::MAX_FILE_SIZE {
        return Err(RsTransferErrorV3::InvalidConfiguration {
            message: format!(
                "File size {} exceeds maximum allowed ({})",
                file_size,
                locara::model::dto_v3::MAX_FILE_SIZE
            ),
        });
    }

    Ok(RsSourceFileInfoV3 {
        path: file_path,
        file_name,
        file_size,
    })
}

/// Configuration options for V3 transfer orchestration.
#[derive(Clone, Debug)]
pub struct RsTransferConfigV3 {
    pub chunk_size: u64,
    pub max_concurrency: u32,
    pub max_retries: u32,
    pub retry_base_delay_ms: u32,
    pub retry_max_delay_ms: u32,
    pub verify_chunk_hashes: bool,
}

impl Default for RsTransferConfigV3 {
    fn default() -> Self {
        Self {
            chunk_size: locara::model::dto_v3::DEFAULT_CHUNK_SIZE,
            max_concurrency: 1,
            max_retries: 3,
            retry_base_delay_ms: 200,
            retry_max_delay_ms: 2000,
            verify_chunk_hashes: true,
        }
    }
}

/// Detailed outcome of a completed V3 file transfer.
#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RsTransferResultV3 {
    pub transfer_id: String,
    pub file_name: String,
    pub file_size: u64,
    pub total_chunks: u64,
    pub chunks_uploaded: u64,
    pub chunks_resumed: u64,
}

/// Validated source file metadata for V3 chunk transfers.
#[derive(Clone, Debug)]
pub struct RsSourceFileInfoV3 {
    pub path: String,
    pub file_name: String,
    pub file_size: u64,
}

/// Structured, actionable transfer error categories without sensitive data leakage.
#[derive(Clone, Debug, PartialEq, Eq)]
pub enum RsTransferErrorV3 {
    InvalidConfiguration { message: String },
    UnsupportedSource { message: String },
    SourceChanged { message: String },
    NetworkOrTimeout { message: String },
    PeerIdentityMismatch { message: String },
    Conflict { message: String },
    IntegrityVerificationFailed { message: String },
    DestinationCollision { message: String },
    InsufficientStorage { message: String },
    Cancelled,
    Unexpected { message: String },
}

/// Events emitted during V3 file transfer orchestration.
#[derive(Clone, Debug)]
pub enum RsTransferEventV3 {
    Progress {
        bytes_transferred: u64,
        total_bytes: u64,
        progress: f64,
    },
    Success {
        result: RsTransferResultV3,
    },
    Failed {
        error: RsTransferErrorV3,
    },
}

fn map_client_error_v3(e: ClientError) -> RsTransferErrorV3 {
    match e {
        ClientError::Cancelled => RsTransferErrorV3::Cancelled,
        ClientError::StatusCode(status_err) => {
            let msg = status_err.message.unwrap_or_default();
            match status_err.status {
                403 => RsTransferErrorV3::PeerIdentityMismatch {
                    message: if msg.is_empty() {
                        "Peer authentication or certificate mismatch (HTTP 403)".to_string()
                    } else {
                        format!("Peer authentication or pin mismatch (HTTP 403): {}", msg)
                    },
                },
                409 => {
                    let msg_lower = msg.to_lowercase();
                    if msg_lower.contains("exist")
                        || msg_lower.contains("collision")
                        || msg_lower.contains("destination")
                    {
                        RsTransferErrorV3::DestinationCollision {
                            message: if msg.is_empty() {
                                "Destination file already exists on receiving device".to_string()
                            } else {
                                msg
                            },
                        }
                    } else {
                        RsTransferErrorV3::Conflict {
                            message: if msg.is_empty() {
                                "Transfer session conflict or concurrent transfer in progress (HTTP 409)".to_string()
                            } else {
                                msg
                            },
                        }
                    }
                }
                422 => RsTransferErrorV3::IntegrityVerificationFailed {
                    message: if msg.is_empty() {
                        "File data failed integrity checksum verification (HTTP 422)".to_string()
                    } else {
                        msg
                    },
                },
                507 => RsTransferErrorV3::InsufficientStorage {
                    message: if msg.is_empty() {
                        "Receiver has insufficient disk space (HTTP 507)".to_string()
                    } else {
                        msg
                    },
                },
                408 | 502 | 503 | 504 => RsTransferErrorV3::NetworkOrTimeout {
                    message: format!("HTTP gateway or timeout error ({}): {}", status_err.status, msg),
                },
                other => RsTransferErrorV3::Unexpected {
                    message: format!("Server returned error HTTP {}: {}", other, msg),
                },
            }
        }
        ClientError::Reqwest(err) => RsTransferErrorV3::NetworkOrTimeout {
            message: format!("Network request failed: {}", err),
        },
        ClientError::Io(err) => RsTransferErrorV3::Unexpected {
            message: format!("I/O error during transfer: {}", err),
        },
        ClientError::Json(err) => RsTransferErrorV3::Unexpected {
            message: format!("Protocol serialization error: {}", err),
        },
        ClientError::Other(err) => {
            let s = err.to_string();
            let s_lower = s.to_lowercase();
            if s_lower.contains("changed during transfer") || s_lower.contains("no longer a regular file") {
                RsTransferErrorV3::SourceChanged {
                    message: "Source file size or modification time changed during transfer".to_string(),
                }
            } else if s_lower.contains("invalid file name")
                || s_lower.contains("invalid chunk_size")
                || s_lower.contains("invalid transfer_id")
                || s_lower.contains("invalid manifest")
            {
                RsTransferErrorV3::InvalidConfiguration { message: s }
            } else if s_lower.contains("storage access framework") || s_lower.contains("content://") {
                RsTransferErrorV3::UnsupportedSource { message: s }
            } else {
                RsTransferErrorV3::Unexpected { message: s }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_validate_source_file_v3_unsupported_content_uri() {
        let err = validate_source_file_v3("content://media/external/images/media/123".to_string()).unwrap_err();
        assert!(matches!(err, RsTransferErrorV3::UnsupportedSource { .. }));
    }

    #[test]
    fn test_validate_source_file_v3_nonexistent_file() {
        let err = validate_source_file_v3("nonexistent_file_path_12345.bin".to_string()).unwrap_err();
        assert!(matches!(err, RsTransferErrorV3::UnsupportedSource { .. }));
    }

    #[test]
    fn test_validate_source_file_v3_valid_file() {
        let file_path = std::env::temp_dir().join(format!("locara_test_{}.txt", uuid::Uuid::new_v4()));
        std::fs::write(&file_path, b"hello world").unwrap();

        let info = validate_source_file_v3(file_path.to_str().unwrap().to_string()).unwrap();
        assert!(info.file_name.starts_with("locara_test_"));
        assert_eq!(info.file_size, 11);

        let _ = std::fs::remove_file(file_path);
    }

    #[test]
    fn test_map_client_error_v3_categories() {
        let err_cancel = map_client_error_v3(ClientError::Cancelled);
        assert_eq!(err_cancel, RsTransferErrorV3::Cancelled);

        let err_403 = map_client_error_v3(ClientError::StatusCode(locara::http::StatusCodeError {
            status: 403,
            message: Some("forbidden".into()),
        }));
        assert!(matches!(err_403, RsTransferErrorV3::PeerIdentityMismatch { .. }));

        let err_409 = map_client_error_v3(ClientError::StatusCode(locara::http::StatusCodeError {
            status: 409,
            message: Some("conflict".into()),
        }));
        assert!(matches!(err_409, RsTransferErrorV3::Conflict { .. }));

        let err_collision = map_client_error_v3(ClientError::StatusCode(locara::http::StatusCodeError {
            status: 409,
            message: Some("file already exists".into()),
        }));
        assert!(matches!(err_collision, RsTransferErrorV3::DestinationCollision { .. }));

        let err_422 = map_client_error_v3(ClientError::StatusCode(locara::http::StatusCodeError {
            status: 422,
            message: Some("bad sha256".into()),
        }));
        assert!(matches!(err_422, RsTransferErrorV3::IntegrityVerificationFailed { .. }));

        let err_507 = map_client_error_v3(ClientError::StatusCode(locara::http::StatusCodeError {
            status: 507,
            message: Some("out of disk".into()),
        }));
        assert!(matches!(err_507, RsTransferErrorV3::InsufficientStorage { .. }));
    }
}

