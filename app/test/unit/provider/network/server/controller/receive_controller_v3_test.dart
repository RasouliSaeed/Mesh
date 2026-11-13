import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locara_app/model/persistence/color_mode.dart';
import 'package:locara_app/model/persistence/favorite_device.dart';
import 'package:locara_app/model/send_mode.dart';
import 'package:locara_app/model/state/server/server_state.dart';
import 'package:locara_app/model/state/settings_state.dart';
import 'package:locara_app/provider/device_info_provider.dart';
import 'package:locara_app/provider/favorites_provider.dart';
import 'package:locara_app/provider/network/server/controller/receive_controller.dart';
import 'package:locara_app/provider/network/server/server_utils.dart';
import 'package:locara_app/provider/persistence_provider.dart';
import 'package:locara_app/provider/settings_provider.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/model/device_info_result.dart';
import 'package:locara_isolates/model/dto/multicast_dto.dart';
import 'package:locara_isolates/model/session_status.dart';
import 'package:locara_isolates/model/stored_security_context.dart';
import 'package:locara_isolates/src/isolate/child/server_isolate.dart';
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

class FakePersistence extends Fake implements PersistenceService {}

class FakeSettingsService extends SettingsService {
  final SettingsState initial;
  FakeSettingsService(this.initial) : super(FakePersistence());

  @override
  SettingsState init() => initial;
}

class FakeFavoritesService extends FavoritesService {
  final List<FavoriteDevice> initial;
  FakeFavoritesService(this.initial) : super(FakePersistence());

  @override
  List<FavoriteDevice> init() => initial;
}

class MockHttpServerConnector
    implements IsolateConnector<IsolateTaskStreamResult<HttpServerEvent>, SendToIsolateData<IsolateTask<BaseHttpServerTask>>> {
  final List<BaseHttpServerTask> sentTasks = [];

  @override
  void sendToIsolate(SendToIsolateData<IsolateTask<BaseHttpServerTask>> message) {
    final taskData = message.data?.data;
    if (taskData != null) {
      sentTasks.add(taskData);
    }
  }

  @override
  Stream<IsolateTaskStreamResult<HttpServerEvent>> get receiveFromIsolate => const Stream.empty();

  @override
  Isolate get isolate => throw UnimplementedError();
}

SettingsState _createSettings({
  bool quickSave = false,
  bool quickSaveFromFavorites = false,
  String? destination,
}) {
  return SettingsState(
    showToken: 'token',
    alias: 'alias',
    theme: ThemeMode.system,
    colorMode: ColorMode.system,
    customColor: Colors.teal,
    locale: null,
    port: 53317,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: '224.0.0.167',
    destination: destination ?? 'C:/locara_downloads',
    saveToGallery: false,
    saveToHistory: false,
    quickSave: quickSave,
    quickSaveFromFavorites: quickSaveFromFavorites,
    receivePin: null,
    autoFinish: false,
    minimizeToTray: false,
    https: true,
    sendMode: SendMode.single,
    saveWindowPlacement: false,
    enableAnimations: true,
    deviceType: DeviceType.desktop,
    deviceModel: 'Model',
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: true,
    verifyChecksums: true,
    discoveryTimeout: 2000,
    advancedSettings: false,
  );
}

ParentIsolateState _createParentState(MockHttpServerConnector connector) {
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
    httpUpload: null,
    httpServer: connector,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  PathProviderPlatform.instance = MockPathProviderPlatform();
  TransferNotification.init(
    NotificationStrings(
      titleReceiving: 'Receiving',
      titleSending: 'Sending',
      remainingTimeMinutes: ({required m, required ss}) => '$m:$ss',
      remainingTimeLong: ({required h, required m}) => '${h}h ${m}m',
    ),
  );

  late MockHttpServerConnector mockConnector;
  late ServerState? currentServerState;
  late RefenaContainer container;
  late ReceiveController controller;

  void setupEnvironment({
    bool quickSave = false,
    bool quickSaveFromFavorites = false,
    String? destination,
    List<FavoriteDevice>? favorites,
  }) {
    mockConnector = MockHttpServerConnector();
    final parentState = _createParentState(mockConnector);
    final isolateController = IsolateController(initialState: parentState);

    final settings = _createSettings(
      quickSave: quickSave,
      quickSaveFromFavorites: quickSaveFromFavorites,
      destination: destination,
    );

    container = RefenaContainer(
      overrides: [
        parentIsolateProvider.overrideWithNotifier((ref) => isolateController),
        settingsProvider.overrideWithNotifier((ref) => FakeSettingsService(settings)),
        favoritesProvider.overrideWithNotifier((ref) => FakeFavoritesService(favorites ?? [])),
        deviceRawInfoProvider.overrideWithValue(
          DeviceInfoResult(
            deviceType: DeviceType.desktop,
            deviceModel: 'PC',
            androidSdkInt: null,
          ),
        ),
      ],
    );

    currentServerState = const ServerState(
      alias: 'Test Server',
      port: 53317,
      https: true,
      session: null,
      web: null,
    );

    final serverUtils = ServerUtils(
      refFunc: () => container,
      getState: () => currentServerState!,
      getStateOrNull: () => currentServerState,
      setState: (builder) {
        currentServerState = builder(currentServerState);
      },
    );

    controller = ReceiveController(serverUtils);
  }

  testWidgets('V3 transfer with quickSave=false stays in waiting status until user explicitly accepts', (tester) async {
    setupEnvironment(quickSave: false, quickSaveFromFavorites: false);

    Routerino.navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          navigatorKey: Routerino.navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    final event = HttpServerPrepareUploadV3Event(
      sessionId: 'session-123',
      ip: '192.168.1.50',
      fileName: 'secure_file.bin',
      fileSize: 1048576,
      totalChunks: 2,
      chunkSize: 524288,
      certFingerprint: 'SENDER_FP',
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(event);
    });
    await tester.pump();

    // Verification 1: Session is created in waiting status
    final session = currentServerState?.session;
    expect(session, isNotNull);
    expect(session!.status, SessionStatus.waiting);
    expect(controller.pendingV3SessionId, 'session-123');

    // Verification 2: Gate A Security Check - NO decision sent yet!
    expect(mockConnector.sentTasks, isEmpty, reason: 'Must NOT auto-accept when quickSave=false');

    // User explicitly approves file via interactive accept
    await tester.runAsync(() async {
      await controller.acceptFileRequest({'session-123': 'secure_file.bin'});
    });
    await tester.pump();

    // Verification 3: Decision sent with accept: true and valid destination path
    expect(mockConnector.sentTasks.length, 1);
    final decision = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision.sessionId, 'session-123');
    expect(decision.accept, isTrue);
    expect(decision.destinationPath, 'C:/locara_downloads/secure_file.bin');
    expect(controller.pendingV3SessionId, isNull);
  }, timeout: const Timeout(Duration(seconds: 5)));

  testWidgets('V3 transfer declined by user dispatches accept=false and closes session', (tester) async {
    setupEnvironment(quickSave: false, quickSaveFromFavorites: false);

    Routerino.navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          navigatorKey: Routerino.navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    final event = HttpServerPrepareUploadV3Event(
      sessionId: 'session-decline',
      ip: '192.168.1.51',
      fileName: 'declined_file.bin',
      fileSize: 2048,
      totalChunks: 1,
      chunkSize: 2048,
      certFingerprint: 'SENDER_FP_2',
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(event);
    });
    await tester.pump();

    expect(controller.pendingV3SessionId, 'session-decline');

    // User explicitly declines
    controller.declineFileRequest();
    await tester.pump();

    expect(mockConnector.sentTasks.length, 1);
    final decision = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision.sessionId, 'session-decline');
    expect(decision.accept, isFalse);
    expect(currentServerState?.session, isNull);
    expect(controller.pendingV3SessionId, isNull);
  }, timeout: const Timeout(Duration(seconds: 5)));

  testWidgets('V3 transfer closed or dismissed while waiting dispatches accept=false', (tester) async {
    setupEnvironment(quickSave: false, quickSaveFromFavorites: false);

    Routerino.navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          navigatorKey: Routerino.navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    final event = HttpServerPrepareUploadV3Event(
      sessionId: 'session-dismiss',
      ip: '192.168.1.52',
      fileName: 'dismissed_file.bin',
      fileSize: 4096,
      totalChunks: 1,
      chunkSize: 4096,
      certFingerprint: 'SENDER_FP_3',
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(event);
    });
    await tester.pump();

    // Closing the session (e.g. navigation away or window close)
    controller.closeSession();
    await tester.pump();

    expect(mockConnector.sentTasks.length, 1);
    final decision = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision.sessionId, 'session-dismiss');
    expect(decision.accept, isFalse);
    expect(controller.pendingV3SessionId, isNull);
  }, timeout: const Timeout(Duration(seconds: 5)));

  testWidgets('V3 transfer with quickSave=true auto-accepts immediately', (tester) async {
    setupEnvironment(quickSave: true, quickSaveFromFavorites: false);

    Routerino.navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          navigatorKey: Routerino.navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    final event = HttpServerPrepareUploadV3Event(
      sessionId: 'session-quicksave',
      ip: '192.168.1.53',
      fileName: 'auto_file.bin',
      fileSize: 8192,
      totalChunks: 1,
      chunkSize: 8192,
      certFingerprint: 'SENDER_FP_4',
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(event);
    });
    await tester.pump();

    expect(mockConnector.sentTasks.length, 1);
    final decision = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision.sessionId, 'session-quicksave');
    expect(decision.accept, isTrue);
    expect(decision.destinationPath, 'C:/locara_downloads/auto_file.bin');
    expect(controller.pendingV3SessionId, isNull);
  }, timeout: const Timeout(Duration(seconds: 5)));

  testWidgets('V3 transfer with quickSaveFromFavorites auto-accepts only recognized favorites', (tester) async {
    setupEnvironment(
      quickSave: false,
      quickSaveFromFavorites: true,
      favorites: [
        const FavoriteDevice(
          id: 'fav-1',
          fingerprint: 'TRUSTED_FP',
          ip: '192.168.1.60',
          port: 53317,
          alias: 'Trusted Friend',
        ),
      ],
    );

    Routerino.navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          navigatorKey: Routerino.navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    // Subtest A: Untrusted sender -> MUST stay in waiting state
    final untrustedEvent = HttpServerPrepareUploadV3Event(
      sessionId: 'session-untrusted',
      ip: '192.168.1.70',
      fileName: 'untrusted.bin',
      fileSize: 1024,
      totalChunks: 1,
      chunkSize: 1024,
      certFingerprint: 'UNTRUSTED_FP',
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(untrustedEvent);
    });
    await tester.pump();

    expect(mockConnector.sentTasks, isEmpty, reason: 'Untrusted sender must NOT be auto-accepted');
    expect(controller.pendingV3SessionId, 'session-untrusted');
    expect(currentServerState?.session?.status, SessionStatus.waiting);

    // Clean up untrusted session
    controller.closeSession();
    await tester.pump();
    mockConnector.sentTasks.clear();

    // Subtest B: Trusted favorite sender -> auto-accepted
    final trustedEvent = HttpServerPrepareUploadV3Event(
      sessionId: 'session-trusted',
      ip: '192.168.1.60',
      fileName: 'trusted.bin',
      fileSize: 1024,
      totalChunks: 1,
      chunkSize: 1024,
      certFingerprint: 'TRUSTED_FP',
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(trustedEvent);
    });
    await tester.pump();

    expect(mockConnector.sentTasks.length, 1);
    final decision = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision.sessionId, 'session-trusted');
    expect(decision.accept, isTrue);
  }, timeout: const Timeout(Duration(seconds: 5)));

  testWidgets('V3 transfer explicitly rejects Android SAF and SD card destination paths', (tester) async {
    // Subtest A: content:// URI
    setupEnvironment(
      quickSave: true,
      destination: 'content://com.android.externalstorage.documents/tree/primary%3ADocuments',
    );

    Routerino.navigatorKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          navigatorKey: Routerino.navigatorKey,
          home: const Scaffold(body: Text('Home')),
        ),
      ),
    );

    final event1 = HttpServerPrepareUploadV3Event(
      sessionId: 'session-saf-1',
      ip: '192.168.1.80',
      fileName: 'saf1.bin',
      fileSize: 1024,
      totalChunks: 1,
      chunkSize: 1024,
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(event1);
    });
    await tester.pump();

    expect(mockConnector.sentTasks.length, 1);
    final decision1 = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision1.sessionId, 'session-saf-1');
    expect(decision1.accept, isFalse, reason: 'content:// URIs must be immediately rejected with accept=false');
    expect(currentServerState?.session, isNull);

    // Subtest B: /storage/XXXX-XXXX/ SD card path
    setupEnvironment(
      quickSave: true,
      destination: '/storage/1234-5678/Downloads',
    );

    final event2 = HttpServerPrepareUploadV3Event(
      sessionId: 'session-saf-2',
      ip: '192.168.1.81',
      fileName: 'saf2.bin',
      fileSize: 1024,
      totalChunks: 1,
      chunkSize: 1024,
    );

    await tester.runAsync(() async {
      await controller.onPrepareUploadV3(event2);
    });
    await tester.pump();

    expect(mockConnector.sentTasks.length, 1);
    final decision2 = mockConnector.sentTasks.first as HttpServerPrepareUploadV3DecisionTask;
    expect(decision2.sessionId, 'session-saf-2');
    expect(decision2.accept, isFalse, reason: 'SD card paths requiring SAF must be immediately rejected with accept=false');
    expect(currentServerState?.session, isNull);
  }, timeout: const Timeout(Duration(seconds: 5)));
}
