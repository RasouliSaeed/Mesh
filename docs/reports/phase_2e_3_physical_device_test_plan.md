# Mesh — Phase 2E-3: Physical Device Test Plan

**Date:** 2026-10-19  
**Status:** Preparation Only (Ready for Physical Device Execution)  
**Target Environments:** Windows 10/11 Desktop & Android 10+ Device  
**Repository:** `C:\Users\SR\Desktop\Mesh`  
**Reference Document:** `docs/MESH_MASTER_SPEC.md` (Rules 6, 7, 16, 19, 21, 26, 45, 46)  

---

## 1. Executive Summary

This plan specifies the exact procedure for validating Mesh's V3 transfer engine, broken-session recovery UI, and fallback mechanisms on **two independent physical devices** (Windows PC + Android Smartphone) connected over a local Wi-Fi network.

While loopback testing in Phase 2E-2 verified socket semantics, protocol serialization, and memory/disk transitions in a controlled environment, physical-device testing validates:
- Real 802.11 Wi-Fi multicast discovery and unicast registration.
- Asynchronous radio disconnection and reconnect behavior.
- Android OS lifecycle events (app backgrounding, process death, doze mode).
- True cross-platform mutual TLS (mTLS) handshake and certificate pinning.
- Physical storage I/O on flash memory (eMMC/UFS) and Android SAF boundaries.

---

## 2. Build & Launch Procedures

### 2.1 Sender: Windows Desktop Build
Run from `app/` in PowerShell:
```powershell
# 1. Resolve workspace dependencies
fvm flutter pub get

# 2. Codegen (Mappable, Slang i18n)
fvm dart run build_runner build -d
fvm dart run slang

# 3. Build Release Windows Executable
fvm flutter build windows --release
```
- **Binary Location:** `app/build/windows/x64/runner/Release/mesh_app.exe`
- **Development Launch:** `fvm flutter run -d windows`

### 2.2 Receiver: Android Physical Device Build
Run from `app/` in PowerShell:
```powershell
# 1. Resolve dependencies & codegen
fvm flutter pub get
fvm dart run build_runner build -d
fvm dart run slang

# 2. Build Release APK (arm64-v8a recommended for modern Android devices)
fvm flutter build apk --release --split-per-abi
```
- **Binary Location:** `app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk`
- **Installation via ADB:**
  ```powershell
  adb install -r app/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
  ```
- **Development Launch:** `fvm flutter run -d <device-id>`

---

## 3. Protocol, Discovery & Security Paths

### 3.1 Device Discovery
1. **Multicast Announcement:** Sender/Receiver broadcast UDP packets to `224.0.0.167:53317` (`DEFAULT_MULTICAST_GROUP`) and `ff12::fd3a:e420:53317` (`DEFAULT_MULTICAST_GROUP_V6`).
2. **Payload:** Carries `alias`, `deviceModel`, `version: "3.0"`, `port: 53317`, `protocol: "https"`, and SHA-256 certificate `fingerprint`.
3. **Unicast Registration:** The discovering peer responds with a unicast HTTP `POST /api/mesh/v3/register` (or `/api/mesh/v2/register`).
4. **Fallback:** If multicast is blocked by the router, peers can connect via the **Manual Connection** dialog (`SendPage` -> Enter IP & Port).

### 3.2 Mutual TLS & Identity Pinning
1. **Certificate Generation:** Each device generates an on-the-fly self-signed X.509 certificate upon startup (`mesh::crypto::cert::generate_self_signed`).
2. **mTLS Handshake:**
   - Windows client pins the Android server certificate against the advertised SHA-256 `fingerprint`.
   - Android server requires client certificate authentication and extracts public key DER (`RequestClientInfo::identifier()`) to establish `authenticated_peer_binding`.
3. **Reconnection Pinning:** Even if Android reconnects with a different DHCP IP address, Windows routes to the new IP while **strictly verifying** that the TLS certificate fingerprint matches the original target device.

### 3.3 Outbound V3 Transfer Pipeline
`SendNotifier.canUseV3Upload(target, files)` authorizes V3 direct chunk streaming when:
- Peer advertised `version == "3.0"`.
- Files list is non-empty and all files have valid local filesystem paths.
- No files have `content://` URIs.

---

## 4. Android Capabilities and SAF Boundaries

| Operating Context | V3 Direct Chunk Streaming Supported? | Documented Behavior & Safety Guard |
|---|:---:|---|
| **Android Native Internal Storage** (`/data/user/0/...`) | **YES** | Direct POSIX file handle, `truncate(false)`, `write_at`. |
| **Android Standard External App Directory** (`/storage/emulated/0/Download/Mesh`) | **YES** | Full V3 support with resume across reconnect and app restarts. |
| **Android SAF Destination Tree** (`content://...`) | **NO (by design)** | `ReceiveController.onPrepareUploadV3` rejects with `accept: false`; transfer automatically falls back to V2 streaming. |
| **Android External SD Card Directory** (`/storage/XXXX-XXXX/`) | **NO (by design)** | Rejects V3 manifest (`accept: false`); falls back to V2 via `FileSaveTarget` file descriptor. |
| **Android SAF Sender File Picker** (`content://...`) | **NO (by design)** | `validate_source_file_v3` returns `UnsupportedSource`; automatically falls back to V2 streaming. |
| **SAF Resume Across App Restarts** | **NO (OS constraint)** | Android OS revokes `ParcelFileDescriptor` on process death; persistent resume across restarts is supported only on native filesystem paths. |

---

## 5. Minimum Safe Test Setup

### 5.1 Hardware & Network Prerequisites
1. **Device A (Windows):** Windows 10/11 laptop or desktop, connected to Wi-Fi. Windows Firewall configured to allow port `53317` (TCP and UDP) on Private networks.
2. **Device B (Android):** Physical smartphone running Android 10+ (API 29+), connected to the same Wi-Fi SSID.
3. **Wi-Fi Router:** Standard 2.4 GHz or 5 GHz Wi-Fi Access Point with **Access Point (AP) / Client Isolation DISABLED**. No VPNs or captive portals active on either device.
4. **Android Permissions:** Granted "Nearby devices" (Wi-Fi multicast), "Notifications" (Android 13+), and "Storage / Files access".

### 5.2 Deterministic Test Data Generation
Generate a deterministic 50 MB test file on Windows with a known pre-calculated SHA-256 hash:
```powershell
$testDir = "C:\Users\SR\Desktop\Mesh_E2E_Test"
New-Item -ItemType Directory -Force -Path $testDir | Out-Null
$testFilePath = "$testDir\deterministic_test_50mb.bin"

# 50 MiB deterministic payload (seeded Random = 42)
$bytes = New-Object byte[] (50 * 1024 * 1024)
(New-Object System.Random(42)).NextBytes($bytes)
[System.IO.File]::WriteAllBytes($testFilePath, $bytes)

# Calculate expected SHA-256
$expectedHash = (Get-FileHash -Algorithm SHA256 $testFilePath).Hash
Write-Host "Generated: $testFilePath"
Write-Host "Expected SHA-256: $expectedHash"
```

---

## 6. Physical Device Test Cases

### Test Case 1: Baseline Windows-to-Android V3 Transfer
- **Objective:** Verify clean, uninterrupted end-to-end V3 transfer over real Wi-Fi.
- **Steps:**
  1. Open Mesh on Android (Device B); ensure Quick Save is OFF.
  2. Open Mesh on Windows (Device A); select Android device from nearby list.
  3. Select `deterministic_test_50mb.bin` and click **Send**.
  4. On Android, confirm `ReceivePage` displays file name and size (`52,428,800 bytes`). Tap **Accept**.
  5. Observe progress bar streaming to 100%.
  6. Verify transfer finishes and displays in history.
- **Verification:**
  - Pull received file via ADB: `adb pull /storage/emulated/0/Download/deterministic_test_50mb.bin test_received.bin`.
  - Calculate hash: `(Get-FileHash -Algorithm SHA256 test_received.bin).Hash`.
  - Assert received hash exactly equals `$expectedHash`.
  - Verify no `.part` or `.json` files linger in Android cache.

---

### Test Case 2: Baseline Android-to-Windows Transfer
- **Objective:** Verify reverse outbound transfer from Android to Windows.
- **Steps:**
  1. Push deterministic test file to Android: `adb push deterministic_test_50mb.bin /storage/emulated/0/Download/`.
  2. In Android Mesh, tap **Send** -> **Files** -> Select `deterministic_test_50mb.bin` from local storage.
  3. Select Windows PC from discovered devices.
  4. Accept transfer on Windows PC.
- **Verification:**
  - Check received file on Windows destination directory.
  - Assert `Get-FileHash` matches expected hash.

---

### Test Case 3: Network Interruption and Resumption (Air Gap / Wi-Fi Toggle)
- **Objective:** Verify that severed network mid-transfer allows clean resume without re-transmitting completed chunks.
- **Steps:**
  1. Initiate 50 MB transfer from Windows to Android.
  2. When progress reaches approximately **40% – 60%**, immediately turn OFF Wi-Fi on Android (or disable network interface).
  3. Observe Windows sender: Status transitions to `interrupted` or `waiting for peer`.
  4. Observe Android receiver: In `ReceiveHistoryPage` -> `RecoveryList`, transfer appears under status chip **Waiting for sender** (with no fake resume button).
  5. Inspect intermediate `.part` file on Android via ADB:
     ```bash
     adb shell "ls -l /data/data/org.mesh.mesh_app/cache/mesh_part_*.part"
     ```
     Confirm file size is greater than 0 bytes and matches ~50% of the total size.
  6. Re-enable Wi-Fi on Android. Wait for devices to rediscover each other.
  7. On Windows: Open `ReceiveHistoryPage` -> `RecoveryList`. Confirm transfer displays **Ready to resume** with an active **Resume** button.
  8. Tap **Resume** on Windows.
  9. Observe: Android server responds with missing chunks; transfer resumes from intermediate point; completes to 100%.
- **Verification:**
  - Pull final file via ADB and verify SHA-256 matches `$expectedHash`.
  - Check logs to confirm only missing chunks were transmitted during the resume pass.

---

### Test Case 4: Receiver App Process Termination & Cold Restart
- **Objective:** Verify that receiver can resume after the Android application process is completely terminated.
- **Steps:**
  1. Start 50 MB transfer from Windows to Android.
  2. Disconnect Wi-Fi at ~50%.
  3. On Android: Force-stop the application:
     ```powershell
     adb shell am force-stop org.mesh.mesh_app
     ```
  4. Re-enable Wi-Fi on Android.
  5. Relaunch Mesh on Android:
     ```powershell
     adb shell am start -n org.mesh.mesh_app/.MainActivity
     ```
  6. On Android: Check `RecoveryList` in `ReceiveHistoryPage`. Confirm the interrupted transfer is discovered from disk metadata and displays **Waiting for sender**.
  7. On Windows: Tap **Resume**.
  8. Android server reopens `.part` file without truncation (`truncate(false)`), returns missing chunk list, receives remaining chunks, and commits.
- **Verification:**
  - Verify final published file SHA-256 matches `$expectedHash`.
  - Verify `mesh_resume_<id>.json` is deleted after commit.

---

### Test Case 5: Dynamic IP Address Change During Interruption
- **Objective:** Verify dynamic IP renegotiation while strictly enforcing TLS certificate pinning.
- **Steps:**
  1. Start transfer; interrupt at ~50%.
  2. Disconnect Android from Wi-Fi and reconnect to a mobile hotspot or trigger DHCP lease renewal so Android acquires a **new IP address** (e.g. from `192.168.1.50` to `192.168.1.85`).
  3. Wait for Windows to discover the new Android IP via multicast announcement.
  4. Tap **Resume** on Windows.
  5. Windows updates target routing to the new IP while pinning the connection to Android's original TLS certificate fingerprint.
  6. Complete transfer and verify SHA-256.
- **Verification:**
  - Verify that connection succeeds and transfer completes without `BadCertificate` errors.
  - Verify that an unrelated third device at the old IP cannot intercept or resume the session.

---

### Test Case 6: Android SAF Fallback Verification
- **Objective:** Verify that configuring an Android SAF document tree gracefully falls back to V2 streaming.
- **Steps:**
  1. On Android: Go to **Settings** -> **Destination** -> Pick a folder via system file picker (which returns a SAF `content://` URI or SD card tree).
  2. Send `deterministic_test_50mb.bin` from Windows to Android.
  3. Observe Android receiver: `onPrepareUploadV3` detects `content://` destination and rejects V3 with `accept: false`.
  4. Observe Windows sender: Detects V3 rejection and automatically executes V2 upload.
  5. Accept transfer on Android.
- **Verification:**
  - Verify file is received via V2 pipeline.
  - Verify received file SHA-256 matches `$expectedHash`.

---

## 7. Automation vs Manual Classification

| Test Step / Scenario | Execution Mode | Tools & Automation Method |
|---|:---:|---|
| **Deterministic File Generation & Hash Calculation** | **Automated** | PowerShell script (`Get-FileHash`). |
| **Android APK Build & Installation** | **Automated** | `fvm flutter build apk` + `adb install -r`. |
| **Windows Executable Build & Launch** | **Automated** | `fvm flutter build windows` + PowerShell process start. |
| **Device Selection & Initial Send Tap** | **Manual / Interactive** | User taps device card and selects file in UI. |
| **Receive Approval Dialog (Gate A)** | **Manual / Interactive** | User taps "Accept" on Android screen (or automated via Quick Save). |
| **Wi-Fi Interruption** | **Semi-Automated** | Manual Wi-Fi toggle or `adb shell svc wifi disable`. |
| **Android Process Force-Stop & Relaunch** | **Automated** | `adb shell am force-stop` + `am start`. |
| **Resume Button Tap in Recovery UI** | **Manual / Interactive** | User taps "Resume" in `RecoveryList` on Windows. |
| **Post-Transfer Hash Validation** | **Automated** | `adb pull` + PowerShell `Get-FileHash` comparison. |

---

## 8. Physical Device Execution Checklist

Follow this checklist once physical devices are connected:

```markdown
[ ] 1. ENVIRONMENT VERIFICATION
    [ ] Windows PC and Android smartphone on identical Wi-Fi network.
    [ ] Router AP-isolation confirmed disabled.
    [ ] Windows Firewall allows port 53317 TCP/UDP on Private network.
    [ ] Android USB debugging connected via ADB (`adb devices` confirms 1 device).

[ ] 2. BUILD & INSTALL
    [ ] Build Windows Release: `fvm flutter build windows --release`.
    [ ] Build Android Release: `fvm flutter build apk --release --split-per-abi`.
    [ ] Install APK on Android: `adb install -r <apk-path>`.
    [ ] Grant Android runtime permissions (Notifications, Nearby Devices, Storage).

[ ] 3. TEST DATA PREPARATION
    [ ] Generate 50 MB deterministic binary test file with known SHA-256.

[ ] 4. TEST CASE EXECUTION
    [ ] Case 1: Windows-to-Android Uninterrupted V3 Transfer -> Compare SHA-256 (MUST MATCH).
    [ ] Case 2: Android-to-Windows Uninterrupted V3 Transfer -> Compare SHA-256 (MUST MATCH).
    [ ] Case 3: Network Interruption -> Verify "Waiting for sender" -> Reconnect -> Tap Resume -> Compare SHA-256 (MUST MATCH).
    [ ] Case 4: Process Kill -> `adb shell am force-stop` -> Relaunch -> Tap Resume -> Compare SHA-256 (MUST MATCH).
    [ ] Case 5: Dynamic IP Change -> Reconnect on new IP -> Tap Resume -> Compare SHA-256 (MUST MATCH).
    [ ] Case 6: Verify full-file SHA-256 matches expected hash across all test files.
    [ ] Case 7: Configure Android SAF destination -> Send -> Verify graceful V2 fallback -> Compare SHA-256.

[ ] 5. POST-TEST INSPECTION
    [ ] Verify no orphan `.part` or `.tmp` files in Android cache directory.
    [ ] Verify `mesh_resume_<id>.json` is deleted from storage.
    [ ] Record execution results and logs in final physical test summary.
```
