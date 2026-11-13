import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:locara_app/model/persistence/color_mode.dart';
import 'package:locara_app/model/persistence/favorite_device.dart';
import 'package:locara_app/model/persistence/receive_history_entry.dart';
import 'package:locara_app/model/send_mode.dart';
import 'package:locara_app/model/state/nearby_devices_state.dart';
import 'package:locara_app/model/state/network_state.dart';
import 'package:locara_app/model/state/server/server_state.dart';
import 'package:locara_app/model/state/settings_state.dart';
import 'package:locara_app/pages/cyber/mesh_desktop_home_view.dart';
import 'package:locara_app/provider/chat_provider.dart';
import 'package:locara_app/provider/favorites_provider.dart';
import 'package:locara_app/provider/local_ip_provider.dart';
import 'package:locara_app/provider/logging/discovery_logs_provider.dart';
import 'package:locara_app/provider/network/nearby_devices_provider.dart';
import 'package:locara_app/provider/network/server/server_provider.dart';
import 'package:locara_app/provider/persistence_provider.dart';
import 'package:locara_app/provider/receive_history_provider.dart';
import 'package:locara_app/provider/settings_provider.dart';
import 'package:locara_app/widget/cyber/mesh_discovery_card.dart';
import 'package:locara_app/widget/cyber/mesh_radar_pulse.dart';
import 'package:locara_app/widget/cyber/mesh_stage_widget.dart';
import 'package:locara_app/widget/cyber/mesh_stats_bar.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:locara_isolates/model/device.dart';
import 'package:locara_isolates/model/device_info_result.dart';
import 'package:locara_isolates/model/dto/multicast_dto.dart';
import 'package:locara_isolates/model/file_type.dart';
import 'package:locara_isolates/model/stored_security_context.dart';
import 'package:refena_flutter/refena_flutter.dart';

// --- Fakes & Mocks ---

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

class FakeServerService extends ServerService {
  final ServerState? _initial;
  FakeServerService(this._initial);

  @override
  ServerState? init() => _initial;
}

class FakeLocalIpService extends LocalIpService {
  final NetworkState _initial;
  FakeLocalIpService(this._initial, SettingsService settingsService) : super(settingsService);

  @override
  NetworkState init() => _initial;

  @override
  get initialAction => null;
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
        deviceModel: 'Windows Test Host',
        androidSdkInt: null,
      ),
      alias: 'Windows-PC',
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

SettingsState _createSettings() {
  return SettingsState(
    showToken: 'test_token',
    alias: 'Windows-PC',
    theme: ThemeMode.dark,
    colorMode: ColorMode.system,
    customColor: Colors.blue,
    locale: null,
    port: 53317,
    networkWhitelist: null,
    networkBlacklist: null,
    multicastGroup: '224.0.0.167',
    destination: 'C:/LocaraDownloads',
    saveToGallery: false,
    saveToHistory: true,
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
    deviceModel: 'Windows 11',
    shareViaLinkAutoAccept: false,
    receiveViaLinkAutoAccept: false,
    createChecksums: true,
    verifyChecksums: true,
    discoveryTimeout: 2000,
    advancedSettings: false,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildDesktopTestApp({
    ServerState? serverState = const ServerState(
      alias: 'Windows-PC',
      port: 53317,
      https: true,
      session: null,
      web: null,
    ),
    NetworkState networkState = const NetworkState(
      localIps: ['192.168.1.150'],
      initialized: true,
    ),
    NearbyDevicesState nearbyState = const NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: {},
      devices: {},
      signalingDevices: {},
    ),
    List<ReceiveHistoryEntry> history = const [],
    DesktopNavTab initialTab = DesktopNavTab.home,
    TextDirection textDirection = TextDirection.rtl,
    VoidCallback? onScanToggled,
  }) {
    final isolateCtrl = IsolateController(initialState: _createParentState());
    final settingsCtrl = FakeSettingsService(_createSettings());

    final container = RefenaContainer(
      overrides: [
        parentIsolateProvider.overrideWithNotifier((ref) => isolateCtrl),
        settingsProvider.overrideWithNotifier((ref) => settingsCtrl),
        favoritesProvider.overrideWithNotifier((ref) => FakeFavoritesService()),
        serverProvider.overrideWithNotifier((ref) => FakeServerService(serverState)),
        localIpProvider.overrideWithNotifier((ref) => FakeLocalIpService(networkState, settingsCtrl)),
        nearbyDevicesProvider.overrideWithNotifier((ref) => FakeNearbyDevicesService(nearbyState, isolateCtrl)),
        receiveHistoryProvider.overrideWithNotifier((ref) => FakeReceiveHistoryService(history)),
        chatProvider.overrideWithNotifier((ref) => ChatNotifier()),
      ],
    );

    return RefenaScope.withContainer(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: Directionality(
          textDirection: textDirection,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(1280, 800)),
            child: LocaraDesktopHomeView(
              key: UniqueKey(),
              initialTab: initialTab,
              historyCount: history.length,
              onScanToggled: onScanToggled,
            ),
          ),
        ),
      ),
    );
  }

  group('Locara Windows Desktop UI Redesign - Verification Checklist Tests', () {
    testWidgets('1. Desktop Shell & Sidebar Checklist: brand header, 6 tabs, and footer status', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildDesktopTestApp());
      await tester.pump();

      // Verify brand header elements in Sidebar
      expect(find.text('Mesh'), findsOneWidget);
      expect(find.text('Nearby. Instant. Private'), findsOneWidget);

      // Verify all 6 navigation tabs exist
      expect(find.text('خانه'), findsOneWidget);
      expect(find.text('دستگاه‌ها'), findsOneWidget);
      expect(find.text('فایل‌ها'), findsOneWidget);
      expect(find.text('پیام‌های محلی'), findsOneWidget);
      expect(find.text('تنظیمات'), findsOneWidget);
      expect(find.text('درباره'), findsOneWidget);

      // Verify Tab icons
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.devices_rounded), findsOneWidget);
      expect(find.byIcon(Icons.folder_open_rounded), findsOneWidget);
      expect(find.byIcon(Icons.chat_bubble_outline_rounded), findsOneWidget);
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);

      // Verify Sidebar Footer: version and IP / network status
      expect(find.text('Mesh v1.8.0'), findsOneWidget);
      expect(find.text('192.168.1.150'), findsOneWidget);
      expect(find.byIcon(Icons.signal_cellular_alt_rounded), findsOneWidget);
    });

    testWidgets('2. RTL vs LTR Alignment: Sidebar properly placed at start', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Test RTL (Persian): Sidebar is on the right side of the screen
      await tester.pumpWidget(buildDesktopTestApp(textDirection: TextDirection.rtl));
      await tester.pump();

      final brandInRtl = tester.getTopLeft(find.text('Mesh'));
      // On 1280 width in RTL, the right sidebar text should have x > 900
      expect(brandInRtl.dx, greaterThan(900));

      // Test LTR (English): Sidebar is on the left side of the screen
      await tester.pumpWidget(buildDesktopTestApp(textDirection: TextDirection.ltr));
      await tester.pump();

      final brandInLtr = tester.getTopLeft(find.text('Mesh'));
      // On 1280 width in LTR, the left sidebar text should have x < 300
      expect(brandInLtr.dx, lessThan(300));
    });

    testWidgets('3a. Header Bar & Server Status Badge: Live Ready Badge when Server is Running', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildDesktopTestApp(
        serverState: const ServerState(
          alias: 'Windows-PC',
          port: 53317,
          https: true,
          session: null,
          web: null,
        ),
      ));
      await tester.pump();

      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('به مش خوش آمدید')), findsOneWidget);
      expect(find.text('انتقال سریع و امن فایل بین دستگاه‌های نزدیک'), findsOneWidget);
      expect(find.text('آماده به کار'), findsOneWidget);
    });

    testWidgets('3b. Header Bar & Server Status Badge: Stopped Badge when Server is Inactive', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildDesktopTestApp(serverState: null));
      await tester.pump();

      expect(find.text('متوقف'), findsOneWidget);
    });

    testWidgets('4a. 3D Stage Pedestal (Image 2 representation): Stage components with 0 devices', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildDesktopTestApp(
        nearbyState: const NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: {},
          devices: {},
          signalingDevices: {},
        ),
      ));
      await tester.pump();

      expect(find.byType(LocaraStageWidget), findsOneWidget);
      final stage0 = tester.widget<LocaraStageWidget>(find.byType(LocaraStageWidget));
      expect(stage0.availableDevicesCount, equals(0));
      expect(find.byIcon(Icons.laptop_chromebook_rounded), findsOneWidget);
      expect(find.byIcon(Icons.desktop_windows_rounded), findsOneWidget);
      expect(find.byIcon(Icons.wifi_rounded), findsOneWidget);
    });

    testWidgets('4b. 3D Stage Pedestal (Image 2 representation): Reflects 2 registered devices', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final device1 = Device(
        signalingId: null,
        ip: '192.168.1.101',
        version: '1.0',
        port: 53317,
        https: true,
        fingerprint: 'FP1',
        alias: 'Office-PC',
        deviceModel: 'PC',
        deviceType: DeviceType.desktop,
        download: false,
        channels: const [],
      );
      final device2 = Device(
        signalingId: null,
        ip: '192.168.1.102',
        version: '1.0',
        port: 53317,
        https: true,
        fingerprint: 'FP2',
        alias: 'Galaxy S24',
        deviceModel: 'Phone',
        deviceType: DeviceType.mobile,
        download: false,
        channels: const [],
      );

      await tester.pumpWidget(buildDesktopTestApp(
        nearbyState: NearbyDevicesState(
          runningFavoriteScan: false,
          runningIps: {},
          devices: {'FP1': device1, 'FP2': device2},
          signalingDevices: {},
        ),
      ));
      await tester.pump();

      final stage2 = tester.widget<LocaraStageWidget>(find.byType(LocaraStageWidget));
      expect(stage2.availableDevicesCount, equals(2));
    });

    testWidgets('5. Active Discovery Card & Radar Pulse Checklist: Scanning state & Action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      var scanToggled = false;

      await tester.pumpWidget(buildDesktopTestApp(
        onScanToggled: () {
          scanToggled = true;
        },
      ));
      await tester.pump();

      expect(find.byType(LocaraDiscoveryCard), findsOneWidget);
      expect(find.text('جستجوی دستگاه‌ها در شبکه...'), findsOneWidget);
      expect(find.text('در حال یافتن دستگاه‌های متصل به شبکه محلی'), findsOneWidget);

      // Verify LocaraRadarPulseWidget is mounted inside the card
      expect(find.byType(LocaraRadarPulseWidget), findsOneWidget);

      // Verify the stop/start button is present
      expect(find.text('توقف'), findsOneWidget);

      // Tap stop button to test interactive toggle
      await tester.tap(find.text('توقف'));
      await tester.pump();

      expect(scanToggled, isTrue);
      expect(find.text('شروع'), findsOneWidget);
    });

    testWidgets('6. Stats Bar (4 Capsules) on Desktop Checklist: Files, Rate, Speed, Elapsed Time', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final testHistory = [
        ReceiveHistoryEntry(
          id: 'test_1',
          fileName: 'video.mp4',
          fileType: FileType.video,
          path: '/path/video.mp4',
          savedToGallery: false,
          isMessage: false,
          fileSize: 1048576,
          senderAlias: 'Galaxy S24',
          timestamp: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(buildDesktopTestApp(history: testHistory));
      await tester.pump();

      expect(find.byType(LocaraStatsBar), findsOneWidget);

      // Capsule 1: Transferred Files
      expect(find.text('فایل منتقل شده'), findsOneWidget);
      expect(find.text('1'), findsOneWidget);

      // Capsule 2: Success Rate
      expect(find.text('موفقیت انتقال'), findsOneWidget);
      expect(find.text('۹۸٪'), findsOneWidget);

      // Capsule 3: Transfer Speed
      expect(find.text('سرعت انتقال'), findsOneWidget);
      expect(find.text('۱۲.۵ MB/s'), findsOneWidget);

      // Capsule 4: Elapsed Time (Desktop only)
      expect(find.text('زمان سپری شده'), findsOneWidget);
      expect(find.text('۰۰:۰۱:۲۳'), findsOneWidget);
    });

    testWidgets('7. Sidebar Interactive Navigation: Switch to Local Messages & Back to Home', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1280, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(buildDesktopTestApp());
      await tester.pump();

      // On Home tab, Stage is visible
      expect(find.byType(LocaraStageWidget), findsOneWidget);

      // Tap on "پیام‌های محلی" in Sidebar
      await tester.tap(find.text('پیام‌های محلی'));
      await tester.pump();

      // Should now show the ChatPage
      expect(find.text('گفتگوی محلی'), findsOneWidget);
      expect(find.byType(LocaraStageWidget), findsNothing);

      // Tap back on "خانه" in Sidebar
      await tester.tap(find.text('خانه'));
      await tester.pump();

      // Should return to Home Cyber Dashboard
      expect(find.byType(LocaraStageWidget), findsOneWidget);
    });
  });
}
