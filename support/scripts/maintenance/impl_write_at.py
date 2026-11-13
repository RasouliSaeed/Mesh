with open('packages/core/src/model/storage_adapter.rs', 'r', encoding='utf-8') as f:
    content = f.read()

desktop_write_at = """    fn write_at<'a>(&'a mut self, offset: u64, data: &'a [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                use tokio::io::{AsyncSeekExt, AsyncWriteExt};
                f.seek(std::io::SeekFrom::Start(offset)).await.map_err(|e| StorageError::WriteFailed(e.to_string()))?;
                f.write_all(data).await.map_err(|e| StorageError::WriteFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }"""

android_write_at = """    fn write_at<'a>(&'a mut self, offset: u64, data: &'a [u8]) -> Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>> {
        Box::pin(async move {
            if let Some(f) = self.file.as_mut() {
                use tokio::io::{AsyncSeekExt, AsyncWriteExt};
                f.seek(std::io::SeekFrom::Start(offset)).await.map_err(|e| StorageError::WriteFailed(e.to_string()))?;
                f.write_all(data).await.map_err(|e| StorageError::WriteFailed(e.to_string()))
            } else {
                Err(StorageError::Unavailable)
            }
        })
    }"""

content = content.replace("fn flush<'a>", f"{desktop_write_at}\n\n    fn flush<'a>", 1)
content = content.replace("fn flush<'a>", f"{android_write_at}\n\n    fn flush<'a>")

with open('packages/core/src/model/storage_adapter.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Implemented write_at in adapters")
