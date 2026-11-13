use locara::model::storage::{FileTimestamps, StorageError, StorageHandle};
use locara::model::storage_adapter::DesktopStorageHandle;
use sha2::{Digest, Sha256};
use std::path::PathBuf;

fn to_hex(bytes: &[u8]) -> String {
    bytes.iter().map(|b| format!("{b:02x}")).collect()
}

fn create_isolated_test_dir(name: &str) -> PathBuf {
    let dir = std::env::temp_dir().join(format!("locara-storage-test-{}-{}", name, uuid::Uuid::new_v4()));
    std::fs::create_dir_all(&dir).expect("Failed to create isolated test dir");
    dir
}

// 1. Create new partial file: writes initial content successfully.
#[tokio::test]
async fn test_create_new_partial_file() {
    let test_dir = create_isolated_test_dir("create_new");
    let final_path = test_dir.join("test_file.bin");
    let temp_path = DesktopStorageHandle::temp_path_for(&final_path);

    let mut handle = DesktopStorageHandle::create_new(final_path.clone())
        .await
        .expect("create_new should succeed");

    assert!(temp_path.exists(), "Temporary .locara.part file should exist");
    assert!(!final_path.exists(), "Final destination must not exist yet");

    handle
        .write_data(b"hello locara storage")
        .await
        .expect("write_data should succeed");
    handle.flush().await.expect("flush should succeed");

    let read_on_disk = tokio::fs::read(&temp_path).await.expect("read .part file");
    assert_eq!(read_on_disk, b"hello locara storage");

    let _ = Box::new(handle).abort().await;
    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 2. Reopen without truncation: write content, close the handle, reopen the same partial file, and verify existing bytes remain intact.
#[tokio::test]
async fn test_reopen_without_truncation() {
    let test_dir = create_isolated_test_dir("reopen_no_trunc");
    let final_path = test_dir.join("resumable.bin");
    let temp_path = DesktopStorageHandle::temp_path_for(&final_path);

    // Initial write
    {
        let mut handle = DesktopStorageHandle::create_new(final_path.clone())
            .await
            .expect("create_new should succeed");
        handle
            .write_data(b"chunk_0_data_12345")
            .await
            .expect("write chunk 0");
        handle.flush().await.expect("flush initial write");
        // Handle dropped here (simulating network disconnect or app shutdown)
    }

    assert!(temp_path.exists(), ".part file should exist after drop");

    // Reopen for resume
    let mut resume_handle = DesktopStorageHandle::reopen_existing(final_path.clone())
        .await
        .expect("reopen_existing should succeed");

    // Verify existing bytes remain intact
    let mut buf = [0u8; 18];
    let n = resume_handle
        .read_at(0, &mut buf)
        .await
        .expect("read_at should succeed");
    assert_eq!(n, 18);
    assert_eq!(&buf[..n], b"chunk_0_data_12345");

    // Append additional content at offset 18
    resume_handle
        .write_at(18, b"_chunk_1_data_67890")
        .await
        .expect("write chunk 1");
    resume_handle.flush().await.expect("flush resume handle");

    let total_bytes = tokio::fs::read(&temp_path).await.expect("read full .part file");
    assert_eq!(total_bytes, b"chunk_0_data_12345_chunk_1_data_67890");

    let _ = Box::new(resume_handle).abort().await;
    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 3. Random-access write: write additional content at a specified offset and verify the expected byte layout.
#[tokio::test]
async fn test_random_access_write() {
    let test_dir = create_isolated_test_dir("random_access");
    let final_path = test_dir.join("random_access.bin");

    let mut handle = DesktopStorageHandle::create_new(final_path.clone())
        .await
        .expect("create_new should succeed");

    // Write chunk at offset 100 first
    handle
        .write_at(100, b"CHUNK_AT_100")
        .await
        .expect("write at 100");
    // Write chunk at offset 0 next
    handle
        .write_at(0, b"CHUNK_AT_0")
        .await
        .expect("write at 0");
    // Write chunk at offset 50
    handle
        .write_at(50, b"CHUNK_AT_50")
        .await
        .expect("write at 50");
    handle.flush().await.expect("flush handle");

    // Verify layout using read_at
    let mut buf_0 = [0u8; 10];
    let n0 = handle.read_at(0, &mut buf_0).await.expect("read at 0");
    assert_eq!(&buf_0[..n0], b"CHUNK_AT_0");

    let mut buf_50 = [0u8; 11];
    let n50 = handle.read_at(50, &mut buf_50).await.expect("read at 50");
    assert_eq!(&buf_50[..n50], b"CHUNK_AT_50");

    let mut buf_100 = [0u8; 12];
    let n100 = handle.read_at(100, &mut buf_100).await.expect("read at 100");
    assert_eq!(&buf_100[..n100], b"CHUNK_AT_100");

    // Verify intermediate gap (e.g. between 10 and 50) is zeroed by filesystem
    let mut gap_buf = [0u8; 10];
    let ngap = handle.read_at(20, &mut gap_buf).await.expect("read at gap");
    assert_eq!(ngap, 10);
    assert_eq!(gap_buf, [0u8; 10]);

    let _ = Box::new(handle).abort().await;
    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 4. Read existing partial content: read bounded ranges without loading the entire file.
#[tokio::test]
async fn test_read_existing_partial_content_bounded_streaming() {
    let test_dir = create_isolated_test_dir("bounded_read");
    let final_path = test_dir.join("large_partial.bin");

    let mut handle = DesktopStorageHandle::create_new(final_path.clone())
        .await
        .expect("create_new should succeed");

    // Write 256 KiB with a known deterministic sequence
    let total_size = 256 * 1024;
    let pattern: Vec<u8> = (0..total_size).map(|i| (i % 251) as u8).collect();
    let expected_sha256 = {
        let mut hasher = Sha256::new();
        hasher.update(&pattern);
        to_hex(&hasher.finalize())
    };

    handle.write_data(&pattern).await.expect("write pattern");
    handle.flush().await.expect("flush pattern");

    // Stream verification using bounded 8 KiB buffer without buffering complete file
    let mut offset = 0u64;
    let mut bounded_buf = [0u8; 8192];
    let mut streaming_hasher = Sha256::new();

    loop {
        let n = handle
            .read_at(offset, &mut bounded_buf)
            .await
            .expect("read_at bounded slice");
        if n == 0 {
            break;
        }
        streaming_hasher.update(&bounded_buf[..n]);
        offset += n as u64;
    }

    assert_eq!(offset, total_size as u64, "Must have read exactly 256 KiB");
    let actual_sha256 = to_hex(&streaming_hasher.finalize());
    assert_eq!(actual_sha256, expected_sha256, "Full-file streaming SHA-256 must match");

    let _ = Box::new(handle).abort().await;
    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 5. Invalid or conflicting reopen: verify that an incompatible file or unexpected existing path is rejected safely.
#[tokio::test]
async fn test_invalid_or_conflicting_reopen() {
    let test_dir = create_isolated_test_dir("invalid_reopen");
    let final_path = test_dir.join("target.bin");
    let temp_path = DesktopStorageHandle::temp_path_for(&final_path);

    // Case 5a: reopen_existing when partial file does not exist -> NotFound
    let err_not_found = DesktopStorageHandle::reopen_existing(final_path.clone()).await;
    assert!(
        matches!(err_not_found, Err(StorageError::NotFound)),
        "Expected NotFound when .part does not exist, got: {:?}",
        err_not_found
    );

    // Case 5b: reopen_existing when partial path is a directory -> UnexpectedFileType
    tokio::fs::create_dir(&temp_path).await.expect("create dir at temp_path");
    let err_dir = DesktopStorageHandle::reopen_existing(final_path.clone()).await;
    assert!(
        matches!(err_dir, Err(StorageError::UnexpectedFileType(_))),
        "Expected UnexpectedFileType when path is a directory, got: {:?}",
        err_dir
    );
    tokio::fs::remove_dir(&temp_path).await.expect("clean up temp dir");

    // Case 5c: create_new when partial file already exists -> AlreadyExists (conflict prevention)
    tokio::fs::write(&temp_path, b"already exists").await.expect("create existing .part");
    let err_already_exists = DesktopStorageHandle::create_new(final_path.clone()).await;
    assert!(
        matches!(err_already_exists, Err(StorageError::AlreadyExists)),
        "Expected AlreadyExists when creating over an existing partial file, got: {:?}",
        err_already_exists
    );

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 6. Atomic commit: verify the final file contents and expected partial-file lifecycle.
#[tokio::test]
async fn test_atomic_commit_lifecycle() {
    let test_dir = create_isolated_test_dir("atomic_commit");
    let final_path = test_dir.join("committed.bin");
    let temp_path = DesktopStorageHandle::temp_path_for(&final_path);

    let mut handle = DesktopStorageHandle::create_new(final_path.clone())
        .await
        .expect("create_new should succeed");

    let content = b"atomic commit payload bytes";
    handle.write_data(content).await.expect("write payload");
    handle.flush().await.expect("flush payload");

    assert!(temp_path.exists(), "Temporary file exists before commit");
    assert!(!final_path.exists(), "Final file does not exist before commit");

    Box::new(handle)
        .commit(FileTimestamps::default())
        .await
        .expect("commit should succeed");

    assert!(!temp_path.exists(), "Temporary file must be removed/renamed after commit");
    assert!(final_path.exists(), "Final destination must exist after commit");

    let final_bytes = tokio::fs::read(&final_path).await.expect("read final destination");
    assert_eq!(final_bytes, content);

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 7. Abort: verify cleanup behavior and ensure unrelated files are not deleted.
#[tokio::test]
async fn test_abort_cleanup_preserves_unrelated_files() {
    let test_dir = create_isolated_test_dir("abort_cleanup");
    let unrelated_file = test_dir.join("unrelated_user_document.txt");
    tokio::fs::write(&unrelated_file, b"precious user content")
        .await
        .expect("create unrelated file");

    let final_path = test_dir.join("aborted_transfer.bin");
    let temp_path = DesktopStorageHandle::temp_path_for(&final_path);

    let mut handle = DesktopStorageHandle::create_new(final_path.clone())
        .await
        .expect("create_new should succeed");

    handle.write_data(b"incomplete partial junk").await.expect("write partial");
    assert!(temp_path.exists(), "Temporary file exists prior to abort");

    Box::new(handle).abort().await.expect("abort should succeed");

    assert!(!temp_path.exists(), "Temporary file must be cleaned up on abort");
    assert!(!final_path.exists(), "Final file must never be created on abort");

    // Unrelated file must be intact
    assert!(unrelated_file.exists(), "Unrelated file must not be deleted");
    let unrelated_bytes = tokio::fs::read(&unrelated_file).await.expect("read unrelated file");
    assert_eq!(unrelated_bytes, b"precious user content");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 8. Destination collision: verify the defined behavior when the final destination already exists.
#[tokio::test]
async fn test_destination_collision_rejection() {
    let test_dir = create_isolated_test_dir("collision");
    let final_path = test_dir.join("existing_file.bin");

    // Pre-create the final destination
    tokio::fs::write(&final_path, b"original existing file content")
        .await
        .expect("create existing destination");

    // 8a. create_new must reject destination collision
    let err_create = DesktopStorageHandle::create_new(final_path.clone()).await;
    assert!(
        matches!(err_create, Err(StorageError::AlreadyExists)),
        "create_new must fail with AlreadyExists when final_path exists, got: {:?}",
        err_create
    );

    // 8b. reopen_existing must reject destination collision
    let err_reopen = DesktopStorageHandle::reopen_existing(final_path.clone()).await;
    assert!(
        matches!(err_reopen, Err(StorageError::AlreadyExists)),
        "reopen_existing must fail with AlreadyExists when final_path exists, got: {:?}",
        err_reopen
    );

    // 8c. new (V2 legacy mode) permits opening and overwriting final_path upon commit
    let new_res = DesktopStorageHandle::new(final_path.clone()).await;
    assert!(new_res.is_ok(), "new must succeed in V2 legacy mode even if final_path exists");
    let mut new_handle = new_res.unwrap();
    new_handle.write_data(b"overwritten by v2").await.expect("write data");
    Box::new(new_handle).commit(FileTimestamps::default()).await.expect("commit v2 overwrite");
    let overwritten = tokio::fs::read(&final_path).await.expect("read final_path");
    assert_eq!(overwritten, b"overwritten by v2");

    // 8d. Commit must not overwrite an existing final destination if created mid-transfer
    let collision_dir = create_isolated_test_dir("commit_collision");
    let target_path = collision_dir.join("target.bin");
    let mut handle = DesktopStorageHandle::create_new(target_path.clone())
        .await
        .expect("create_new in clean dir");
    handle.write_data(b"new incoming data").await.expect("write data");

    // Create target_path behind the handle's back before commit
    tokio::fs::write(&target_path, b"racing existing file")
        .await
        .expect("simulate race creation");

    let commit_res = Box::new(handle).commit(FileTimestamps::default()).await;
    assert!(
        matches!(commit_res, Err(StorageError::AlreadyExists)),
        "commit must reject overwriting existing final_path with AlreadyExists, got: {:?}",
        commit_res
    );

    // Verify existing content is intact
    let preserved = tokio::fs::read(&target_path).await.expect("read target");
    assert_eq!(preserved, b"racing existing file");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
    let _ = tokio::fs::remove_dir_all(&collision_dir).await;
}

// 9. Regression: ensure existing storage and V2 transfer tests remain compatible.
#[tokio::test]
async fn test_desktop_storage_v2_compat_retry_truncation() {
    let test_dir = create_isolated_test_dir("v2_compat");
    let final_path = test_dir.join("v2_upload.bin");
    let temp_path = DesktopStorageHandle::temp_path_for(&final_path);

    // First attempt creates partial file but fails/aborts or retries without abort
    {
        let mut handle1 = DesktopStorageHandle::new(final_path.clone())
            .await
            .expect("initial V2 handle");
        handle1.write_data(b"corrupted attempt").await.expect("write bad");
        handle1.flush().await.expect("flush bad");
        // Drop handle1 without commit
    }
    assert!(temp_path.exists());

    // V2 retry uses DesktopStorageHandle::new(final_path) which truncates the partial file for clean rewrite
    let mut handle2 = DesktopStorageHandle::new(final_path.clone())
        .await
        .expect("retry V2 handle");
    handle2.write_data(b"clean successful retry").await.expect("write clean");
    handle2.flush().await.expect("flush clean");
    Box::new(handle2)
        .commit(FileTimestamps::default())
        .await
        .expect("commit clean retry");

    let final_data = tokio::fs::read(&final_path).await.expect("read final V2 file");
    assert_eq!(final_data, b"clean successful retry");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 10. Verify symlink and unexpected file type rejection on partial paths.
#[tokio::test]
async fn test_reopen_existing_symlink_rejection() {
    let test_dir = create_isolated_test_dir("symlink_rejection");
    let target_file = test_dir.join("secret_target.txt");
    tokio::fs::write(&target_file, b"CONFIDENTIAL_DATA")
        .await
        .expect("write secret target");

    let final_path = test_dir.join("untrusted_transfer.bin");
    let temp_part_path = DesktopStorageHandle::temp_path_for(&final_path);

    // Attempt to create a symlink at the partial path pointing to secret_target
    let mut symlink_created = false;

    #[cfg(unix)]
    {
        use std::os::unix::fs::symlink;
        if symlink(&target_file, &temp_part_path).is_ok() {
            symlink_created = true;
        }
    }

    #[cfg(windows)]
    {
        use std::os::windows::fs::symlink_file;
        if symlink_file(&target_file, &temp_part_path).is_ok() {
            symlink_created = true;
        }
    }

    if symlink_created {
        // reopen_existing MUST reject the partial path because it is a symlink
        let res = DesktopStorageHandle::reopen_existing(final_path.clone()).await;
        assert!(
            matches!(res, Err(StorageError::UnexpectedFileType(_))),
            "reopen_existing must reject symlinked partial path with UnexpectedFileType, got: {:?}",
            res
        );

        // Verify the secret target file was never modified
        let intact = tokio::fs::read(&target_file).await.expect("read secret target");
        assert_eq!(intact, b"CONFIDENTIAL_DATA");
    } else {
        println!("Note: Symlink creation skipped due to platform privileges (e.g. Windows non-developer mode)");
    }

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 11. Existing destination remains byte-for-byte unchanged after a strict commit collision.
#[tokio::test]
async fn test_destination_byte_for_byte_unchanged_on_strict_commit_collision() {
    let test_dir = create_isolated_test_dir("byte_for_byte_collision");
    let final_path = test_dir.join("protected_dest.bin");

    // Establish pre-existing file with specific binary content
    let original_bytes: Vec<u8> = (0..1024).map(|i| (i % 256) as u8).collect();
    tokio::fs::write(&final_path, &original_bytes)
        .await
        .expect("write original destination file");

    // Create partial file for another transfer targeting the same path
    let collision_dir = create_isolated_test_dir("collision_source");
    let staging_path = collision_dir.join("protected_dest.bin");
    let mut handle = DesktopStorageHandle::create_new(staging_path.clone())
        .await
        .expect("create_new in clean staging dir");

    let attack_bytes = b"COMPLETELY_DIFFERENT_CORRUPT_BYTES";
    handle.write_data(attack_bytes).await.expect("write attack bytes");

    // Manually point handle's final_path to the pre-existing target file to simulate collision
    // (Or create a handle with target_path = final_path by creating it before destination was written)
    let alt_staging = test_dir.join("another_incoming.bin");
    let mut collision_handle = DesktopStorageHandle::create_new(alt_staging.clone())
        .await
        .expect("create alt handle");
    collision_handle.write_data(attack_bytes).await.expect("write data");

    // Create collision by racing: create final_path for alt_staging
    tokio::fs::write(&alt_staging, &original_bytes).await.expect("create destination race");

    let commit_res = Box::new(collision_handle).commit(FileTimestamps::default()).await;
    assert!(
        matches!(commit_res, Err(StorageError::AlreadyExists)),
        "strict commit must return AlreadyExists on collision, got: {:?}",
        commit_res
    );

    // Verify target file remains 100% byte-for-byte unchanged
    let current_bytes = tokio::fs::read(&alt_staging).await.expect("read target");
    assert_eq!(
        current_bytes, original_bytes,
        "pre-existing destination must remain byte-for-byte identical after commit collision"
    );

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
    let _ = tokio::fs::remove_dir_all(&collision_dir).await;
}

// 12. Cleanup failure after successful hard-link publication is handled consistently.
#[tokio::test]
async fn test_cleanup_failure_after_successful_publication_handled_consistently() {
    let test_dir = create_isolated_test_dir("cleanup_failure");
    let final_path = test_dir.join("published_file.bin");
    let temp_part_path = DesktopStorageHandle::temp_path_for(&final_path);

    let mut handle = DesktopStorageHandle::create_new(final_path.clone())
        .await
        .expect("create new handle");

    let payload = b"IMPORTANT_PUBLISHED_CONTENT_42";
    handle.write_data(payload).await.expect("write data");

    // On Windows, open a locking read handle to the temporary file without FILE_SHARE_DELETE.
    // This allows hard linking but causes removal of the .part file to fail with AccessDenied.
    #[cfg(windows)]
    let lock_file = {
        use std::os::windows::fs::OpenOptionsExt;
        // Share read and write, but NOT delete
        std::fs::OpenOptions::new()
            .read(true)
            .share_mode(1 | 2) // FILE_SHARE_READ | FILE_SHARE_WRITE (no FILE_SHARE_DELETE)
            .open(&temp_part_path)
            .ok()
    };

    // Execute commit: hard_link should succeed, but remove_file may fail due to lock
    let commit_res = Box::new(handle).commit(FileTimestamps::default()).await;

    // Publication must be reported as successful (Ok(())) and not concealed with CommitFailed
    assert!(
        commit_res.is_ok(),
        "commit must report Ok(()) once publication succeeds, even if temp link cleanup fails: {:?}",
        commit_res
    );

    // Verify destination exists and has complete valid content
    let final_content = tokio::fs::read(&final_path).await.expect("read final path");
    assert_eq!(final_content, payload);

    #[cfg(windows)]
    {
        if lock_file.is_some() {
            // Because the lock prevented delete, the temporary link still exists
            assert!(
                temp_part_path.exists(),
                "temp link should linger while lock was held"
            );
            drop(lock_file);
            // After dropping the lock, temp link can now be removed
            let _ = tokio::fs::remove_file(&temp_part_path).await;
        }
    }

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

// 13. Reopening directory or reparse junction at partial path is rejected.
#[tokio::test]
async fn test_reopen_existing_directory_and_junction_rejection() {
    let test_dir = create_isolated_test_dir("junction_rejection");
    let final_path = test_dir.join("test_file.bin");
    let temp_part_path = DesktopStorageHandle::temp_path_for(&final_path);

    // 1. Create a directory at the partial file path
    tokio::fs::create_dir(&temp_part_path).await.expect("create dir at part path");

    let err_dir = DesktopStorageHandle::reopen_existing(final_path.clone()).await;
    assert!(
        matches!(err_dir, Err(StorageError::UnexpectedFileType(_))),
        "reopen_existing must reject directories with UnexpectedFileType, got: {:?}",
        err_dir
    );

    tokio::fs::remove_dir(&temp_part_path).await.expect("remove test dir");

    // 2. On Windows, test directory junction if command is available
    #[cfg(windows)]
    {
        let target_dir = test_dir.join("junction_target_dir");
        let _ = tokio::fs::create_dir(&target_dir).await;

        let status = std::process::Command::new("cmd")
            .args(&["/C", "mklink", "/J", temp_part_path.to_str().unwrap(), target_dir.to_str().unwrap()])
            .output();

        if let Ok(output) = status {
            if output.status.success() {
                let err_junction = DesktopStorageHandle::reopen_existing(final_path.clone()).await;
                assert!(
                    matches!(err_junction, Err(StorageError::UnexpectedFileType(_))),
                    "reopen_existing must reject junctions with UnexpectedFileType, got: {:?}",
                    err_junction
                );
                let _ = tokio::fs::remove_dir(&temp_part_path).await;
            } else {
                println!("Note: Junction creation skipped: {:?}", String::from_utf8_lossy(&output.stderr));
            }
        }
    }

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}


