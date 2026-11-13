with open('packages/core/src/model/storage.rs', 'r', encoding='utf-8') as f:
    content = f.read()

# Rename write_chunk to write_data
content = content.replace("fn write_chunk<'a>(", "fn write_data<'a>(")

# Add documentation clarification for abort
if "Aborts the storage operation (e.g., deletes the temporary file)." in content:
    content = content.replace(
        "Aborts the storage operation (e.g., deletes the temporary file).",
        "Aborts the storage operation. Incomplete temporary files might be left on disk per policy (this is NOT a persistent resume state)."
    )

with open('packages/core/src/model/storage.rs', 'w', encoding='utf-8') as f:
    f.write(content)

with open('packages/core/src/model/storage_adapter.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("fn write_chunk<'a>(", "fn write_data<'a>(")
content = content.replace(
    "// Intentionally leaving the temporary file on disk (current policy)",
    "// Intentionally leaving the temporary file on disk (current policy).\n            // NOTE: .mesh.part remaining after abort is NOT equivalent to persistent resume. It is strictly an incomplete temporary file."
)
content = content.replace(
    "// [Master Spec Rule 20] Atomic File Commit",
    "// [Master Spec Rule 20] Atomic File Commit (Temporary file for atomic commit, NOT a resume manifest)"
)

with open('packages/core/src/model/storage_adapter.rs', 'w', encoding='utf-8') as f:
    f.write(content)

with open('packages/core/src/http/server/common/save.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace("handle.write_chunk(&chunk).await", "handle.write_data(&chunk).await")

with open('packages/core/src/http/server/common/save.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("Micro-fixes applied")
