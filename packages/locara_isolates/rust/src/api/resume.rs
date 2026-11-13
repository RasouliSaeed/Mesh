use locara::model::resume::{RecoverableSessionInfo, ResumeManager};
use std::path::Path;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct RsRecoverableSession {
    pub transfer_id: String,
    pub file_name: Option<String>,
    pub file_size: u64,
    pub chunk_size: u64,
    pub total_chunks: u64,
    pub completed_chunks_count: u64,
    pub bytes_transferred: u64,
    pub last_updated_at: u64,
    pub authenticated_peer_binding: Option<String>,
    pub is_resumable: bool,
    pub unresumable_reason: Option<String>,
}

impl From<RecoverableSessionInfo> for RsRecoverableSession {
    fn from(info: RecoverableSessionInfo) -> Self {
        Self {
            transfer_id: info.transfer_id,
            file_name: info.file_name,
            file_size: info.file_size,
            chunk_size: info.chunk_size,
            total_chunks: info.total_chunks,
            completed_chunks_count: info.completed_chunks_count,
            bytes_transferred: info.bytes_transferred,
            last_updated_at: info.last_updated_at,
            authenticated_peer_binding: info.authenticated_peer_binding,
            is_resumable: info.is_resumable,
            unresumable_reason: info.unresumable_reason,
        }
    }
}

/// Lists all active and recoverable V3 transfer sessions from disk metadata.
pub async fn list_active_v3_sessions(storage_dir: Option<String>) -> Vec<RsRecoverableSession> {
    let result = match storage_dir {
        Some(dir) => ResumeManager::list_active_sessions_in(Path::new(&dir)).await,
        None => ResumeManager::list_active_sessions().await,
    };
    result.unwrap_or_default().into_iter().map(Into::into).collect()
}

/// Prunes an active or stale V3 transfer session metadata and temporary files.
pub async fn prune_v3_session(transfer_id: String, storage_dir: Option<String>) -> bool {
    let result = match storage_dir {
        Some(dir) => ResumeManager::prune_session_in(Path::new(&dir), &transfer_id).await,
        None => ResumeManager::prune_session(&transfer_id).await,
    };
    result.is_ok()
}
