import re

with open('app/lib/widget/list_tile/custom_list_tile.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('if (trailing != null) trailing!,', 'if (trailing != null) trailing,')
# Actually, the lint wants ?trailing,. Let's just suppress it or use what it wants.
# Let's try if (trailing != null) trailing, first. Wait, use_null_aware_elements means we can just use ?trailing, in Dart 3.3+.
content = content.replace('if (trailing != null) trailing,', '?trailing,')

with open('app/lib/widget/list_tile/custom_list_tile.dart', 'w', encoding='utf-8') as f:
    f.write(content)
