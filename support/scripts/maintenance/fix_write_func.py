with open('packages/core/src/http/server/common/save.rs', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Find write_file_from_receiver
start_idx = content.find("async fn write_file_from_receiver(")
end_idx = content.find("\n}", start_idx) + 2

old_func = content[start_idx:end_idx]

new_func = """async fn write_file_from_receiver(
    mut handle: Box<dyn crate::model::storage::StorageHandle>,
    expected_size: u64,
    rx: &mut mpsc::Receiver<Bytes>,
    progress_tx: Option<mpsc::Sender<u64>>,
    timestamps: FileTimestamps,
) -> Result<(), String> {
    let mut written: u64 = 0;
    while let Some(chunk) = rx.recv().await {
        written += chunk.len() as u64;
        if written > expected_size {
            let _ = handle.abort().await;
            return Err(format!(
                "Expected {expected_size} bytes, received at least {written}"
            ));
        }
        if let Err(e) = handle.write_chunk(&chunk).await {
            let _ = handle.abort().await;
            return Err(format!("Failed to write file: {e}"));
        }
        if let Some(progress_tx) = &progress_tx {
            let _ = progress_tx.try_send(written);
        }
    }
    
    if let Err(e) = handle.flush().await {
        let _ = handle.abort().await;
        return Err(format!("Failed to flush file: {e}"));
    }

    if written != expected_size {
        let _ = handle.abort().await;
        return Err(format!(
            "Expected {expected_size} bytes, received {written}"
        ));
    }

    if let Err(e) = handle.set_len(written).await {
        tracing::warn!("Could not truncate file to {written} bytes: {e}");
    }

    if let Err(e) = handle.commit(timestamps).await {
        return Err(format!("Failed to commit file: {e}"));
    }

    Ok(())
}"""

content = content.replace(old_func, new_func)

with open('packages/core/src/http/server/common/save.rs', 'w', encoding='utf-8') as f:
    f.write(content)
print("Fixed write_file_from_receiver")
