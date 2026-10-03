import re

with open('app/lib/config/theme.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace ThemeData instantiation in getTheme
content = re.sub(
    r'return ThemeData\(\s*colorScheme: colorScheme,',
    '''return ThemeData(
    colorScheme: colorScheme,
    scaffoldBackgroundColor: colorScheme.brightness == Brightness.dark ? const Color(0xFF101827) : const Color(0xFFF4F6FA),''',
    content
)

with open('app/lib/config/theme.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated getTheme in theme.dart')
