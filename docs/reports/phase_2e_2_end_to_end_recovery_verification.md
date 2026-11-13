# Phase 2E-2: Controlled End-to-End Recovery Verification Report

**Date:** 2026-10-19  
**Repository:** `C:\Users\SR\Desktop\Mesh`  
**Commit:** `1a08fa63a3b2dd9d485b4ac568f17d55c42d514d` (Branch: `main`)  
**Specification:** `docs/MESH_MASTER_SPEC.md`  
**Execution Mode:** Controlled E2E Dual-Endpoint In-Process / Socket Verification  

---

## 1. Environment and Baseline

- **Platform:** Windows 10/11 x86_64, PowerShell 7 / Windows PowerShell.
- **Hardware Profile:** Single host environment; two independent network endpoints running in dual-socket loopback configuration (`127.0.0.1:<ephemeral-port>`).
- **Receiver Endpoint:** Full in-process Axum V3 HTTP / mTLS server (`start_with_port`).
- **Sender Endpoint:** Native Rust `LsHttpClientV3` communicating over real TCP/TLS network sockets.
- **Physical Device Limitation:** Physical separate-device testing over Wi-Fi/LAN is currently unavailable in this local test environment and is noted as an external validation boundary.
- **Git Baseline:** Commit `1a08fa63a3b2dd9d485b4ac568f17d55c42d514d` on branch `main`. Baseline working tree had 95 modified tracked files and 60 untracked files, all of which are preserved.

---

## 2. Test Matrix and Individual Results

| Test Identifier | Scenario | Result | Command / Source Reference | Evidence Summary |
|---|---|:---:|---|---|
| **Test A** | Baseline V3 Transfer (Uninterrupted) | **PASS** | `cargo test --test v3_client test_client_transfer_exact_multiple_chunks`<br>`cargo test --test v3_client test_client_transfer_non_multiple_chunks` | 1024-byte & 1025-byte files transferred to completion; byte-for-byte payload match; SHA-256 match; zero leftover temp files. |
| **Test B** | Interrupted Transfer & Reconnect | **PASS** | `cargo test --test v3_client test_client_transfer_resume_partial_chunks` | 256-byte file (4x64B chunks). Chunks 0 & 1 sent. Connection severed. Resumed: server returned missing `[2, 3]`. `chunks_resumed == 2`, `chunks_uploaded == 2`. Full file intact. |
| **Test C** | Application Process Restart | **PASS** | `cargo test --test v3_server test_v3_cold_restart_recovery_across_server_instances` | Server 1 received chunk 0; Server 1 terminated. Server 2 booted with empty memory store. Resumed from disk metadata; only chunk 1 uploaded; SHA-256 verified; committed once. |
| **Test D** | Peer Identity Enforcement | **PASS** | `cargo test --test v3_client test_client_cold_restart_tls_peer_binding_negative` | Client A initiated transfer over TLS; server restarted; Client B attempted to resume; rejected with HTTP 403 Forbidden; legitimate transfer state unaltered. |
| **Test E** | Finalization and Cleanup | **PASS** | `cargo test --test v3_client test_client_commit_retry_and_destination_collision`<br>`cargo test --test resume_manager test_resume_manager_prune_session` | Re-commit is idempotent (200 OK); destination collision rejected (409 Conflict); `ResumeState` cleaned up on commit; explicit prune removes metadata and `.part` file. |
| **Test F** | V2 Compatibility Regression | **PASS** | `cargo test --test v2_server --features full` | All 22 tests in `v2_server.rs` pass; registration, tokens, upload retries, timestamps, and cancel endpoints intact. |
| **UI-1** | Recovery UI Widget Rendering | **PASS** | `flutter test --no-pub test/unit/widget/recovery_ui_test.dart` | 6/6 widget tests pass; displays "Ready to resume" (with button) for senders, "Waiting for sender" (no button) for receivers, and "Not Resumable" with specific reason. |

---

## 3. Hash Verification Evidence

All transfer scenarios verify integrity via dual-layer SHA-256 (per-chunk + full-file):

1. **Test A (Baseline):**
   - Transferred files: 1024 bytes (2 chunks of 512B) and 1025 bytes (3 chunks of 512B).
   - Receiver read: Exactly 1024 bytes and 1025 bytes from `<storage_dir>/<file_name>.mesh_incoming`.
   - Receiver hash: Computed SHA-256 matches sender's source file hash byte-for-byte.
2. **Test B (Interrupted & Resumed):**
   - Transferred file: 256 bytes (4 chunks of 64B).
   - SHA-256 of final published file matches original source file content.
3. **Test C (Cold Restart):**
   - Transferred file: 128 bytes (2 chunks of 64B).
   - Source SHA-256: `sha256_hex(&full_file)`.
   - On-disk read from Server 2: `on_disk_bytes == full_file` and `sha256_hex(&on_disk_bytes) == expected_sha`.
4. **Integrity Rejection Negative Tests:**
   - Chunk hash mismatch: Returns `422 Unprocessable Entity` (`test_v3_chunk_bad_hash_returns_422`).
   - Final full-file SHA-256 mismatch: Returns `422 Unprocessable Entity` and marks session `Failed` without publishing file (`test_v3_commit_sha256_mismatch_returns_422`).

---

## 4. Resume Behavior and Retransmission Evidence

In Test B (`test_client_transfer_resume_partial_chunks`):
- Total chunks: `4` (256 bytes).
- Initial pass: Manually transmitted manifest and only chunks `0` and `1`.
- Second pass: `transfer_file` invoked on the same `transfer_id`.
- The client re-queried `/manifest` and received `missing_chunks: [2, 3]`.
- Output assertions:
  - `result.total_chunks == 4`
  - `result.chunks_uploaded == 2` (Only missing chunks 2 and 3 were transmitted across the socket).
  - `result.chunks_resumed == 2` (Chunks 0 and 1 were confirmed already present on the receiver).
- Retransmission proof: Zero duplicate bytes were re-uploaded for chunks 0 and 1 during the resumption pass.

---

## 5. Cold-Restart Recovery Results

In Test C (`test_v3_cold_restart_recovery_across_server_instances`):
1. **Server 1 Phase:**
   - Manifest posted; chunk 0 (64 bytes) uploaded.
   - `ResumeManager::load(&id)` asserted on disk: `completed_chunks == [0]`.
   - Server 1 terminated with `server1.stop().await`.
2. **Server 2 Phase:**
   - Server 2 started on a fresh ephemeral port with an empty in-memory store (`store.count() == 0`).
   - Manifest submitted for the same `transfer_id`.
   - Server 2 read `mesh_resume_<id>.json`, checked `mesh_part_<id>.part`, and reopened the file using `DesktopStorageHandle::reopen_existing_with_temp` (`truncate(false)`).
   - Response: `missingChunks: [1]`.
   - Chunk 0 was recognized as an idempotent duplicate (`200 OK`).
   - Chunk 1 was uploaded and `commit` succeeded (`200 OK`).
   - Final destination file exists and matches full file payload.
   - `ResumeManager::load(&id)` confirmed deleted from disk after commit.

---

## 6. Peer-Binding Results

In Test D (`test_client_cold_restart_tls_peer_binding_negative`):
1. Server started with TLS (`TlsConfig`).
2. Client A registered manifest and uploaded chunk 0 over mTLS.
3. Server stopped and restarted as Server 2.
4. Client B (distinct private key and certificate) attempted to resume Client A's session using the original `transfer_id`.
5. Server 2 inspected `ResumeState.authenticated_peer_binding` against Client B's certificate public key.
6. Result: Client B was rejected with `403 Forbidden` (`"Transfer session belongs to a different peer"`).
7. The legitimate transfer's `.part` file and `ResumeState` remained unaltered.

---

## 7. V2 Compatibility Results

Executed: `cargo test --test v2_server --features full`
- **Result:** **22 passed, 0 failed** (0.62s).
- Tests validated:
  - `test_full_upload_flow`: Full legacy upload flow.
  - `test_upload_retry_reuses_the_same_path`: V2 retry idempotence.
  - `test_upload_with_matching_sha256` & `test_upload_with_mismatched_sha256`: V2 SHA-256 verification.
  - `test_prepare_upload_declined` & `test_prepare_upload_cancelled_by_session_less_cancel`: V2 rejection/cancellation.
  - `test_info_on_legacy_v1_route`: Backward compatibility.

---

## 8. Android SAF Limitations

1. **Direct POSIX vs SAF:**
   - V3 chunk streaming uses direct random-access seeking (`seek(Start(offset))` and `write_at`), which requires POSIX filesystem access.
   - Android SAF (`content://` URIs) operates via Java `ParcelFileDescriptor` streams and does not support arbitrary chunk indexing or cross-boundary atomic hard-linking.
2. **Rejection Safeguards:**
   - **Sender:** `validate_source_file_v3` returns `RsTransferErrorV3::UnsupportedSource` if path starts with `content://`.
   - **Receiver:** `ReceiveController.onPrepareUploadV3` rejects transfers with `accept: false` if the destination path uses Android SAF or SD card (`content://` or `/storage/XXXX-XXXX/`).
   - In both cases, transfers gracefully fall back to the V2 pipeline.
3. **App Restarts:**
   - SAF paths do NOT support persistent resume across process restarts because Android revokes ephemeral file descriptor permissions on process death.

---

## 9. Before/After Git-State Comparison

- **Baseline Status:** 95 modified tracked files, 60 untracked files.
- **Post-Verification Status:** Exactly the same 95 modified tracked files and 60 untracked files (with the addition of this verification report at `docs/reports/phase_2e_2_end_to_end_recovery_verification.md`).
- Zero source code modifications, zero dependency modifications, and zero file deletions occurred.

---

## 10. Remaining Risks and Recommended Next Step

### Remaining Risks
- **Physical Wi-Fi Multi-Device Verification:** Testing in this environment was conducted via dual-endpoint network socket loopbacks on a single host. Field validation over actual 802.11 Wi-Fi with radio packet loss between two distinct physical devices (e.g. Android phone + Windows PC) remains recommended prior to public release.

### **Conclusion: E2E PASS**
All required end-to-end recovery, interruption, cold-restart, peer-binding, and V2 compatibility scenarios were executed and passed with objective automated evidence.
