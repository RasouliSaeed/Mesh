with open('packages/core/src/http/server/v2.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace(
'''    let result = common::save::save_req_to_target(
        req,
        target,
        file_size,
        expected_sha256.as_deref(),
        timestamps,
    )
    .await;''',
'''    use crate::http::server::transport_adapter::HttpIncomingAdapter;
    let stream = Box::pin(HttpIncomingAdapter::new(req.into_body()));
    let result = common::save::save_req_to_target(
        stream,
        target,
        file_size,
        expected_sha256.as_deref(),
        timestamps,
    )
    .await;'''
)

with open('packages/core/src/http/server/v2.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("Modified v2.rs")
