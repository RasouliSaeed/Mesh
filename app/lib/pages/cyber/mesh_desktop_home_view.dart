import 'dart:async';
import 'package:flutter/material.dart';
import 'package:locara_app/gen/assets.gen.dart';
import 'package:locara_app/pages/changelog_page.dart';
import 'package:locara_app/pages/chat_page.dart';
import 'package:locara_app/pages/tabs/receive_tab.dart';
import 'package:locara_app/pages/tabs/send_tab.dart';
import 'package:locara_app/pages/tabs/settings_tab.dart';
import 'package:locara_app/provider/clipboard_provider.dart';
import 'package:locara_app/provider/local_ip_provider.dart';
import 'package:locara_app/provider/network/nearby_devices_provider.dart';
import 'package:locara_app/provider/network/scan_facade.dart';
import 'package:locara_app/provider/network/server/server_provider.dart';
import 'package:locara_app/provider/receive_history_provider.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/widget/cyber/mesh_discovery_card.dart';
import 'package:locara_app/widget/cyber/mesh_stage_widget.dart';
import 'package:locara_app/widget/cyber/mesh_stats_bar.dart';
import 'package:locara_app/widget/design/mesh_glass_card.dart';
import 'package:locara_isolates/isolate.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

enum DesktopNavTab {
  home(Icons.home_rounded, 'خانه'),
  devices(Icons.devices_rounded, 'دستگاه‌ها'),
  files(Icons.folder_open_rounded, 'فایل‌ها'),
  messages(Icons.chat_bubble_outline_rounded, 'پیام‌های محلی'),
  settings(Icons.settings_outlined, 'تنظیمات'),
  about(Icons.info_outline_rounded, 'درباره');

  final IconData icon;
  final String label;

  const DesktopNavTab(this.icon, this.label);
}

class LocaraDesktopHomeView extends StatefulWidget {
  final int historyCount;
  final DesktopNavTab initialTab;
  final VoidCallback? onScanToggled;

  const LocaraDesktopHomeView({
    this.historyCount = 248,
    this.initialTab = DesktopNavTab.home,
    this.onScanToggled,
    super.key,
  });

  @override
  State<LocaraDesktopHomeView> createState() => _LocaraDesktopHomeViewState();
}

class _LocaraDesktopHomeViewState extends State<LocaraDesktopHomeView> {
  late DesktopNavTab _selectedTab;

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.initialTab;
  }

  void switchTab(DesktopNavTab tab) {
    if (tab == DesktopNavTab.about) {
      unawaited(context.push(() => const ChangelogPage()));
      return;
    }
    setState(() {
      _selectedTab = tab;
    });
  }

  @override
  Widget build(BuildContext context) {
    final serverState = context.watch(serverProvider);
    final isServerRunning = serverState != null;
    final localIps = context.watch(localIpProvider).localIps;
    final activeIp = localIps.isNotEmpty ? localIps.first : '127.0.0.1';
    final deviceCount = context.watch(nearbyDevicesProvider).devices.length;
    final historyList = context.watch(receiveHistoryProvider);
    final effectiveHistoryCount = historyList.isNotEmpty ? historyList.length : widget.historyCount;

    return Container(
      decoration: const BoxDecoration(
        gradient: LocaraDesignTokens.backgroundGradient,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Row(
          children: [
            // Sidebar positioned at start (Right in RTL, Left in LTR)
            _buildSidebar(activeIp: activeIp),

            // Main Content Area
            Expanded(
              child: _buildMainContent(
                isServerRunning: isServerRunning,
                deviceCount: deviceCount,
                historyCount: effectiveHistoryCount,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSidebar({required String activeIp}) {
    return Container(
      width: 260,
      margin: const EdgeInsetsDirectional.all(LocaraDesignTokens.spacing16),
      decoration: LocaraCyberTheme.glassCardDecoration(
        borderRadius: 28,
        borderColor: LocaraDesignTokens.cardBorderSubtle,
        fillColor: LocaraDesignTokens.darkNavy.withValues(alpha: 0.9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: LocaraDesignTokens.spacing24),
          // Brand Block: Glowing Logo + Title + Subtitle
          Center(
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LocaraDesignTokens.cyan.withValues(alpha: 0.4),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Assets.img.logo128.image(
                    width: 60,
                    height: 60,
                  ),
                ),
                const SizedBox(height: LocaraDesignTokens.spacing12),
                const Text(
                  'Mesh',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                const Text(
                  'Nearby. Instant. Private',
                  style: TextStyle(
                    color: LocaraDesignTokens.secondaryText,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: LocaraDesignTokens.spacing24),

          // Navigation Menu Items
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ListView(
                physics: const NeverScrollableScrollPhysics(),
                children: DesktopNavTab.values.map((tab) {
                  final isActive = _selectedTab == tab;
                  return _buildNavItem(tab, isActive);
                }).toList(),
              ),
            ),
          ),

          // Bottom Sidebar Status Footer
          _buildSidebarFooter(activeIp: activeIp),
        ],
      ),
    );
  }

  Widget _buildNavItem(DesktopNavTab tab, bool isActive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: () => switchTab(tab),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isActive ? LocaraDesignTokens.primaryBlue : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: LocaraDesignTokens.primaryBlue.withValues(alpha: 0.45),
                      blurRadius: 14,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Icon(
                tab.icon,
                color: isActive ? Colors.white : LocaraDesignTokens.secondaryText,
                size: 20,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? Colors.white : LocaraDesignTokens.secondaryText,
                    fontSize: 14,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSidebarFooter({required String activeIp}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(
            color: Color(0x2212D8E8),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Mesh v1.8.0',
            style: TextStyle(
              color: LocaraDesignTokens.mutedText,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: LocaraDesignTokens.success,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: LocaraDesignTokens.success,
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    activeIp != '127.0.0.1' ? activeIp : 'شبکه محلی • آماده',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: LocaraDesignTokens.secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(
                  Icons.signal_cellular_alt_rounded,
                  color: LocaraDesignTokens.secondaryText,
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent({
    required bool isServerRunning,
    required int deviceCount,
    required int historyCount,
  }) {
    switch (_selectedTab) {
      case DesktopNavTab.home:
        return _buildCyberDashboard(
          isServerRunning: isServerRunning,
          deviceCount: deviceCount,
          historyCount: historyCount,
        );
      case DesktopNavTab.devices:
        return _buildPaddedView(const SendTab());
      case DesktopNavTab.files:
        return _buildPaddedView(const ReceiveTab());
      case DesktopNavTab.messages:
        return _buildPaddedView(const ChatPage());
      case DesktopNavTab.settings:
        return _buildPaddedView(const SettingsTab());
      case DesktopNavTab.about:
        return _buildCyberDashboard(
          isServerRunning: isServerRunning,
          deviceCount: deviceCount,
          historyCount: historyCount,
        );
    }
  }

  Widget _buildPaddedView(Widget child) {
    return Container(
      margin: const EdgeInsetsDirectional.only(
        top: LocaraDesignTokens.spacing16,
        bottom: LocaraDesignTokens.spacing16,
        end: LocaraDesignTokens.spacing16,
      ),
      decoration: LocaraCyberTheme.glassCardDecoration(
        borderRadius: 28,
        borderColor: LocaraDesignTokens.cardBorderSubtle,
        fillColor: LocaraDesignTokens.cardSurface.withValues(alpha: 0.85),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: child,
      ),
    );
  }

  Widget _buildCyberDashboard({
    required bool isServerRunning,
    required int deviceCount,
    required int historyCount,
  }) {
    return Container(
      margin: const EdgeInsetsDirectional.only(
        top: LocaraDesignTokens.spacing16,
        bottom: LocaraDesignTokens.spacing16,
        end: LocaraDesignTokens.spacing16,
      ),
      padding: EdgeInsets.all(LocaraDesignTokens.spacing28),
      decoration: LocaraCyberTheme.glassCardDecoration(
        borderRadius: 28,
        borderColor: LocaraDesignTokens.cardBorderSubtle,
        fillColor: LocaraDesignTokens.deepNavy.withValues(alpha: 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Top Header Bar: Title, Subtitle, and "آماده به کار" badge
          _buildHeaderBar(isServerRunning: isServerRunning),

          const Spacer(),

          // 2. Center 3D Stage with Connected Devices
          LocaraStageWidget(
            isDesktop: true,
            availableDevicesCount: deviceCount,
          ),

          const Spacer(),

          // 3. Active Discovery / Search Status Card
          LocaraDiscoveryCard(
            onToggleScan: () {
              if (widget.onScanToggled != null) {
                widget.onScanToggled!();
                return;
              }
              try {
                context.ref.redux(parentIsolateProvider).dispatch(IsolateDiscoveryRestartAction());
              } catch (_) {}
              try {
                unawaited(context.ref.global.dispatchAsync(StartSmartScan()));
              } catch (_) {}
            },
          ),

          const SizedBox(height: LocaraDesignTokens.spacing20),

          // 4. Bottom Stats Bar (4 capsules)
          LocaraStatsBar(
            isDesktop: true,
            transferredFilesCount: historyCount,
            successRate: '۹۸٪',
            speedText: '۱۲.۵ MB/s',
            elapsedTime: '۰۰:۰۱:۲۳',
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar({required bool isServerRunning}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and Subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                  children: [
                    TextSpan(text: 'به '),
                    TextSpan(
                      text: 'مش',
                      style: TextStyle(
                        color: LocaraDesignTokens.cyan,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    TextSpan(text: ' خوش آمدید'),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'انتقال سریع و امن فایل بین دستگاه‌های نزدیک',
                style: TextStyle(
                  color: LocaraDesignTokens.secondaryText,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Clipboard Sync Button
            LocaraGlassCard(
              onTap: () async {
                final devices = context.read(nearbyDevicesProvider).devices.values.toList();
                if (devices.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('دستگاهی در شبکه محلی یافت نشد.'),
                      backgroundColor: LocaraDesignTokens.darkNavy,
                    ),
                  );
                  return;
                }
                final target = devices.first;
                await ClipboardSyncService.sendClipboard(
                  context: context,
                  target: target,
                );
              },
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              borderColor: LocaraDesignTokens.cyan.withValues(alpha: 0.4),
              fillColor: LocaraDesignTokens.cardSurface.withValues(alpha: 0.85),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.content_paste_go_rounded,
                    size: 16,
                    color: LocaraDesignTokens.cyan,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'همگام‌سازی کلیپ‌بورد',
                    style: LocaraDesignTokens.bodySmall.copyWith(
                      color: LocaraDesignTokens.primaryText,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),

            // Status Badge: "آماده به کار" or "متوقف" with pulsing dot
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: LocaraDesignTokens.cardSurface.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isServerRunning ? LocaraDesignTokens.success.withValues(alpha: 0.3) : LocaraDesignTokens.warning.withValues(alpha: 0.3),
                  width: 1.2,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isServerRunning ? LocaraDesignTokens.success : LocaraDesignTokens.warning,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isServerRunning ? LocaraDesignTokens.success : LocaraDesignTokens.warning,
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isServerRunning ? 'آماده به کار' : 'متوقف',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Backward compatibility and rebranding alias
typedef MeshDesktopHomeView = LocaraDesktopHomeView;
