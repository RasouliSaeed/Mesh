import 'package:locara_app/provider/network/send_provider.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/src/isolate/child/upload_isolate.dart';
import 'package:test/test.dart';

void main() {
  const v3Device = Device(
    signalingId: null,
    ip: '192.168.1.10',
    version: '3.0',
    port: 53317,
    https: true,
    fingerprint: 'AABBCCDDEEFF',
    alias: 'V3 Peer',
    deviceModel: 'TestModel',
    deviceType: DeviceType.desktop,
    download: true,
    channels: [],
  );

  const v2Device = Device(
    signalingId: null,
    ip: '192.168.1.11',
    version: '2.2',
    port: 53317,
    https: true,
    fingerprint: '112233445566',
    alias: 'V2 Peer',
    deviceModel: 'TestModel',
    deviceType: DeviceType.desktop,
    download: true,
    channels: [],
  );

  const v1Device = Device(
    signalingId: null,
    ip: '192.168.1.12',
    version: '1.0',
    port: 53317,
    https: false,
    fingerprint: '998877665544',
    alias: 'V1 Peer',
    deviceModel: 'TestModel',
    deviceType: DeviceType.mobile,
    download: false,
    channels: [],
  );

  group('SendNotifier.canUseV3Upload', () {
    test('returns true for V3 peer with standard local filesystem files', () {
      final files = [
        HttpUploadFile(
          remoteFileToken: 'tok1',
          fileId: 'file-1',
          filePath: 'C:/Users/Test/file1.bin',
          fileBytes: null,
          fileSize: 1024,
        ),
        HttpUploadFile(
          remoteFileToken: 'tok2',
          fileId: 'file-2',
          filePath: '/home/user/file2.bin',
          fileBytes: null,
          fileSize: 2048,
        ),
      ];

      expect(SendNotifier.canUseV3Upload(target: v3Device, files: files), isTrue);
    });

    test('returns false when peer is V2', () {
      final files = [
        HttpUploadFile(
          remoteFileToken: 'tok1',
          fileId: 'file-1',
          filePath: 'C:/Users/Test/file1.bin',
          fileBytes: null,
          fileSize: 1024,
        ),
      ];

      expect(SendNotifier.canUseV3Upload(target: v2Device, files: files), isFalse);
    });

    test('returns false when peer is V1', () {
      final files = [
        HttpUploadFile(
          remoteFileToken: 'tok1',
          fileId: 'file-1',
          filePath: 'C:/Users/Test/file1.bin',
          fileBytes: null,
          fileSize: 1024,
        ),
      ];

      expect(SendNotifier.canUseV3Upload(target: v1Device, files: files), isFalse);
    });

    test('returns false when file list is empty', () {
      expect(SendNotifier.canUseV3Upload(target: v3Device, files: []), isFalse);
    });

    test('returns false when a file has null path (in-memory bytes / text preview)', () {
      final files = [
        HttpUploadFile(
          remoteFileToken: 'tok1',
          fileId: 'file-1',
          filePath: null,
          fileBytes: [1, 2, 3, 4],
          fileSize: 4,
        ),
      ];

      expect(SendNotifier.canUseV3Upload(target: v3Device, files: files), isFalse);
    });

    test('returns false when a file has Android SAF content:// URI', () {
      final files = [
        HttpUploadFile(
          remoteFileToken: 'tok1',
          fileId: 'file-1',
          filePath: 'content://com.android.providers.media.documents/document/image%3A123',
          fileBytes: null,
          fileSize: 4096,
        ),
      ];

      expect(SendNotifier.canUseV3Upload(target: v3Device, files: files), isFalse);
    });

    test('returns false for mixed file list where one is local and one is content://', () {
      final files = [
        HttpUploadFile(
          remoteFileToken: 'tok1',
          fileId: 'file-1',
          filePath: 'C:/test/file1.bin',
          fileBytes: null,
          fileSize: 1024,
        ),
        HttpUploadFile(
          remoteFileToken: 'tok2',
          fileId: 'file-2',
          filePath: 'content://tree/primary%3ADocuments/doc.pdf',
          fileBytes: null,
          fileSize: 5000,
        ),
      ];

      expect(SendNotifier.canUseV3Upload(target: v3Device, files: files), isFalse);
    });
  });
}
