import 'dart:io';
import 'dart:ui';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:locara_app/config/init.dart';
import 'package:locara_app/gen/strings.g.dart';
import 'package:locara_app/pages/home_page_controller.dart';
import 'package:locara_app/pages/tabs/receive_tab.dart';
import 'package:locara_app/pages/tabs/send_tab.dart';
import 'package:locara_app/pages/tabs/settings_tab.dart';
import 'package:locara_app/provider/selection/selected_sending_files_provider.dart';
import 'package:locara_app/util/native/cross_file_converters.dart';
import 'package:locara_app/widget/responsive_builder.dart';
import 'package:refena_flutter/refena_flutter.dart';

enum HomeTab {
  receive(Icons.wifi),
  send(Icons.send),
  settings(Icons.settings);

  const HomeTab(this.icon);

  final IconData icon;

  String get label {
    switch (this) {
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
          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Scaffold(

              backgroundColor: Colors.transparent,
              body: Padding(
                padding: sizingInformation.isMobile ? EdgeInsets.zero : const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    if (!sizingInformation.isMobile)
                      Container(
                        margin: const EdgeInsets.only(right: 24.0),
                        width: sizingInformation.isDesktop ? 260 : 80,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: NavigationRail(
                            selectedIndex: vm.currentTab.index,
                            onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                            extended: sizingInformation.isDesktop,
                            backgroundColor: Colors.transparent,
                            indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                            unselectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.onSurfaceVariant),
                            selectedIconTheme: IconThemeData(color: Theme.of(context).colorScheme.primary),
                            unselectedLabelTextStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                            selectedLabelTextStyle: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold),
                            leading: sizingInformation.isDesktop
                                ? Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 32.0),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.rocket_launch, color: Theme.of(context).colorScheme.primary, size: 28),
                                        const SizedBox(width: 12),
                                        Text(
                                          t.appName,
                                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: -0.5),
                                        ),
                                      ],
                                    ),
                                  )
                                : const SizedBox(height: 32),
                            destinations: HomeTab.values.map((tab) {
                              return NavigationRailDestination(
                                icon: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Icon(tab.icon),
                                ),
                                label: Text(tab.label),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    Expanded(
                      child: Container(
                        decoration: sizingInformation.isMobile ? null : BoxDecoration(
                          color: Theme.of(context).colorScheme.surface,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: sizingInformation.isMobile ? BorderRadius.zero : BorderRadius.circular(24),
                          child: SafeArea(
                            left: sizingInformation.isMobile,
                            child: Stack(
                              children: [
                                PageView(
                                  controller: vm.controller,
                                  physics: const NeverScrollableScrollPhysics(),
                                  children: const [
                                    ReceiveTab(),
                                    SendTab(),
                                    SettingsTab(),
                                  ],
                                ),
                                if (_dragAndDropIndicator)
                                  Container(
                                    width: double.infinity,
                                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.file_download, size: 128, color: Theme.of(context).colorScheme.primary),
                                        const SizedBox(height: 30),
                                        Text(t.sendTab.placeItems, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              extendBody: true,
              bottomNavigationBar: sizingInformation.isMobile
                  ? Padding(
                      padding: const EdgeInsets.only(left: 20, right: 20, bottom: 24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            height: 70,
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.5),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: NavigationBar(
                              backgroundColor: Colors.transparent,
                              indicatorColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
                              elevation: 0,
                              labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
                              selectedIndex: vm.currentTab.index,
                              onDestinationSelected: (index) => vm.changeTab(HomeTab.values[index]),
                              destinations: HomeTab.values.map((tab) {
                                return NavigationDestination(
                                  icon: Icon(tab.icon, color: Theme.of(context).colorScheme.onSurfaceVariant),
                                  selectedIcon: Icon(tab.icon, color: Theme.of(context).colorScheme.primary),
                                  label: tab.label,
                                );
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}
