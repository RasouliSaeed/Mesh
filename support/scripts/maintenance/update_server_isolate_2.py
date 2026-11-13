with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# Find the rename block
rename_block = """      // [Master Spec Rule 20] Atomic File Commit: Rename .mesh.part to final file
        if (target.path != null && target.finalPath != null && target.path!.endsWith(".mesh.part")) {
          final partFile = File(target.path!);
          if (await partFile.exists()) {
            await partFile.rename(target.finalPath!);
          }
        }"""

content = content.replace(rename_block, "")

with open('packages/mesh_isolates/lib/src/isolate/child/server_isolate.dart', 'w', encoding='utf-8') as f:
    f.write(content)
print("Updated server_isolate.dart")
