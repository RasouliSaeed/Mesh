import re

with open('app/lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the body Row for desktop to have floating panels
new_body = '''              body: Padding(
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
              ),'''

# Use regex to replace the body part
content = re.sub(r'              body: Row\(.*?\]\,\n                      \),\n                    \),\n                  \),\n                \],\n              \),', new_body, content, flags=re.DOTALL)

with open('app/lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated home_page.dart body')
