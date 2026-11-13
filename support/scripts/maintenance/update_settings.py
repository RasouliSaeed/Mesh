import re

with open('app/lib/pages/tabs/settings_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_section = '''  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: padding,
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.3)
              : colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).brightness == Brightness.dark 
                ? colorScheme.outline.withValues(alpha: 0.2)
                : colorScheme.outline.withValues(alpha: 0.5),
          ),
          boxShadow: Theme.of(context).brightness == Brightness.light ? [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ] : null,
        ),
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title, 
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.bold,
                )
              ),
              const SizedBox(height: 16),
              ...children,
            ],
          ),
        ),
      ),
    );
  }'''

content = re.sub(r'  @override\n  Widget build\(BuildContext context\) \{\n    return Padding\(\n      padding: padding,\n      child: Card\(.*?\),\n        \),\n      \),\n    \);\n  \}', new_section, content, flags=re.DOTALL)

with open('app/lib/pages/tabs/settings_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated SettingsSection in settings_tab.dart')
