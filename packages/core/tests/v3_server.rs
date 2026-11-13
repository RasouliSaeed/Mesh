#![cfg(feature = "http")]

//! Integration tests for the V3 chunk-transfer protocol.
//!
//! Tests cover the full manifest → chunk → commit flow, resumption from
//! persisted ResumeState, and error contracts (missing chunks, SHA-256 mismatch,
//! unknown session, duplicate manifest).
//!
//! Each test uses a unique transfer_id derived from the test name plus a
//! process-unique counter, so tests can run in parallel without file collisions.

use locara::crypto::hash::sha256_hex;
use locara::http::server::web::WebConfig;
use locara::http::server::start_with_port;
use locara::http::state::ClientInfo;
use locara::model::resume::ResumeManager;
use reqwest::StatusCode;
use std::sync::atomic::{AtomicU64, Ordering};
use tokio::sync::oneshot;

// ─── Unique transfer-id counter ───────────────────────────────────────────────

static XFER_COUNTER: AtomicU64 = AtomicU64::new(1);

fn unique_id(label: &str) -> String {
    let n = XFER_COUNTER.fetch_add(1, Ordering::Relaxed);
    let pid = std::process::id();
    format!("{label}-{pid}-{n}")
}

// ─── Test server helpers ───────────────────────────────────────────────────────

struct TestServer {
    port: u16,
    stop_tx: Option<oneshot::Sender<()>>,
    handle: Option<locara::http::server::ServerHandle>,
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

    fn v3(&self) -> Option<&std::sync::Arc<locara::http::server::common::v3_session::V3State>> {
        self.handle.as_ref().and_then(|h| h.v3.as_ref())
    }
}

impl Drop for TestServer {
    fn drop(&mut self) {
        if let Some(tx) = self.stop_tx.take() {
            let _ = tx.send(());
        }
    }
}

async fn start_v3_test_server() -> TestServer {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();
    let (stop_tx, stop_rx) = oneshot::channel::<()>();

    let handle = start_with_port(
        0,
        None, // plain HTTP (no TLS)
        ClientInfo {
            alias: "V3 Test Server".to_string(),
            version: "3.0".to_string(),
            device_model: Some("Rust test".to_string()),
            device_type: None,
            token: "test-server-fingerprint".to_string(),
        },
        None,
        None, // V2 not needed for V3 tests
        WebConfig::default(),
        stop_rx,
    )
    .await
    .expect("Failed to start V3 test server");

    let port = handle.port();
    TestServer {
        port,
        stop_tx: Some(stop_tx),
        handle: Some(handle),
    }
}

fn base_url(server: &TestServer) -> String {
    format!("http://127.0.0.1:{}", server.port)
}

// ─── Helper: generate a deterministic test payload ────────────────────────────

fn make_payload(size: usize, seed: u8) -> Vec<u8> {
    (0..size).map(|i| (i as u8).wrapping_add(seed)).collect()
}

// ─── Helper: build a manifest JSON body ──────────────────────────────────────

fn manifest_body(
    transfer_id: &str,
    file_name: &str,
    file_size: u64,
    chunk_size: u64,
    sha256: Option<&str>,
) -> serde_json::Value {
    let total_chunks = if chunk_size == 0 { 0 } else { file_size.div_ceil(chunk_size) };
    let mut m = serde_json::json!({
        "transferId": transfer_id,
        "fileName": file_name,
        "fileSize": file_size,
        "chunkSize": chunk_size,
        "totalChunks": total_chunks,
    });
    if let Some(h) = sha256 {
        m["expectedSha256"] = serde_json::Value::String(h.to_string());
    }
    m
}

// ─── Cleanup helper ───────────────────────────────────────────────────────────

async fn cleanup(transfer_id: &str, file_name: &str) {
    let _ = ResumeManager::delete(transfer_id).await;
    if let Ok(dir) = ResumeManager::default_storage_dir() {
        let part_isolated = dir.join(format!("locara_part_{transfer_id}.part"));
        let _ = tokio::fs::remove_file(&part_isolated).await;
        let part_legacy = locara::model::storage_adapter::DesktopStorageHandle::temp_path_for(
            &dir.join(format!("{file_name}.locara_incoming")),
        );
        let _ = tokio::fs::remove_file(&part_legacy).await;
        let _ = tokio::fs::remove_file(dir.join(format!("{file_name}.locara_incoming"))).await;
    }
}

// ─── Tests ────────────────────────────────────────────────────────────────────

/// Happy path: manifest → chunk (single) → commit with no SHA-256 check.
#[tokio::test]
async fn test_v3_single_chunk_transfer_no_hash() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let payload = make_payload(128, 1);
    let id = unique_id("single-no-hash");
    let fname = format!("{id}.bin");

    // POST manifest
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, payload.len() as u64, 512, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "manifest must return 200");
    let body: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(body["sessionId"], id.as_str());
    let missing = body["missingChunks"].as_array().unwrap();
    assert_eq!(missing.len(), 1, "fresh transfer: exactly 1 missing chunk");
    assert_eq!(missing[0], 0, "missing chunk is index 0");

    // POST chunk 0
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(payload.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "chunk must return 200");

    // POST commit
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "commit must return 200");

    cleanup(&id, &fname).await;
}

/// Happy path: manifest → two chunks → commit with SHA-256 verification.
#[tokio::test]
async fn test_v3_multi_chunk_with_sha256() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let chunk_size: u64 = 64;
    let chunk0 = make_payload(64, 10);
    let chunk1 = make_payload(40, 20); // last chunk is shorter
    let mut full_file = chunk0.clone();
    full_file.extend_from_slice(&chunk1);
    let file_sha256 = sha256_hex(&full_file);

    let id = unique_id("multi-sha256");
    let fname = format!("{id}.bin");

    // POST manifest
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, full_file.len() as u64, chunk_size, Some(&file_sha256)))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    let missing = body["missingChunks"].as_array().unwrap();
    assert_eq!(missing.len(), 2, "two chunks expected missing");

    // POST chunk 0 with per-chunk hash
    let chunk0_hash = sha256_hex(&chunk0);
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0&chunkHash={chunk0_hash}"))
        .body(chunk0.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "chunk 0 must succeed");

    // POST chunk 1
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=1"))
        .body(chunk1.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "chunk 1 must succeed");

    // POST commit — triggers full-file SHA-256 verification
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "commit must succeed with correct SHA-256");

    cleanup(&id, &fname).await;
}

/// Commit while chunks are still missing must return 409 Conflict and list the missing indices.
#[tokio::test]
async fn test_v3_commit_with_missing_chunks_returns_409() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("premature-commit");
    let fname = format!("{id}.bin");

    // Two-chunk transfer, but we only send one.
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 128, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Send only chunk 0 (chunk 1 missing).
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(make_payload(64, 5))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Commit should fail with 409.
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::CONFLICT, "commit with missing chunks must be 409");
    let body: serde_json::Value = resp.json().await.unwrap();
    let missing_arr = body["missing_chunks"].as_array().unwrap();
    assert!(missing_arr.contains(&serde_json::json!(1)), "chunk 1 must be in missing_chunks");

    // Session still exists — complete the transfer.
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=1"))
        .body(make_payload(64, 6))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "chunk 1 must succeed after re-send");

    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "commit must succeed after completing missing chunk");

    cleanup(&id, &fname).await;
}

/// Chunk with wrong SHA-256 must return 422 Unprocessable Entity.
#[tokio::test]
async fn test_v3_chunk_bad_hash_returns_422() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("chunk-bad-hash");
    let fname = format!("{id}.bin");

    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Send chunk 0 with an incorrect hash.
    let bad_hash = "0000000000000000000000000000000000000000000000000000000000000000";
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0&chunkHash={bad_hash}"))
        .body(make_payload(64, 99))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNPROCESSABLE_ENTITY, "bad chunk hash must be 422");

    cleanup(&id, &fname).await;
}

/// Chunk to an unknown sessionId must return 404.
#[tokio::test]
async fn test_v3_chunk_unknown_session_returns_404() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let ghost = unique_id("ghost-chunk");
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={ghost}&chunkIndex=0"))
        .body(vec![0u8; 32])
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);
}

/// Commit for unknown sessionId must return 404.
#[tokio::test]
async fn test_v3_commit_unknown_session_returns_404() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let ghost = unique_id("ghost-commit");
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={ghost}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::NOT_FOUND);
}

/// Manifest for an already-active session is idempotent and returns current missing chunks.
#[tokio::test]
async fn test_v3_manifest_idempotent_returns_current_missing() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("idempotent-manifest");
    let fname = format!("{id}.bin");
    let mf = manifest_body(&id, &fname, 128, 64, None);

    // First manifest call — everything is missing.
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&mf)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(body["missingChunks"].as_array().unwrap().len(), 2);

    // Send chunk 0.
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(make_payload(64, 7))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Second manifest call — should return only chunk 1 as missing.
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&mf)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    let missing = body["missingChunks"].as_array().unwrap();
    assert_eq!(missing.len(), 1, "only chunk 1 should be missing");
    assert_eq!(missing[0], 1, "missing chunk should be index 1");

    // Finish the transfer cleanly.
    let _ = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=1"))
        .body(make_payload(64, 8))
        .send()
        .await;
    let _ = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await;

    cleanup(&id, &fname).await;
}

/// Full-file SHA-256 mismatch at commit time must return 422.
#[tokio::test]
async fn test_v3_commit_sha256_mismatch_returns_422() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("commit-sha-mismatch");
    let fname = format!("{id}.bin");
    let payload = make_payload(64, 42);
    let wrong_sha256 = "0000000000000000000000000000000000000000000000000000000000000000";

    // Manifest with deliberately wrong expected SHA-256.
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, Some(wrong_sha256)))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(payload)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Commit should fail because the stored SHA-256 doesn't match.
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::UNPROCESSABLE_ENTITY, "SHA-256 mismatch must be 422");

    cleanup(&id, &fname).await;
}

/// Missing chunkIndex query param must return 400.
#[tokio::test]
async fn test_v3_chunk_missing_index_param_returns_400() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("missing-param");
    let fname = format!("{id}.bin");

    // Create a session first.
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Missing chunkIndex.
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}"))
        .body(make_payload(64, 1))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "missing chunkIndex must be 400");

    cleanup(&id, &fname).await;
}

/// Manifest path traversal attempts in file_name must return 400 Bad Request.
#[tokio::test]
async fn test_v3_manifest_path_traversal_rejected() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let malicious_names = [
        "../../escape.sh",
        "..\\escape.bat",
        "/etc/passwd",
        "C:\\Windows\\evil.exe",
        "evil:stream.txt",
        "evil\0null.txt",
        "CON.txt",
        "NUL",
        "..",
        ".",
        "   ",
        "",
    ];

    for name in &malicious_names {
        let id = unique_id("traversal");
        let body = manifest_body(&id, name, 64, 64, None);
        let resp = client
            .post(format!("{base}/api/locara/v3/manifest"))
            .json(&body)
            .send()
            .await
            .unwrap();
        assert_eq!(
            resp.status(),
            StatusCode::BAD_REQUEST,
            "Path traversal '{name}' should be rejected with 400"
        );
        cleanup(&id, name).await;
    }
}

/// Concurrent transfers with identical file_name must have isolated partial paths
/// and must not overwrite each other during chunk transfer.
#[tokio::test]
async fn test_v3_manifest_transfer_isolation() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let shared_filename = format!("shared_{}.bin", unique_id("iso"));
    let id_a = unique_id("tx-iso-a");
    let id_b = unique_id("tx-iso-b");

    let payload_a = vec![0xAA; 64];
    let payload_b = vec![0xBB; 64];

    // Manifest A
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id_a, &shared_filename, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Manifest B (identical file_name, different transfer_id)
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id_b, &shared_filename, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Upload chunk A
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id_a}&chunkIndex=0"))
        .body(payload_a.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Upload chunk B with different content
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id_b}&chunkIndex=0"))
        .body(payload_b.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Commit A: should succeed
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id_a}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Commit B: should fail with 409 CONFLICT because destination already exists
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id_b}"))
        .send()
        .await
        .unwrap();
    assert_eq!(
        resp.status(),
        StatusCode::CONFLICT,
        "Commit B should return 409 Conflict due to destination collision"
    );

    // Check that response does NOT leak internal filesystem paths
    let body_text = resp.text().await.unwrap();
    assert!(!body_text.contains('\\'), "Error body must not leak filesystem path: {}", body_text);
    assert!(!body_text.contains('/'), "Error body must not leak filesystem path: {}", body_text);

    // Verify transfer B's ResumeState still exists on disk (preserved on failure)
    let state_b = ResumeManager::load(&id_b).await.unwrap();
    assert!(state_b.is_some(), "Transfer B ResumeState must be preserved on commit collision");

    cleanup(&id_a, &shared_filename).await;
    cleanup(&id_b, &shared_filename).await;
}

/// Manifest chunk size and total chunks bounds validation.
#[tokio::test]
async fn test_v3_manifest_chunk_bounds_validation() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("bounds");
    let fname = format!("{id}.bin");

    // 1. Total chunks mismatch (declared 5 but 100/50 requires 2)
    let mut bad_mf = manifest_body(&id, &fname, 100, 50, None);
    bad_mf["totalChunks"] = serde_json::json!(5);
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&bad_mf)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    // 2. Chunk size 0
    let mut zero_chunk = manifest_body(&id, &fname, 100, 0, None);
    zero_chunk["chunkSize"] = serde_json::json!(0);
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&zero_chunk)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    // 3. Chunk size exceeds 16 MiB
    let mut huge_chunk = manifest_body(&id, &fname, 32 * 1024 * 1024, 32 * 1024 * 1024, None);
    huge_chunk["chunkSize"] = serde_json::json!(32 * 1024 * 1024);
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&huge_chunk)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    cleanup(&id, &fname).await;
}

/// Zero-byte file transfer with 0 total chunks commits immediately.
#[tokio::test]
async fn test_v3_manifest_zero_byte_file() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("zero-byte");
    let fname = format!("{id}.bin");
    let empty_sha256 = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";

    let mut mf = manifest_body(&id, &fname, 0, 64, Some(empty_sha256));
    mf["totalChunks"] = serde_json::json!(0);

    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&mf)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(body["missingChunks"].as_array().unwrap().len(), 0);

    // Commit immediately without chunks
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    cleanup(&id, &fname).await;
}

/// Chunk body length validation: under-length or over-length returns error.
#[tokio::test]
async fn test_v3_chunk_body_length_validation() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("body-length");
    let fname = format!("{id}.bin");

    // 100 bytes file, 64 chunk_size => chunk 0 expected 64, chunk 1 expected 36
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 100, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // 1. Under-length chunk 0 (send 60 bytes instead of 64) -> 400
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(vec![0u8; 60])
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    // 2. Over-length chunk 0 (send 65 bytes instead of 64) -> 413 or 400
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(vec![0u8; 65])
        .send()
        .await
        .unwrap();
    assert!(
        resp.status() == StatusCode::PAYLOAD_TOO_LARGE || resp.status() == StatusCode::BAD_REQUEST,
        "Over-length payload should be rejected with 413 or 400, got {}",
        resp.status()
    );

    // 3. Under-length final chunk 1 (send 30 bytes instead of 36) -> 400
    // First send valid chunk 0
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(vec![0u8; 64])
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=1"))
        .body(vec![0u8; 30])
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST);

    cleanup(&id, &fname).await;
}

/// Duplicate chunk handling: identical repeated chunk returns 200 OK;
/// conflicting chunk data returns 409 Conflict.
#[tokio::test]
async fn test_v3_chunk_duplicate_idempotent_vs_conflicting() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("dup-chunk");
    let fname = format!("{id}.bin");

    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let payload_original = vec![0xAA; 64];
    let payload_conflicting = vec![0xBB; 64];

    // Send chunk first time
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(payload_original.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Send identical chunk again -> 200 OK (idempotent)
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(payload_original.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "Identical chunk must return 200 OK");

    // Send conflicting chunk -> 409 Conflict
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(payload_conflicting)
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::CONFLICT, "Conflicting chunk must return 409 Conflict");

    cleanup(&id, &fname).await;
}

/// Commit failure preserves ResumeState; once conflict is resolved, retry succeeds;
/// subsequent commit is idempotent 200 OK.
#[tokio::test]
async fn test_v3_commit_preserve_state_on_collision_and_idempotence() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("commit-preserve");
    let fname = format!("{id}.bin");

    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Send chunk
    let resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(vec![0x77; 64])
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Pre-create destination file to cause a collision
    let dest_path = {
        let dir = ResumeManager::default_storage_dir().unwrap();
        dir.join(format!("{fname}.locara_incoming"))
    };
    tokio::fs::write(&dest_path, b"already exists").await.unwrap();

    // Commit should fail with 409 CONFLICT
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::CONFLICT);

    // Verify ResumeState is still intact on disk
    let loaded = ResumeManager::load(&id).await.unwrap();
    assert!(loaded.is_some(), "ResumeState must not be deleted on commit failure");

    // Remove colliding destination file
    let _ = tokio::fs::remove_file(&dest_path).await;

    // Retry commit: must succeed now!
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "Retry commit after clearing collision must succeed");

    // Second commit: must be idempotent 200 OK
    let resp = client
        .post(format!("{base}/api/locara/v3/commit?sessionId={id}"))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "Subsequent commit must be idempotent 200 OK");

    cleanup(&id, &fname).await;
}

/// F-01: Manifest bounds validation, overflow-safe arithmetic, and rejection of hostile manifests.
#[tokio::test]
async fn test_v3_manifest_bounds_and_overflow_protection() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("bounds-overflow");
    let fname = format!("{id}.bin");

    // 1. Zero file_size with non-zero total_chunks -> 400
    let mut bad_zero = manifest_body(&id, &fname, 0, 64, None);
    bad_zero["totalChunks"] = serde_json::json!(1);
    let resp = client.post(format!("{base}/api/locara/v3/manifest")).json(&bad_zero).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "file_size=0 with total_chunks>0 must return 400");

    // 2. Non-zero file_size with zero total_chunks -> 400
    let mut bad_chunks = manifest_body(&id, &fname, 100, 64, None);
    bad_chunks["totalChunks"] = serde_json::json!(0);
    let resp = client.post(format!("{base}/api/locara/v3/manifest")).json(&bad_chunks).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "file_size>0 with total_chunks=0 must return 400");

    // 3. Exceeds MAX_FILE_SIZE (1 TiB + 1) -> 400
    let huge_file = (1024 * 1024 * 1024 * 1024u64) + 1;
    let bad_file = manifest_body(&id, &fname, huge_file, 16 * 1024 * 1024, None);
    let resp = client.post(format!("{base}/api/locara/v3/manifest")).json(&bad_file).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "file_size > 1 TiB must return 400");

    // 4. u64::MAX boundary: does not panic or crash server
    let max_u64 = manifest_body(&id, &fname, u64::MAX, 1024, None);
    let resp = client.post(format!("{base}/api/locara/v3/manifest")).json(&max_u64).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "u64::MAX file_size must be rejected with 400");

    // 5. Exceeds MAX_TOTAL_CHUNKS (100_000)
    let total_chunks = 100_001u64;
    let file_sz = total_chunks * 1024;
    let bad_total = manifest_body(&id, &fname, file_sz, 1024, None);
    let resp = client.post(format!("{base}/api/locara/v3/manifest")).json(&bad_total).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "total_chunks > 100_000 must return 400");

    // 6. Hostile manifest with tiny chunk size (file_size = 10_000_000, chunk_size = 1) -> exceeds MAX_TOTAL_CHUNKS
    let hostile_id = unique_id("hostile-alloc");
    let hostile_fname = format!("{hostile_id}.bin");
    let hostile = manifest_body(&hostile_id, &hostile_fname, 10_000_000, 1, None);
    let resp = client.post(format!("{base}/api/locara/v3/manifest")).json(&hostile).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::BAD_REQUEST, "Hostile chunk count must return 400 without allocation");

    // Ensure no files were created on disk
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let hostile_part = storage_dir.join(format!("locara_part_{hostile_id}.part"));
    assert!(!hostile_part.exists(), "No partial file should be created for rejected manifest");
    let state = ResumeManager::load(&hostile_id).await.unwrap();
    assert!(state.is_none(), "No ResumeState should be saved for rejected manifest");

    cleanup(&id, &fname).await;
    cleanup(&hostile_id, &hostile_fname).await;
}

/// F-02: Connect and verify the session janitor runtime and expiration behavior.
#[tokio::test]
async fn test_v3_session_janitor_lifecycle_and_reap() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let id = unique_id("janitor-test");
    let fname = format!("{id}.bin");

    // Create a transfer session
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    let v3_state = server.v3().expect("v3 state must be present").clone();
    assert_eq!(v3_state.store.count().await, 1, "Session should be in memory");

    // Verify session has active reservation
    assert_eq!(v3_state.store.total_reserved_bytes().await, 64);

    // Active session with recent activity is NOT reaped with timeout = 600
    let reaped = v3_state.store.reap_expired(600).await;
    assert!(reaped.is_empty(), "Active session must not be reaped");
    assert_eq!(v3_state.store.count().await, 1);

    // Reap with timeout = 0 (simulates inactivity expiration)
    let reaped = v3_state.store.reap_expired(0).await;
    assert_eq!(reaped.len(), 1, "Inactive session must be reaped from memory");
    assert_eq!(reaped[0], id);
    assert_eq!(v3_state.store.count().await, 0, "In-memory session count should be 0 after reap");

    // In-memory reservation is freed
    assert_eq!(v3_state.store.total_reserved_bytes().await, 0);

    // CRITICAL: Persistent resume data and partial file MUST be preserved on disk!
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let part_file = storage_dir.join(format!("locara_part_{id}.part"));
    assert!(part_file.exists(), "Partial file must remain intact on disk after in-memory expiration");
    let state = ResumeManager::load(&id).await.unwrap();
    assert!(state.is_some(), "ResumeState metadata must remain intact on disk after in-memory expiration");

    // Verify server can still cleanly stop (TaskTracker shuts down janitor)
    server.stop().await;

    cleanup(&id, &fname).await;
}

/// F-03: Enforce aggregate reservation ceiling and release on commit.
#[tokio::test]
async fn test_v3_manifest_aggregate_storage_quota() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let v3_state = server.v3().expect("v3 state must be present").clone();
    // Configure aggregate quota to 128 bytes
    v3_state.store.set_max_aggregate_bytes(128).await;

    let id1 = unique_id("quota-1");
    let fname1 = format!("{id1}.bin");
    let id2 = unique_id("quota-2");
    let fname2 = format!("{id2}.bin");
    let id3 = unique_id("quota-3");
    let fname3 = format!("{id3}.bin");

    // Manifest 1: 64 bytes -> OK (total reserved: 64 / 128)
    let resp1 = client.post(format!("{base}/api/locara/v3/manifest")).json(&manifest_body(&id1, &fname1, 64, 64, None)).send().await.unwrap();
    assert_eq!(resp1.status(), StatusCode::OK);
    assert_eq!(v3_state.store.total_reserved_bytes().await, 64);

    // Manifest 2: 64 bytes -> OK (total reserved: 128 / 128)
    let resp2 = client.post(format!("{base}/api/locara/v3/manifest")).json(&manifest_body(&id2, &fname2, 64, 64, None)).send().await.unwrap();
    assert_eq!(resp2.status(), StatusCode::OK);
    assert_eq!(v3_state.store.total_reserved_bytes().await, 128);

    // Manifest 3: 64 bytes -> 507 Insufficient Storage (would exceed 128 quota)
    let resp3 = client.post(format!("{base}/api/locara/v3/manifest")).json(&manifest_body(&id3, &fname3, 64, 64, None)).send().await.unwrap();
    assert_eq!(resp3.status(), StatusCode::INSUFFICIENT_STORAGE, "Exceeding aggregate quota must return 507");

    // Verify Manifest 3 left no orphaned files
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    assert!(!storage_dir.join(format!("locara_part_{id3}.part")).exists());
    assert!(ResumeManager::load(&id3).await.unwrap().is_none());

    // Complete and commit Transfer 1 -> releases its reservation from quota
    let _ = client.post(format!("{base}/api/locara/v3/chunk?sessionId={id1}&chunkIndex=0")).body(vec![1u8; 64]).send().await;
    let commit_resp = client.post(format!("{base}/api/locara/v3/commit?sessionId={id1}")).send().await.unwrap();
    assert_eq!(commit_resp.status(), StatusCode::OK);

    // Total reserved bytes dropped back down to 64
    assert_eq!(v3_state.store.total_reserved_bytes().await, 64);

    // Manifest 3 now succeeds within released quota!
    let resp3_retry = client.post(format!("{base}/api/locara/v3/manifest")).json(&manifest_body(&id3, &fname3, 64, 64, None)).send().await.unwrap();
    assert_eq!(resp3_retry.status(), StatusCode::OK);
    assert_eq!(v3_state.store.total_reserved_bytes().await, 128);

    cleanup(&id1, &fname1).await;
    cleanup(&id2, &fname2).await;
    cleanup(&id3, &fname3).await;
}

/// F-04: Failed manifest initialization cleans up partial files and releases reservations.
#[tokio::test]
async fn test_v3_manifest_failed_init_no_orphaned_files() {
    let server = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base = base_url(&server);

    let v3_state = server.v3().expect("v3 state must be present").clone();

    // Set max active sessions to 0 to simulate server capacity saturation
    v3_state.store.set_max_active_sessions(0).await;

    let id = unique_id("failed-init");
    let fname = format!("{id}.bin");

    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::SERVICE_UNAVAILABLE);

    // Verify NO orphaned partial file or resume metadata was created on disk
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let part_file = storage_dir.join(format!("locara_part_{id}.part"));
    assert!(!part_file.exists(), "No partial file must remain after failed manifest initialization");
    assert!(ResumeManager::load(&id).await.unwrap().is_none(), "No ResumeState must exist on disk");

    // Verify no reservation or slot leaked
    assert_eq!(v3_state.store.total_reserved_bytes().await, 0);

    // Restore capacity and verify a subsequent valid request succeeds normally
    v3_state.store.set_max_active_sessions(64).await;
    let resp_retry = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&manifest_body(&id, &fname, 64, 64, None))
        .send()
        .await
        .unwrap();
    assert_eq!(resp_retry.status(), StatusCode::OK);
    assert!(part_file.exists());

    cleanup(&id, &fname).await;
}

/// F-05: Cold-restart recovery integration test across distinct server instances.
/// Proves that a transfer can resume from on-disk state without an existing in-memory session.
#[tokio::test]
async fn test_v3_cold_restart_recovery_across_server_instances() {
    let id = unique_id("cold-restart");
    let fname = format!("{id}.bin");

    let chunk0 = make_payload(64, 11);
    let chunk1 = make_payload(64, 22);

    let mut full_file = chunk0.clone();
    full_file.extend_from_slice(&chunk1);
    let expected_sha = sha256_hex(&full_file);

    let manifest = manifest_body(&id, &fname, 128, 64, Some(&expected_sha));

    // ── Phase 1: Server 1 ─────────────────────────────────────────────────────
    let server1 = start_v3_test_server().await;
    let client = reqwest::Client::new();
    let base1 = base_url(&server1);

    // Submit manifest to Server 1
    let resp = client.post(format!("{base1}/api/locara/v3/manifest")).json(&manifest).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    assert_eq!(body["missingChunks"].as_array().unwrap().len(), 2);

    // Upload chunk 0 to Server 1
    let resp = client
        .post(format!("{base1}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(chunk0.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Verify chunk 0 was persisted to disk in ResumeState
    let saved_state = ResumeManager::load(&id).await.unwrap().expect("ResumeState must exist on disk");
    assert_eq!(saved_state.completed_chunks, vec![0]);

    // Shut down Server 1 completely and wait for full termination
    server1.stop().await;

    // ── Phase 2: Server 2 (Fresh process / empty in-memory store) ─────────────
    let server2 = start_v3_test_server().await;
    let base2 = base_url(&server2);

    // Verify Server 2 has no active sessions in memory
    assert_eq!(server2.v3().unwrap().store.count().await, 0);

    // Submit manifest to Server 2: triggers cold-restart recovery from disk!
    let resp = client.post(format!("{base2}/api/locara/v3/manifest")).json(&manifest).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);
    let body: serde_json::Value = resp.json().await.unwrap();
    let missing = body["missingChunks"].as_array().unwrap();
    assert_eq!(missing.len(), 1, "Only chunk 1 should be missing after cold restart");
    assert_eq!(missing[0], 1, "Chunk 1 must be the missing index");

    // Resending chunk 0 to Server 2 is recognized as idempotent duplicate -> 200 OK
    let resp = client
        .post(format!("{base2}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(chunk0.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK, "Duplicate chunk 0 must be idempotent 200 OK");

    // Upload remaining chunk 1 to Server 2
    let resp = client
        .post(format!("{base2}/api/locara/v3/chunk?sessionId={id}&chunkIndex=1"))
        .body(chunk1.clone())
        .send()
        .await
        .unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Commit on Server 2
    let resp = client.post(format!("{base2}/api/locara/v3/commit?sessionId={id}")).send().await.unwrap();
    assert_eq!(resp.status(), StatusCode::OK);

    // Verify final committed file on disk
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let final_dest = storage_dir.join(format!("{fname}.locara_incoming"));
    assert!(final_dest.exists(), "Final file must be published on disk");
    let on_disk_bytes = tokio::fs::read(&final_dest).await.unwrap();
    assert_eq!(on_disk_bytes, full_file, "On-disk file content must match full byte payload");
    assert_eq!(sha256_hex(&on_disk_bytes), expected_sha);

    // Verify ResumeState was cleaned up on commit
    assert!(ResumeManager::load(&id).await.unwrap().is_none(), "ResumeState must be deleted after commit");

    // Shut down Server 2 cleanly
    server2.stop().await;

    cleanup(&id, &fname).await;
}

// ─── Tests: V3 Manifest Decision Channel (Receive-Approval Policy) ───────────

async fn start_v3_test_server_with_events() -> (TestServer, tokio::sync::mpsc::Receiver<locara::http::server::v2::ServerEventV2>) {
    let _ = tracing_subscriber::fmt().with_test_writer().try_init();
    let (stop_tx, stop_rx) = oneshot::channel::<()>();
    let (event_tx, event_rx) = tokio::sync::mpsc::channel(32);

    let handle = start_with_port(
        0,
        None, // plain HTTP (no TLS)
        ClientInfo {
            alias: "V3 Event Test Server".to_string(),
            version: "3.0".to_string(),
            device_model: Some("Rust test".to_string()),
            device_type: None,
            token: "test-server-fingerprint".to_string(),
        },
        None,
        Some(locara::http::server::ServerConfigV2 {
            pin: None,
            verify_checksums: true,
            event_tx,
        }),
        WebConfig::default(),
        stop_rx,
    )
    .await
    .expect("Failed to start V3 event test server");

    let port = handle.port();
    (
        TestServer {
            port,
            stop_tx: Some(stop_tx),
            handle: Some(handle),
        },
        event_rx,
    )
}

#[tokio::test]
async fn test_v3_manifest_decision_channel_accept() {
    let (server, mut event_rx) = start_v3_test_server_with_events().await;
    let base = base_url(&server);
    let id = unique_id("v3-accept");
    let fname = format!("{id}.bin");
    let client = reqwest::Client::new();

    let expected_id = id.clone();
    let expected_fname = fname.clone();
    let handler_task = tokio::spawn(async move {
        match event_rx.recv().await {
            Some(locara::http::server::v2::ServerEventV2::PrepareUploadV3 {
                session_id,
                file_name,
                decision_tx,
                ..
            }) => {
                assert_eq!(session_id, expected_id);
                assert_eq!(file_name, expected_fname);
                let _ = decision_tx.send(locara::http::server::v2::PrepareUploadDecisionV3 {
                    accept: true,
                    destination_path: None,
                });
            }
            other => panic!("Unexpected event: {other:?}"),
        }
    });

    let body = manifest_body(&id, &fname, 1024, 512, None);
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&body)
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::OK, "Manifest must succeed when decision is accept: true");
    handler_task.await.unwrap();

    // Verify storage session was created
    assert!(ResumeManager::load(&id).await.unwrap().is_some(), "ResumeState must be created when accepted");

    server.stop().await;
    cleanup(&id, &fname).await;
}

#[tokio::test]
async fn test_v3_manifest_decision_channel_decline() {
    let (server, mut event_rx) = start_v3_test_server_with_events().await;
    let base = base_url(&server);
    let id = unique_id("v3-decline");
    let fname = format!("{id}.bin");
    let client = reqwest::Client::new();

    let expected_id = id.clone();
    let expected_fname = fname.clone();
    let handler_task = tokio::spawn(async move {
        match event_rx.recv().await {
            Some(locara::http::server::v2::ServerEventV2::PrepareUploadV3 {
                session_id,
                file_name,
                decision_tx,
                ..
            }) => {
                assert_eq!(session_id, expected_id);
                assert_eq!(file_name, expected_fname);
                let _ = decision_tx.send(locara::http::server::v2::PrepareUploadDecisionV3 {
                    accept: false,
                    destination_path: None,
                });
            }
            other => panic!("Unexpected event: {other:?}"),
        }
    });

    let body = manifest_body(&id, &fname, 1024, 512, None);
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&body)
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::FORBIDDEN, "Manifest must return 403 Forbidden when declined");
    handler_task.await.unwrap();

    // Verify NO .part file or ResumeState exists on disk
    assert!(ResumeManager::load(&id).await.unwrap().is_none(), "ResumeState must not be created when declined");
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let part_path = storage_dir.join(format!("locara_part_{id}.part"));
    assert!(!part_path.exists(), "Part file must not exist on disk when declined");

    // Sending a chunk to this session must fail (404)
    let chunk_resp = client
        .post(format!("{base}/api/locara/v3/chunk?sessionId={id}&chunkIndex=0"))
        .body(vec![0u8; 512])
        .send()
        .await
        .unwrap();
    assert_eq!(chunk_resp.status(), StatusCode::NOT_FOUND);

    server.stop().await;
    cleanup(&id, &fname).await;
}

#[tokio::test]
async fn test_v3_manifest_decision_channel_dropped() {
    let (server, mut event_rx) = start_v3_test_server_with_events().await;
    let base = base_url(&server);
    let id = unique_id("v3-dropped");
    let fname = format!("{id}.bin");
    let client = reqwest::Client::new();

    let expected_id = id.clone();
    let expected_fname = fname.clone();
    let handler_task = tokio::spawn(async move {
        match event_rx.recv().await {
            Some(locara::http::server::v2::ServerEventV2::PrepareUploadV3 {
                session_id,
                file_name,
                decision_tx,
                ..
            }) => {
                assert_eq!(session_id, expected_id);
                assert_eq!(file_name, expected_fname);
                // Intentionally drop decision_tx without sending
                drop(decision_tx);
            }
            other => panic!("Unexpected event: {other:?}"),
        }
    });

    let body = manifest_body(&id, &fname, 1024, 512, None);
    let resp = client
        .post(format!("{base}/api/locara/v3/manifest"))
        .json(&body)
        .send()
        .await
        .unwrap();

    assert_eq!(resp.status(), StatusCode::INTERNAL_SERVER_ERROR, "Manifest must return 500 when decision channel drops");
    handler_task.await.unwrap();

    // Verify NO .part file or ResumeState exists on disk
    assert!(ResumeManager::load(&id).await.unwrap().is_none(), "ResumeState must not be created when channel is dropped");
    let storage_dir = ResumeManager::default_storage_dir().unwrap();
    let part_path = storage_dir.join(format!("locara_part_{id}.part"));
    assert!(!part_path.exists(), "Part file must not exist on disk when channel is dropped");

    server.stop().await;
    cleanup(&id, &fname).await;
}
