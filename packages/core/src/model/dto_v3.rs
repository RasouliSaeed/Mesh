use serde::{Deserialize, Serialize};

pub const DEFAULT_CHUNK_SIZE: u64 = 1024 * 1024; // 1 MiB
pub const MAX_CHUNK_SIZE: u64 = 16 * 1024 * 1024; // 16 MiB
pub const MAX_FILE_SIZE: u64 = 1024 * 1024 * 1024 * 1024; // 1 TiB (1,099,511,627,776 bytes)
pub const MAX_TOTAL_CHUNKS: u64 = 100_000;

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct TransferManifestDto {
    pub transfer_id: String,
    pub file_name: String,
    pub file_size: u64,
    pub chunk_size: u64,
    pub total_chunks: u64,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub expected_sha256: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ManifestResponseDto {
    pub session_id: String,
    pub missing_chunks: Vec<u64>,
}

/// Computes the expected total chunk count for a file with bounds and overflow checks.
pub fn calculate_chunk_count(file_size: u64, chunk_size: u64) -> Result<u64, &'static str> {
    if chunk_size == 0 || chunk_size > MAX_CHUNK_SIZE {
        return Err("chunk_size must be between 1 and 16 MiB");
    }
    if file_size > MAX_FILE_SIZE {
        return Err("file_size exceeds maximum allowed (1 TiB)");
    }
    if file_size == 0 {
        return Ok(0);
    }
    let q = file_size / chunk_size;
    let r = file_size % chunk_size;
    let count = if r == 0 {
        q
    } else {
        q.checked_add(1).ok_or("Chunk count calculation overflow")?
    };
    if count > MAX_TOTAL_CHUNKS {
        return Err("Total chunks exceeds limit of 100,000");
    }
    Ok(count)
}

/// Validates file names to prevent path traversal and reserved device names.
pub fn validate_filename(file_name: &str) -> Result<(), &'static str> {
    if file_name.trim().is_empty() {
        return Err("File name cannot be empty or whitespace");
    }
    if file_name.len() > 255 {
        return Err("File name exceeds maximum length of 255 bytes");
    }
    if file_name == "." || file_name == ".." {
        return Err("File name cannot be '.' or '..'");
    }
    if file_name.contains("..") {
        return Err("File name cannot contain '..'");
    }
    for c in file_name.chars() {
        if c.is_control()
            || c == '/'
            || c == '\\'
            || c == ':'
            || c == '<'
            || c == '>'
            || c == '"'
            || c == '|'
            || c == '?'
            || c == '*'
        {
            return Err("File name contains illegal or path separator characters");
        }
    }
    let stem = file_name.split('.').next().unwrap_or("").to_ascii_uppercase();
    const RESERVED: &[&str] = &[
        "CON", "PRN", "AUX", "NUL", "COM1", "COM2", "COM3", "COM4", "COM5", "COM6", "COM7",
        "COM8", "COM9", "LPT1", "LPT2", "LPT3", "LPT4", "LPT5", "LPT6", "LPT7", "LPT8", "LPT9",
    ];
    if RESERVED.contains(&stem.as_str()) {
        return Err("File name is a reserved device name");
    }
    Ok(())
}

