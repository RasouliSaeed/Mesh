use crate::model::storage::{StorageHandle, StorageError, FileTimestamps};
use std::path::{Path, PathBuf};
use tokio::fs::File;
use tokio::io::{AsyncReadExt, AsyncSeekExt, AsyncWriteExt};
use std::pin::Pin;

#[derive(Debug)]
pub struct DesktopStorageHandle {
    file: Option<File>,
    temp_path: PathBuf,
    final_path: PathBuf,
    allow_overwrite: bool,
}

impl DesktopStorageHandle {
    /// Computes the temporary file path for a given final destination path.
    pub fn temp_path_for(final_path: &Path) -> PathBuf {
        let mut temp_path_str = final_path.to_string_lossy().to_string();
        temp_path_str.push_str(".locara.part");
        PathBuf::from(temp_path_str)
    }

    /// Creates a brand new partial file at an explicitly specified temporary path.
    ///
    /// # Errors
    /// - `StorageError::AlreadyExists` if either `final_path` or `temp_path` already exists.
    /// - `StorageError::OpenFailed` if creating the partial file fails.
    pub async fn create_new_with_temp(temp_path: PathBuf, final_path: PathBuf) -> Result<Self, StorageError> {
        if tokio::fs::symlink_metadata(&final_path).await.is_ok() {
            return Err(StorageError::AlreadyExists);
        }

        let mut options = tokio::fs::OpenOptions::new();
        options.read(true).write(true).create_new(true);

        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.custom_flags(libc::O_NOFOLLOW);
        }

        #[cfg(windows)]
        {
            const FILE_FLAG_OPEN_REPARSE_POINT: u32 = 0x00200000;
            options.custom_flags(FILE_FLAG_OPEN_REPARSE_POINT);
        }

        let file = options
            .open(&temp_path)
            .await
            .map_err(|e| {
                if e.kind() == std::io::ErrorKind::AlreadyExists {
                    StorageError::AlreadyExists
                } else {
                    StorageError::OpenFailed(e.to_string())
                }
            })?;

        Ok(Self {
            file: Some(file),
            temp_path,
            final_path,
            allow_overwrite: false,
        })
    }

    /// Creates a brand new partial file for a transfer.
    ///
    /// # Errors
    /// - `StorageError::AlreadyExists` if either `final_path` or `<final_path>.locara.part` already exists.
    /// - `StorageError::OpenFailed` if creating the partial file fails.
    pub async fn create_new(final_path: PathBuf) -> Result<Self, StorageError> {
        let temp_path = Self::temp_path_for(&final_path);
        Self::create_new_with_temp(temp_path, final_path).await
    }

    /// Reopens an existing partial file at an explicitly specified temporary path without truncating it.
    ///
    /// # Errors
    /// - `StorageError::AlreadyExists` if `final_path` already exists (as file, dir, or symlink).
    /// - `StorageError::NotFound` if `temp_path` does not exist.
    /// - `StorageError::UnexpectedFileType` if `temp_path` is a symlink, junction, or non-regular file.
    /// - `StorageError::OpenFailed` if opening the partial file fails.
    pub async fn reopen_existing_with_temp(temp_path: PathBuf, final_path: PathBuf) -> Result<Self, StorageError> {
        if tokio::fs::symlink_metadata(&final_path).await.is_ok() {
            return Err(StorageError::AlreadyExists);
        }

        let metadata = tokio::fs::symlink_metadata(&temp_path).await.map_err(|e| {
            if e.kind() == std::io::ErrorKind::NotFound {
                StorageError::NotFound
            } else {
                StorageError::OpenFailed(e.to_string())
            }
        })?;

        let file_type = metadata.file_type();
        if file_type.is_symlink() {
            return Err(StorageError::UnexpectedFileType(format!(
                "Partial path {:?} is a symbolic link or junction",
                temp_path
            )));
        }

        if !file_type.is_file() {
            return Err(StorageError::UnexpectedFileType(format!(
                "Partial path {:?} is not a regular file",
                temp_path
            )));
        }

        let mut options = tokio::fs::OpenOptions::new();
        options.read(true).write(true).create(false).truncate(false);

        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.custom_flags(libc::O_NOFOLLOW);
        }

        #[cfg(windows)]
        {
            const FILE_FLAG_OPEN_REPARSE_POINT: u32 = 0x00200000;
            options.custom_flags(FILE_FLAG_OPEN_REPARSE_POINT);
        }

        let file = options
            .open(&temp_path)
            .await
            .map_err(|e| {
                #[cfg(unix)]
                if e.raw_os_error() == Some(libc::ELOOP) {
                    return StorageError::UnexpectedFileType(format!(
                        "Partial path {:?} is a symbolic link (O_NOFOLLOW)",
                        temp_path
                    ));
                }
                StorageError::OpenFailed(e.to_string())
            })?;

        let opened_meta = file.metadata().await.map_err(|e| StorageError::OpenFailed(e.to_string()))?;

        #[cfg(windows)]
        {
            use std::os::windows::fs::MetadataExt;
            const FILE_ATTRIBUTE_REPARSE_POINT: u32 = 0x00000400;
            if opened_meta.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 || opened_meta.file_type().is_symlink() {
                return Err(StorageError::UnexpectedFileType(format!(
                    "Opened partial handle {:?} is a reparse point or junction",
                    temp_path
                )));
            }
        }

        #[cfg(unix)]
        {
            if opened_meta.file_type().is_symlink() {
                return Err(StorageError::UnexpectedFileType(format!(
                    "Opened partial handle {:?} is a symbolic link",
                    temp_path
                )));
            }
        }

        if !opened_meta.is_file() {
            return Err(StorageError::UnexpectedFileType(format!(
                "Opened partial handle {:?} is not a regular file",
                temp_path
            )));
        }

        Ok(Self {
            file: Some(file),
            temp_path,
            final_path,
            allow_overwrite: false,
        })
    }

    /// Reopens an existing partial file for resuming a transfer without truncating it.
    ///
    /// # Errors
    /// - `StorageError::AlreadyExists` if `final_path` already exists (as file, dir, or symlink).
    /// - `StorageError::NotFound` if `<final_path>.locara.part` does not exist.
    /// - `StorageError::UnexpectedFileType` if `<final_path>.locara.part` is a symlink, junction, or non-regular file.
    /// - `StorageError::OpenFailed` if opening the partial file fails.
    pub async fn reopen_existing(final_path: PathBuf) -> Result<Self, StorageError> {
        let temp_path = Self::temp_path_for(&final_path);
        Self::reopen_existing_with_temp(temp_path, final_path).await
    }

    /// Opens or creates a partial file for sequential writing (V2 legacy mode).
    ///
    /// Reuses or truncates any existing `.locara.part` file for clean retries,
    /// and permits replacing `final_path` upon commit (supporting V2 retry semantics).
    pub async fn new(final_path: PathBuf) -> Result<Self, StorageError> {
        let temp_path = Self::temp_path_for(&final_path);

        let file = tokio::fs::OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(true)
            .open(&temp_path)
            .await
            .map_err(|e| StorageError::OpenFailed(e.to_string()))?;

        Ok(Self {
            file: Some(file),
            temp_path,
            final_path,
            allow_overwrite: true,
        })
    }

    /// Accessor for the temporary partial file path.
    pub fn temp_path(&self) -> &Path {
        &self.temp_path
    }

    /// Accessor for the final destination path.
    pub fn final_path(&self) -> &Path {
        &self.final_path
    }
}

impl StorageHandle for DesktopStorageHandle {
    fn write_data<'a>(&'a mut self, data: &'a [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.write_all(data).await.map_err(|e| StorageError::WriteFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

    fn write_at<'a>(&'a mut self, offset: u64, data: &'a [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.seek(std::io::SeekFrom::Start(offset)).await.map_err(|e| StorageError::WriteFailed(e.to_string()))?;
                f.write_all(data).await.map_err(|e| StorageError::WriteFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

    fn read_at<'a>(&'a mut self, offset: u64, buf: &'a mut [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<usize, StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.seek(std::io::SeekFrom::Start(offset)).await.map_err(|e| StorageError::ReadFailed(e.to_string()))?;
                f.read(buf).await.map_err(|e| StorageError::ReadFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

    fn flush<'a>(&'a mut self) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.flush().await.map_err(|e| StorageError::FlushFailed(e.to_string()))?;
                f.sync_data().await.map_err(|e| StorageError::FlushFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

    fn set_len<'a>(&'a mut self, len: u64) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.set_len(len).await.map_err(|e| StorageError::WriteFailed(e.to_string()))?;
            }
            Ok(())
        })
    }

    fn commit(mut self: Box<Self>, timestamps: FileTimestamps) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send>> {
        Box::pin(async move {
            if !self.allow_overwrite && tokio::fs::symlink_metadata(&self.final_path).await.is_ok() {
                return Err(StorageError::AlreadyExists);
            }
            if let Some(mut f) = self.file.take() {
                let _ = f.flush().await; // Ignore flush error on commit
                let _ = f.sync_data().await;
                
                if !timestamps.is_empty() {
                    let mut times = std::fs::FileTimes::new();
                    if let Some(m) = timestamps.modified {
                        times = times.set_modified(m);
                    }
                    if let Some(a) = timestamps.accessed {
                        times = times.set_accessed(a);
                    }
                    let std_file = f.into_std().await;
                    let _ = std_file.set_times(times); // best effort
                } else {
                    drop(f); // Close file before renaming or linking
                }
            }

            if self.allow_overwrite {
                // V2 legacy retry/overwrite mode
                tokio::fs::rename(&self.temp_path, &self.final_path)
                    .await
                    .map_err(|e| {
                        if e.kind() == std::io::ErrorKind::AlreadyExists {
                            StorageError::AlreadyExists
                        } else {
                            StorageError::CommitFailed(e.to_string())
                        }
                    })
            } else {
                // V3 strict non-replacing atomic commit
                match tokio::fs::hard_link(&self.temp_path, &self.final_path).await {
                    Ok(()) => {
                        // Destination is now atomically published.
                        // Remove temporary partial file link.
                        if let Err(e) = tokio::fs::remove_file(&self.temp_path).await {
                            tracing::warn!(
                                "Destination published successfully at {:?}, but failed to remove temporary partial link {:?}: {}",
                                self.final_path,
                                self.temp_path,
                                e
                            );
                        }
                        Ok(())
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                        Err(StorageError::AlreadyExists)
                    }
                    Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
                        Err(StorageError::PermissionDenied)
                    }
                    Err(link_err) => {
                        // Fall back to copy-then-delete if hard link is not supported across filesystem volumes
                        match tokio::fs::copy(&self.temp_path, &self.final_path).await {
                            Ok(_) => {
                                if let Err(e) = tokio::fs::remove_file(&self.temp_path).await {
                                    tracing::warn!(
                                        "Destination published via copy successfully at {:?}, but failed to remove temporary partial link {:?}: {}",
                                        self.final_path,
                                        self.temp_path,
                                        e
                                    );
                                }
                                Ok(())
                            }
                            Err(e) if e.kind() == std::io::ErrorKind::AlreadyExists => {
                                Err(StorageError::AlreadyExists)
                            }
                            Err(e) if e.kind() == std::io::ErrorKind::PermissionDenied => {
                                Err(StorageError::PermissionDenied)
                            }
                            Err(copy_err) => {
                                Err(StorageError::CommitFailed(format!(
                                    "Commit failed via hard link ({link_err}) and copy ({copy_err}) on {:?}",
                                    self.final_path
                                )))
                            }
                        }
                    }
                }
            }
        })
    }

    fn abort(mut self: Box<Self>) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send>> {
        Box::pin(async move {
            if let Some(f) = self.file.take() {
                drop(f);
            }
            if self.temp_path.exists() {
                let _ = tokio::fs::remove_file(&self.temp_path).await;
            }
            Ok(())
        })
    }
}

#[cfg(target_os = "android")]
pub struct AndroidSafStorageHandle {
    file: Option<File>,
}

#[cfg(target_os = "android")]
impl AndroidSafStorageHandle {
    pub async fn new(fd: std::os::fd::RawFd) -> Result<Self, StorageError> {
        use std::os::fd::FromRawFd;
        let std_file = unsafe { std::fs::File::from_raw_fd(fd) };
        let file = tokio::fs::File::from_std(std_file);
        Ok(Self { file: Some(file) })
    }
}

#[cfg(target_os = "android")]
impl StorageHandle for AndroidSafStorageHandle {
    fn write_data<'a>(&'a mut self, data: &'a [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.write_all(data).await.map_err(|e| StorageError::WriteFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

        fn write_at<'a>(&'a mut self, offset: u64, data: &'a [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                use tokio::io::{AsyncSeekExt, AsyncWriteExt};
                f.seek(std::io::SeekFrom::Start(offset)).await.map_err(|e| StorageError::WriteFailed(e.to_string()))?;
                f.write_all(data).await.map_err(|e| StorageError::WriteFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

    fn read_at<'a>(&'a mut self, _offset: u64, _buf: &'a mut [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<usize, StorageError>> + Send + 'a>> {
        Box::pin(async move {
            Err(StorageError::ReadFailed("read_at is not currently supported or tested on Android SAF".to_string()))
        })
    }

    fn flush<'a>(&'a mut self) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                f.flush().await.map_err(|e| StorageError::FlushFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }

    fn set_len<'a>(&'a mut self, len: u64) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                let _ = f.set_len(len).await;
            }
            Ok(())
        })
    }

    fn commit(mut self: Box<Self>, timestamps: FileTimestamps) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send>> {
        Box::pin(async move {
            if let Some(mut f) = self.file.take() {
                let _ = f.flush().await; // Flush before close
                
                if !timestamps.is_empty() {
                    let mut times = std::fs::FileTimes::new();
                    if let Some(m) = timestamps.modified {
                        times = times.set_modified(m);
                    }
                    if let Some(a) = timestamps.accessed {
                        times = times.set_accessed(a);
                    }
                    let std_file = f.into_std().await;
                    let _ = std_file.set_times(times); // best effort
                } else {
                    drop(f); // Close file to commit SAF changes
                }
            }
            Ok(())
        })
    }

    fn abort(mut self: Box<Self>) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send>> {
        Box::pin(async move {
            if let Some(f) = self.file.take() {
                drop(f);
            }
            Ok(())
        })
    }
}
