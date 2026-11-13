with open('packages/core/src/model/storage_adapter.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
    "let _ = tokio::fs::remove_file(&self.temp_path).await; // Ignore missing file\n            Ok(())",
    "// Intentionally leaving the temporary file on disk (current policy)\n            Ok(())"
)

with open('packages/core/src/model/storage_adapter.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated abort in storage_adapter.rs")
