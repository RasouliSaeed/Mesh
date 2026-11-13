import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:locara_app/model/persistence/color_mode.dart';
import 'package:locara_app/model/persistence/favorite_device.dart';
import 'package:locara_app/model/persistence/receive_history_entry.dart';
import 'package:locara_app/model/recovery/recoverable_transfer.dart';
import 'package:locara_app/model/send_mode.dart';
import 'package:locara_app/model/state/nearby_devices_state.dart';
import 'package:locara_app/model/state/send/send_session_state.dart';
import 'package:locara_app/model/state/settings_state.dart';
import 'package:locara_app/pages/receive_history_page.dart';
import 'package:locara_app/provider/favorites_provider.dart';
import 'package:locara_app/provider/logging/discovery_logs_provider.dart';
import 'package:locara_app/provider/network/nearby_devices_provider.dart';
import 'package:locara_app/provider/network/send_provider.dart';
import 'package:locara_app/provider/persistence_provider.dart';
import 'package:locara_app/provider/receive_history_provider.dart';
import 'package:locara_app/provider/recovery_contract_provider.dart';
import 'package:locara_app/provider/settings_provider.dart';
import 'package:locara_app/widget/recovery_list.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/model/device_info_result.dart';
import 'package:locara_isolates/model/dto/multicast_dto.dart';
import 'package:locara_isolates/model/file_type.dart';
import 'package:locara_isolates/model/stored_security_context.dart';
import 'package:refena_flutter/refena_flutter.dart';

class FakePersistenceService extends Fake implements PersistenceService {
  @override
  List<FavoriteDevice> getFavorites() => [];

  @override
  List<ReceiveHistoryEntry> getReceiveHistory() => [];
}

class FakeReceiveHistoryService extends ReceiveHistoryService {
  final List<ReceiveHistoryEntry> initial;
  FakeReceiveHistoryService([this.initial = const []]) : super(FakePersistenceService());

  @override
  List<ReceiveHistoryEntry> init() => initial;
}

class FakeSettingsService extends SettingsService {
  final SettingsState initial;
  FakeSettingsService(this.initial) : super(FakePersistenceService());

  @override
  SettingsState init() => initial;
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

class FakeRecoveryContractService extends RecoveryContractService {
  final List<RecoverableTransfer> initial;
  final List<String> prunedTransferIds = [];

  FakeRecoveryContractService(this.initial);

  @override
  Future<List<RecoverableTransfer>> init() async => initial;

  @override
  Future<void> pruneTransfer({
    required String transferId,
    required RecoverableTransferDirection direction,
  }) async {
    prunedTransferIds.add(transferId);
    await setState((snap) async => (snap.curr ?? []).where((t) => t.transferId != transferId).toList());
  }
}

class FakeSendNotifier extends SendNotifier {
  final List<String> resumedTransferIds = [];
  final Set<String> _resuming = {};

  void setResuming(String transferId, bool resuming) {
    if (resuming) {
      _resuming.add(transferId);
    } else {
      _resuming.remove(transferId);
    }
  }

  @override
  Map<String, SendSessionState> init() => {};

  @override
  bool isTransferResuming(String transferId) => _resuming.contains(transferId);

  @override
  Future<bool> resumeTransfer(String transferId) async {
    resumedTransferIds.add(transferId);
    return true;
  }
}

ParentIsolateState _createParentState() {
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
    httpServer: null,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting();
  });

  late IsolateController isolateController;
  late FakeSendNotifier fakeSendNotifier;

  setUp(() {
    isolateController = IsolateController(initialState: _createParentState());
    fakeSendNotifier = FakeSendNotifier();
  });

  Widget buildTestWidget({
    required List<RecoverableTransfer> transfers,
    NearbyDevicesState nearbyState = const NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: {},
      devices: {},
      signalingDevices: {},
    ),
    required FakeRecoveryContractService recoveryService,
  }) {
    final container = RefenaContainer(
      overrides: [
        parentIsolateProvider.overrideWithNotifier((ref) => isolateController),
        recoveryContractProvider.overrideWithNotifier((ref) => recoveryService),
        sendProvider.overrideWithNotifier((ref) => fakeSendNotifier),
        nearbyDevicesProvider.overrideWithNotifier(
          (ref) => FakeNearbyDevicesService(nearbyState, isolateController),
        ),
      ],
    );

    return RefenaScope.withContainer(
      container: container,
      child: const MaterialApp(
        home: Scaffold(
          body: RecoveryList(),
        ),
      ),
    );
  }

  testWidgets('RecoveryList renders nothing when transfers list is empty', (tester) async {
    final recoveryService = FakeRecoveryContractService([]);
    await tester.pumpWidget(
      buildTestWidget(transfers: [], recoveryService: recoveryService),
    );
    await tester.pumpAndSettle();

    expect(find.text('Interrupted Transfers'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('RecoveryList displays "Waiting for sender" and NO resume button for receiver transfer', (tester) async {
    final transfer = RecoverableTransfer(
      transferId: 'receiver_transfer_1',
      direction: RecoverableTransferDirection.receive,
      fileName: 'inbound_file.iso',
      fileSize: 10485760,
      bytesTransferred: 5242880,
      progress: 0.5,
      peerFingerprint: 'SENDER_FINGERPRINT_123',
      isResumable: true,
      unresumableReason: null,
      lastUpdated: DateTime.now().toUtc(),
    );

    final recoveryService = FakeRecoveryContractService([transfer]);
    await tester.pumpWidget(
      buildTestWidget(transfers: [transfer], recoveryService: recoveryService),
    );
    await tester.pumpAndSettle();

    expect(find.text('Interrupted Transfers'), findsOneWidget);
    expect(find.text('inbound_file.iso'), findsOneWidget);
    expect(find.text('Waiting for sender'), findsOneWidget);
    expect(find.text('Inbound transfer awaiting sender reconnection.'), findsOneWidget);

    // CRITICAL: Receiver-initiated pull is not possible in V3 push protocol; no fake Resume button!
    expect(find.widgetWithText(ElevatedButton, 'Resume'), findsNothing);
    // Discard button must be present
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('RecoveryList displays "Not Resumable" and specific reason for broken sender transfer', (tester) async {
    final transfer = RecoverableTransfer(
      transferId: 'broken_sender_tx',
      direction: RecoverableTransferDirection.send,
      fileName: 'deleted_source.mp4',
      fileSize: 20000000,
      bytesTransferred: 5000000,
      progress: 0.25,
      peerAlias: 'Laptop',
      peerFingerprint: 'FP_PEER_456',
      isResumable: false,
      unresumableReason: 'Source file missing or modified on disk',
      lastUpdated: DateTime.now().toUtc(),
    );

    final recoveryService = FakeRecoveryContractService([transfer]);
    await tester.pumpWidget(
      buildTestWidget(transfers: [transfer], recoveryService: recoveryService),
    );
    await tester.pumpAndSettle();

    expect(find.text('deleted_source.mp4'), findsOneWidget);
    expect(find.text('Not Resumable'), findsOneWidget);
    expect(find.text('Source file missing or modified on disk'), findsOneWidget);

    // Cannot resume an unresumable transfer
    expect(find.widgetWithText(ElevatedButton, 'Resume'), findsNothing);
    expect(find.byIcon(Icons.delete_outline), findsOneWidget);
  });

  testWidgets('RecoveryList displays "Ready to resume" and active Resume button when peer is online', (tester) async {
    const onlinePeer = Device(
      signalingId: null,
      ip: '192.168.1.150',
      version: '3.0',
      port: 53317,
      https: true,
      fingerprint: 'PEER_FP_REACHABLE',
      alias: 'Desktop PC',
      deviceModel: 'Linux',
      deviceType: DeviceType.desktop,
      download: true,
      channels: [],
    );

    final transfer = RecoverableTransfer(
      transferId: 'resumable_sender_tx',
      direction: RecoverableTransferDirection.send,
      fileName: 'dataset.zip',
      fileSize: 100000000,
      bytesTransferred: 40000000,
      progress: 0.4,
      peerAlias: 'Desktop PC',
      peerFingerprint: 'PEER_FP_REACHABLE',
      localPath: '/path/to/dataset.zip',
      isResumable: true,
      unresumableReason: null,
      lastUpdated: DateTime.now().toUtc(),
    );

    final recoveryService = FakeRecoveryContractService([transfer]);
    await tester.pumpWidget(
      buildTestWidget(
        transfers: [transfer],
        nearbyState: const NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: {},
          devices: {'PEER_FP_REACHABLE': onlinePeer},
          signalingDevices: {},
        ),
        recoveryService: recoveryService,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('dataset.zip'), findsOneWidget);
    expect(find.text('Ready to resume'), findsOneWidget);

    final resumeButton = find.widgetWithText(ElevatedButton, 'Resume');
    expect(resumeButton, findsOneWidget);

    // Tap Resume button and verify invocation
    await tester.tap(resumeButton);
    await tester.pumpAndSettle();

    expect(fakeSendNotifier.resumedTransferIds, contains('resumable_sender_tx'));
  });

  testWidgets('RecoveryList allows discarding a session with confirmation dialog', (tester) async {
    final transfer = RecoverableTransfer(
      transferId: 'discard_target_tx',
      direction: RecoverableTransferDirection.send,
      fileName: 'stale_session.bin',
      fileSize: 1000,
      bytesTransferred: 200,
      progress: 0.2,
      peerAlias: 'Phone',
      peerFingerprint: 'FP_DISCARD',
      isResumable: false,
      unresumableReason: 'Session expired',
      lastUpdated: DateTime.now().toUtc(),
    );

    final recoveryService = FakeRecoveryContractService([transfer]);
    await tester.pumpWidget(
      buildTestWidget(transfers: [transfer], recoveryService: recoveryService),
    );
    await tester.pumpAndSettle();

    final deleteButton = find.byIcon(Icons.delete_outline);
    expect(deleteButton, findsOneWidget);

    // Tap delete button to open confirmation dialog
    await tester.tap(deleteButton);
    await tester.pumpAndSettle();

    expect(find.text('Discard Transfer Session?'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Discard'), findsOneWidget);

    // Tap Discard in dialog
    await tester.tap(find.widgetWithText(FilledButton, 'Discard'));
    await tester.pumpAndSettle();

    expect(recoveryService.prunedTransferIds, contains('discard_target_tx'));
  });

  testWidgets('ReceiveHistoryPage embeds RecoveryList at the top of the history view', (tester) async {
    final transfer = RecoverableTransfer(
      transferId: 'history_embedded_tx',
      direction: RecoverableTransferDirection.send,
      fileName: 'embedded_recovery_doc.pdf',
      fileSize: 5000000,
      bytesTransferred: 2500000,
      progress: 0.5,
      peerAlias: 'Office PC',
      peerFingerprint: 'FP_OFFICE',
      isResumable: true,
      lastUpdated: DateTime.now().toUtc(),
    );

    final historyEntry = ReceiveHistoryEntry(
      id: 'entry_1',
      fileName: 'completed_file.txt',
      fileType: FileType.text,
      path: '/path/to/completed_file.txt',
      savedToGallery: false,
      isMessage: false,
      fileSize: 1024,
      senderAlias: 'Alice',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    );

    final recoveryService = FakeRecoveryContractService([transfer]);
    final settings = SettingsState(
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
      destination: 'C:/locara_downloads',
      saveToGallery: false,
      saveToHistory: false,
      quickSave: false,
      quickSaveFromFavorites: false,
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

    final container = RefenaContainer(
      overrides: [
        parentIsolateProvider.overrideWithNotifier((ref) => isolateController),
        recoveryContractProvider.overrideWithNotifier((ref) => recoveryService),
        sendProvider.overrideWithNotifier((ref) => fakeSendNotifier),
        nearbyDevicesProvider.overrideWithNotifier(
          (ref) => FakeNearbyDevicesService(
            const NearbyDevicesState(
              runningFavoriteScan: false,
              runningIps: {},
              devices: {},
              signalingDevices: {},
            ),
            isolateController,
          ),
        ),
        receiveHistoryProvider.overrideWithNotifier((ref) => FakeReceiveHistoryService([historyEntry])),
        settingsProvider.overrideWithNotifier((ref) => FakeSettingsService(settings)),
      ],
    );

    await tester.pumpWidget(
      RefenaScope.withContainer(
        container: container,
        child: MaterialApp(
          theme: ThemeData(
            inputDecorationTheme: const InputDecorationTheme(fillColor: Colors.grey),
          ),
          home: const ReceiveHistoryPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify both RecoveryList section and receive history entry are rendered
    expect(find.text('Interrupted Transfers'), findsOneWidget);
    expect(find.text('embedded_recovery_doc.pdf'), findsOneWidget);
    expect(find.text('completed_file.txt'), findsOneWidget);
  });
}
