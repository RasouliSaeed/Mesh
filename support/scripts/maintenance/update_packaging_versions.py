import re

def update_version(filepath, old_version, new_version):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
    content = content.replace(old_version, new_version)
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write(content)

update_version('support/build/msix/content/AppxManifest.xml', 'Version="1.7.9.0"', 'Version="1.8.0.0"')
update_version('support/build/appimage/AppImageBuilder_x86_64.yml', 'version: 1.7.9', 'version: 1.8.0')
update_version('support/build/appimage/AppImageBuilder_arm_64.yml', 'version: 1.7.9', 'version: 1.8.0')

print('Remaining versions updated to 1.8.0')
