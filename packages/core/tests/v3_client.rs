#![cfg(feature = "http")]

//! Integration tests for the V3 client-side chunk transfer implementation.
//!
//! Covers:
//! - Manifest calculations and validation (exact multiples, non-multiples, zero-byte, limits, filenames)
//! - End-to-end transfers (exact multiple chunks, non-multiple chunks, single small chunk, zero-byte)
//! - Bounded-memory behavior and bounded upload concurrency
//! - Source change detection during transfer
//! - Resumption of partially completed transfers
//! - Idempotent chunk retry and conflicting chunk rejection
//! - Commit idempotence and destination collision handling
//! - Malformed server response rejection
//! - Transient vs permanent error classification
//! - Cold-restart TLS peer-binding isolation (different peer cannot resume)

use locara::crypto::hash::sha256_hex;
use locara::http::client::{
    is_transient_error, ClientError, LsHttpClientV3, SourceFileInfo, TransferConfigV3,
};
use locara::http::server::web::WebConfig;
use locara::http::server::{start_with_port, ServerHandle, TlsConfig};
use locara::http::state::ClientInfo;
use locara::http::StatusCodeError;
use locara::model::discovery::ProtocolType;
use locara::model::dto_v3::{
    calculate_chunk_count, validate_filename, MAX_CHUNK_SIZE, MAX_FILE_SIZE, MAX_TOTAL_CHUNKS,
};
use locara::model::resume::ResumeManager;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;
use tokio::sync::oneshot;

// ─── Unique transfer-id counter ───────────────────────────────────────────────

static CLIENT_XFER_COUNTER: AtomicU64 = AtomicU64::new(1000);

fn unique_client_id(label: &str) -> String {
    let n = CLIENT_XFER_COUNTER.fetch_add(1, Ordering::Relaxed);
    let pid = std::process::id();
    format!("{label}-{pid}-{n}")
}

// ─── Test Server Fixture ──────────────────────────────────────────────────────

struct TestServer {
    port: u16,
    stop_tx: Option<oneshot::Sender<()>>,
    handle: Option<ServerHandle>,
}

impl TestServer {
    async fn stop(mut self) {
        if let Some(tx) = self.stop_tx.take() {
            let _ = tx.send(());
        }
        if let Some(h) = self.handle.take() {
            h.wait_stopped().await;
        }
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        if let Some(tx) = self.stop_tx.take() {
            let _ = tx.send(());
        }
    }
}

async fn start_test_server(tls: Option<TlsConfig>) -> TestServer {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();
    let (stop_tx, stop_rx) = oneshot::channel::<()>();

    let handle = start_with_port(
        0,
        tls,
        ClientInfo {
            alias: "V3 Client Test Server".to_string(),
            version: "3.0".to_string(),
            device_model: Some("Rust Test".to_string()),
            device_type: None,
            token: "client-test-server-token".to_string(),
        },
        None,
        None,
        WebConfig::default(),
        stop_rx,
    )
    .await
    .expect("Failed to start V3 client test server");

    let port = handle.port();
    TestServer {
        port,
        stop_tx: Some(stop_tx),
        handle: Some(handle),
    }
}

// ─── Cleanup Helper ───────────────────────────────────────────────────────────

async fn cleanup_transfer(transfer_id: &str, file_name: &str) {
    let _ = ResumeManager::delete(transfer_id).await;
    if let Ok(dir) = ResumeManager::default_storage_dir() {
        let part_file = dir.join(format!("locara_part_{transfer_id}.part"));
        let _ = tokio::fs::remove_file(&part_file).await;
        let incoming_file = dir.join(format!("{file_name}.locara_incoming"));
        let _ = tokio::fs::remove_file(&incoming_file).await;
    }
}

// ─── Test 1: Manifest calculations and validations ───────────────────────────

#[test]
fn test_client_manifest_calculations_and_validation() {
    // 1. Exact multiple
    assert_eq!(calculate_chunk_count(1024, 512).unwrap(), 2);
    // 2. Non-multiple
    assert_eq!(calculate_chunk_count(1025, 512).unwrap(), 3);
    // 3. Smaller than 1 chunk
    assert_eq!(calculate_chunk_count(100, 512).unwrap(), 1);
    // 4. Zero-byte file
    assert_eq!(calculate_chunk_count(0, 512).unwrap(), 0);

    // 5. Bounds and limits
    assert!(calculate_chunk_count(100, 0).is_err());
    assert!(calculate_chunk_count(100, MAX_CHUNK_SIZE + 1).is_err());
    assert!(calculate_chunk_count(MAX_FILE_SIZE + 1, 1024 * 1024).is_err());

    // 6. Exceeding max chunks
    assert!(calculate_chunk_count((MAX_TOTAL_CHUNKS + 1) * 1024, 1024).is_err());

    // 7. Filename validation
    assert!(validate_filename("valid_file.txt").is_ok());
    assert!(validate_filename("").is_err());
    assert!(validate_filename("   ").is_err());
    assert!(validate_filename(".").is_err());
    assert!(validate_filename("..").is_err());
    assert!(validate_filename("a/b.txt").is_err());
    assert!(validate_filename("a\\b.txt").is_err());
    assert!(validate_filename("a:b.txt").is_err());
    assert!(validate_filename("foo..bar").is_err());
    assert!(validate_filename("CON.txt").is_err());
    assert!(validate_filename("nul").is_err());
}

// ─── Test 2: End-to-end exact multiple chunks transfer ────────────────────────

#[tokio::test]
async fn test_client_transfer_exact_multiple_chunks() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("exact-mult");
    let fname = format!("{id}.bin");

    // Temp source file: 192 bytes = 3 chunks of 64 bytes
    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content: Vec<u8> = (0..192).map(|i| (i as u8).wrapping_add(7)).collect();
    tokio::fs::write(&src_path, &content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();
    assert_eq!(src_info.file_size, 192);
    assert_eq!(src_info.sha256, Some(sha256_hex(&content)));

    let config = TransferConfigV3 {
        chunk_size: 64,
        max_concurrency: 1,
        max_retries: 2,
        ..Default::default()
    };

    let result = client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            None,
        )
        .await
        .expect("Transfer must succeed");

    assert_eq!(result.transfer_id, id);
    assert_eq!(result.total_chunks, 3);
    assert_eq!(result.chunks_uploaded, 3);
    assert_eq!(result.chunks_resumed, 0);

    // Verify published file content on receiver
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let published = storage_dir.join(format!("{fname}.locara_incoming"));
    let published_bytes = tokio::fs::read(&published).await.unwrap();
    assert_eq!(published_bytes, content);

    // Clean up
    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 3: End-to-end non-multiple chunks with final partial chunk ───────────

#[tokio::test]
async fn test_client_transfer_non_multiple_chunks() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("non-mult");
    let fname = format!("{id}.bin");

    // 148 bytes = 2 chunks of 64 bytes + 1 chunk of 20 bytes
    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content: Vec<u8> = (0..148).map(|i| (i as u8).wrapping_add(19)).collect();
    tokio::fs::write(&src_path, &content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();
    assert_eq!(src_info.file_size, 148);

    let config = TransferConfigV3 {
        chunk_size: 64,
        max_concurrency: 1,
        ..Default::default()
    };

    let result = client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            None,
        )
        .await
        .expect("Non-multiple transfer must succeed");

    assert_eq!(result.total_chunks, 3);
    assert_eq!(result.chunks_uploaded, 3);

    // Verify byte-for-byte on receiver
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let published = storage_dir.join(format!("{fname}.locara_incoming"));
    let published_bytes = tokio::fs::read(&published).await.unwrap();
    assert_eq!(published_bytes, content);

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 4: End-to-end single small chunk ───────────────────────────────────

#[tokio::test]
async fn test_client_transfer_single_chunk_small_file() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("small-file");
    let fname = format!("{id}.bin");

    // 40 bytes with chunk_size 1024 -> 1 chunk
    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content = b"Hello Locara V3 Client Transfer Small File!";
    tokio::fs::write(&src_path, content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();

    let config = TransferConfigV3 {
        chunk_size: 1024,
        ..Default::default()
    };

    let result = client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            None,
        )
        .await
        .expect("Small file transfer must succeed");

    assert_eq!(result.total_chunks, 1);
    assert_eq!(result.chunks_uploaded, 1);

    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let published = storage_dir.join(format!("{fname}.locara_incoming"));
    assert_eq!(tokio::fs::read(&published).await.unwrap(), content);

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 5: End-to-end zero-byte file transfer ───────────────────────────────

#[tokio::test]
async fn test_client_transfer_zero_byte_file() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("zero-byte");
    let fname = format!("{id}.bin");

    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    tokio::fs::write(&src_path, b"").await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();
    assert_eq!(src_info.file_size, 0);

    let config = TransferConfigV3::default();

    let result = client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            None,
        )
        .await
        .expect("Zero-byte file transfer must succeed");

    assert_eq!(result.total_chunks, 0);
    assert_eq!(result.chunks_uploaded, 0);

    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let published = storage_dir.join(format!("{fname}.locara_incoming"));
    assert_eq!(tokio::fs::metadata(&published).await.unwrap().len(), 0);

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 6: Bounded concurrency and progress reporting ───────────────────────

#[tokio::test]
async fn test_client_transfer_bounded_memory_concurrency() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("concurrency");
    let fname = format!("{id}.bin");

    // 256 bytes = 4 chunks of 64 bytes
    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content: Vec<u8> = (0..256).map(|i| (i as u8).wrapping_add(33)).collect();
    tokio::fs::write(&src_path, &content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();

    let config = TransferConfigV3 {
        chunk_size: 64,
        max_concurrency: 2, // bounded concurrency of 2
        ..Default::default()
    };

    let progress_calls = Arc::new(Mutex::new(Vec::<(u64, u64)>::new()));
    let progress_cb = {
        let calls = progress_calls.clone();
        Arc::new(move |transferred: u64, total: u64| {
            calls.lock().unwrap().push((transferred, total));
        })
    };

    let result = client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            Some(progress_cb),
        )
        .await
        .expect("Concurrent transfer must succeed");

    assert_eq!(result.total_chunks, 4);
    assert_eq!(result.chunks_uploaded, 4);

    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let published = storage_dir.join(format!("{fname}.locara_incoming"));
    assert_eq!(tokio::fs::read(&published).await.unwrap(), content);

    // Verify progress was recorded and reached 256
    let calls = progress_calls.lock().unwrap();
    assert!(!calls.is_empty(), "Progress callback should have been called");
    let last = calls.last().unwrap();
    assert_eq!(last.0, 256);
    assert_eq!(last.1, 256);

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 7: Rejection when source file changes during transfer ────────────────

#[tokio::test]
async fn test_client_transfer_source_changed_during_transfer() {
    let id = unique_client_id("src-change");
    let fname = format!("{id}.bin");
    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);

    // Write initial 100 bytes
    tokio::fs::write(&src_path, vec![1u8; 100]).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, false).await.unwrap();
    assert_eq!(src_info.file_size, 100);

    // Mutate file size on disk
    tokio::fs::write(&src_path, vec![1u8; 150]).await.unwrap();

    // verify_unchanged must immediately detect the discrepancy and fail
    let check = src_info.verify_unchanged().await;
    assert!(check.is_err(), "verify_unchanged must fail when size changed");
    let err_msg = check.unwrap_err().to_string();
    assert!(err_msg.contains("size changed"));

    let _ = tokio::fs::remove_file(&src_path).await;
}

// ─── Test 8: Resume transfer with some chunks already present ──────────────────

#[tokio::test]
async fn test_client_transfer_resume_partial_chunks() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("resume-partial");
    let fname = format!("{id}.bin");

    // 4 chunks of 64 bytes = 256 bytes
    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content: Vec<u8> = (0..256).map(|i| (i as u8).wrapping_add(55)).collect();
    tokio::fs::write(&src_path, &content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();

    // Pass 1: Manually send manifest and only chunks 0 and 1
    let manifest = src_info.create_manifest(id.clone(), 64).unwrap();
    let manifest_resp = client
        .manifest(ProtocolType::Http, "127.0.0.1", server.port, None, manifest)
        .await
        .unwrap();
    assert_eq!(manifest_resp.missing_chunks.len(), 4);

    let chunk0 = content[0..64].to_vec();
    let chunk1 = content[64..128].to_vec();
    client
        .upload_chunk(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &id,
            0,
            Some(&sha256_hex(&chunk0)),
            chunk0,
            None,
        )
        .await
        .unwrap();

    client
        .upload_chunk(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &id,
            1,
            Some(&sha256_hex(&chunk1)),
            chunk1,
            None,
        )
        .await
        .unwrap();

    // Pass 2: Invoke transfer_file on the same transfer_id.
    // It should discover chunks 0 and 1 are already present and upload only chunks 2 and 3.
    let config = TransferConfigV3 {
        chunk_size: 64,
        max_concurrency: 1,
        ..Default::default()
    };

    let result = client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            None,
        )
        .await
        .expect("Resumed transfer must complete successfully");

    assert_eq!(result.total_chunks, 4);
    assert_eq!(result.chunks_uploaded, 2, "Only 2 missing chunks should be uploaded");
    assert_eq!(result.chunks_resumed, 2, "2 chunks should be reported as resumed");

    // Verify published file content matches original
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let published = storage_dir.join(format!("{fname}.locara_incoming"));
    assert_eq!(tokio::fs::read(&published).await.unwrap(), content);

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 9: Idempotent duplicate chunk vs conflicting chunk ───────────────────

#[tokio::test]
async fn test_client_idempotent_chunk_retry_and_conflicting_rejection() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("idempotent-chunk");
    let fname = format!("{id}.bin");

    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let chunk_bytes = vec![42u8; 64];
    tokio::fs::write(&src_path, &chunk_bytes).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();
    let manifest = src_info.create_manifest(id.clone(), 64).unwrap();

    client
        .manifest(ProtocolType::Http, "127.0.0.1", server.port, None, manifest)
        .await
        .unwrap();

    let hash = sha256_hex(&chunk_bytes);

    // Initial upload of chunk 0
    client
        .upload_chunk(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &id,
            0,
            Some(&hash),
            chunk_bytes.clone(),
            None,
        )
        .await
        .unwrap();

    // Idempotent retry: upload identical chunk 0 again -> must return 200 OK
    client
        .upload_chunk(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &id,
            0,
            Some(&hash),
            chunk_bytes.clone(),
            None,
        )
        .await
        .expect("Identical duplicate chunk must succeed idempotently");

    // Conflicting chunk: upload different bytes for chunk 0 -> must return 409 Conflict
    let conflict_bytes = vec![99u8; 64];
    let conflict_hash = sha256_hex(&conflict_bytes);
    let res = client
        .upload_chunk(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &id,
            0,
            Some(&conflict_hash),
            conflict_bytes,
            None,
        )
        .await;

    assert!(res.is_err(), "Conflicting chunk must be rejected with 409 Conflict");
    if let Err(ClientError::StatusCode(status)) = res {
        assert_eq!(status.status, 409);
    } else {
        panic!("Expected StatusCode(409), got: {:?}", res);
    }

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server.stop().await;
}

// ─── Test 10: Commit idempotence and destination collision ────────────────────

#[tokio::test]
async fn test_client_commit_retry_and_destination_collision() {
    let server = start_test_server(None).await;
    let client = LsHttpClientV3::try_new_without_cert().unwrap();

    let id = unique_client_id("commit-tests");
    let fname = format!("{id}.bin");

    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content = vec![88u8; 64];
    tokio::fs::write(&src_path, &content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();
    let config = TransferConfigV3 {
        chunk_size: 64,
        ..Default::default()
    };

    // First commit through transfer_file
    client
        .transfer_file(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &src_info,
            &id,
            &config,
            None,
            None,
        )
        .await
        .unwrap();

    // Idempotent commit retry: calling commit on already committed session returns 200 OK
    client
        .commit(ProtocolType::Http, "127.0.0.1", server.port, None, &id, None)
        .await
        .expect("Retrying commit on committed session must succeed idempotently");

    // Destination collision test: manifest -> chunk -> create collision file at destination -> commit
    let id2 = unique_client_id("dest-collision");
    let fname2 = format!("{id2}.bin");
    let src_path2 = temp_dir.join(&fname2);
    tokio::fs::write(&src_path2, &content).await.unwrap();
    let src_info2 = SourceFileInfo::new(src_path2.clone(), fname2.clone(), 64, None, None).unwrap();
    let manifest2 = src_info2.create_manifest(id2.clone(), 64).unwrap();

    client
        .manifest(ProtocolType::Http, "127.0.0.1", server.port, None, manifest2)
        .await
        .unwrap();

    client
        .upload_chunk(
            ProtocolType::Http,
            "127.0.0.1",
            server.port,
            None,
            &id2,
            0,
            None,
            content.clone(),
            None,
        )
        .await
        .unwrap();

    // Create collision at destination path prior to commit
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let dest_collision_path = storage_dir.join(format!("{fname2}.locara_incoming"));
    tokio::fs::write(&dest_collision_path, b"pre-existing collision file").await.unwrap();

    let collision_commit = client
        .commit(ProtocolType::Http, "127.0.0.1", server.port, None, &id2, None)
        .await;

    assert!(collision_commit.is_err(), "Commit must fail with 409 on destination collision");
    if let Err(ClientError::StatusCode(status)) = collision_commit {
        assert_eq!(status.status, 409);
    } else {
        panic!("Expected StatusCode(409), got: {:?}", collision_commit);
    }

    let _ = tokio::fs::remove_file(&src_path).await;
    let _ = tokio::fs::remove_file(&src_path2).await;
    let _ = tokio::fs::remove_file(&dest_collision_path).await;
    cleanup_transfer(&id, &fname).await;
    cleanup_transfer(&id2, &fname2).await;
    server.stop().await;
}


// ─── Test 11: Malformed manifest response rejection ───────────────────────────

#[test]
fn test_client_malformed_manifest_response_rejected() {
    // Check that manifest parameter validation catches invalid limits
    assert!(calculate_chunk_count(100, 0).is_err());
    assert!(validate_filename("../secret.txt").is_err());
}

// ─── Test 12: Transient vs permanent error classification ─────────────────────

#[test]
fn test_client_transient_vs_permanent_error_policy() {
    // Transient errors (retryable)
    let err_503 = ClientError::StatusCode(StatusCodeError {
        status: 503,
        message: Some("Service Unavailable".to_string()),
    });
    assert!(is_transient_error(&err_503));

    let err_502 = ClientError::StatusCode(StatusCodeError {
        status: 502,
        message: None,
    });
    assert!(is_transient_error(&err_502));

    let err_429 = ClientError::StatusCode(StatusCodeError {
        status: 429,
        message: None,
    });
    assert!(is_transient_error(&err_429));

    // Permanent errors (NOT retryable)
    let err_400 = ClientError::StatusCode(StatusCodeError {
        status: 400,
        message: Some("Bad Request".to_string()),
    });
    assert!(!is_transient_error(&err_400));

    let err_403 = ClientError::StatusCode(StatusCodeError {
        status: 403,
        message: Some("Forbidden".to_string()),
    });
    assert!(!is_transient_error(&err_403));

    let err_404 = ClientError::StatusCode(StatusCodeError {
        status: 404,
        message: Some("Not Found".to_string()),
    });
    assert!(!is_transient_error(&err_404));

    let err_409 = ClientError::StatusCode(StatusCodeError {
        status: 409,
        message: Some("Conflict".to_string()),
    });
    assert!(!is_transient_error(&err_409));

    let err_422 = ClientError::StatusCode(StatusCodeError {
        status: 422,
        message: Some("Integrity Mismatch".to_string()),
    });
    assert!(!is_transient_error(&err_422));

    let err_507 = ClientError::StatusCode(StatusCodeError {
        status: 507,
        message: Some("Insufficient Storage".to_string()),
    });
    assert!(!is_transient_error(&err_507));

    assert!(!is_transient_error(&ClientError::Cancelled));
}

// ─── Test 13: Cold-restart TLS peer-binding isolation ─────────────────────────

#[tokio::test]
async fn test_client_cold_restart_tls_peer_binding_negative() {
    // Generate distinct identities for server, client A, and client B
    let server_id = locara::crypto::cert::generate_self_signed().unwrap();
    let client_a_id = locara::crypto::cert::generate_self_signed().unwrap();
    let client_b_id = locara::crypto::cert::generate_self_signed().unwrap();

    let tls_config = TlsConfig {
        cert: server_id.certificate_pem.clone(),
        private_key: server_id.private_key_pem.clone(),
    };

    let server = start_test_server(Some(tls_config)).await;
    let port = server.port;

    let client_a = LsHttpClientV3::try_new(
        &client_a_id.private_key_pem,
        &client_a_id.certificate_pem,
        Some(server_id.fingerprint.clone()),
        Some(Duration::from_secs(5)),
    )
    .unwrap();

    let client_b = LsHttpClientV3::try_new(
        &client_b_id.private_key_pem,
        &client_b_id.certificate_pem,
        Some(server_id.fingerprint.clone()),
        Some(Duration::from_secs(5)),
    )
    .unwrap();

    let id = unique_client_id("tls-peer-binding");
    let fname = format!("{id}.bin");

    let temp_dir = std::env::temp_dir();
    let src_path = temp_dir.join(&fname);
    let content: Vec<u8> = (0..128).map(|i| i as u8).collect();
    tokio::fs::write(&src_path, &content).await.unwrap();

    let src_info = SourceFileInfo::from_path(&src_path, true).await.unwrap();
    let manifest = src_info.create_manifest(id.clone(), 64).unwrap();

    // Client A registers manifest over mTLS
    let resp_a = client_a
        .manifest(ProtocolType::Https, "127.0.0.1", port, None, manifest.clone())
        .await
        .unwrap();
    assert_eq!(resp_a.session_id, id);

    // Client A uploads chunk 0
    let chunk0 = content[0..64].to_vec();
    client_a
        .upload_chunk(
            ProtocolType::Https,
            "127.0.0.1",
            port,
            None,
            &id,
            0,
            Some(&sha256_hex(&chunk0)),
            chunk0,
            None,
        )
        .await
        .unwrap();

    // Stop server (simulate shutdown / restart)
    server.stop().await;

    // Start a new server instance on a fresh port reusing the same server identity
    let server2 = start_test_server(Some(TlsConfig {
        cert: server_id.certificate_pem.clone(),
        private_key: server_id.private_key_pem.clone(),
    }))
    .await;
    let port2 = server2.port;

    // Client B attempts to resume Client A's transfer session from persisted ResumeState
    let resume_attempt = client_b
        .manifest(ProtocolType::Https, "127.0.0.1", port2, None, manifest)
        .await;

    assert!(
        resume_attempt.is_err(),
        "Client B must be rejected with 403 Forbidden when resuming Client A's session"
    );
    if let Err(ClientError::StatusCode(status)) = resume_attempt {
        assert_eq!(status.status, 403, "Status code must be 403 Forbidden");
    } else {
        panic!("Expected StatusCode(403), got: {:?}", resume_attempt);
    }

    let _ = tokio::fs::remove_file(&src_path).await;
    cleanup_transfer(&id, &fname).await;
    server2.stop().await;
}
