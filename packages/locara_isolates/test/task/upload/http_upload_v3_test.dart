import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/rust/api/cancel.dart';
import 'package:locara_isolates/rust/api/http.dart';
import 'package:locara_isolates/rust/api/model.dart' show ProtocolType;
import 'package:locara_isolates/util/rust.dart';

class FakeRsHttpClient implements RsHttpClient {
  final Stream<RsTransferEventV3> Function() onTransferV3;

  FakeRsHttpClient({required this.onTransferV3});

  @override
  Stream<RsTransferEventV3> transferV3({
    required ProtocolType protocol,
    required String ip,
    required int port,
    String? publicKey,
    required String transferId,
    required String filePath,
    required RsTransferConfigV3 config,
    required RsCancellationToken cancelToken,
  }) => onTransferV3();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeRsCancellationToken implements RsCancellationToken {
  bool isCancelled = false;

  @override
  void cancel() {
    isCancelled = true;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  const testDevice = Device(
    signalingId: null,
    ip: '127.0.0.1',
    version: '3.0',
    port: 53317,
    https: true,
    fingerprint: 'TARGET_FINGERPRINT',
    alias: 'TargetDevice',
    deviceModel: 'TestModel',
    deviceType: DeviceType.desktop,
    download: true,
    channels: [],
  );

  group('HttpUploadV3Service', () {
    test('successful transfer completes with expected RsTransferResultV3 and triggers progress', () async {
      final progressEvents = <(int, int, double)>[];
      final controller = StreamController<RsTransferEventV3>();

      final client = FakeRsHttpClient(onTransferV3: () => controller.stream);
      final cancelToken = FakeRsCancellationToken();
      final service = const HttpUploadV3Service();

      final future = service.transfer(
        client: client,
        target: testDevice,
        transferId: 'session-v3-1234',
        filePath: 'C:/test/file.bin',
        onProgress: (transferred, total, progress) {
          progressEvents.add((transferred, total, progress));
        },
        cancelToken: cancelToken,
      );

      // Emit progress 0%
      controller.add(
        RsTransferEventV3.progress(
          bytesTransferred: BigInt.zero,
          totalBytes: BigInt.from(1000),
          progress: 0.0,
        ),
      );

      // Emit progress 50%
      controller.add(
        RsTransferEventV3.progress(
          bytesTransferred: BigInt.from(500),
          totalBytes: BigInt.from(1000),
          progress: 0.5,
        ),
      );

      // Emit success
      final expectedResult = RsTransferResultV3(
        transferId: 'session-v3-1234',
        fileName: 'file.bin',
        fileSize: BigInt.from(1000),
        totalChunks: BigInt.from(1),
        chunksUploaded: BigInt.from(1),
        chunksResumed: BigInt.zero,
      );
      controller.add(RsTransferEventV3.success(result: expectedResult));
      await controller.close();

      final result = await future;
      expect(result.transferId, 'session-v3-1234');
      expect(result.fileSize, BigInt.from(1000));
      expect(result.chunksUploaded, BigInt.from(1));
      expect(progressEvents.length, 2);
      expect(progressEvents[0], (0, 1000, 0.0));
      expect(progressEvents[1], (500, 1000, 0.5));
    });

    test('failed transfer throws typed RsTransferErrorV3', () async {
      final controller = StreamController<RsTransferEventV3>();
      final client = FakeRsHttpClient(onTransferV3: () => controller.stream);
      final cancelToken = FakeRsCancellationToken();
      const service = HttpUploadV3Service();

      final future = service.transfer(
        client: client,
        target: testDevice,
        transferId: 'session-v3-err',
        filePath: 'C:/test/file.bin',
        onProgress: (_, _, _) {},
        cancelToken: cancelToken,
      );

      controller.add(
        const RsTransferEventV3.failed(
          error: RsTransferErrorV3.insufficientStorage(message: 'Disk quota exceeded'),
        ),
      );
      await controller.close();

      expect(
        () => future,
        throwsA(isA<RsTransferErrorV3_InsufficientStorage>()),
      );
    });

    test('cancellation token passes through to client call', () async {
      final controller = StreamController<RsTransferEventV3>();
      final client = FakeRsHttpClient(onTransferV3: () => controller.stream);
      final cancelToken = FakeRsCancellationToken();
      const service = HttpUploadV3Service();

      final future = service.transfer(
        client: client,
        target: testDevice,
        transferId: 'session-v3-cancel',
        filePath: 'C:/test/file.bin',
        onProgress: (_, _, _) {},
        cancelToken: cancelToken,
      );

      cancelToken.cancel();
      expect(cancelToken.isCancelled, isTrue);

      controller.add(const RsTransferEventV3.failed(error: RsTransferErrorV3.cancelled()));
      await controller.close();

      expect(
        () => future,
        throwsA(isA<RsTransferErrorV3_Cancelled>()),
      );
    });

    test('stream closure without terminal event throws unexpected error', () async {
      final controller = StreamController<RsTransferEventV3>();
      final client = FakeRsHttpClient(onTransferV3: () => controller.stream);
      final cancelToken = FakeRsCancellationToken();
      const service = HttpUploadV3Service();

      final future = service.transfer(
        client: client,
        target: testDevice,
        transferId: 'session-v3-eof',
        filePath: 'C:/test/file.bin',
        onProgress: (_, _, _) {},
        cancelToken: cancelToken,
      );

      await controller.close();

      expect(
        () => future,
        throwsA(isA<RsTransferErrorV3_Unexpected>()),
      );
    });
  });

  group('HumanErrorMessageExt for RsTransferErrorV3', () {
    test('formats all structured error categories with clear, safe messages', () {
      expect(
        const RsTransferErrorV3.invalidConfiguration(message: 'Invalid chunk size').humanErrorMessage,
        'Invalid configuration: Invalid chunk size',
      );
      expect(
        const RsTransferErrorV3.unsupportedSource(message: 'Content URI not supported').humanErrorMessage,
        'Unsupported source: Content URI not supported',
      );
      expect(
        const RsTransferErrorV3.sourceChanged(message: 'File size changed').humanErrorMessage,
        'File changed during transfer: File size changed',
      );
      expect(
        const RsTransferErrorV3.networkOrTimeout(message: 'Connection reset').humanErrorMessage,
        'Network error: Connection reset',
      );
      expect(
        const RsTransferErrorV3.peerIdentityMismatch(message: 'Cert mismatch').humanErrorMessage,
        'Security mismatch: Cert mismatch',
      );
      expect(
        const RsTransferErrorV3.conflict(message: 'Active session exists').humanErrorMessage,
        'Transfer conflict: Active session exists',
      );
      expect(
        const RsTransferErrorV3.integrityVerificationFailed(message: 'SHA-256 mismatch').humanErrorMessage,
        'Checksum failed: SHA-256 mismatch',
      );
      expect(
        const RsTransferErrorV3.destinationCollision(message: 'File already exists').humanErrorMessage,
        'File already exists: File already exists',
      );
      expect(
        const RsTransferErrorV3.insufficientStorage(message: 'No space left').humanErrorMessage,
        'Receiver out of storage: No space left',
      );
      expect(
        const RsTransferErrorV3.cancelled().humanErrorMessage,
        'Transfer cancelled',
      );
      expect(
        const RsTransferErrorV3.unexpected(message: 'Server error').humanErrorMessage,
        'Error: Server error',
      );
    });
  });

  group('V3 Isolate Task and Event DTOs', () {
    test('HttpUploadFileV3 and HttpUploadFilesV3Task structure', () {
      final file = HttpUploadFileV3(
        transferId: 'session-42',
        filePath: 'C:/docs/report.pdf',
        fileSize: 2048,
      );
      final task = HttpUploadFilesV3Task(
        files: [file],
        device: testDevice,
      );

      expect(task.files.length, 1);
      expect(task.files.first.transferId, 'session-42');
      expect(task.files.first.fileSize, 2048);
      expect(task.device.fingerprint, 'TARGET_FINGERPRINT');
      expect(task.config, isNull);
    });

    test('HttpUploadFileProgressEvent supports optional byte counts', () {
      final event = HttpUploadFileProgressEvent(
        fileId: 'transfer-1',
        progress: 0.75,
        bytesTransferred: 750,
        totalBytes: 1000,
      );

      expect(event.fileId, 'transfer-1');
      expect(event.progress, 0.75);
      expect(event.bytesTransferred, 750);
      expect(event.totalBytes, 1000);
    });

    test('HttpUploadFileFinishedEvent supports optional RsTransferResultV3', () {
      final result = RsTransferResultV3(
        transferId: 'transfer-1',
        fileName: 'report.pdf',
        fileSize: BigInt.from(1000),
        totalChunks: BigInt.from(1),
        chunksUploaded: BigInt.from(1),
        chunksResumed: BigInt.zero,
      );

      final event = HttpUploadFileFinishedEvent(
        fileId: 'transfer-1',
        result: result,
      );

      expect(event.fileId, 'transfer-1');
      expect(event.result?.transferId, 'transfer-1');
      expect(event.result?.fileName, 'report.pdf');
    });

    test('IsolateHttpUploadFilesV3Action initializes task and dispatches', () {
      final file = HttpUploadFileV3(
        transferId: 'action-test',
        filePath: 'C:/file.txt',
        fileSize: 100,
      );
      final action = IsolateHttpUploadFilesV3Action(
        files: [file],
        device: testDevice,
      );

      expect(action.files.length, 1);
      expect(action.device.fingerprint, 'TARGET_FINGERPRINT');
    });
  });
}
