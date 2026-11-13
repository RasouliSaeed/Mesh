use locara::model::resume::{ResumeManager, ResumeState};
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

fn create_isolated_test_dir(test_name: &str) -> PathBuf {
    let nanos = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_nanos();
    let dir = std::env::temp_dir()
        .join("locara_test_resume")
        .join(format!("{}_{}", test_name, nanos));
    std::fs::create_dir_all(&dir).expect("create test dir");
    dir
}

#[tokio::test]
async fn test_resume_manager_save_load_delete_in_dir() {
    let test_dir = create_isolated_test_dir("save_load_delete");

    let state = ResumeState::new(
        "3.0".to_string(),
        "test-transfer-abc-123".to_string(),
        1048576,
        65536,
        16,
        Some("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855".to_string()),
        vec![0, 1, 2, 3],
    );

    // 1. Save in specific directory
    ResumeManager::save_in(&test_dir, &state)
        .await
        .expect("save resume state");

    // Verify file exists on disk
    let expected_file = test_dir.join("locara_resume_test-transfer-abc-123.json");
    assert!(expected_file.exists(), "metadata file must exist");

    // 2. Load from specific directory
    let loaded = ResumeManager::load_from(&test_dir, "test-transfer-abc-123")
        .await
        .expect("load resume state")
        .expect("state should be found");
    assert_eq!(loaded, state);

    // 3. Delete from specific directory
    ResumeManager::delete_from(&test_dir, "test-transfer-abc-123")
        .await
        .expect("delete resume state");
    assert!(!expected_file.exists(), "metadata file must be deleted");

    // 4. Load after delete returns None
    let missing = ResumeManager::load_from(&test_dir, "test-transfer-abc-123")
        .await
        .expect("load should succeed");
    assert!(missing.is_none());

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_path_traversal_rejection() {
    let test_dir = create_isolated_test_dir("path_traversal");

    // Disallow traversal attempts
    assert!(ResumeManager::validate_transfer_id("../escape").is_err());
    assert!(ResumeManager::validate_transfer_id("..\\escape").is_err());
    assert!(ResumeManager::validate_transfer_id("/etc/passwd").is_err());
    assert!(ResumeManager::validate_transfer_id("C:\\Windows").is_err());
    assert!(ResumeManager::validate_transfer_id("has space").is_err());
    assert!(ResumeManager::validate_transfer_id("has$special").is_err());
    assert!(ResumeManager::validate_transfer_id("").is_err());

    // Allowed valid IDs
    assert!(ResumeManager::validate_transfer_id("valid-uuid-1234_ABCD").is_ok());

    // Attempting to save with malicious ID must fail
    let malicious_state = ResumeState::new(
        "3.0".to_string(),
        "../../../escape".to_string(),
        100,
        50,
        2,
        None,
        vec![],
    );
    let save_res = ResumeManager::save_in(&test_dir, &malicious_state).await;
    assert!(save_res.is_err(), "saving with invalid ID must fail");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_durability_and_atomic_replace() {
    let test_dir = create_isolated_test_dir("atomic_replace");

    let mut state = ResumeState::new(
        "3.0".to_string(),
        "tx-atomic-001".to_string(),
        5000,
        1000,
        5,
        None,
        vec![0],
    );

    ResumeManager::save_in(&test_dir, &state).await.expect("initial save");
    let loaded1 = ResumeManager::load_from(&test_dir, "tx-atomic-001").await.unwrap().unwrap();
    assert_eq!(loaded1.completed_chunks, vec![0]);

    // Update state with newly completed chunks
    state.completed_chunks = vec![0, 1, 2];
    ResumeManager::save_in(&test_dir, &state).await.expect("second save");

    let loaded2 = ResumeManager::load_from(&test_dir, "tx-atomic-001").await.unwrap().unwrap();
    assert_eq!(loaded2.completed_chunks, vec![0, 1, 2]);

    // Verify no temporary files (.tmp) linger in directory
    let mut entries = tokio::fs::read_dir(&test_dir).await.expect("read dir");
    let mut count = 0;
    while let Some(entry) = entries.next_entry().await.expect("entry") {
        let name = entry.file_name().to_string_lossy().to_string();
        assert!(!name.ends_with(".tmp"), "no .tmp files should linger: {}", name);
        count += 1;
    }
    assert_eq!(count, 1, "exactly one committed metadata file must exist");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_global_default_dir_operations() {
    // Test the global convenience wrappers
    let test_state = ResumeState::new(
        "3.0".to_string(),
        "test-global-convenience-999".to_string(),
        2048,
        512,
        4,
        None,
        vec![0],
    );

    // Save using default dir
    ResumeManager::save(&test_state).await.expect("global save");

    // Load using default dir
    let loaded = ResumeManager::load("test-global-convenience-999")
        .await
        .expect("global load")
        .expect("must be found");
    assert_eq!(loaded, test_state);

    // Delete using default dir
    ResumeManager::delete("test-global-convenience-999")
        .await
        .expect("global delete");

    let missing = ResumeManager::load("test-global-convenience-999")
        .await
        .expect("global load missing");
    assert!(missing.is_none());
}

#[test]
fn test_resume_manager_default_dir_resolution() {
    let dir = ResumeManager::default_storage_dir().expect("default storage dir should resolve on standard environment");
    assert!(dir.is_absolute(), "default storage dir must be absolute: {:?}", dir);
    let dir_str = dir.to_string_lossy();
    assert!(
        dir_str.contains("locara") && dir_str.contains("resume"),
        "default dir must contain locara/resume: {:?}",
        dir
    );
}

#[test]
fn test_resume_manager_explicit_override_and_clear() {
    let test_dir = create_isolated_test_dir("override_and_clear");
    ResumeManager::set_storage_dir(test_dir.clone());

    let resolved = ResumeManager::default_storage_dir().expect("should resolve overridden dir");
    assert_eq!(resolved, test_dir);

    ResumeManager::clear_storage_dir();
    let restored = ResumeManager::default_storage_dir().expect("should resolve standard dir");
    assert_ne!(restored, test_dir);

    let _ = std::fs::remove_dir_all(&test_dir);
}

#[test]
fn test_resume_manager_failure_when_no_persistent_path() {
    // Simulate an environment where none of the persistent env vars are set
    let res = ResumeManager::resolve_storage_dir_with(|_var| None);
    assert!(
        res.is_err(),
        "must fail closed when no persistent directory environment variables are present"
    );
    let err_msg = res.err().unwrap();
    assert!(err_msg.contains("No persistent storage directory available"));
}

#[tokio::test]
async fn test_resume_manager_invalid_ids_across_all_entry_points() {
    let test_dir = create_isolated_test_dir("invalid_ids");
    let invalid_id = "../malicious/traversal";

    // validate_transfer_id
    assert!(ResumeManager::validate_transfer_id(invalid_id).is_err());

    // get_path_in
    assert!(ResumeManager::get_path_in(&test_dir, invalid_id).is_err());

    // get_path
    assert!(ResumeManager::get_path(invalid_id).is_err());

    // load_from
    assert!(ResumeManager::load_from(&test_dir, invalid_id).await.is_err());

    // load
    assert!(ResumeManager::load(invalid_id).await.is_err());

    // delete_from
    assert!(ResumeManager::delete_from(&test_dir, invalid_id).await.is_err());

    // delete
    assert!(ResumeManager::delete(invalid_id).await.is_err());

    // save_in
    let bad_state = ResumeState::new(
        "3.0".to_string(),
        invalid_id.to_string(),
        100,
        10,
        10,
        None,
        vec![],
    );
    assert!(ResumeManager::save_in(&test_dir, &bad_state).await.is_err());

    // save
    assert!(ResumeManager::save(&bad_state).await.is_err());

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_atomic_replacement_preserves_valid_state_on_failure() {
    let test_dir = create_isolated_test_dir("preserve_on_failure");

    let state = ResumeState::new(
        "3.0".to_string(),
        "preserve-me-001".to_string(),
        1000,
        100,
        10,
        None,
        vec![0, 1],
    );

    // 1. Initial valid save
    ResumeManager::save_in(&test_dir, &state)
        .await
        .expect("initial save should succeed");

    let loaded = ResumeManager::load_from(&test_dir, "preserve-me-001")
        .await
        .expect("load")
        .expect("state");
    assert_eq!(loaded.completed_chunks, vec![0, 1]);

    // 2. Create a subfolder where the temp file path would be unwriteable or simulate failed commit
    // by making a directory at the temp path
    let tmp_path = test_dir.join(format!(".locara_resume_preserve-me-001_{}.tmp", std::process::id()));
    tokio::fs::create_dir(&tmp_path).await.expect("create dir to block file open");

    let mut update_state = state.clone();
    update_state.completed_chunks = vec![0, 1, 2, 3, 4];

    // Saving update should fail because tmp_path is a directory
    let res = ResumeManager::save_in(&test_dir, &update_state).await;
    assert!(res.is_err(), "saving must fail when temp file cannot be opened as a file");

    // Clean up blocking directory
    let _ = tokio::fs::remove_dir(&tmp_path).await;

    // 3. Verify that the previous valid state is 100% preserved
    let preserved = ResumeManager::load_from(&test_dir, "preserve-me-001")
        .await
        .expect("load")
        .expect("state");
    assert_eq!(preserved.completed_chunks, vec![0, 1]);

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_list_active_sessions_discovery() {
    let test_dir = create_isolated_test_dir("list_discovery");

    // 1. Valid resumable session with .part file (2 of 4 chunks done)
    let s1 = ResumeState::new(
        "3.0".to_string(),
        "transfer-resumable-01".to_string(),
        1000,
        250,
        4,
        None,
        vec![0, 1],
    );
    ResumeManager::save_in(&test_dir, &s1).await.expect("save s1");
    // Create corresponding .part file
    tokio::fs::write(test_dir.join("locara_part_transfer-resumable-01.part"), b"part-data")
        .await
        .expect("write part file");

    // 2. All chunks completed session (awaiting commit)
    let s2 = ResumeState::new(
        "3.0".to_string(),
        "transfer-completed-02".to_string(),
        500,
        250,
        2,
        None,
        vec![0, 1],
    );
    ResumeManager::save_in(&test_dir, &s2).await.expect("save s2");
    tokio::fs::write(test_dir.join("locara_part_transfer-completed-02.part"), b"part-data-2")
        .await
        .expect("write part file 2");

    // 3. Incomplete session with missing .part file
    let s3 = ResumeState::new(
        "3.0".to_string(),
        "transfer-missing-part-03".to_string(),
        1000,
        250,
        4,
        None,
        vec![0],
    );
    ResumeManager::save_in(&test_dir, &s3).await.expect("save s3");
    // Notice: no .part file created for s3!

    // 4. Create noise: unrelated file and temp file
    tokio::fs::write(test_dir.join("unrelated_notes.txt"), b"ignore me")
        .await
        .expect("write unrelated");
    tokio::fs::write(test_dir.join(".locara_resume_temp_123.tmp"), b"ignore temp")
        .await
        .expect("write temp");

    // Discover sessions
    let sessions = ResumeManager::list_active_sessions_in(&test_dir)
        .await
        .expect("list sessions");

    assert_eq!(sessions.len(), 3, "Only the 3 valid resume metadata files should be enumerated");

    let s1_info = sessions.iter().find(|s| s.transfer_id == "transfer-resumable-01").expect("find s1");
    assert!(s1_info.is_resumable, "s1 with .part file must be marked resumable");
    assert_eq!(s1_info.completed_chunks_count, 2);
    assert_eq!(s1_info.bytes_transferred, 500); // 2 * 250 bytes
    assert!(s1_info.unresumable_reason.is_none());

    let s2_info = sessions.iter().find(|s| s.transfer_id == "transfer-completed-02").expect("find s2");
    assert!(!s2_info.is_resumable, "s2 with all chunks completed must not be marked as mid-transfer resumable");
    assert!(s2_info.unresumable_reason.as_ref().unwrap().contains("All chunks completed"));

    let s3_info = sessions.iter().find(|s| s.transfer_id == "transfer-missing-part-03").expect("find s3");
    assert!(!s3_info.is_resumable, "s3 with missing .part file must not be marked resumable");
    assert!(s3_info.unresumable_reason.as_ref().unwrap().contains("Partial payload file (.part) is missing"));

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_list_active_sessions_corrupted_metadata() {
    let test_dir = create_isolated_test_dir("corrupted_meta");

    // Write completely corrupted JSON
    tokio::fs::write(test_dir.join("locara_resume_bad-json-01.json"), b"not valid json {{{")
        .await
        .expect("write bad json");

    // Write valid JSON but with total_chunks = 0
    let invalid_bounds = serde_json::json!({
        "protocol": "3.0",
        "transfer_id": "invalid-bounds-02",
        "file_size": 100,
        "chunk_size": 100,
        "total_chunks": 0,
        "completed_chunks": []
    });
    tokio::fs::write(
        test_dir.join("locara_resume_invalid-bounds-02.json"),
        serde_json::to_vec(&invalid_bounds).unwrap(),
    )
    .await
    .expect("write invalid bounds");

    // Write valid JSON but with incompatible protocol
    let invalid_protocol = serde_json::json!({
        "protocol": "1.0",
        "transfer_id": "invalid-proto-03",
        "file_size": 100,
        "chunk_size": 100,
        "total_chunks": 1,
        "completed_chunks": []
    });
    tokio::fs::write(
        test_dir.join("locara_resume_invalid-proto-03.json"),
        serde_json::to_vec(&invalid_protocol).unwrap(),
    )
    .await
    .expect("write invalid proto");

    // Discovery should safely skip all invalid and corrupted entries without panic
    let sessions = ResumeManager::list_active_sessions_in(&test_dir)
        .await
        .expect("list sessions");
    assert_eq!(sessions.len(), 0, "No corrupted or invalid sessions should be returned");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}

#[tokio::test]
async fn test_resume_manager_prune_session() {
    let test_dir = create_isolated_test_dir("prune_session");

    let state = ResumeState::new(
        "3.0".to_string(),
        "prune-target-99".to_string(),
        1000,
        500,
        2,
        None,
        vec![0],
    );
    ResumeManager::save_in(&test_dir, &state).await.expect("save state");
    let part_path = test_dir.join("locara_part_prune-target-99.part");
    tokio::fs::write(&part_path, b"some partial data").await.expect("write part");

    let meta_path = test_dir.join("locara_resume_prune-target-99.json");
    assert!(meta_path.exists());
    assert!(part_path.exists());

    // Prune session
    ResumeManager::prune_session_in(&test_dir, "prune-target-99")
        .await
        .expect("prune session");

    assert!(!meta_path.exists(), "Metadata file must be removed by prune");
    assert!(!part_path.exists(), "Partial file must be removed by prune");

    let _ = tokio::fs::remove_dir_all(&test_dir).await;
}
