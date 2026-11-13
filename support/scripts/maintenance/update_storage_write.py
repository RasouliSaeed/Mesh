with open('packages/core/src/model/storage.rs', 'r', encoding='utf-8') as f:
    content = f.read()

write_at = """    /// Writes a chunk of data sequentially (Phase 2C).
    fn write_data<'a>(&'a mut self, data: &'a [u8]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;

    /// Writes a chunk of data at a specific offset (Phase 2D).
    fn write_at<'a>(&'a mut self, offset: u64, data: &'a [u8]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;"""

content = content.replace("    fn write_data<'a>(&'a mut self, data: &'a [u8]) -> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), StorageError>> + Send + 'a>>;", write_at)

with open('packages/core/src/model/storage.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Added write_at to StorageHandle")
