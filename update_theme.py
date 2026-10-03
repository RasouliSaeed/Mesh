import re

with open('app/lib/config/theme.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Replace _determineColorScheme implementation
new_impl = '''ColorScheme _determineColorScheme(ColorMode mode, Color customColor, Brightness brightness, DynamicColors? dynamicColors) {
  if (mode == ColorMode.yaru) throw 'Should reach here';
  
  final isDark = brightness == Brightness.dark;
  
  // Premium Locara Palette
  final colorScheme = ColorScheme(
    brightness: brightness,
    primary: isDark ? const Color(0xFF1769FF) : const Color(0xFF3685FF),
    onPrimary: Colors.white,
    secondary: const Color(0xFF27B7D9),
    onSecondary: Colors.white,
    error: const Color(0xFFDC4C4C),
    onError: Colors.white,
    surface: isDark ? const Color(0xFF17243A) : const Color(0xFFFFFFFF),
    onSurface: isDark ? const Color(0xFFF1F5F9) : const Color(0xFF172033),
  ).copyWith(
    surfaceContainerHighest: isDark ? const Color(0xFF1D2A40) : const Color(0xFFF8FAFD),
    onSurfaceVariant: isDark ? const Color(0xFF9BAAC0) : const Color(0xFF64748B),
    outline: isDark ? const Color(0xFF2B3B53) : const Color(0xFFE2E8F0),
  );

  return colorScheme;
}
'''

content = re.sub(r'ColorScheme _determineColorScheme.*?return colorScheme \?\? defaultColorScheme;\s*}', new_impl, content, flags=re.DOTALL)

with open('app/lib/config/theme.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated theme.dart')
