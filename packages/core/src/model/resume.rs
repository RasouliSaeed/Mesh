use crate::model::dto_v3::{MAX_CHUNK_SIZE, MAX_FILE_SIZE, MAX_TOTAL_CHUNKS};
use serde::{Deserialize, Serialize};
use std::path::{Path, PathBuf};
use std::sync::RwLock;
use std::time::{SystemTime, UNIX_EPOCH};

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct RecoverableSessionInfo {
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

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ResumeState {
    pub protocol: String,
    pub transfer_id: String,
    pub file_size: u64,
    pub chunk_size: u64,
    pub total_chunks: u64,
    pub full_sha256: Option<String>,
    pub completed_chunks: Vec<u64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub file_name: Option<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub authenticated_peer_binding: Option<String>,
    #[serde(default, skip_serializing_if = "std::collections::HashMap::is_empty")]
    pub chunk_hashes: std::collections::HashMap<u64, String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub last_updated_at: Option<u64>,
}

impl ResumeState {
    pub fn new(
        protocol: String,
        transfer_id: String,
        file_size: u64,
        chunk_size: u64,
        total_chunks: u64,
        full_sha256: Option<String>,
        completed_chunks: Vec<u64>,
    ) -> Self {
        let now = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);
        Self {
            protocol,
            transfer_id,
            file_size,
            chunk_size,
            total_chunks,
            full_sha256,
            completed_chunks,
            file_name: None,
            authenticated_peer_binding: None,
            chunk_hashes: std::collections::HashMap::new(),
            last_updated_at: Some(now),
        }
    }
}

static CUSTOM_RESUME_DIR: RwLock<Option<PathBuf>> = RwLock::new(None);

pub struct ResumeManager;

impl ResumeManager {
    /// Overrides the persistent directory used for resume metadata.
    ///
    /// Useful for tests or application integration where an explicit path is desired.
    pub fn set_storage_dir(dir: PathBuf) {
        if let Ok(mut lock) = CUSTOM_RESUME_DIR.write() {
            *lock = Some(dir);
        }
    }

    /// Clears any overridden storage directory, restoring default resolution.
    pub fn clear_storage_dir() {
        if let Ok(mut lock) = CUSTOM_RESUME_DIR.write() {
            *lock = None;
        }
    }

    /// Resolves the default persistent directory for resume metadata.
    ///
    /// Priority:
    /// 1. Explicitly configured custom directory via [`set_storage_dir`].
    /// 2. Windows: `%LOCALAPPDATA%\locara\resume` (or `%APPDATA%\locara\resume`, or `%USERPROFILE%\AppData\Local\locara\resume`).
    /// 3. Unix: `$XDG_DATA_HOME/locara/resume` (or `~/.local/share/locara/resume`).
    ///
    /// Returns an actionable error if no persistent directory could be determined.
    /// Does NOT silently fall back to a volatile temporary directory.
    pub fn default_storage_dir() -> Result<PathBuf, String> {
        Self::resolve_storage_dir_with(|var| std::env::var_os(var))
    }

    /// Internal resolution helper allowing testable environment lookup without mutating global process state.
    pub fn resolve_storage_dir_with<F>(env_lookup: F) -> Result<PathBuf, String>
    where
        F: Fn(&str) -> Option<std::ffi::OsString>,
    {
        if let Ok(lock) = CUSTOM_RESUME_DIR.read() {
            if let Some(dir) = lock.as_ref() {
                return Ok(dir.clone());
            }
        }

        #[cfg(windows)]
        {
            if let Some(local_app_data) = env_lookup("LOCALAPPDATA") {
                return Ok(PathBuf::from(local_app_data).join("locara").join("resume"));
            }
            if let Some(app_data) = env_lookup("APPDATA") {
                return Ok(PathBuf::from(app_data).join("locara").join("resume"));
            }
            if let Some(user_profile) = env_lookup("USERPROFILE") {
                return Ok(PathBuf::from(user_profile).join("AppData").join("Local").join("locara").join("resume"));
            }
        }

        #[cfg(unix)]
        {
            if let Some(data_home) = env_lookup("XDG_DATA_HOME") {
                return Ok(PathBuf::from(data_home).join("locara").join("resume"));
            }
            if let Some(home) = env_lookup("HOME") {
                return Ok(PathBuf::from(home).join(".local").join("share").join("locara").join("resume"));
            }
        }

        Err("No persistent storage directory available for resume metadata (neither LOCALAPPDATA, APPDATA, USERPROFILE, XDG_DATA_HOME, nor HOME is set)".to_string())
    }

    /// Validates `transfer_id` to strictly prevent directory traversal attacks.
    /// Only alphanumeric characters, dashes (`-`), and underscores (`_`) are allowed.
    pub fn validate_transfer_id(transfer_id: &str) -> Result<(), String> {
        if transfer_id.is_empty() {
            return Err("Transfer ID cannot be empty".to_string());
        }
        if transfer_id.len() > 128 {
            return Err("Transfer ID exceeds maximum length of 128 characters".to_string());
        }
        if !transfer_id.chars().all(|c| c.is_ascii_alphanumeric() || c == '-' || c == '_') {
            return Err("Transfer ID contains invalid characters (only alphanumeric, '-', '_' allowed)".to_string());
        }
        Ok(())
    }

    /// Computes the metadata path for a transfer in a specific directory.
    pub fn get_path_in(dir: &Path, transfer_id: &str) -> Result<PathBuf, String> {
        Self::validate_transfer_id(transfer_id)?;
        Ok(dir.join(format!("locara_resume_{}.json", transfer_id)))
    }

    /// Computes the metadata path for a transfer in the default persistent directory.
    pub fn get_path(transfer_id: &str) -> Result<PathBuf, String> {
        let dir = Self::default_storage_dir()?;
        Self::get_path_in(&dir, transfer_id)
    }

    /// Saves resume state to a specific directory with durable atomic replacement.
    pub async fn save_in(dir: &Path, state: &ResumeState) -> Result<(), String> {
        Self::validate_transfer_id(&state.transfer_id)?;

        tokio::fs::create_dir_all(dir)
            .await
            .map_err(|e| format!("Failed to create resume directory {}: {}", dir.display(), e))?;

        let target_path = dir.join(format!("locara_resume_{}.json", state.transfer_id));
        let tmp_path = dir.join(format!(".locara_resume_{}_{}.tmp", state.transfer_id, std::process::id()));
        let mut state_to_save = state.clone();
        if state_to_save.last_updated_at.is_none() {
            state_to_save.last_updated_at = Some(
                SystemTime::now()
                    .duration_since(UNIX_EPOCH)
                    .map(|d| d.as_secs())
                    .unwrap_or(0),
            );
        }

        let data = serde_json::to_vec(&state_to_save)
            .map_err(|e| format!("Failed to serialize resume state: {}", e))?;

        // 1. Write to temp file and sync data to physical storage
        {
            use tokio::io::AsyncWriteExt;
            let mut file = tokio::fs::OpenOptions::new()
                .write(true)
                .create(true)
                .truncate(true)
                .open(&tmp_path)
                .await
                .map_err(|e| format!("Failed to open temp resume file {}: {}", tmp_path.display(), e))?;

            file.write_all(&data)
                .await
                .map_err(|e| format!("Failed to write temp resume data: {}", e))?;

            file.flush()
                .await
                .map_err(|e| format!("Failed to flush temp resume file: {}", e))?;

            file.sync_data()
                .await
                .map_err(|e| format!("Failed to sync temp resume file: {}", e))?;
        } // File closed before rename (required on Windows)

        // 2. Atomic rename on the same filesystem
        tokio::fs::rename(&tmp_path, &target_path)
            .await
            .map_err(|e| {
                let _ = std::fs::remove_file(&tmp_path);
                format!("Failed to commit resume state {}: {}", target_path.display(), e)
            })?;

        // 3. Parent-directory durability sync on Unix platforms
        #[cfg(unix)]
        {
            if let Ok(dir_file) = std::fs::File::open(dir) {
                let _ = dir_file.sync_all();
            }
        }

        Ok(())
    }

    /// Saves resume state using the default persistent storage directory.
    pub async fn save(state: &ResumeState) -> Result<(), String> {
        let dir = Self::default_storage_dir()?;
        Self::save_in(&dir, state).await
    }

    /// Loads resume state from a specific directory.
    pub async fn load_from(dir: &Path, transfer_id: &str) -> Result<Option<ResumeState>, String> {
        let path = Self::get_path_in(dir, transfer_id)?;
        if !path.exists() {
            return Ok(None);
        }

        let data = tokio::fs::read(&path)
            .await
            .map_err(|e| format!("Failed to read resume state {}: {}", path.display(), e))?;

        let state: ResumeState = serde_json::from_slice(&data)
            .map_err(|e| format!("Failed to deserialize resume state: {}", e))?;

        Ok(Some(state))
    }

    /// Loads resume state from the default persistent storage directory.
    pub async fn load(transfer_id: &str) -> Result<Option<ResumeState>, String> {
        let dir = Self::default_storage_dir()?;
        Self::load_from(&dir, transfer_id).await
    }

    /// Deletes resume state from a specific directory.
    pub async fn delete_from(dir: &Path, transfer_id: &str) -> Result<(), String> {
        let path = Self::get_path_in(dir, transfer_id)?;
        if path.exists() {
            let _ = tokio::fs::remove_file(&path).await;
        }
        Ok(())
    }

    /// Deletes resume state from the default persistent storage directory.
    pub async fn delete(transfer_id: &str) -> Result<(), String> {
        let dir = Self::default_storage_dir()?;
        Self::delete_from(&dir, transfer_id).await
    }

    /// Discovers and validates all recoverable transfer sessions stored in a specific directory.
    ///
    /// Ignores corrupted metadata, temporary files (.tmp), and sessions whose transfer IDs
    /// violate traversal constraints. Distinguishes between fully resumable sessions and
    /// unresumable ones (e.g. missing `.part` files or expired sessions).
    pub async fn list_active_sessions_in(dir: &Path) -> Result<Vec<RecoverableSessionInfo>, String> {
        if !dir.exists() {
            return Ok(Vec::new());
        }

        let mut read_dir = tokio::fs::read_dir(dir)
            .await
            .map_err(|e| format!("Failed to read resume directory {}: {}", dir.display(), e))?;

        let mut sessions = Vec::new();

        while let Some(entry) = read_dir
            .next_entry()
            .await
            .map_err(|e| format!("Failed to iterate resume directory {}: {}", dir.display(), e))?
        {
            let path = entry.path();
            if !path.is_file() {
                continue;
            }

            let file_name = match path.file_name().and_then(|n| n.to_str()) {
                Some(n) => n,
                None => continue,
            };

            // Must match locara_resume_{transfer_id}.json
            // Ignore hidden files, temporary (.tmp) files, or unrelated files
            if file_name.starts_with('.') || !file_name.starts_with("locara_resume_") || !file_name.ends_with(".json") {
                continue;
            }

            let transfer_id = &file_name["locara_resume_".len()..file_name.len() - ".json".len()];
            if Self::validate_transfer_id(transfer_id).is_err() {
                continue;
            }

            let data = match tokio::fs::read(&path).await {
                Ok(d) => d,
                Err(_) => continue,
            };

            let state: ResumeState = match serde_json::from_slice(&data) {
                Ok(s) => s,
                Err(_) => continue,
            };

            if state.transfer_id != transfer_id {
                continue;
            }

            if !state.protocol.starts_with("v3") && state.protocol != "3.0" {
                continue;
            }

            if state.total_chunks == 0
                || state.total_chunks > MAX_TOTAL_CHUNKS
                || state.chunk_size == 0
                || state.chunk_size > MAX_CHUNK_SIZE
                || state.file_size > MAX_FILE_SIZE
            {
                continue;
            }

            if state.completed_chunks.iter().any(|&c| c >= state.total_chunks) {
                continue;
            }

            let last_updated = match state.last_updated_at {
                Some(t) => t,
                None => match entry.metadata().await {
                    Ok(m) => m
                        .modified()
                        .ok()
                        .and_then(|t| t.duration_since(UNIX_EPOCH).ok())
                        .map(|d| d.as_secs())
                        .unwrap_or(0),
                    Err(_) => 0,
                },
            };

            let now_secs = SystemTime::now()
                .duration_since(UNIX_EPOCH)
                .unwrap_or_default()
                .as_secs();

            // 7 days expiration threshold for inactive on-disk sessions
            const DISK_SESSION_EXPIRATION_SECS: u64 = 7 * 86400;
            let is_expired = now_secs.saturating_sub(last_updated) > DISK_SESSION_EXPIRATION_SECS;

            let part_path = dir.join(format!("locara_part_{}.part", state.transfer_id));
            let part_exists = part_path.is_file();

            let mut is_resumable = true;
            let mut unresumable_reason = None;

            if is_expired {
                is_resumable = false;
                unresumable_reason = Some("Session expired on disk (exceeded 7 days inactivity)".to_string());
            } else if state.completed_chunks.len() as u64 == state.total_chunks {
                is_resumable = false;
                unresumable_reason = Some("All chunks completed; awaiting commit".to_string());
            } else if !part_exists && !state.completed_chunks.is_empty() {
                is_resumable = false;
                unresumable_reason = Some("Partial payload file (.part) is missing".to_string());
            }

            let mut bytes_transferred: u64 = 0;
            if state.total_chunks > 0 && state.file_size > 0 {
                let last_chunk_idx = state.total_chunks - 1;
                let regular_chunk_size = state.chunk_size;
                let last_chunk_size = state
                    .file_size
                    .saturating_sub(last_chunk_idx.saturating_mul(regular_chunk_size));

                for &c in &state.completed_chunks {
                    if c == last_chunk_idx {
                        bytes_transferred = bytes_transferred.saturating_add(last_chunk_size);
                    } else {
                        bytes_transferred = bytes_transferred.saturating_add(regular_chunk_size);
                    }
                }
            }

            sessions.push(RecoverableSessionInfo {
                transfer_id: state.transfer_id,
                file_name: state.file_name,
                file_size: state.file_size,
                chunk_size: state.chunk_size,
                total_chunks: state.total_chunks,
                completed_chunks_count: state.completed_chunks.len() as u64,
                bytes_transferred,
                last_updated_at: last_updated,
                authenticated_peer_binding: state.authenticated_peer_binding,
                is_resumable,
                unresumable_reason,
            });
        }

        sessions.sort_by(|a, b| b.last_updated_at.cmp(&a.last_updated_at));
        Ok(sessions)
    }

    /// Discovers and validates all recoverable transfer sessions stored in the default directory.
    pub async fn list_active_sessions() -> Result<Vec<RecoverableSessionInfo>, String> {
        let dir = Self::default_storage_dir()?;
        Self::list_active_sessions_in(&dir).await
    }

    /// Safely prunes both the resume metadata and partial payload file for a session.
    pub async fn prune_session_in(dir: &Path, transfer_id: &str) -> Result<(), String> {
        Self::validate_transfer_id(transfer_id)?;
        let meta_path = Self::get_path_in(dir, transfer_id)?;
        if meta_path.exists() {
            let _ = tokio::fs::remove_file(&meta_path).await;
        }
        let part_path = dir.join(format!("locara_part_{}.part", transfer_id));
        if part_path.exists() {
            let _ = tokio::fs::remove_file(&part_path).await;
        }
        Ok(())
    }

    /// Safely prunes both the resume metadata and partial payload file in the default directory.
    pub async fn prune_session(transfer_id: &str) -> Result<(), String> {
        let dir = Self::default_storage_dir()?;
        Self::prune_session_in(&dir, transfer_id).await
    }
}
