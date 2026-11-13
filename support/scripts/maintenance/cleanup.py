import re

def remove_import(filepath, import_str):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(import_str + '\n', '')
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

remove_import('app/lib/pages/tabs/receive_tab.dart', "import 'package:mesh_app/model/state/server/server_state.dart';")
remove_import('app/lib/pages/tabs/receive_tab.dart', "import 'package:mesh_isolates/util/sleep.dart';")
remove_import('app/lib/widget/big_button.dart', "import 'package:mesh_app/config/theme.dart';")
remove_import('app/lib/widget/list_tile/custom_list_tile.dart', "import 'package:mesh_app/config/theme.dart';")

print('Cleaned up unused imports')
