with open('packages/core/src/http/server/common/save.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('use http_body_util::BodyExt;\n', '')

with open('packages/core/src/http/server/common/save.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed BodyExt")
