use crate::http::dto::{NonceRequest, NonceResponse, RegisterDto, RegisterResponseDto};
use crate::http::server::common::collect_to_json::CollectToJson;
use crate::http::server::common::error::AppError;
use crate::http::server::common::response::{empty_body, full_body, BoxedBody, JsonResponse};
use crate::http::server::{AppState, RequestClientInfo};
use crate::http::server::common::v3_session::V3TransferSession;
use crate::model::dto_v3::{ManifestResponseDto, TransferManifestDto};
use crate::model::resume::{ResumeManager, ResumeState};
use crate::model::storage::{FileTimestamps, StorageHandle};
use crate::{crypto, util};
use hyper::body::Incoming;
use hyper::StatusCode;

// ─── Nonce Exchange ──────────────────────────────────────────────────────────

pub(crate) async fn nonce_exchange(
    body: Incoming,
    state: AppState,
    client_info: RequestClientInfo,
) -> Result<JsonResponse<NonceResponse>, AppError> {
    let payload = body.collect_to_json::<NonceRequest>().await?;

    let nonce = util::base64::decode(&payload.nonce).map_err(|_| {
        tracing::warn!("Failed to decode nonce from base64");
        AppError::BadRequest("Invalid nonce format".to_string())
    })?;

    if !crypto::nonce::validate_nonce(&nonce) {
        tracing::warn!("Invalid nonce received");
        return Err(AppError::BadRequest("Invalid nonce".to_string()));
    }

    let remote_key = client_info.identifier();
    let mut received_nonce_map = state.received_nonce_map.lock().await;
    received_nonce_map.put(remote_key.clone(), nonce);

    let new_nonce = crypto::nonce::generate_nonce();
    let new_nonce_base64 = util::base64::encode(&new_nonce);
    let mut generated_nonce_map = state.generated_nonce_map.lock().await;
    generated_nonce_map.put(remote_key.clone(), new_nonce);

    Ok(JsonResponse {
        status: StatusCode::OK,
        body: NonceResponse {
            nonce: new_nonce_base64,
        },
    })
}

// ─── Register ────────────────────────────────────────────────────────────────

pub(crate) async fn register(
    body: Incoming,
    state: AppState,
    client_info: RequestClientInfo,
) -> Result<JsonResponse<RegisterResponseDto>, AppError> {
    let payload = body.collect_to_json::<RegisterDto>().await?;

    // On TLS, only trust registrations whose claimed token/fingerprint matches the client cert.
    if let Some(cert_fingerprint) = client_info.cert_fingerprint() {
        if payload.token.to_ascii_uppercase() != cert_fingerprint {
            tracing::warn!(
                "Ignoring register from {}: claimed token does not match client certificate",
                client_info.ip
            );
            return Err(AppError::Message(StatusCode::FORBIDDEN, "Certificate fingerprint mismatch".to_string()));
        }
    }

    let info = state.info.lock().await.clone();
    let has_web_interface = state.web.share.download().is_some();

    Ok(JsonResponse {
        status: StatusCode::OK,
        body: RegisterResponseDto {
            alias: info.alias,
            version: info.version,
            device_model: info.device_model,
            device_type: info.device_type,
            token: info.token,
            has_web_interface,
        },
    })
}

use crate::model::dto_v3::validate_filename;


// ─── Manifest ────────────────────────────────────────────────────────────────

/// POST /api/locara/v3/manifest
///
/// First call: allocates a partial file, saves initial ResumeState, creates a V3TransferSession
/// in the store, and returns all chunk indices as `missing_chunks`.
///
/// Subsequent calls (idempotent resumption): if a session already exists in memory returns
/// current missing chunks; if only a ResumeState exists on disk reopens the partial file.
pub(crate) async fn manifest(
    body: Incoming,
    state: AppState,
    client_info: RequestClientInfo,
) -> Result<JsonResponse<ManifestResponseDto>, AppError> {
    use crate::http::server::common::v3_session::V3TransferSession;
    use crate::model::storage_adapter::DesktopStorageHandle;
    use std::collections::HashMap;
    use std::sync::Arc;

    let manifest_dto = body.collect_to_json::<TransferManifestDto>().await?;

    let v3 = state.v3.as_ref().ok_or_else(|| AppError::Status(StatusCode::NOT_FOUND))?;

    let peer_binding = client_info.identifier();

    // 1. Validate transfer_id and file_name
    ResumeManager::validate_transfer_id(&manifest_dto.transfer_id)
        .map_err(|e| AppError::BadRequest(format!("Invalid transfer_id: {e}")))?;

    validate_filename(&manifest_dto.file_name)
        .map_err(|e| AppError::BadRequest(format!("Invalid file_name: {e}")))?;

    // 2. Validate chunk_size, file_size, and total_chunks with strict bounds
    use crate::http::server::common::v3_session::{
        available_space_for_path, MAX_CHUNK_SIZE, MAX_FILE_SIZE, MAX_TOTAL_CHUNKS,
    };

    if manifest_dto.chunk_size == 0 || manifest_dto.chunk_size > MAX_CHUNK_SIZE {
        return Err(AppError::BadRequest(format!(
            "chunk_size {} is invalid (must be 1..={})",
            manifest_dto.chunk_size, MAX_CHUNK_SIZE
        )));
    }

    if manifest_dto.file_size > MAX_FILE_SIZE {
        return Err(AppError::BadRequest(format!(
            "file_size {} exceeds maximum allowed ({} bytes)",
            manifest_dto.file_size, MAX_FILE_SIZE
        )));
    }

    // Derive expected chunk count using overflow-safe division
    let expected_chunks = if manifest_dto.file_size == 0 {
        0
    } else {
        let q = manifest_dto.file_size / manifest_dto.chunk_size;
        let r = manifest_dto.file_size % manifest_dto.chunk_size;
        if r == 0 {
            q
        } else {
            q.checked_add(1).ok_or_else(|| {
                AppError::BadRequest("Total chunks calculation overflow".to_string())
            })?
        }
    };

    if manifest_dto.file_size == 0 && manifest_dto.total_chunks != 0 {
        return Err(AppError::BadRequest("Zero-length file must have total_chunks = 0".to_string()));
    }
    if manifest_dto.file_size > 0 && manifest_dto.total_chunks == 0 {
        return Err(AppError::BadRequest("Non-empty file must have total_chunks > 0".to_string()));
    }

    if manifest_dto.total_chunks != expected_chunks {
        return Err(AppError::BadRequest(format!(
            "total_chunks mismatch: manifest declared {}, but file_size {} with chunk_size {} requires {}",
            manifest_dto.total_chunks, manifest_dto.file_size, manifest_dto.chunk_size, expected_chunks
        )));
    }

    if expected_chunks > MAX_TOTAL_CHUNKS {
        return Err(AppError::BadRequest(format!(
            "total_chunks {} exceeds maximum allowed chunks ({})",
            expected_chunks, MAX_TOTAL_CHUNKS
        )));
    }

    // ── In-memory session already exists ──────────────────────────────────────
    if let Some(existing) = v3.store.get(&manifest_dto.transfer_id).await {
        if existing.authenticated_peer_binding != peer_binding {
            tracing::warn!(
                "Manifest for transfer_id {} rejected: peer binding mismatch",
                manifest_dto.transfer_id
            );
            return Err(AppError::Message(
                StatusCode::FORBIDDEN,
                "Transfer session belongs to a different peer".to_string(),
            ));
        }

        if existing.manifest.file_size != manifest_dto.file_size
            || existing.manifest.chunk_size != manifest_dto.chunk_size
            || existing.manifest.total_chunks != manifest_dto.total_chunks
            || existing.manifest.expected_sha256 != manifest_dto.expected_sha256
            || existing.manifest.file_name != manifest_dto.file_name
        {
            return Err(AppError::Message(
                StatusCode::CONFLICT,
                "Manifest parameters do not match active in-memory session".to_string(),
            ));
        }

        let completed = existing.completed_chunks.lock().await;
        let missing: Vec<u64> = (0..manifest_dto.total_chunks).filter(|i| !completed.contains_key(i)).collect();
        return Ok(JsonResponse {
            status: StatusCode::OK,
            body: ManifestResponseDto { session_id: manifest_dto.transfer_id, missing_chunks: missing },
        });
    }

    // ── Determine save paths & physical disk space check ──────────────────────
    let (temp_path, save_path) = {
        let dir = ResumeManager::default_storage_dir().map_err(|e| {
            tracing::warn!("Cannot resolve storage dir for V3 save: {}", e);
            AppError::Message(StatusCode::INTERNAL_SERVER_ERROR, "Storage directory unavailable".to_string())
        })?;
        if let Err(e) = tokio::fs::create_dir_all(&dir).await {
            tracing::warn!("Failed to create V3 save dir {:?}: {}", dir, e);
        }
        if let Some(free_space) = available_space_for_path(&dir) {
            if manifest_dto.file_size > free_space {
                return Err(AppError::Message(
                    StatusCode::INSUFFICIENT_STORAGE,
                    format!("Insufficient disk space: required {} bytes, available {} bytes", manifest_dto.file_size, free_space),
                ));
            }
        }
        let temp_p = dir.join(format!("locara_part_{}.part", manifest_dto.transfer_id));
        let final_p = dir.join(format!("{}.locara_incoming", manifest_dto.file_name));
        (temp_p, final_p)
    };

    // ── Acquire atomic reservation before creating disk resources ────────────
    let reservation_guard = v3.store.reserve(&manifest_dto.transfer_id, manifest_dto.file_size).await?;

    // ── Notify application if event listener is configured ───────────────────
    let mut custom_destination: Option<std::path::PathBuf> = None;
    if let Some(ref tx) = v3.event_tx {
        let (decision_tx, decision_rx) = tokio::sync::oneshot::channel();
        let event = crate::http::server::v2::ServerEventV2::PrepareUploadV3 {
            session_id: manifest_dto.transfer_id.clone(),
            file_name: manifest_dto.file_name.clone(),
            file_size: manifest_dto.file_size,
            chunk_size: manifest_dto.chunk_size,
            total_chunks: manifest_dto.total_chunks,
            ip: client_info.ip.clone(),
            cert_fingerprint: client_info.cert_fingerprint(),
            decision_tx,
        };
        if tx.send(event).await.is_err() {
            reservation_guard.rollback().await;
            return Err(AppError::Message(
                StatusCode::INTERNAL_SERVER_ERROR,
                "Server event listener unavailable".to_string(),
            ));
        }
        match decision_rx.await {
            Ok(decision) => {
                if !decision.accept {
                    reservation_guard.rollback().await;
                    return Err(AppError::Message(
                        StatusCode::FORBIDDEN,
                        "Transfer declined by user".to_string(),
                    ));
                }
                custom_destination = decision.destination_path;
            }
            Err(_) => {
                reservation_guard.rollback().await;
                return Err(AppError::Message(
                    StatusCode::INTERNAL_SERVER_ERROR,
                    "Transfer decision aborted".to_string(),
                ));
            }
        }
    }

    // ── Reconstruct from persisted ResumeState or start fresh ────────────────
    let (missing, completed_map, storage): (Vec<u64>, HashMap<u64, String>, Box<dyn StorageHandle>) =
        match ResumeManager::load(&manifest_dto.transfer_id).await {
            Ok(Some(resume)) => {
                match &resume.authenticated_peer_binding {
                    Some(bound_peer) => {
                        if bound_peer != &peer_binding {
                            tracing::warn!(
                                "Manifest resume for {} rejected: peer binding mismatch",
                                manifest_dto.transfer_id
                            );
                            reservation_guard.rollback().await;
                            return Err(AppError::Message(
                                StatusCode::FORBIDDEN,
                                "Transfer session belongs to a different peer".to_string(),
                            ));
                        }
                    }
                    None => {
                        tracing::warn!(
                            "Manifest resume for {} rejected: persisted state lacks peer binding",
                            manifest_dto.transfer_id
                        );
                        reservation_guard.rollback().await;
                        return Err(AppError::Message(
                            StatusCode::FORBIDDEN,
                            "Legacy transfer state lacks peer binding; cannot resume".to_string(),
                        ));
                    }
                }

                if resume.file_size != manifest_dto.file_size
                    || resume.chunk_size != manifest_dto.chunk_size
                    || resume.total_chunks != manifest_dto.total_chunks
                    || resume.full_sha256 != manifest_dto.expected_sha256
                    || (resume.file_name.is_some() && resume.file_name.as_deref() != Some(&manifest_dto.file_name))
                {
                    tracing::warn!("Resumed manifest parameters mismatch for transfer {}", manifest_dto.transfer_id);
                    reservation_guard.rollback().await;
                    return Err(AppError::Message(
                        StatusCode::CONFLICT,
                        "Resumed transfer parameters do not match stored metadata".to_string(),
                    ));
                }

                if resume.total_chunks > MAX_TOTAL_CHUNKS || resume.file_size > MAX_FILE_SIZE {
                    reservation_guard.rollback().await;
                    return Err(AppError::Message(
                        StatusCode::BAD_REQUEST,
                        "Stored transfer metadata exceeds current system limits".to_string(),
                    ));
                }

                let done_set: std::collections::HashSet<u64> = resume.completed_chunks.iter().copied().collect();
                let missing: Vec<u64> = (0..manifest_dto.total_chunks).filter(|i| !done_set.contains(i)).collect();
                let mut completed_map = resume.chunk_hashes.clone();
                for &idx in &resume.completed_chunks {
                    completed_map.entry(idx).or_insert_with(String::new);
                }

                let storage: Box<dyn StorageHandle> = if completed_map.is_empty() {
                    let _ = tokio::fs::remove_file(&temp_path).await;
                    match DesktopStorageHandle::create_new_with_temp(temp_path.clone(), save_path.clone()).await {
                        Ok(mut h) => {
                            if manifest_dto.file_size > 0 {
                                if let Err(e) = h.set_len(manifest_dto.file_size).await {
                                    tracing::warn!(
                                        "set_len({}) failed for {}: {:?}",
                                        manifest_dto.file_size,
                                        manifest_dto.transfer_id,
                                        e
                                    );
                                    let _ = tokio::fs::remove_file(&temp_path).await;
                                    reservation_guard.rollback().await;
                                    return Err(AppError::Message(
                                        StatusCode::INSUFFICIENT_STORAGE,
                                        "Failed to allocate file length on disk".to_string(),
                                    ));
                                }
                            }
                            Box::new(h)
                        }
                        Err(e) => {
                            tracing::warn!("Failed to create partial file for {}: {:?}", manifest_dto.transfer_id, e);
                            reservation_guard.rollback().await;
                            return Err(AppError::Message(
                                StatusCode::INTERNAL_SERVER_ERROR,
                                "Failed to create partial file".to_string(),
                            ));
                        }
                    }
                } else {
                    match DesktopStorageHandle::reopen_existing_with_temp(temp_path.clone(), save_path.clone()).await {
                        Ok(h) => Box::new(h),
                        Err(_) => {
                            tracing::warn!(
                                "Partial file missing for resume of {}, restarting",
                                manifest_dto.transfer_id
                            );
                            let _ = ResumeManager::delete(&manifest_dto.transfer_id).await;
                            let fresh = ResumeState {
                                protocol: "3.0".to_string(),
                                transfer_id: manifest_dto.transfer_id.clone(),
                                file_size: manifest_dto.file_size,
                                chunk_size: manifest_dto.chunk_size,
                                total_chunks: manifest_dto.total_chunks,
                                full_sha256: manifest_dto.expected_sha256.clone(),
                                completed_chunks: Vec::new(),
                                file_name: Some(manifest_dto.file_name.clone()),
                                authenticated_peer_binding: Some(peer_binding.clone()),
                                chunk_hashes: HashMap::new(),
                                last_updated_at: Some(V3TransferSession::now()),
                            };
                            let _ = ResumeManager::save(&fresh).await;
                            let _ = tokio::fs::remove_file(&temp_path).await;
                            match DesktopStorageHandle::create_new_with_temp(temp_path.clone(), save_path.clone()).await {
                                Ok(mut h) => {
                                    if manifest_dto.file_size > 0 {
                                        let _ = h.set_len(manifest_dto.file_size).await;
                                    }
                                    Box::new(h)
                                }
                                Err(e) => {
                                    tracing::warn!(
                                        "Failed to recreate partial file for {}: {:?}",
                                        manifest_dto.transfer_id,
                                        e
                                    );
                                    reservation_guard.rollback().await;
                                    return Err(AppError::Message(
                                        StatusCode::INTERNAL_SERVER_ERROR,
                                        "Failed to create partial file".to_string(),
                                    ));
                                }
                            }
                        }
                    }
                };

                (missing, completed_map, storage)
            }
            _ => {
                // Fresh transfer or unreadable state:
                // 1. Create partial file
                let _ = tokio::fs::remove_file(&temp_path).await;
                let mut handle = match DesktopStorageHandle::create_new_with_temp(temp_path.clone(), save_path.clone()).await {
                    Ok(h) => h,
                    Err(e) => {
                        tracing::warn!("Failed to create partial file for {}: {:?}", manifest_dto.transfer_id, e);
                        reservation_guard.rollback().await;
                        return Err(AppError::Message(
                            StatusCode::INTERNAL_SERVER_ERROR,
                            "Failed to create partial file".to_string(),
                        ));
                    }
                };

                // 2. Allocate file length
                if manifest_dto.file_size > 0 {
                    if let Err(e) = handle.set_len(manifest_dto.file_size).await {
                        tracing::warn!("set_len failed for {}: {:?}", manifest_dto.transfer_id, e);
                        let _ = tokio::fs::remove_file(&temp_path).await;
                        reservation_guard.rollback().await;
                        return Err(AppError::Message(
                            StatusCode::INSUFFICIENT_STORAGE,
                            "Failed to allocate file size on disk".to_string(),
                        ));
                    }
                }

                // 3. Persist initial ResumeState
                let new_state = ResumeState {
                    protocol: "3.0".to_string(),
                    transfer_id: manifest_dto.transfer_id.clone(),
                    file_size: manifest_dto.file_size,
                    chunk_size: manifest_dto.chunk_size,
                    total_chunks: manifest_dto.total_chunks,
                    full_sha256: manifest_dto.expected_sha256.clone(),
                    completed_chunks: Vec::new(),
                    file_name: Some(manifest_dto.file_name.clone()),
                    authenticated_peer_binding: Some(peer_binding.clone()),
                    chunk_hashes: HashMap::new(),
                    last_updated_at: Some(V3TransferSession::now()),
                };
                if let Err(e) = ResumeManager::save(&new_state).await {
                    tracing::warn!("Failed to persist initial ResumeState for {}: {}", manifest_dto.transfer_id, e);
                    let _ = tokio::fs::remove_file(&temp_path).await;
                    reservation_guard.rollback().await;
                    return Err(AppError::Message(
                        StatusCode::INTERNAL_SERVER_ERROR,
                        "Failed to persist initial transfer state".to_string(),
                    ));
                }

                let missing: Vec<u64> = (0..manifest_dto.total_chunks).collect();
                (missing, HashMap::new(), Box::new(handle))
            }
        };

    let session = Arc::new(V3TransferSession::new(
        manifest_dto.transfer_id.clone(),
        peer_binding,
        manifest_dto.clone(),
        storage,
        completed_map,
    ));
    if let Some(dest) = custom_destination {
        *session.destination_path.lock().await = Some(dest);
    }
    v3.store.commit_reservation(reservation_guard, session).await;

    tracing::info!("V3 session created for transfer_id={}", manifest_dto.transfer_id);

    Ok(JsonResponse {
        status: StatusCode::OK,
        body: ManifestResponseDto {
            session_id: manifest_dto.transfer_id,
            missing_chunks: missing,
        },
    })
}

// ─── Chunk ───────────────────────────────────────────────────────────────────

/// POST /api/locara/v3/chunk?sessionId=…&chunkIndex=…[&chunkHash=…]
///
/// Receives a single chunk body (raw bytes), writes it at the correct offset in the partial
/// file under the `operation_gate` to prevent cursor interleaving, then persists ResumeState.
pub(crate) async fn chunk(
    req: hyper::Request<Incoming>,
    state: AppState,
    client_info: RequestClientInfo,
) -> Result<hyper::Response<BoxedBody>, AppError> {
    use http_body_util::BodyExt;
    use crate::http::server::common::v3_session::SessionStatus;

    let v3 = state.v3.as_ref().ok_or_else(|| AppError::Status(StatusCode::NOT_FOUND))?;

    // ── Parse query parameters ────────────────────────────────────────────────
    let uri_query = req.uri().query().unwrap_or("").to_owned();
    let params: std::collections::HashMap<String, String> =
        form_urlencoded::parse(uri_query.as_bytes())
            .map(|(k, v)| (k.into_owned(), v.into_owned()))
            .collect();

    let session_id = params
        .get("sessionId")
        .cloned()
        .ok_or_else(|| AppError::BadRequest("Missing sessionId query parameter".to_string()))?;

    ResumeManager::validate_transfer_id(&session_id)
        .map_err(|e| AppError::BadRequest(format!("Invalid sessionId: {e}")))?;

    let chunk_index: u64 = params
        .get("chunkIndex")
        .and_then(|v| v.parse().ok())
        .ok_or_else(|| AppError::BadRequest("Missing or invalid chunkIndex query parameter".to_string()))?;

    let chunk_hash_claim = params.get("chunkHash").cloned();

    // ── Lookup session ────────────────────────────────────────────────────────
    let session = v3.store.get(&session_id).await.ok_or_else(|| {
        tracing::warn!("Chunk request for unknown session: {session_id}");
        AppError::Message(StatusCode::NOT_FOUND, "Session not found".to_string())
    })?;

    if session.authenticated_peer_binding != client_info.identifier() {
        tracing::warn!("Chunk for session {session_id} rejected: peer binding mismatch");
        return Err(AppError::Message(StatusCode::FORBIDDEN, "Peer binding mismatch".to_string()));
    }

    if chunk_index >= session.manifest.total_chunks {
        return Err(AppError::BadRequest(format!(
            "chunkIndex {} out of range (total_chunks={})",
            chunk_index, session.manifest.total_chunks
        )));
    }

    // ── Calculate offset and expected length with checked arithmetic ──────────
    let offset = chunk_index
        .checked_mul(session.manifest.chunk_size)
        .ok_or_else(|| AppError::BadRequest("Chunk offset overflow".to_string()))?;

    let expected_len = if chunk_index == session.manifest.total_chunks - 1 {
        session.manifest.file_size
            .checked_sub(offset)
            .ok_or_else(|| AppError::BadRequest("Final chunk offset exceeds declared file size".to_string()))?
    } else {
        session.manifest.chunk_size
    };

    let end_offset = offset
        .checked_add(expected_len)
        .ok_or_else(|| AppError::BadRequest("Chunk end offset overflow".to_string()))?;

    if end_offset > session.manifest.file_size {
        return Err(AppError::BadRequest("Chunk extends beyond declared file size".to_string()));
    }

    // ── Bounded body collection using http_body_util::Limited ─────────────────
    let limited = http_body_util::Limited::new(req.into_body(), (expected_len + 1) as usize);
    let body_bytes = limited
        .collect()
        .await
        .map_err(|e| {
            AppError::Message(
                StatusCode::PAYLOAD_TOO_LARGE,
                format!("Chunk payload exceeds maximum allowed size: {e}"),
            )
        })?
        .to_bytes();

    if body_bytes.len() as u64 != expected_len {
        return Err(AppError::Message(
            StatusCode::BAD_REQUEST,
            format!(
                "Chunk size mismatch: received {} bytes, expected {} bytes for chunk index {}",
                body_bytes.len(),
                expected_len,
                chunk_index
            ),
        ));
    }

    // ── Optional per-chunk integrity check ────────────────────────────────────
    let actual_hash = crate::crypto::hash::sha256_hex(&body_bytes);
    if let Some(ref expected) = chunk_hash_claim {
        if actual_hash != expected.to_lowercase() {
            tracing::warn!(
                "Chunk {chunk_index} of session {session_id}: hash mismatch (expected={expected}, actual={actual_hash})"
            );
            return Err(AppError::Message(
                StatusCode::UNPROCESSABLE_ENTITY,
                format!("Chunk {chunk_index} integrity check failed"),
            ));
        }
    }

    // ── Atomic Operation Gate ─────────────────────────────────────────────────
    // Acquire exclusive gate BEFORE duplicate check, write, in-memory update,
    // and ResumeState persistence to guarantee complete serializability.
    let _gate = session.operation_gate.lock().await;

    {
        let status = session.status.lock().await;
        if *status != SessionStatus::Transferring {
            return Err(AppError::Message(
                StatusCode::CONFLICT,
                format!("Session is not in Transferring state (current: {:?})", *status),
            ));
        }
    }

    // Duplicate / idempotency check under lock
    let already_completed = {
        let completed = session.completed_chunks.lock().await;
        completed.get(&chunk_index).cloned()
    };

    if let Some(existing_hash) = already_completed {
        if !existing_hash.is_empty() {
            if existing_hash.to_lowercase() == actual_hash {
                return Ok(hyper::Response::builder()
                    .status(StatusCode::OK)
                    .body(empty_body())
                    .unwrap());
            } else {
                return Err(AppError::Message(
                    StatusCode::CONFLICT,
                    format!("Chunk {chunk_index} already written with different content"),
                ));
            }
        } else {
            // Chunk was previously marked complete but hash was omitted; compare bytes on disk
            let mut existing_bytes = vec![0u8; body_bytes.len()];
            let mut handle = session.storage_handle.lock().await;
            let n = handle.read_at(offset, &mut existing_bytes).await.map_err(|e| {
                tracing::warn!("Failed to read existing chunk {chunk_index} for comparison: {e:?}");
                AppError::Status(StatusCode::INTERNAL_SERVER_ERROR)
            })?;
            if n == body_bytes.len() && existing_bytes == body_bytes.as_ref() {
                drop(handle);
                let mut completed = session.completed_chunks.lock().await;
                completed.insert(chunk_index, actual_hash);
                return Ok(hyper::Response::builder()
                    .status(StatusCode::OK)
                    .body(empty_body())
                    .unwrap());
            } else {
                return Err(AppError::Message(
                    StatusCode::CONFLICT,
                    format!("Chunk {chunk_index} already exists with different content"),
                ));
            }
        }
    }

    // ── Write at offset ───────────────────────────────────────────────────────
    {
        let mut handle = session.storage_handle.lock().await;
        handle.write_at(offset, &body_bytes).await.map_err(|e| {
            tracing::warn!("write_at failed for chunk {chunk_index} of session {session_id}: {e:?}");
            AppError::Message(StatusCode::INTERNAL_SERVER_ERROR, "Failed to write chunk data".to_string())
        })?;
    }

    // ── Update in-memory completed_chunks ─────────────────────────────────────
    {
        let mut completed = session.completed_chunks.lock().await;
        completed.insert(chunk_index, actual_hash);
    }
    session.update_activity();

    // ── Persist updated ResumeState under the same operation gate ─────────────
    let (completed_list, chunk_hashes_map) = {
        let completed = session.completed_chunks.lock().await;
        let list: Vec<u64> = completed.keys().copied().collect();
        let hashes = completed.clone();
        (list, hashes)
    };
    let updated = ResumeState {
        protocol: "3.0".to_string(),
        transfer_id: session_id.clone(),
        file_size: session.manifest.file_size,
        chunk_size: session.manifest.chunk_size,
        total_chunks: session.manifest.total_chunks,
        full_sha256: session.manifest.expected_sha256.clone(),
        completed_chunks: completed_list,
        file_name: Some(session.manifest.file_name.clone()),
        authenticated_peer_binding: Some(session.authenticated_peer_binding.clone()),
        chunk_hashes: chunk_hashes_map,
        last_updated_at: Some(V3TransferSession::now()),
    };
    if let Err(e) = ResumeManager::save(&updated).await {
        tracing::warn!("Failed to persist ResumeState after chunk {chunk_index}: {e}");
        // Revert in-memory state so memory and disk stay consistent
        let mut completed = session.completed_chunks.lock().await;
        completed.remove(&chunk_index);
        return Err(AppError::Message(
            StatusCode::INTERNAL_SERVER_ERROR,
            "Failed to persist transfer progress".to_string(),
        ));
    }

    tracing::debug!("Chunk {chunk_index} of session {session_id} written ({} bytes)", body_bytes.len());

    if let Some(ref tx) = v3.event_tx {
        let total_bytes = session.manifest.file_size;
        let completed_count = session.completed_chunks.lock().await.len() as u64;
        let total_chunks = session.manifest.total_chunks;
        let is_last = completed_count >= total_chunks;

        let now_millis = std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .map(|d| d.as_millis() as u64)
            .unwrap_or(0);
        let last_emit = session.last_progress_emit.load(std::sync::atomic::Ordering::Relaxed);

        if is_last || now_millis.saturating_sub(last_emit) >= 100 {
            session.last_progress_emit.store(now_millis, std::sync::atomic::Ordering::Relaxed);
            let approx_bytes = if total_chunks > 0 {
                (completed_count.min(total_chunks) as f64 / total_chunks as f64 * total_bytes as f64) as u64
            } else {
                total_bytes
            };
            let progress = if total_bytes > 0 {
                (approx_bytes as f64 / total_bytes as f64).min(1.0)
            } else {
                1.0
            };
            let _ = tx.send(crate::http::server::v2::ServerEventV2::TransferProgressV3 {
                session_id: session_id.clone(),
                bytes_received: approx_bytes,
                total_bytes,
                progress,
            }).await;
        }
    }

    let mut res = hyper::Response::new(empty_body());
    *res.status_mut() = StatusCode::OK;
    Ok(res)
}

// ─── Commit ───────────────────────────────────────────────────────────────────

/// POST /api/locara/v3/commit?sessionId=…
///
/// Verifies all chunks are present, streams full-file SHA-256 in 64 KiB chunks,
/// then atomically commits the partial file to its final destination using `hard_link`.
pub(crate) async fn commit(
    req: hyper::Request<Incoming>,
    state: AppState,
    client_info: RequestClientInfo,
) -> Result<hyper::Response<BoxedBody>, AppError> {
    use sha2::{Digest, Sha256};
    use crate::http::server::common::v3_session::SessionStatus;
    use crate::model::storage_adapter::DesktopStorageHandle;

    let v3 = state.v3.as_ref().ok_or_else(|| AppError::Status(StatusCode::NOT_FOUND))?;

    // ── Parse query parameters ────────────────────────────────────────────────
    let uri_query = req.uri().query().unwrap_or("").to_owned();
    let params: std::collections::HashMap<String, String> =
        form_urlencoded::parse(uri_query.as_bytes())
            .map(|(k, v)| (k.into_owned(), v.into_owned()))
            .collect();

    let session_id = params
        .get("sessionId")
        .cloned()
        .ok_or_else(|| AppError::BadRequest("Missing sessionId query parameter".to_string()))?;

    ResumeManager::validate_transfer_id(&session_id)
        .map_err(|e| AppError::BadRequest(format!("Invalid sessionId: {e}")))?;

    // ── Lookup session without removing from store ────────────────────────────
    let session = v3.store.get(&session_id).await.ok_or_else(|| {
        tracing::warn!("Commit request for unknown session: {session_id}");
        AppError::Message(StatusCode::NOT_FOUND, "Session not found".to_string())
    })?;

    if session.authenticated_peer_binding != client_info.identifier() {
        return Err(AppError::Message(StatusCode::FORBIDDEN, "Peer binding mismatch".to_string()));
    }

    // ── Acquire exclusive operation gate ──────────────────────────────────────
    let _gate = session.operation_gate.lock().await;

    // ── Status check & transition ─────────────────────────────────────────────
    {
        let mut status = session.status.lock().await;
        if *status == SessionStatus::Committed {
            // Already committed — idempotent 200 OK
            let mut res = hyper::Response::new(empty_body());
            *res.status_mut() = StatusCode::OK;
            return Ok(res);
        }
        if *status == SessionStatus::Verifying {
            return Err(AppError::Message(StatusCode::CONFLICT, "Commit verification already in progress".to_string()));
        }
        *status = SessionStatus::Verifying;
    }

    // ── Verify all chunks present ─────────────────────────────────────────────
    {
        let completed = session.completed_chunks.lock().await;
        let total = session.manifest.total_chunks;
        let missing: Vec<u64> = (0..total).filter(|i| !completed.contains_key(i)).collect();
        if !missing.is_empty() {
            tracing::warn!(
                "Commit for session {session_id} rejected: {} chunk(s) missing (first: {})",
                missing.len(),
                missing[0]
            );
            drop(completed);
            *session.status.lock().await = SessionStatus::Transferring;
            let body = serde_json::json!({
                "message": format!("{} chunk(s) missing", missing.len()),
                "missing_chunks": missing,
            });
            let mut res = hyper::Response::new(full_body(body.to_string()));
            *res.status_mut() = StatusCode::CONFLICT;
            return Ok(res);
        }
    }

    // ── Flush & Streaming SHA-256 Verification (64 KiB buffer) ────────────────
    {
        let mut handle = session.storage_handle.lock().await;
        if let Err(e) = handle.flush().await {
            tracing::warn!("Flush failed for session {session_id}: {e:?}");
        }

        if let Some(ref expected_sha256) = session.manifest.expected_sha256 {
            let mut hasher = Sha256::new();
            let mut buf = vec![0u8; 65536];
            let mut bytes_read: u64 = 0;
            loop {
                let n = handle.read_at(bytes_read, &mut buf).await.map_err(|e| {
                    tracing::warn!("Read failed during SHA-256 verification of {session_id}: {e:?}");
                    AppError::Message(StatusCode::INTERNAL_SERVER_ERROR, "Integrity verification read failure".to_string())
                })?;
                if n == 0 {
                    break;
                }
                hasher.update(&buf[..n]);
                bytes_read += n as u64;
            }

            if bytes_read != session.manifest.file_size {
                tracing::warn!(
                    "File size on disk mismatch for {session_id}: expected {}, read {}",
                    session.manifest.file_size,
                    bytes_read
                );
                drop(handle);
                *session.status.lock().await = SessionStatus::Failed;
                return Err(AppError::Message(
                    StatusCode::UNPROCESSABLE_ENTITY,
                    "File length on disk differs from declared manifest size".to_string(),
                ));
            }

            let actual = crate::crypto::hash::to_hex(&hasher.finalize());
            if actual != expected_sha256.to_lowercase() {
                tracing::warn!(
                    "Full-file SHA-256 mismatch for session {session_id}: expected={expected_sha256}, actual={actual}"
                );
                drop(handle);
                *session.status.lock().await = SessionStatus::Failed;
                if let Some(ref tx) = v3.event_tx {
                    let _ = tx.send(crate::http::server::v2::ServerEventV2::TransferFailedV3 {
                        session_id: session_id.clone(),
                        file_name: session.manifest.file_name.clone(),
                        error: "Full-file integrity check failed".to_string(),
                    }).await;
                }
                return Err(AppError::Message(
                    StatusCode::UNPROCESSABLE_ENTITY,
                    "Full-file integrity check failed".to_string(),
                ));
            }
            tracing::info!("Full-file SHA-256 verified for session {session_id}");
        }
    }

    let (temp_p, final_p) = {
        let dir = ResumeManager::default_storage_dir().map_err(|e| {
            tracing::warn!("Cannot resolve storage dir: {}", e);
            AppError::Message(StatusCode::INTERNAL_SERVER_ERROR, "Storage directory unavailable".to_string())
        })?;
        let temp = dir.join(format!("locara_part_{session_id}.part"));
        let custom = session.destination_path.lock().await.clone();
        let final_dest = custom.unwrap_or_else(|| dir.join(format!("{}.locara_incoming", session.manifest.file_name)));
        (temp, final_dest)
    };

    // Pre-check destination collision before consuming the storage handle
    if tokio::fs::symlink_metadata(&final_p).await.is_ok() {
        tracing::warn!("Commit for session {session_id} rejected: destination file {:?} already exists", final_p);
        *session.status.lock().await = SessionStatus::Transferring;
        return Err(AppError::Message(StatusCode::CONFLICT, "Destination file already exists".to_string()));
    }

    // If handle was previously consumed, restore it from the intact partial file
    {
        let mut guard = session.storage_handle.lock().await;
        if temp_p.exists() && !final_p.exists() {
            if let Ok(reopened) = DesktopStorageHandle::reopen_existing_with_temp(temp_p.clone(), final_p.clone()).await {
                *guard = Box::new(reopened);
            }
        }
    }

    // ── Atomic commit ─────────────────────────────────────────────────────────
    let owned_handle: Box<dyn StorageHandle> = {
        let mut guard = session.storage_handle.lock().await;
        std::mem::replace(&mut *guard, Box::new(UnavailableStorageHandle))
    };

    if let Err(e) = owned_handle.commit(FileTimestamps::default()).await {
        tracing::warn!("Atomic commit failed for session {session_id}: {e:?}");
        {
            let mut status = session.status.lock().await;
            *status = SessionStatus::Transferring;
        }

        // Restore reopenable storage handle so session can be recovered/retried
        if let Ok(dir) = ResumeManager::default_storage_dir() {
            let temp_p = dir.join(format!("locara_part_{}.part", session_id));
            let final_p = dir.join(format!("{}.locara_incoming", session.manifest.file_name));
            if let Ok(reopened) = DesktopStorageHandle::reopen_existing_with_temp(temp_p, final_p).await {
                let mut guard = session.storage_handle.lock().await;
                *guard = Box::new(reopened);
            }
        }

        // Return sanitized message with no internal path leakage
        let (status_code, msg) = match e {
            crate::model::storage::StorageError::AlreadyExists => {
                (StatusCode::CONFLICT, "Destination file already exists")
            }
            crate::model::storage::StorageError::PermissionDenied => {
                (StatusCode::FORBIDDEN, "Permission denied writing destination file")
            }
            crate::model::storage::StorageError::Unsupported(_) => {
                (StatusCode::INTERNAL_SERVER_ERROR, "Non-replacing commit unsupported on storage filesystem")
            }
            _ => {
                (StatusCode::INTERNAL_SERVER_ERROR, "Atomic commit failed")
            }
        };

        if let Some(ref tx) = v3.event_tx {
            let _ = tx.send(crate::http::server::v2::ServerEventV2::TransferFailedV3 {
                session_id: session_id.clone(),
                file_name: session.manifest.file_name.clone(),
                error: msg.to_string(),
            }).await;
        }

        return Err(AppError::Message(status_code, msg.to_string()));
    }

    // ── Success: Mark Committed and Cleanup ───────────────────────────────────
    {
        let mut status = session.status.lock().await;
        *status = SessionStatus::Committed;
    }
    session.is_committed.store(true, std::sync::atomic::Ordering::Release);
    session.update_activity();

    // Only delete ResumeState AFTER successful publication
    if let Err(e) = ResumeManager::delete(&session_id).await {
        tracing::warn!("Failed to delete ResumeState for {session_id}: {e}");
    }

    if let Some(ref tx) = v3.event_tx {
        let _ = tx.send(crate::http::server::v2::ServerEventV2::TransferFinishedV3 {
            session_id: session_id.clone(),
            file_name: session.manifest.file_name.clone(),
            file_size: session.manifest.file_size,
            destination_path: final_p.to_string_lossy().to_string(),
            saved_to_gallery: false,
        }).await;
    }

    tracing::info!("V3 transfer committed successfully for session {session_id}");

    let mut res = hyper::Response::new(empty_body());
    *res.status_mut() = StatusCode::OK;
    Ok(res)
}

// ─── Sentinel storage handle ──────────────────────────────────────────────────

/// Placeholder `StorageHandle` placed into `V3TransferSession.storage_handle` after
/// the real handle has been moved out for the consuming `commit()` call.
/// Every operation returns `StorageError::Unavailable`.
struct UnavailableStorageHandle;

impl StorageHandle for UnavailableStorageHandle {
    fn write_data<'a>(&'a mut self, _data: &'a [u8])
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), crate::model::storage::StorageError>> + Send + 'a>>
    {
        Box::pin(async { Err(crate::model::storage::StorageError::Unavailable) })
    }
    fn write_at<'a>(&'a mut self, _offset: u64, _data: &'a [u8])
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), crate::model::storage::StorageError>> + Send + 'a>>
    {
        Box::pin(async { Err(crate::model::storage::StorageError::Unavailable) })
    }
    fn read_at<'a>(&'a mut self, _offset: u64, _buf: &'a mut [u8])
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<usize, crate::model::storage::StorageError>> + Send + 'a>>
    {
        Box::pin(async { Err(crate::model::storage::StorageError::Unavailable) })
    }
    fn flush<'a>(&'a mut self)
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), crate::model::storage::StorageError>> + Send + 'a>>
    {
        Box::pin(async { Ok(()) })
    }
    fn set_len<'a>(&'a mut self, _len: u64)
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), crate::model::storage::StorageError>> + Send + 'a>>
    {
        Box::pin(async { Ok(()) })
    }
    fn commit(self: Box<Self>, _timestamps: FileTimestamps)
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), crate::model::storage::StorageError>> + Send>>
    {
        Box::pin(async { Err(crate::model::storage::StorageError::Unavailable) })
    }
    fn abort(self: Box<Self>)
        -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), crate::model::storage::StorageError>> + Send>>
    {
        Box::pin(async { Ok(()) })
    }
}
