with open('packages/core/src/http/dto_v3.rs', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('use crate::model::discovery::DeviceType;', 
    'use crate::model::discovery::DeviceType;\nuse crate::model::discovery::{device_type_v2, protocol_type_v2};')

content = content.replace('pub device_type: Option<DeviceType>,', 
    '#[serde(default, with = "device_type_v2", skip_serializing_if = "Option::is_none")]\n    pub device_type: Option<DeviceType>,')

with open('packages/core/src/http/dto_v3.rs', 'w', encoding='utf-8') as f:
    f.write(content)

print("fixed device_type")
