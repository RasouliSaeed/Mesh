with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("import 'dart:async';", "import 'dart:async';\nimport 'dart:io';")

with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("added dart:io")
