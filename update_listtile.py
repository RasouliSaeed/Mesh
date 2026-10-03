import re

with open('app/lib/widget/list_tile/custom_list_tile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_build = '''  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark 
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
            : colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Theme.of(context).brightness == Brightness.dark 
              ? colorScheme.outline.withValues(alpha: 0.3)
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
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: padding,
            child: Row(
              children: [
                if (icon != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconTheme(
                      data: IconThemeData(color: colorScheme.primary),
                      child: icon!,
                    ),
                  ),
                  const SizedBox(width: 16),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: colorScheme.onSurface,
                        ),
                        child: title,
                      ),
                      const SizedBox(height: 6),
                      DefaultTextStyle(
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        child: subTitle,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
          ),
        ),
      ),
    );
  }'''

content = re.sub(r'  @override\n  Widget build\(BuildContext context\) \{.*\}', new_build, content, flags=re.DOTALL)
content = content.replace('?trailing,', 'if (trailing != null) trailing!,') # Ensure ?trailing isn't left over

with open('app/lib/widget/list_tile/custom_list_tile.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated custom_list_tile.dart')
