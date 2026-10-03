import re

with open('app/lib/pages/home_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace the Container background with a subtle, solid or very soft minimalist background
new_bg = '''          return Container(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: Scaffold(
'''
content = re.sub(r'          return Container\(\s*decoration: BoxDecoration\(.*?child: Scaffold\(', new_bg, content, flags=re.DOTALL)

# Refine the bottom navigation bar to be a floating pill, very clean
new_nav = '''              bottomNavigationBar: sizingInformation.isMobile
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
                  : null,'''

content = re.sub(r'              bottomNavigationBar: sizingInformation\.isMobile.*?null,', new_nav, content, flags=re.DOTALL)

with open('app/lib/pages/home_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated home_page.dart layout and navigation')
