import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locara_app/model/persistence/durable_send_entry.dart';
import 'package:locara_app/model/persistence/favorite_device.dart';
import 'package:locara_app/model/state/nearby_devices_state.dart';
import 'package:locara_app/provider/durable_send_provider.dart';
import 'package:locara_app/provider/favorites_provider.dart';
import 'package:locara_app/provider/logging/discovery_logs_provider.dart';
import 'package:locara_app/provider/network/nearby_devices_provider.dart';
import 'package:locara_app/provider/network/send_provider.dart';
import 'package:locara_app/provider/persistence_provider.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/model/device_info_result.dart';
import 'package:locara_isolates/model/dto/multicast_dto.dart';
import 'package:locara_isolates/model/stored_security_context.dart';
import 'package:locara_isolates/src/isolate/child/upload_isolate.dart';
import 'package:locara_isolates/src/isolate/dto/send_to_isolate_data.dart';
import 'package:locara_isolates/util/notification_strings.dart';
import 'package:locara_isolates/util/transfer_notification.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';
import 'package:typed_isolates/typed_isolates.dart';

class MockPathProviderPlatform extends Fake with MockPlatformInterfaceMixin implements PathProviderPlatform {
  @override
  Future<String?> getTemporaryPath() async => '${Directory.systemTemp.path}/locara_test_cache';

  @override
  Future<String?> getApplicationDocumentsPath() async => '${Directory.systemTemp.path}/locara_test_docs';

  @override
  Future<String?> getDownloadsPath() async => '${Directory.systemTemp.path}/locara_test_downloads';
}

class FakePersistenceService extends Fake implements PersistenceService {
  List<DurableSendEntry> entries;

  FakePersistenceService([List<DurableSendEntry>? initial]) : entries = initial ?? [];

  @override
  List<DurableSendEntry> getDurableSendTransfers() => entries;

  @override
  Future<void> setDurableSendTransfers(List<DurableSendEntry> newEntries) async {
    entries = newEntries;
  }

  @override
  List<FavoriteDevice> getFavorites() => [];
}

class MockHttpUploadConnector
    implements IsolateConnector<IsolateTaskStreamResult<HttpUploadEvent>, SendToIsolateData<IsolateTask<BaseHttpUploadTask>>> {
  final List<BaseHttpUploadTask> sentTasks = [];
  int lastTaskId = 0;
  final StreamController<IsolateTaskStreamResult<HttpUploadEvent>> streamController = StreamController.broadcast();

  Stream<IsolateTaskStreamResult<HttpUploadEvent>> get stream => streamController.stream;

  @override
  Stream<IsolateTaskStreamResult<HttpUploadEvent>> get receiveFromIsolate => streamController.stream;

  @override
  Isolate get isolate => throw UnimplementedError();

  @override
  void sendToIsolate(SendToIsolateData<IsolateTask<BaseHttpUploadTask>> message) {
    final task = message.data;
    if (task != null) {
      lastTaskId = task.id;
      sentTasks.add(task.data);
    }
  }

  void emitFinished({required String fileId}) {
    streamController.add(
      IsolateTaskStreamResult.event(
        id: lastTaskId,
        data: HttpUploadFileFinishedEvent(fileId: fileId),
      ),
    );
    streamController.add(
      IsolateTaskStreamResult.done(
        id: lastTaskId,
      ),
    );
  }

  Future<void> close() async {
    await streamController.close();
  }

  void dispose() {
    unawaited(streamController.close());
  }
}

ParentIsolateState _createParentState(MockHttpUploadConnector connector) {
  return ParentIsolateState(
    syncState: SyncState(
      rootIsolateToken: Object(),
      securityContext: const StoredSecurityContext(
        privateKey: '',
        publicKey: '',
        certificate: '',
        certificateHash: 'HASH',
      ),
      deviceInfo: DeviceInfoResult(
        deviceType: DeviceType.desktop,
        deviceModel: 'TestModel',
        androidSdkInt: null,
      ),
      alias: 'TestAlias',
      port: 53317,
      networkWhitelist: null,
      networkBlacklist: null,
      protocol: ProtocolType.https,
      multicastGroup: '224.0.0.167',
      discoveryTimeout: 2000,
      serverRunning: true,
      download: false,
    ),
    discovery: null,
    httpUpload: connector,
    httpServer: null,
  );
}

class FakeFavoritesService extends FavoritesService {
  FakeFavoritesService() : super(FakePersistenceService());

  @override
  List<FavoriteDevice> init() => [];
}

class FakeNearbyDevicesService extends NearbyDevicesService {
  final NearbyDevicesState initial;

  FakeNearbyDevicesService(this.initial, IsolateController isolateController)
    : super(
        isolateController: isolateController,
        favoriteService: FakeFavoritesService(),
        discoveryLogs: DiscoveryLogger(),
      );

  @override
  NearbyDevicesState init() => initial;
}

String _dummyRemainingMinutes({required Object m, required Object ss}) => '$m:$ss';
String _dummyRemainingLong({required num h, required num m}) => '${h}h ${m}m';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = MockPathProviderPlatform();

  setUpAll(() {
    TransferNotification.init(
      NotificationStrings(
        titleReceiving: 'Receiving',
        titleSending: 'Sending',
        remainingTimeMinutes: _dummyRemainingMinutes,
        remainingTimeLong: _dummyRemainingLong,
      ),
    );
  });

  group('SendNotifier.resumeTransfer', () {
    late File validFile;
    late MockHttpUploadConnector mockConnector;

    setUp(() {
      validFile = File('${Directory.systemTemp.path}/resume_valid_${DateTime.now().microsecondsSinceEpoch}.bin');
      validFile.writeAsBytesSync(List.generate(2048, (i) => i % 256));
      mockConnector = MockHttpUploadConnector();
    });

    tearDown(() {
      if (validFile.existsSync()) {
        validFile.deleteSync();
      }
    });

    testWidgets('aborts and returns false if transfer ID does not exist in durableSendProvider', (tester) async {
      final fakePersistence = FakePersistenceService([]);
      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
        ],
      );

      final result = await container.notifier(sendProvider).resumeTransfer('nonexistent_id');
      expect(result, isFalse);
      expect(container.notifier(sendProvider).isTransferResuming('nonexistent_id'), isFalse);
    });

    testWidgets('aborts and returns false if source file is missing on disk', (tester) async {
      final now = DateTime.now().toUtc();
      final entry = DurableSendEntry(
        transferId: 'missing_source_tx',
        targetDeviceAlias: 'Target Device',
        targetFingerprint: 'FP_PEER_1',
        targetIp: '192.168.1.100',
        targetPort: 53317,
        filePath: '/nonexistent/path/never_created.bin',
        fileName: 'never_created.bin',
        fileSize: 2048,
        bytesTransferred: 512,
        status: 'interrupted',
        createdAt: now.subtract(const Duration(minutes: 5)),
        updatedAt: now.subtract(const Duration(minutes: 1)),
      );

      final fakePersistence = FakePersistenceService([entry]);
      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
        ],
      );

      final result = await container.notifier(sendProvider).resumeTransfer('missing_source_tx');
      expect(result, isFalse);
      expect(container.notifier(sendProvider).isTransferResuming('missing_source_tx'), isFalse);
      expect(mockConnector.sentTasks.isEmpty, isTrue);
    });

    testWidgets('prevents duplicate concurrent resume attempts for the same transfer ID', (tester) async {
      final now = DateTime.now().toUtc();
      final entry = DurableSendEntry(
        transferId: 'concurrent_tx',
        targetDeviceAlias: 'Target Device',
        targetFingerprint: 'FP_CONC',
        targetIp: '192.168.1.100',
        targetPort: 53317,
        filePath: validFile.path,
        fileName: 'concurrent.bin',
        fileSize: 2048,
        bytesTransferred: 1024,
        status: 'interrupted',
        createdAt: now,
        updatedAt: now,
      );

      final fakePersistence = FakePersistenceService([entry]);
      final isolateController = IsolateController(
        initialState: _createParentState(mockConnector),
      );

      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
          parentIsolateProvider.overrideWithNotifier((ref) => isolateController),
        ],
      );

      Routerino.navigatorKey = GlobalKey<NavigatorState>();

      await tester.runAsync(() async {
        // Start first resume call
        final firstFuture = container.notifier(sendProvider).resumeTransfer('concurrent_tx');

        // Check that isTransferResuming reports true
        expect(container.notifier(sendProvider).isTransferResuming('concurrent_tx'), isTrue);

        // Attempt a duplicate concurrent resume call
        final duplicateResult = await container.notifier(sendProvider).resumeTransfer('concurrent_tx');
        expect(duplicateResult, isFalse, reason: 'Duplicate concurrent resume call must be rejected');

        // Allow microtask to process isolate task dispatch
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Complete the first call by emitting finished event to mock connector
        mockConnector.emitFinished(fileId: 'concurrent_tx');

        await firstFuture;
        expect(container.notifier(sendProvider).isTransferResuming('concurrent_tx'), isFalse);
      });
    });

    testWidgets('resumes with original transfer ID, preserves TLS pinning, and updates IP from nearby devices', (tester) async {
      final now = DateTime.now().toUtc();
      final entry = DurableSendEntry(
        transferId: 'original_v3_transfer_id_123',
        targetDeviceAlias: 'Original Device Alias',
        targetFingerprint: 'FINGERPRINT_STRICT_123',
        targetIp: '192.168.1.50', // Stale old IP
        targetPort: 53317,
        filePath: validFile.path,
        fileName: 'resume_file.bin',
        fileSize: 2048,
        bytesTransferred: 1024,
        status: 'interrupted',
        createdAt: now,
        updatedAt: now,
      );

      // Peer has re-connected on a new IP (e.g. DHCP change)
      const updatedNearbyDevice = Device(
        signalingId: null,
        ip: '192.168.1.222', // Updated IP
        version: '3.0',
        port: 53318, // Updated port
        https: true,
        fingerprint: 'FINGERPRINT_STRICT_123', // Matches original certificate fingerprint!
        alias: 'Original Device Alias',
        deviceModel: 'UpdatedModel',
        deviceType: DeviceType.desktop,
        download: true,
        channels: [],
      );

      final fakePersistence = FakePersistenceService([entry]);
      final isolateController = IsolateController(
        initialState: _createParentState(mockConnector),
      );

      final container = RefenaContainer(
        overrides: [
          persistenceProvider.overrideWithValue(fakePersistence),
          parentIsolateProvider.overrideWithNotifier((ref) => isolateController),
          nearbyDevicesProvider.overrideWithNotifier(
            (ref) => FakeNearbyDevicesService(
              const NearbyDevicesState(
                devices: {'FINGERPRINT_STRICT_123': updatedNearbyDevice},
                runningFavoriteScan: false,
                runningIps: {},
                signalingDevices: {},
              ),
              isolateController,
            ),
          ),
        ],
      );

      Routerino.navigatorKey = GlobalKey<NavigatorState>();

      await tester.runAsync(() async {
        final resumeFuture = container.notifier(sendProvider).resumeTransfer('original_v3_transfer_id_123');

        // Allow microtasks to dispatch the isolate task
        await Future<void>.delayed(const Duration(milliseconds: 50));

        expect(mockConnector.sentTasks.length, 1);
        final sentTask = mockConnector.sentTasks.first;
        expect(sentTask, isA<HttpUploadFilesV3Task>());

        final v3Task = sentTask as HttpUploadFilesV3Task;
        // 1. MUST use original transfer ID, NOT a new UUID
        expect(v3Task.files.first.transferId, 'original_v3_transfer_id_123');
        expect(v3Task.files.first.filePath, validFile.path);
        expect(v3Task.files.first.fileSize, 2048);

        // 2. MUST preserve TLS fingerprint pinning
        expect(v3Task.device.fingerprint, 'FINGERPRINT_STRICT_123');

        // 3. MUST use updated IP and port from re-discovered peer
        expect(v3Task.device.ip, '192.168.1.222');
        expect(v3Task.device.port, 53318);

        // Complete the transfer
        mockConnector.emitFinished(fileId: 'original_v3_transfer_id_123');

        final result = await resumeFuture;
        expect(result, isTrue);

        // Verify entry transitioned to finished in durableSendProvider
        final updatedEntry = container.read(durableSendProvider).firstWhere((e) => e.transferId == 'original_v3_transfer_id_123');
        expect(updatedEntry.status, 'finished');
      });
    });
  });
}
