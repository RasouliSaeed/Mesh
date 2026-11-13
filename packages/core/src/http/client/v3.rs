use super::{ClientError, ResponseExt, ResultWithPublicKey};
use crate::http;
use crate::http::client::url::{ApiVersion, TargetUrl};
use crate::model::discovery::ProtocolType;
use crate::model::dto_v3::{
    calculate_chunk_count, validate_filename, DEFAULT_CHUNK_SIZE, MAX_CHUNK_SIZE,
    MAX_FILE_SIZE, ManifestResponseDto, TransferManifestDto,
};
use crate::model::resume::ResumeManager;
use crate::{crypto, util};
use futures_util::stream::{self, TryStreamExt};
use lru::LruCache;
use reqwest::{Response, StatusCode};
use std::num::NonZeroUsize;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::Arc;
use std::time::{Duration, SystemTime};
use tokio::sync::Mutex;
use tokio_util::sync::CancellationToken;

#[derive(Clone)]
pub struct LsHttpClientV3 {

    client: reqwest::Client,

    /// Maps client identifiers to nonces that have been received from remote.
    received_nonce_map: Arc<Mutex<LruCache<String, Vec<u8>>>>,

    /// Maps client identifiers to nonces that are expected to be received from remote.
    generated_nonce_map: Arc<Mutex<LruCache<String, Vec<u8>>>>,
}

impl LsHttpClientV3 {
    pub fn try_new(
        private_key: &str,
        cert: &str,
        expected_fingerprint: Option<String>,
        timeout: Option<std::time::Duration>,
    ) -> Result<Self, ClientError> {
        Ok(Self {
            client: super::create_reqwest_client(private_key, cert, expected_fingerprint, timeout)?,
            received_nonce_map: Arc::new(Mutex::new(LruCache::new(
                NonZeroUsize::new(200).unwrap(),
            ))),
            generated_nonce_map: Arc::new(Mutex::new(LruCache::new(
                NonZeroUsize::new(200).unwrap(),
            ))),
        })
    }

    /// Creates a new HTTP client without TLS client certificate.
    ///
    /// Use this for HTTP-only connections or when client authentication is not needed.
    pub fn try_new_without_cert() -> Result<Self, ClientError> {
        let _ = rustls::crypto::ring::default_provider().install_default();

        let client = reqwest::Client::builder()
            .use_rustls_tls()
            .danger_accept_invalid_certs(true)
            .tls_info(true)
            .no_proxy()
            .redirect(reqwest::redirect::Policy::none())
            .build()?;

        Ok(Self {
            client,
            received_nonce_map: Arc::new(Mutex::new(LruCache::new(
                NonZeroUsize::new(200).unwrap(),
            ))),
            generated_nonce_map: Arc::new(Mutex::new(LruCache::new(
                NonZeroUsize::new(200).unwrap(),
            ))),
        })
    }

    pub async fn nonce(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
    ) -> Result<String, ClientError> {
        // Generate nonce to send to server
        let generated_nonce = crypto::nonce::generate_nonce();
        let generated_nonce_base64 = util::base64::encode(&generated_nonce);

        let request_body = http::dto::NonceRequest {
            nonce: generated_nonce_base64,
        };

        let res = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/nonce",
                    params: &[],
                }
                .to_string(),
            )
            .body(serde_json::to_string(&request_body)?)
            .send()
            .await?;

        if res.status() != StatusCode::OK {
            return res.into_error().await;
        }

        let remote_key = to_identifier(&res, protocol == ProtocolType::Https, None)?;
        let body = res.json::<http::dto::NonceResponse>().await?;

        // Save the response nonce and our generated nonce
        let response_nonce = util::base64::decode(&body.nonce).map_err(|e| anyhow::anyhow!(e))?;

        let mut received_nonce_map = self.received_nonce_map.lock().await;
        received_nonce_map.put(remote_key.clone(), response_nonce);

        let mut generated_nonce_map = self.generated_nonce_map.lock().await;
        generated_nonce_map.put(remote_key.clone(), generated_nonce);

        tracing::info!("Nonce exchange successful for server: {ip} (ID: {remote_key})");

        tracing::debug!(
            "Received map: {:?}",
            received_nonce_map.get(&remote_key).unwrap()
        );
        tracing::debug!(
            "Generated map: {:?}",
            generated_nonce_map.get(&remote_key).unwrap()
        );

        Ok(body.nonce)
    }

    pub async fn register(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        payload: http::dto::RegisterDto,
    ) -> Result<ResultWithPublicKey<http::dto::RegisterResponseDto>, ClientError> {
        let res = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/register",
                    params: &[],
                }
                .to_string(),
            )
            .body(serde_json::to_string(&payload)?)
            .send()
            .await?;

        let (public_key, cert_fingerprint) = match protocol {
            ProtocolType::Https => (
                Some(super::verify_cert_from_res(&res, None)?),
                Some(super::cert_fingerprint_from_res(&res)?),
            ),
            _ => (None, None),
        };

        let body = res.json::<http::dto::RegisterResponseDto>().await?;

        Ok(ResultWithPublicKey {
            public_key,
            cert_fingerprint,
            body,
        })
    }

    /// `cancel` is a cancellation token; cancelling it aborts the request with
    /// [`ClientError::Cancelled`]. Aborting closes the connection, which tells
    /// the receiver that the sender is no longer waiting for a decision.
    pub async fn prepare_upload(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        payload: http::dto::PrepareUploadRequestDto,
        cancel: CancellationToken,
    ) -> Result<http::dto::PrepareUploadResult, ClientError> {
        let send = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/prepare-upload",
                    params: &[],
                }
                .to_string(),
            )
            .body(serde_json::to_string(&payload)?)
            .send();

        let res = tokio::select! {
            res = send => res?,
            _ = cancel.cancelled() => return Err(ClientError::Cancelled),
        };

        if protocol == ProtocolType::Https {
            super::verify_cert_from_res(&res, public_key)?;
        }

        let status = res.status();

        if status.as_u16() >= 400 {
            return res.into_error().await;
        }

        if status == StatusCode::NO_CONTENT {
            return Ok(http::dto::PrepareUploadResult {
                status_code: status.as_u16(),
                response: None,
            });
        }

        let body = res.json::<http::dto::PrepareUploadResponseDto>().await?;

        Ok(http::dto::PrepareUploadResult {
            status_code: status.as_u16(),
            response: Some(body),
        })
    }

    /// Uploads a file to the server.
    ///
    /// `body` is the streaming request body carrying the file content.
    ///
    /// `cancel` is a cancellation token; cancelling it aborts the upload with
    /// [`ClientError::Cancelled`].
    pub async fn upload(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        session_id: &str,
        file_id: &str,
        token: &str,
        body: reqwest::Body,
        cancel: CancellationToken,
    ) -> Result<(), ClientError> {
        let send = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/upload",
                    params: &[
                        ("sessionId", &session_id),
                        ("fileId", &file_id),
                        ("token", &token),
                    ],
                }
                .to_string(),
            )
            .body(body)
            .send();

        let res = tokio::select! {
            res = send => res?,
            _ = cancel.cancelled() => return Err(ClientError::Cancelled),
        };

        if protocol == ProtocolType::Https {
            super::verify_cert_from_res(&res, public_key)?;
        }

        if res.status() != StatusCode::OK {
            return res.into_error().await;
        }

        Ok(())
    }

    pub async fn cancel(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        session_id: &str,
    ) -> Result<(), ClientError> {
        self.client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/cancel",
                    params: &[("sessionId", session_id)],
                }
                .to_string(),
            )
            .send()
            .await?;

        Ok(())
    }

    /// Sends a transfer manifest to the V3 server to initialize or resume a transfer session.
    pub async fn manifest(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        manifest: TransferManifestDto,
    ) -> Result<ManifestResponseDto, ClientError> {
        let res = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/manifest",
                    params: &[],
                }
                .to_string(),
            )
            .body(serde_json::to_string(&manifest)?)
            .send()
            .await?;

        if protocol == ProtocolType::Https {
            super::verify_cert_from_res(&res, public_key)?;
        }

        if res.status() != StatusCode::OK {
            return res.into_error().await;
        }

        let body = res.json::<ManifestResponseDto>().await?;
        Ok(body)
    }

    /// Uploads a single chunk of data to the V3 server.
    pub async fn upload_chunk(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        session_id: &str,
        chunk_index: u64,
        chunk_hash: Option<&str>,
        body: Vec<u8>,
        cancel: Option<CancellationToken>,
    ) -> Result<(), ClientError> {
        let chunk_index_str = chunk_index.to_string();
        let mut params = vec![
            ("sessionId", session_id),
            ("chunkIndex", chunk_index_str.as_str()),
        ];
        if let Some(hash) = chunk_hash {
            params.push(("chunkHash", hash));
        }

        let send = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/chunk",
                    params: &params,
                }
                .to_string(),
            )
            .body(body)
            .send();

        let res = match cancel {
            Some(cancel) => tokio::select! {
                res = send => res?,
                _ = cancel.cancelled() => return Err(ClientError::Cancelled),
            },
            None => send.await?,
        };

        if protocol == ProtocolType::Https {
            super::verify_cert_from_res(&res, public_key)?;
        }

        if res.status() != StatusCode::OK {
            return res.into_error().await;
        }

        Ok(())
    }

    /// Requests the server to verify integrity and commit the completed transfer.
    pub async fn commit(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        session_id: &str,
        cancel: Option<CancellationToken>,
    ) -> Result<(), ClientError> {
        let send = self
            .client
            .post(
                TargetUrl {
                    version: ApiVersion::V3,
                    protocol: protocol.as_str(),
                    host: ip.to_string(),
                    port,
                    path: "/commit",
                    params: &[("sessionId", session_id)],
                }
                .to_string(),
            )
            .send();

        let res = match cancel {
            Some(cancel) => tokio::select! {
                res = send => res?,
                _ = cancel.cancelled() => return Err(ClientError::Cancelled),
            },
            None => send.await?,
        };

        if protocol == ProtocolType::Https {
            super::verify_cert_from_res(&res, public_key)?;
        }

        if res.status() != StatusCode::OK {
            return res.into_error().await;
        }

        Ok(())
    }

    /// Executes an operation with bounded retries for transient errors.
    async fn execute_with_retry<T, F, Fut>(&self, config: &TransferConfigV3, op: F) -> Result<T, ClientError>
    where
        F: Fn() -> Fut,
        Fut: std::future::Future<Output = Result<T, ClientError>>,
    {
        let mut attempt = 0;
        let mut delay = config.retry_base_delay;

        loop {
            attempt += 1;
            match op().await {
                Ok(val) => return Ok(val),
                Err(err) => {
                    if attempt > config.max_retries || !is_transient_error(&err) {
                        return Err(err);
                    }
                    tracing::warn!(
                        "Transient error on attempt {}/{}: {:?}. Retrying in {:?}...",
                        attempt,
                        config.max_retries,
                        err,
                        delay
                    );
                    tokio::time::sleep(delay).await;
                    delay = (delay * 2).min(config.retry_max_delay);
                }
            }
        }
    }

    /// Orchestrates a complete V3 file transfer:
    /// 1. Validates file metadata and limits.
    /// 2. Negotiates or resumes manifest with the server.
    /// 3. Uploads missing chunks with bounded memory and concurrency.
    /// 4. Verifies source integrity and commits atomically.
    pub async fn transfer_file(
        &self,
        protocol: ProtocolType,
        ip: &str,
        port: u16,
        public_key: Option<String>,
        source_file: &SourceFileInfo,
        transfer_id: &str,
        config: &TransferConfigV3,
        cancel: Option<CancellationToken>,
        progress: Option<Arc<dyn Fn(u64, u64) + Send + Sync>>,
    ) -> Result<TransferResultV3, ClientError> {
        if config.chunk_size == 0 || config.chunk_size > MAX_CHUNK_SIZE {
            return Err(ClientError::Other(anyhow::anyhow!(
                "Invalid chunk_size {}: must be 1..={}",
                config.chunk_size,
                MAX_CHUNK_SIZE
            )));
        }

        let concurrency = config.max_concurrency.clamp(1, 16);

        // 1. Initial source verification
        source_file.verify_unchanged().await?;

        // 2. Build manifest
        let manifest = source_file.create_manifest(transfer_id.to_string(), config.chunk_size)?;

        // 3. Handle zero-byte files
        if manifest.file_size == 0 {
            let manifest_resp = self
                .execute_with_retry(config, || {
                    let m = manifest.clone();
                    let pk = public_key.clone();
                    async { self.manifest(protocol, ip, port, pk, m).await }
                })
                .await?;

            if manifest_resp.session_id != manifest.transfer_id {
                return Err(ClientError::Other(anyhow::anyhow!(
                    "Server returned session_id '{}' which does not match transfer_id '{}'",
                    manifest_resp.session_id,
                    manifest.transfer_id
                )));
            }

            if !manifest_resp.missing_chunks.is_empty() {
                return Err(ClientError::Other(anyhow::anyhow!(
                    "Zero-byte file cannot have missing chunks, server returned: {:?}",
                    manifest_resp.missing_chunks
                )));
            }

            // Commit zero-byte file
            self.execute_with_retry(config, || {
                let pk = public_key.clone();
                let sid = manifest_resp.session_id.clone();
                let c = cancel.clone();
                async move { self.commit(protocol, ip, port, pk, &sid, c).await }
            })
            .await?;

            if let Some(ref p) = progress {
                p(0, 0);
            }

            return Ok(TransferResultV3 {
                transfer_id: transfer_id.to_string(),
                file_name: source_file.file_name.clone(),
                file_size: 0,
                total_chunks: 0,
                chunks_uploaded: 0,
                chunks_resumed: 0,
            });
        }

        // 4. Send manifest for regular file
        let manifest_resp = self
            .execute_with_retry(config, || {
                let m = manifest.clone();
                let pk = public_key.clone();
                async { self.manifest(protocol, ip, port, pk, m).await }
            })
            .await?;

        // 5. Validate server response
        if manifest_resp.session_id != manifest.transfer_id {
            return Err(ClientError::Other(anyhow::anyhow!(
                "Server returned session_id '{}' which does not match transfer_id '{}'",
                manifest_resp.session_id,
                manifest.transfer_id
            )));
        }

        let mut seen_indices = std::collections::HashSet::new();
        for &idx in &manifest_resp.missing_chunks {
            if idx >= manifest.total_chunks {
                return Err(ClientError::Other(anyhow::anyhow!(
                    "Server returned invalid missing chunk index {} (total_chunks={})",
                    idx,
                    manifest.total_chunks
                )));
            }
            if !seen_indices.insert(idx) {
                return Err(ClientError::Other(anyhow::anyhow!(
                    "Server returned duplicate missing chunk index {}",
                    idx
                )));
            }
        }

        let total_chunks = manifest.total_chunks;
        let chunks_to_upload = manifest_resp.missing_chunks.clone();
        let chunks_resumed = total_chunks.saturating_sub(chunks_to_upload.len() as u64);

        // Calculate initial transferred bytes from already-completed chunks
        let mut initial_bytes = 0u64;
        for i in 0..total_chunks {
            if !seen_indices.contains(&i) {
                let offset = i.checked_mul(manifest.chunk_size).ok_or_else(|| {
                    ClientError::Other(anyhow::anyhow!("Offset overflow"))
                })?;
                let chunk_len = if i == total_chunks - 1 {
                    manifest.file_size.checked_sub(offset).ok_or_else(|| {
                        ClientError::Other(anyhow::anyhow!("Final chunk offset exceeds file size"))
                    })?
                } else {
                    manifest.chunk_size
                };
                initial_bytes = initial_bytes.saturating_add(chunk_len);
            }
        }

        if let Some(ref p) = progress {
            p(initial_bytes, manifest.file_size);
        }

        // 6. Upload missing chunks with bounded memory and concurrency
        let transferred_bytes = Arc::new(AtomicU64::new(initial_bytes));
        let uploaded_count = Arc::new(AtomicU64::new(0));

        if !chunks_to_upload.is_empty() {
            let file = Arc::new(tokio::sync::Mutex::new(
                tokio::fs::File::open(&source_file.path).await?,
            ));

            let stream = stream::iter(chunks_to_upload.into_iter().map(Ok));
            let chunk_size = manifest.chunk_size;
            let file_size = manifest.file_size;
            let session_id = manifest_resp.session_id.clone();

            stream
                .try_for_each_concurrent(concurrency, |chunk_index| {
                    let file = file.clone();
                    let source_file = source_file.clone();
                    let cancel = cancel.clone();
                    let session_id = session_id.clone();
                    let transferred_bytes = transferred_bytes.clone();
                    let uploaded_count = uploaded_count.clone();
                    let progress = progress.clone();
                    let public_key = public_key.clone();

                    async move {
                        if let Some(ref c) = cancel {
                            if c.is_cancelled() {
                                return Err(ClientError::Cancelled);
                            }
                        }

                        source_file.verify_unchanged().await?;

                        let offset = chunk_index.checked_mul(chunk_size).ok_or_else(|| {
                            ClientError::Other(anyhow::anyhow!("Chunk offset calculation overflow"))
                        })?;

                        let expected_len = if chunk_index == total_chunks - 1 {
                            file_size.checked_sub(offset).ok_or_else(|| {
                                ClientError::Other(anyhow::anyhow!(
                                    "Final chunk offset exceeds declared file size"
                                ))
                            })?
                        } else {
                            chunk_size
                        };

                        if offset.checked_add(expected_len).map_or(true, |end| end > file_size) {
                            return Err(ClientError::Other(anyhow::anyhow!(
                                "Chunk extends beyond declared file size"
                            )));
                        }

                        let chunk_bytes = {
                            use std::io::SeekFrom;
                            use tokio::io::{AsyncReadExt, AsyncSeekExt};

                            let mut f = file.lock().await;
                            f.seek(SeekFrom::Start(offset)).await?;
                            let mut buf = vec![0u8; expected_len as usize];
                            f.read_exact(&mut buf).await?;
                            buf
                        };

                        let chunk_hash = if config.verify_chunk_hashes {
                            Some(crate::crypto::hash::sha256_hex(&chunk_bytes))
                        } else {
                            None
                        };

                        self.execute_with_retry(config, || {
                            let chunk_bytes = chunk_bytes.clone();
                            let cancel = cancel.clone();
                            let hash = chunk_hash.clone();
                            let session_id = session_id.clone();
                            let pk = public_key.clone();
                            async move {
                                self.upload_chunk(
                                    protocol,
                                    ip,
                                    port,
                                    pk,
                                    &session_id,
                                    chunk_index,
                                    hash.as_deref(),
                                    chunk_bytes,
                                    cancel,
                                )
                                .await
                            }
                        })
                        .await?;

                        drop(chunk_bytes);
                        uploaded_count.fetch_add(1, Ordering::SeqCst);
                        let current = transferred_bytes.fetch_add(expected_len, Ordering::SeqCst)
                            + expected_len;
                        if let Some(ref p) = progress {
                            p(current, file_size);
                        }

                        Ok(())
                    }
                })
                .await?;
        }

        // 7. Commit verification and atomic publish
        source_file.verify_unchanged().await?;

        self.execute_with_retry(config, || {
            let pk = public_key.clone();
            let sid = manifest_resp.session_id.clone();
            let c = cancel.clone();
            async move { self.commit(protocol, ip, port, pk, &sid, c).await }
        })
        .await?;

        Ok(TransferResultV3 {
            transfer_id: transfer_id.to_string(),
            file_name: source_file.file_name.clone(),
            file_size: manifest.file_size,
            total_chunks,
            chunks_uploaded: uploaded_count.load(Ordering::SeqCst),
            chunks_resumed,
        })
    }
}

/// Configuration options for V3 chunk transfer orchestration.
#[derive(Debug, Clone)]
pub struct TransferConfigV3 {
    /// Chunk size in bytes. Default: 1 MiB (1,048,576 bytes). Maximum: 16 MiB.
    pub chunk_size: u64,
    /// Maximum concurrent chunk uploads. Default: 1. Bounded to prevent excessive memory/socket usage.
    pub max_concurrency: usize,
    /// Maximum retry attempts for transient errors per operation/chunk. Default: 3.
    pub max_retries: usize,
    /// Base delay for exponential backoff. Default: 200 ms.
    pub retry_base_delay: Duration,
    /// Maximum delay for exponential backoff. Default: 2 seconds.
    pub retry_max_delay: Duration,
    /// Whether to compute and send individual chunk SHA-256 hashes. Default: true.
    pub verify_chunk_hashes: bool,
}

impl Default for TransferConfigV3 {
    fn default() -> Self {
        Self {
            chunk_size: DEFAULT_CHUNK_SIZE,
            max_concurrency: 1,
            max_retries: 3,
            retry_base_delay: Duration::from_millis(200),
            retry_max_delay: Duration::from_secs(2),
            verify_chunk_hashes: true,
        }
    }
}

/// Captures source file identity and metadata for transfer validation and change detection.
#[derive(Debug, Clone)]
pub struct SourceFileInfo {
    pub path: PathBuf,
    pub file_name: String,
    pub file_size: u64,
    pub modified: Option<SystemTime>,
    pub sha256: Option<String>,
}

impl SourceFileInfo {
    /// Inspects the file at `path`, reading its metadata and optionally computing a streaming SHA-256.
    pub async fn from_path(path: impl AsRef<Path>, compute_sha256: bool) -> Result<Self, ClientError> {
        let path = path.as_ref().to_path_buf();
        let meta = tokio::fs::metadata(&path).await?;
        if !meta.is_file() {
            return Err(ClientError::Other(anyhow::anyhow!(
                "Source path is not a regular file: {:?}",
                path
            )));
        }

        let file_name = path
            .file_name()
            .and_then(|n| n.to_str())
            .ok_or_else(|| anyhow::anyhow!("Invalid file name for path {:?}", path))?
            .to_string();

        validate_filename(&file_name)
            .map_err(|e| ClientError::Other(anyhow::anyhow!("Invalid file name '{}': {}", file_name, e)))?;

        let file_size = meta.len();
        if file_size > MAX_FILE_SIZE {
            return Err(ClientError::Other(anyhow::anyhow!(
                "File size {} exceeds maximum allowed ({})",
                file_size,
                MAX_FILE_SIZE
            )));
        }

        let modified = meta.modified().ok();

        let sha256 = if compute_sha256 {
            Some(compute_streaming_sha256(&path).await?)
        } else {
            None
        };

        Ok(Self {
            path,
            file_name,
            file_size,
            modified,
            sha256,
        })
    }

    /// Creates a `SourceFileInfo` with pre-computed values, validating filename and file size limits.
    pub fn new(
        path: PathBuf,
        file_name: String,
        file_size: u64,
        modified: Option<SystemTime>,
        sha256: Option<String>,
    ) -> Result<Self, ClientError> {
        validate_filename(&file_name)
            .map_err(|e| ClientError::Other(anyhow::anyhow!("Invalid file name '{}': {}", file_name, e)))?;

        if file_size > MAX_FILE_SIZE {
            return Err(ClientError::Other(anyhow::anyhow!(
                "File size {} exceeds maximum allowed ({})",
                file_size,
                MAX_FILE_SIZE
            )));
        }

        Ok(Self {
            path,
            file_name,
            file_size,
            modified,
            sha256,
        })
    }

    /// Verifies that the source file on disk still exists and its size/mtime have not changed.
    pub async fn verify_unchanged(&self) -> Result<(), ClientError> {
        let meta = tokio::fs::metadata(&self.path).await.map_err(|e| {
            ClientError::Other(anyhow::anyhow!("Failed to stat source file {:?}: {}", self.path, e))
        })?;

        if !meta.is_file() {
            return Err(ClientError::Other(anyhow::anyhow!(
                "Source file {:?} is no longer a regular file",
                self.path
            )));
        }

        if meta.len() != self.file_size {
            return Err(ClientError::Other(anyhow::anyhow!(
                "Source file {:?} size changed during transfer: expected {} bytes, found {} bytes",
                self.path,
                self.file_size,
                meta.len()
            )));
        }

        if let Some(expected_mod) = self.modified {
            if let Ok(current_mod) = meta.modified() {
                if current_mod != expected_mod {
                    return Err(ClientError::Other(anyhow::anyhow!(
                        "Source file {:?} modification time changed during transfer",
                        self.path
                    )));
                }
            }
        }

        Ok(())
    }

    /// Creates a validated `TransferManifestDto` for the given transfer ID and chunk size.
    pub fn create_manifest(
        &self,
        transfer_id: String,
        chunk_size: u64,
    ) -> Result<TransferManifestDto, ClientError> {
        ResumeManager::validate_transfer_id(&transfer_id)
            .map_err(|e| ClientError::Other(anyhow::anyhow!("Invalid transfer_id: {}", e)))?;

        validate_filename(&self.file_name)
            .map_err(|e| ClientError::Other(anyhow::anyhow!("Invalid file_name: {}", e)))?;

        let total_chunks = calculate_chunk_count(self.file_size, chunk_size)
            .map_err(|e| ClientError::Other(anyhow::anyhow!("Invalid manifest parameters: {}", e)))?;

        Ok(TransferManifestDto {
            transfer_id,
            file_name: self.file_name.clone(),
            file_size: self.file_size,
            chunk_size,
            total_chunks,
            expected_sha256: self.sha256.clone(),
        })
    }
}

/// Computes the SHA-256 hash of a file using a streaming 64 KiB buffer without buffering the entire file into memory.
pub async fn compute_streaming_sha256(path: &Path) -> Result<String, std::io::Error> {
    use sha2::{Digest, Sha256};
    use tokio::io::AsyncReadExt;

    let mut file = tokio::fs::File::open(path).await?;
    let mut hasher = Sha256::new();
    let mut buf = vec![0u8; 65536]; // 64 KiB bounded buffer

    loop {
        let n = file.read(&mut buf).await?;
        if n == 0 {
            break;
        }
        hasher.update(&buf[..n]);
    }

    Ok(crate::crypto::hash::to_hex(&hasher.finalize()))
}

/// Detailed summary of a completed V3 transfer.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TransferResultV3 {
    pub transfer_id: String,
    pub file_name: String,
    pub file_size: u64,
    pub total_chunks: u64,
    pub chunks_uploaded: u64,
    pub chunks_resumed: u64,
}

/// Classifies whether a `ClientError` represents a temporary, retryable condition
/// (e.g. transient network drops, request timeouts, 503 service unavailable).
///
/// Permanent failures (400 Bad Request, 403 Forbidden, 404 Not Found, 409 Conflict,
/// 413 Payload Too Large, 422 Unprocessable Entity, 507 Insufficient Storage, Cancelled)
/// are explicitly classified as non-transient and must NOT be retried.
pub fn is_transient_error(err: &ClientError) -> bool {
    match err {
        ClientError::StatusCode(status_err) => {
            matches!(status_err.status, 429 | 502 | 503 | 504)
        }
        ClientError::Reqwest(req_err) => {
            req_err.is_timeout() || req_err.is_connect() || req_err.is_request()
        }
        ClientError::Io(io_err) => {
            use std::io::ErrorKind;
            matches!(
                io_err.kind(),
                ErrorKind::ConnectionReset
                    | ErrorKind::ConnectionAborted
                    | ErrorKind::TimedOut
                    | ErrorKind::BrokenPipe
                    | ErrorKind::Interrupted
            )
        }
        ClientError::Cancelled => false,
        ClientError::Json(_) | ClientError::Other(_) => false,
    }
}

fn to_identifier(
    response: &Response,
    require_cert: bool,
    public_key: Option<String>,
) -> Result<String, ClientError> {
    match require_cert {
        true => Ok(super::verify_cert_from_res(response, public_key)?),
        false => response
            .remote_addr()
            .map(|addr| addr.ip().to_string())
            .ok_or_else(|| anyhow::anyhow!("Remote address not found in response"))
            .map_err(ClientError::Other),
    }
}

