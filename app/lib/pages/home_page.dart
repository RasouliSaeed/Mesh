import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:locara_app/config/init.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/pages/cyber/mesh_desktop_home_view.dart';
import 'package:locara_app/pages/cyber/mesh_mobile_home_view.dart';
import 'package:locara_app/pages/home_page_controller.dart';
import 'package:locara_app/pages/tabs/receive_tab.dart';
import 'package:locara_app/pages/tabs/send_tab.dart';
import 'package:locara_app/pages/tabs/settings_tab.dart';
import 'package:locara_app/provider/network/nearby_devices_provider.dart';
import 'package:locara_app/provider/receive_history_provider.dart';
import 'package:locara_app/provider/selection/selected_sending_files_provider.dart';
import 'package:locara_app/theme/mesh_cyber_theme.dart';
import 'package:locara_app/theme/mesh_design_tokens.dart';
import 'package:locara_app/util/native/cross_file_converters.dart';
import 'package:locara_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  home(Icons.home_rounded),
  receive(Icons.wifi),
  send(Icons.send),
  settings(Icons.settings);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
      case HomeTab.home:
        return 'خانه';
      case HomeTab.receive:
        return t.receiveTab.title;
      case HomeTab.send:
        return t.sendTab.title;
      case HomeTab.settings:
        return t.settingsTab.title;
    }
  }
}

class HomePage extends StatefulWidget {
  final HomeTab initialTab;

  /// It is important for the initializing step
  /// because the first init clears the cache
  final bool appStart;

  const HomePage({
    required this.initialTab,
    required this.appStart,
    super.key,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with Refena {
  bool _dragAndDropIndicator = false;

  @override
  void initState() {
    super.initState();

    ensureRef((ref) async {
      ref.redux(homePageControllerProvider).dispatch(ChangeTabAction(widget.initialTab));
      await postInit(context, ref, widget.appStart);
    });
  }

  @override
  Widget build(BuildContext context) {
    Translations.of(context); // rebuild on locale change
    final vm = context.watch(homePageControllerProvider);
    final nearbyDevices = context.watch(nearbyDevicesProvider).devices.values.toList();
    final history = context.watch(receiveHistoryProvider);

    return DropTarget(
      onDragEntered: (_) {
        setState(() {
          _dragAndDropIndicator = true;
        });
      },
      onDragExited: (_) {
        setState(() {
          _dragAndDropIndicator = false;
        });
      },
      onDragDone: (event) async {
        // the drop may contain a mix of files and directories
        final droppedDirectories = event.files.where((file) => Directory(file.path).existsSync()).toList();
        final droppedFiles = event.files.where((file) => !Directory(file.path).existsSync()).toList();

        for (final directory in droppedDirectories) {
          await ref.redux(selectedSendingFilesProvider).dispatchAsync(AddDirectoryAction(directory.path));
        }

        if (droppedFiles.isNotEmpty) {
          await ref
              .redux(selectedSendingFilesProvider)
              .dispatchAsync(
                AddFilesAction(
                  files: droppedFiles,
                  converter: CrossFileConverters.convertXFile,
                ),
              );
        }
        vm.changeTab(HomeTab.send);
      },
      child: ResponsiveBuilder(
        builder: (sizingInformation) {
          if (sizingInformation.isDesktop) {
            // Desktop Experience (Windows, macOS, Linux) matching Image 2
            return Stack(
              children: [
                LocaraDesktopHomeView(
                  historyCount: history.length,
                ),
                if (_dragAndDropIndicator) _buildDropIndicator(),
              ],
            );
          }

          // Mobile Experience (Android, iOS) matching Image 1
          return Scaffold(
            backgroundColor: LocaraDesignTokens.deepNavy,
            extendBody: true,
            body: Stack(
              children: [
                PageView(
                  controller: vm.controller,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    // Tab 0: Home (Cyber Mobile Dashboard)
                    LocaraMobileHomeView(
                      nearbyDevices: nearbyDevices,
                      historyCount: history.length,
                      onSendFile: () => vm.changeTab(HomeTab.send),
                      onReceiveFile: () => vm.changeTab(HomeTab.receive),
                      onOpenSettings: () => vm.changeTab(HomeTab.settings),
                      onOpenHistory: () => vm.changeTab(HomeTab.receive),
                      onSeeAllDevices: () => vm.changeTab(HomeTab.send),
                      onSelectDevice: (device) {
                        vm.changeTab(HomeTab.send);
                      },
                    ),
                    // Tab 1: Receive (Transfers & Recovery)
                    const SafeArea(child: ReceiveTab()),
                    // Tab 2: Send (File Picker & Discovery)
                    const SafeArea(child: SendTab()),
                    // Tab 3: Settings
                    const SafeArea(child: SettingsTab()),
                  ],
                ),
                if (_dragAndDropIndicator) _buildDropIndicator(),
              ],
            ),
            bottomNavigationBar: _buildMobileBottomBar(vm),
          );
        },
      ),
    );
  }

  Widget _buildDropIndicator() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.85),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.file_download_rounded, size: 96, color: LocaraDesignTokens.cyan),
          const SizedBox(height: 24),
          Text(
            t.sendTab.placeItems,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(HomePageVm vm) {
    final currentTab = vm.currentTab;

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
      child: Container(
        height: 68,
        decoration: LocaraCyberTheme.glassCardDecoration(
          borderRadius: 28,
          borderColor: LocaraCyberColors.cardBorderSubtle,
          fillColor: const Color(0xFF09142A).withValues(alpha: 0.85),
          withGlow: true,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // 1. Settings (تنظیمات)
                _buildMobileNavItem(
                  icon: Icons.settings_outlined,
                  label: 'تنظیمات',
                  isActive: currentTab == HomeTab.settings,
                  onTap: () => vm.changeTab(HomeTab.settings),
                ),

                // 2. Home (خانه) with top cyan highlight pill
                _buildMobileNavItem(
                  icon: Icons.home_rounded,
                  label: 'خانه',
                  isActive: currentTab == HomeTab.home,
                  withTopPill: true,
                  onTap: () => vm.changeTab(HomeTab.home),
                ),

                // 3. History (تاریخچه)
                _buildMobileNavItem(
                  icon: Icons.access_time_rounded,
                  label: 'تاریخچه',
                  isActive: currentTab == HomeTab.receive,
                  onTap: () => vm.changeTab(HomeTab.receive),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    bool withTopPill = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        width: 80,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Glowing Top Pill for active tab
            if (withTopPill && isActive)
              Container(
                width: 32,
                height: 3,
                margin: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: LocaraCyberColors.auroraCyan,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: const [
                    BoxShadow(
                      color: LocaraCyberColors.auroraCyan,
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              )
            else
              const SizedBox(height: 9),

            Icon(
              icon,
              color: isActive ? LocaraCyberColors.auroraCyan : LocaraCyberColors.textMuted,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                color: isActive ? Colors.white : LocaraCyberColors.textMuted,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
