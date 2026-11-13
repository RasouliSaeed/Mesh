with open('packages/core/src/http/server/common/save.rs', 'r', encoding='utf-8') as f:
    content = f.read()

print(content[content.find('async fn write_file_from_receiver'):content.find('pub(crate) async fn save_req_to_target')])
