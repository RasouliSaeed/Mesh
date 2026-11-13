import re

with open('app/lib/pages/tabs/settings_tab.dart', 'r', encoding='utf-8') as f:
    content = f.read()

# Remove old encryption entry
content = re.sub(r'                  if \(vm\.advanced\)\n                    _BooleanEntry\(\n                      label: t\.settingsTab\.network\.encryption,\n                      value: vm\.settings\.https,\n                      onChanged: \(b\) async \{\n                        final old = vm\.settings\.https;\n                        await ref\.notifier\(settingsProvider\)\.setHttps\(b\);\n                        if \(old && !b && context\.mounted\) \{\n                          await EncryptionDisabledNotice\.open\(context\);\n                        \}\n                      \},\n                    \),\n', '', content)

# Inject new Security section before 'Other' section
security_section = '''              _SettingsSection(
                title: 'Security & Privacy',
                children: [
                  _BooleanEntry(
                    label: t.settingsTab.network.encryption,
                    value: vm.settings.https,
                    onChanged: (b) async {
                      final old = vm.settings.https;
                      await ref.notifier(settingsProvider).setHttps(b);
                      if (old && !b && context.mounted) {
                        await EncryptionDisabledNotice.open(context);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 30),
              _SettingsSection(
                title: t.settingsTab.other.title,'''

content = content.replace('''              _SettingsSection(
                title: t.settingsTab.other.title,''', security_section)

with open('app/lib/pages/tabs/settings_tab.dart', 'w', encoding='utf-8') as f:
    f.write(content)

print('Updated settings_tab.dart with prominent Security section')
