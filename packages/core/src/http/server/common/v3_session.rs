use crate::model::storage::StorageHandle;
use crate::model::dto_v3::TransferManifestDto;
use crate::http::server::common::error::AppError;
use hyper::StatusCode;
use std::collections::HashMap;
use std::path::Path;
use std::sync::Arc;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::{Mutex as AsyncMutex, RwLock};

#[derive(Debug, PartialEq, Eq, Clone, Copy)]
pub enum SessionStatus {
    Transferring,
    Verifying,
    Committed,
    Cancelling,
    Failed,
    Expired,
}

pub struct V3TransferSession {
    pub transfer_id: String,
    pub authenticated_peer_binding: String,
    pub manifest: TransferManifestDto,
    pub operation_gate: AsyncMutex<()>,
    pub storage_handle: AsyncMutex<Box<dyn StorageHandle>>,
    pub status: AsyncMutex<SessionStatus>,
    pub completed_chunks: AsyncMutex<HashMap<u64, String>>,
    pub last_activity: AtomicU64,
    pub is_committed: AtomicBool,
    pub destination_path: AsyncMutex<Option<std::path::PathBuf>>,
    pub last_progress_emit: AtomicU64,
}

impl V3TransferSession {
    pub fn new(
        transfer_id: String,
        authenticated_peer_binding: String,
        manifest: TransferManifestDto,
        storage_handle: Box<dyn StorageHandle>,
        completed_chunks: HashMap<u64, String>,
    ) -> Self {
        Self {
            transfer_id,
            authenticated_peer_binding,
            manifest,
            operation_gate: AsyncMutex::new(()),
            storage_handle: AsyncMutex::new(storage_handle),
            status: AsyncMutex::new(SessionStatus::Transferring),
            completed_chunks: AsyncMutex::new(completed_chunks),
            last_activity: AtomicU64::new(Self::now()),
            is_committed: AtomicBool::new(false),
            destination_path: AsyncMutex::new(None),
            last_progress_emit: AtomicU64::new(0),
        }
    }

    pub fn update_activity(&self) {
        self.last_activity.store(Self::now(), Ordering::Relaxed);
    }

    pub fn is_committed(&self) -> bool {
        self.is_committed.load(Ordering::Acquire)
    }

    pub(crate) fn now() -> u64 {
        SystemTime::now().duration_since(UNIX_EPOCH).unwrap().as_secs()
    }
}

pub const MAX_ACTIVE_SESSIONS: usize = 64;
pub const SESSION_INACTIVITY_TIMEOUT_SECS: u64 = 600; // 10 minutes
pub const JANITOR_INTERVAL_SECS: u64 = 30; // 30 seconds

pub use crate::model::dto_v3::{DEFAULT_CHUNK_SIZE, MAX_CHUNK_SIZE, MAX_FILE_SIZE, MAX_TOTAL_CHUNKS};

pub const DEFAULT_MAX_AGGREGATE_RESERVED_BYTES: u64 = 2 * 1024 * 1024 * 1024 * 1024; // 2 TiB

#[cfg(windows)]
pub fn available_space_for_path(path: &Path) -> Option<u64> {
    use std::os::windows::ffi::OsStrExt;
    let mut wide: Vec<u16> = path.as_os_str().encode_wide().collect();
    wide.push(0);
    let mut free_bytes_available: u64 = 0;
    let mut total_bytes: u64 = 0;
    let mut total_free_bytes: u64 = 0;
    extern "system" {
        fn GetDiskFreeSpaceExW(
            lpDirectoryName: *const u16,
            lpFreeBytesAvailableToCaller: *mut u64,
            lpTotalNumberOfBytes: *mut u64,
            lpTotalNumberOfFreeBytes: *mut u64,
        ) -> i32;
    }
    let res = unsafe {
        GetDiskFreeSpaceExW(
            wide.as_ptr(),
            &mut free_bytes_available,
            &mut total_bytes,
            &mut total_free_bytes,
        )
    };
    if res != 0 {
        Some(free_bytes_available)
    } else {
        None
    }
}

#[cfg(unix)]
pub fn available_space_for_path(path: &Path) -> Option<u64> {
    use std::os::unix::ffi::OsStrExt;
    use std::ffi::CString;
    let c_path = CString::new(path.as_os_str().as_bytes()).ok()?;
    let mut stat: libc::statvfs = unsafe { std::mem::zeroed() };
    if unsafe { libc::statvfs(c_path.as_ptr(), &mut stat) } == 0 {
        let bavail = stat.f_bavail as u64;
        let bsize = stat.f_bsize as u64;
        bavail.checked_mul(bsize)
    } else {
        None
    }
}

#[cfg(not(any(windows, unix)))]
pub fn available_space_for_path(_path: &Path) -> Option<u64> {
    None
}

struct StoreInner {
    sessions: HashMap<String, Arc<V3TransferSession>>,
    in_progress_reservations: HashMap<String, u64>,
    max_active_sessions: usize,
    max_aggregate_bytes: u64,
}

pub struct ReservationGuard {
    transfer_id: String,
    store: Arc<TransferSessionStore>,
    active: bool,
}

impl ReservationGuard {
    pub async fn rollback(mut self) {
        self.active = false;
        self.store.release_reservation(&self.transfer_id).await;
    }
}

impl Drop for ReservationGuard {
    fn drop(&mut self) {
        if self.active {
            let id = self.transfer_id.clone();
            match self.store.inner.try_write() {
                Ok(mut w) => {
                    w.in_progress_reservations.remove(&id);
                }
                Err(_) => {
                    let store = self.store.clone();
                    tokio::spawn(async move {
                        store.release_reservation(&id).await;
                    });
                }
            }
        }
    }
}

pub struct TransferSessionStore {
    inner: RwLock<StoreInner>,
}

impl TransferSessionStore {
    pub fn new() -> Self {
        Self {
            inner: RwLock::new(StoreInner {
                sessions: HashMap::new(),
                in_progress_reservations: HashMap::new(),
                max_active_sessions: MAX_ACTIVE_SESSIONS,
                max_aggregate_bytes: DEFAULT_MAX_AGGREGATE_RESERVED_BYTES,
            }),
        }
    }

    pub async fn count(&self) -> usize {
        self.inner.read().await.sessions.len()
    }

    pub async fn set_max_aggregate_bytes(&self, bytes: u64) {
        let mut w = self.inner.write().await;
        w.max_aggregate_bytes = bytes;
    }

    pub async fn set_max_active_sessions(&self, max: usize) {
        let mut w = self.inner.write().await;
        w.max_active_sessions = max;
    }

    pub async fn max_aggregate_bytes(&self) -> u64 {
        self.inner.read().await.max_aggregate_bytes
    }

    pub async fn max_active_sessions(&self) -> usize {
        self.inner.read().await.max_active_sessions
    }

    pub async fn total_reserved_bytes(&self) -> u64 {
        let r = self.inner.read().await;
        let mut total: u64 = 0;
        for s in r.sessions.values() {
            if !s.is_committed() {
                total = total.saturating_add(s.manifest.file_size);
            }
        }
        for &res in r.in_progress_reservations.values() {
            total = total.saturating_add(res);
        }
        total
    }

    pub async fn reserve(self: &Arc<Self>, transfer_id: &str, file_size: u64) -> Result<ReservationGuard, AppError> {
        let mut w = self.inner.write().await;

        let active_count = w.sessions.len().checked_add(w.in_progress_reservations.len()).unwrap_or(usize::MAX);
        if active_count >= w.max_active_sessions && !w.sessions.contains_key(transfer_id) && !w.in_progress_reservations.contains_key(transfer_id) {
            return Err(AppError::Message(
                StatusCode::SERVICE_UNAVAILABLE,
                format!("Active session limit reached ({})", w.max_active_sessions),
            ));
        }

        let mut current_reserved: u64 = 0;
        for s in w.sessions.values() {
            if !s.is_committed() {
                current_reserved = current_reserved.saturating_add(s.manifest.file_size);
            }
        }
        for (id, &res) in &w.in_progress_reservations {
            if id != transfer_id {
                current_reserved = current_reserved.saturating_add(res);
            }
        }

        let new_total = current_reserved.checked_add(file_size).ok_or_else(|| {
            AppError::BadRequest("Storage reservation arithmetic overflow".to_string())
        })?;

        if new_total > w.max_aggregate_bytes {
            return Err(AppError::Message(
                StatusCode::INSUFFICIENT_STORAGE,
                format!(
                    "Aggregate storage reservation limit exceeded (requested: {} bytes, currently reserved: {} bytes, max quota: {} bytes)",
                    file_size, current_reserved, w.max_aggregate_bytes
                ),
            ));
        }

        w.in_progress_reservations.insert(transfer_id.to_string(), file_size);

        Ok(ReservationGuard {
            transfer_id: transfer_id.to_string(),
            store: self.clone(),
            active: true,
        })
    }

    pub async fn commit_reservation(&self, mut guard: ReservationGuard, session: Arc<V3TransferSession>) {
        guard.active = false;
        let mut w = self.inner.write().await;
        w.in_progress_reservations.remove(&guard.transfer_id);
        w.sessions.insert(session.transfer_id.clone(), session);
    }

    pub async fn release_reservation(&self, transfer_id: &str) {
        let mut w = self.inner.write().await;
        w.in_progress_reservations.remove(transfer_id);
    }

    pub async fn try_insert(&self, session: Arc<V3TransferSession>) -> Result<(), AppError> {
        let mut w = self.inner.write().await;
        let active_count = w.sessions.len().checked_add(w.in_progress_reservations.len()).unwrap_or(usize::MAX);
        if active_count >= w.max_active_sessions && !w.sessions.contains_key(&session.transfer_id) {
            return Err(AppError::Message(
                StatusCode::SERVICE_UNAVAILABLE,
                format!("Active session limit reached ({})", w.max_active_sessions),
            ));
        }
        w.sessions.insert(session.transfer_id.clone(), session);
        Ok(())
    }

    pub async fn insert(&self, session: Arc<V3TransferSession>) {
        let mut w = self.inner.write().await;
        w.sessions.insert(session.transfer_id.clone(), session);
    }

    pub async fn get(&self, transfer_id: &str) -> Option<Arc<V3TransferSession>> {
        let r = self.inner.read().await;
        r.sessions.get(transfer_id).cloned()
    }

    pub async fn remove(&self, transfer_id: &str) -> Option<Arc<V3TransferSession>> {
        let mut w = self.inner.write().await;
        w.in_progress_reservations.remove(transfer_id);
        w.sessions.remove(transfer_id)
    }

    pub async fn reap_expired(&self, timeout_secs: u64) -> Vec<String> {
        let now = V3TransferSession::now();
        let mut expired_ids = Vec::new();
        let mut w = self.inner.write().await;
        let mut to_remove = Vec::new();

        for (id, session) in w.sessions.iter() {
            let last = session.last_activity.load(Ordering::Relaxed);
            if now.saturating_sub(last) >= timeout_secs {
                if let Ok(_gate) = session.operation_gate.try_lock() {
                    let mut status = session.status.lock().await;
                    if *status != SessionStatus::Committed {
                        *status = SessionStatus::Expired;
                        to_remove.push(id.clone());
                    } else {
                        to_remove.push(id.clone());
                    }
                }
            }
        }

        for id in to_remove {
            w.sessions.remove(&id);
            expired_ids.push(id);
        }

        expired_ids
    }
}

pub struct V3State {
    pub store: Arc<TransferSessionStore>,
    pub event_tx: Option<tokio::sync::mpsc::Sender<crate::http::server::v2::ServerEventV2>>,
}

impl V3State {
    pub fn new() -> Self {
        Self {
            store: Arc::new(TransferSessionStore::new()),
            event_tx: None,
        }
    }

    pub fn new_with_event_tx(
        event_tx: Option<tokio::sync::mpsc::Sender<crate::http::server::v2::ServerEventV2>>,
    ) -> Self {
        Self {
            store: Arc::new(TransferSessionStore::new()),
            event_tx,
        }
    }
}
