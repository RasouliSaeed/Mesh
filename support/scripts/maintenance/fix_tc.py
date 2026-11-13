with open('packages/core/src/model/transport.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('#[async_trait::async_trait]\n', '')
content = content.replace('async fn upload(', 'fn upload(')
content = content.replace('-> Result<(), TransportError>;', '-> std::pin::Pin<Box<dyn std::future::Future<Output = Result<(), TransportError>> + Send>>;')

with open('packages/core/src/model/transport.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("Fixed TransportClient async trait")
