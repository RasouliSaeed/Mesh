import re

def update_version(filepath, old_version, new_version):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(old_version, new_version)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

update_version('app/pubspec.yaml', 'version: 1.7.9+66', 'version: 1.8.0+67')
update_version('cli/Cargo.toml', 'version = "1.7.9"', 'version = "1.8.0"')
update_version('support/scripts/compile_windows_exe-inno.iss', '#define MyAppVersion "1.7.9"', '#define MyAppVersion "1.8.0"')

print('Version updated to 1.8.0')
