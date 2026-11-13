with open('packages/core/src/http/mod.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('pub mod dto_v2;', 'pub mod dto_v2;\npub mod dto_v3;')

with open('packages/core/src/http/mod.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("added dto_v3")
