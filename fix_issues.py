import re

# Fix progress_page.dart
with open('app/lib/pages/progress_page.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Fix unused finishedCount
content = re.sub(r'    final finishedCount = transferNotifier\.getStatuses\(widget\.sessionId\)\.where\(\(s\) => s == \nFileStatus\.finished\)\.length;\n', '', content)
content = re.sub(r'    final finishedCount = transferNotifier\.getStatuses\(widget\.sessionId\)\.where\(\(s\) => s == FileStatus\.finished\)\.length;\n', '', content)

# Fix _advanced final
content = content.replace('bool _advanced = false;', 'final bool _advanced = false;')

with open('app/lib/pages/progress_page.dart', 'w', encoding='utf-8') as f:
    f.write(content)

# Fix receive_tab.dart
with open('app/lib/pages/tabs/receive_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('"Ready to receive"', "'Ready to receive'")
content = content.replace('"Secured"', "'Secured'")

with open('app/lib/pages/tabs/receive_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Fixed unused variable and string quotes')
