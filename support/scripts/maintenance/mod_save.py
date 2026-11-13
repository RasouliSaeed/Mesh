with open('packages/core/src/http/server/common/save.rs', 'r', encoding='utf-8') as f:
    content = f.read()

import re

# We will remove #[derive(Debug)]
content = content.replace('#[derive(Debug)]\npub enum FileUploadTarget', 'pub enum FileUploadTarget')

# We will replace Path and Fd variants with Storage variant.
# We also need to fix `spawn_file_writer` and its logic.
