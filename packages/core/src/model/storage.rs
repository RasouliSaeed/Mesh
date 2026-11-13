

#[derive(Debug, Clone, Copy, Default)]
pub struct FileTimestamps {
    pub modified: Option<std::time::SystemTime>,
    pub accessed: Option<std::time::SystemTime>,
}

impl FileTimestamps {
    pub fn is_empty(&self) -> bool {
        self.modified.is_none() && self.accessed.is_none()
    }
}

#[derive(Debug, thiserror::Error)]
pub enum StorageError {
    #[error("File not found")]
    NotFound,
    #[error("Permission denied")]
    PermissionDenied,
    #[error("File already exists")]
    AlreadyExists,
    #[error("Unexpected file type: {0}")]
    UnexpectedFileType(String),
    #[error("Storage unavailable")]
    Unavailable,
    #[error("Failed to open storage: {0}")]
    OpenFailed(String),
    #[error("Failed to read from storage: {0}")]
    ReadFailed(String),
    #[error("Failed to write to storage: {0}")]
    WriteFailed(String),
    #[error("Failed to flush storage: {0}")]
    FlushFailed(String),
    #[error("Failed to commit storage: {0}")]
    CommitFailed(String),
    #[error("Failed to abort storage: {0}")]
    AbortFailed(String),
    #[error("Insufficient space")]
    InsufficientSpace,
    #[error("Storage operation cancelled")]
    Cancelled,
    #[error("Unsupported storage operation: {0}")]
    Unsupported(String),
    #[error("Unknown storage error: {0}")]
    Unknown(String),
}

pub trait StorageHandle: Send + Sync {
    /// Writes a chunk of data to the storage.
    /// Writes a chunk of data sequentially (Phase 2C).
    fn write_data<'a>(&'a mut self, data: &'a [u8]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;

    /// Writes a chunk of data at a specific offset (Phase 2D).
    fn write_at<'a>(&'a mut self, offset: u64, data: &'a [u8]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;

    /// Reads up to `buf.len()` bytes at a specific offset into `buf` (Phase 2D).
    /// Returns the number of bytes read (0 indicates EOF at or beyond `offset`).
    fn read_at<'a>(&'a mut self, offset: u64, buf: &'a mut [u8]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<usize, StorageError>> + Send + 'a>>;

    /// Flushes any buffered data to the underlying storage.
    fn flush<'a>(&'a mut self) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;

    /// Set length / truncate file.
    fn set_len<'a>(&'a mut self, len: u64) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;

    /// Commits the stored data (e.g., renames a temporary file to its final name) and applies timestamps.
    /// After calling commit, the handle is consumed.
    fn commit(self: Box<Self>, timestamps: FileTimestamps) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send>>;

    /// Aborts the storage operation. Incomplete temporary files might be left on disk per policy (this is NOT a persistent resume state).
    /// After calling abort, the handle is consumed.
    fn abort(self: Box<Self>) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send>>;
}
