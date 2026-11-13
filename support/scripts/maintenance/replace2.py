import re

with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'r', encoding='utf-8') as f:
    content = f.read()

content = re.sub(
    r'(\} else \{\s*)(filePath = target\.displayPath;\s*\})',
    r'\1// [Master Spec Rule 20] Atomic File Commit: Rename .mesh.part to final file\n        if (target.path != null && target.finalPath != null && target.path!.endsWith(".mesh.part")) {\n          final partFile = File(target.path!);\n          if (await partFile.exists()) {\n            await partFile.rename(target.finalPath!);\n          }\n        }\n        \2',
    content
)

with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print("Replaced successfully")
