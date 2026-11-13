with open('packages/core/src/model/transport.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('fn upload(', 'async fn upload(')
content = content.replace('-> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), TransportError>> + Send>>;', '-> Result<(), TransportError>;')

with open('packages/core/src/model/transport.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed to async fn")
