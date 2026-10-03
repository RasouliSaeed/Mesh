import 'package:flutter/material.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/pages/home_page.dart';
import 'package:locara_app/pages/home_page_controller.dart';
import 'package:locara_app/pages/receive_history_page.dart';
import 'package:locara_app/pages/web_share_page.dart';
import 'package:locara_app/provider/animation_provider.dart';
import 'package:locara_app/provider/network/server/server_provider.dart';
import 'package:locara_app/provider/local_ip_provider.dart';
import 'package:locara_app/provider/settings_provider.dart';
import 'package:locara_app/widget/animations/initial_fade_transition.dart';
import 'package:locara_app/widget/custom_icon_button.dart';
import 'package:locara_app/widget/locara_logo.dart';
import 'package:refena_flutter/addons.dart';
import 'package:refena_flutter/refena_flutter.dart';
import 'package:routerino/routerino.dart';

class ReceiveTab extends StatefulWidget {
  const ReceiveTab({super.key});

  @override
  State<ReceiveTab> createState() => _ReceiveTabState();
}

class _ReceiveTabState extends State<ReceiveTab> with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final alias = context.watch(settingsProvider.select((s) => s.alias));
    final serverState = context.watch(serverProvider);
    final localIps = context.watch(localIpProvider.select((s) => s.localIps));
    final animations = context.watch(animationProvider);
    final activeTab = context.watch(homePageControllerProvider.select((state) => state.currentTab));
    final isScanning = serverState != null && animations && activeTab == HomeTab.receive;

    final colorScheme = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Radar / Device Centerpiece
              SizedBox(
                width: 320,
                height: 320,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    if (isScanning) ...[
                      // Outer Pulse Ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 200 + (_pulseController.value * 120),
                            height: 200 + (_pulseController.value * 120),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.1 * (1 - _pulseController.value)),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                      // Inner Pulse Ring
                      AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          return Container(
                            width: 160 + (_pulseController.value * 60),
                            height: 160 + (_pulseController.value * 60),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: colorScheme.primary.withValues(alpha: 0.2 * (1 - _pulseController.value)),
                                width: 2,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                    // Central Glow
                    Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.2),
                            blurRadius: 30,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Center(
                        child: const LocaraLogo(withText: false),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Device Name
              InitialFadeTransition(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 200),
                child: Text(
                  serverState?.alias ?? alias,
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 12),

              // Status Indicator (Pill)
              InitialFadeTransition(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 400),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      decoration: BoxDecoration(
                        color: serverState == null ? colorScheme.error.withValues(alpha: 0.1) : colorScheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: serverState == null ? colorScheme.error.withValues(alpha: 0.3) : colorScheme.primary.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: serverState == null ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            serverState == null ? t.general.offline : "Ready to receive",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: serverState == null ? colorScheme.error : colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    // E2E Encryption Badge
                    Tooltip(
                      message: 'End-to-End Encrypted (TLS 1.3)',
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF16A36A).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFF16A36A).withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.lock_outline, size: 16, color: Color(0xFF16A36A)),
                            const SizedBox(width: 8),
                            const Text(
                              "Secured",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF16A36A),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // IP Addresses
              if (serverState != null)
                InitialFadeTransition(
                  duration: const Duration(milliseconds: 300),
                  delay: const Duration(milliseconds: 500),
                  child: Text(
                    localIps.map((ip) => '#').toSet().join('  •  '),
                    style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                    textAlign: TextAlign.center,
                  ),
                ),

              const SizedBox(height: 40),

              // Link Button
              InitialFadeTransition(
                duration: const Duration(milliseconds: 300),
                delay: const Duration(milliseconds: 600),
                child: TextButton.icon(
                  onPressed: () async {
                    await context.global.dispatchAsync(NavigateAction.push(const WebSharePage()));
                  },
                  icon: const Icon(Icons.language),
                  label: Text(t.receiveTab.link),
                  style: TextButton.styleFrom(
                    foregroundColor: colorScheme.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    backgroundColor: colorScheme.primary.withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Top Right Actions
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                CustomIconButton(
                  onPressed: () async {
                    await context.push(() => const ReceiveHistoryPage());
                  },
                  child: Icon(Icons.history, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
