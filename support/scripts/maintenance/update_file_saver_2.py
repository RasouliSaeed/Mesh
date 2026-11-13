with open('packages/mesh_isolates/lib/src/task/server/file_saver.dart', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Remove .mesh.part from file_saver.dart
content = content.replace("path: destinationPath + '.mesh.part',", "path: destinationPath,")

with open('packages/mesh_isolates/lib/src/task/server/file_saver.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated file_saver.dart")
