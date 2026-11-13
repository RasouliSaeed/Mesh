with open('packages/core/src/model/transport.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('use async_trait::async_trait;\n', '')
content = content.replace('#[async_trait]\n', '')

with open('packages/core/src/model/transport.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("Removed async_trait")
