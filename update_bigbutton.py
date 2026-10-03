import re

with open('app/lib/widget/big_button.dart', 'r', encoding='utf-8') as f:
    content = f.read()

new_build = '''  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final sizingInformation = SizingInformation(MediaQuery.sizeOf(context).width);
    final buttonWidth = width ?? (sizingInformation.isDesktop ? desktopWidth : mobileWidth);
    return SizedBox(
      width: buttonWidth,
      height: 75.0,
      child: Material(
        color: filled ? colorScheme.primary : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(
                  icon, 
                  color: filled ? colorScheme.onPrimary : colorScheme.primary,
                  size: 26,
                ),
                FittedBox(
                  alignment: Alignment.bottomCenter,
                  child: Text(
                    label, 
                    maxLines: 1, 
                    style: TextStyle(
                      color: filled ? colorScheme.onPrimary : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }'''

content = re.sub(r'  @override\n  Widget build\(BuildContext context\) \{.*\}', new_build, content, flags=re.DOTALL)

with open('app/lib/widget/big_button.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated big_button.dart')
