import re

with open('.github/workflows/release.yml', 'r', encoding='utf-8') as f:
    content = f.read()

# 1. Add inputs
inputs = '''  workflow_dispatch:
    inputs:
      build_android:
        description: 'Build Android APK'
        required: true
        type: boolean
        default: true
      build_windows:
        description: 'Build Windows Apps'
        required: true
        type: boolean
        default: true
      build_linux:
        description: 'Build Linux Apps'
        required: true
        type: boolean
        default: false
      build_macos:
        description: 'Build macOS/iOS Apps'
        required: true
        type: boolean
        default: false'''

content = content.replace('  workflow_dispatch:', inputs)

# Split into parts: before 'jobs:', and after 'jobs:'
parts = content.split('\njobs:\n')
header = parts[0]
jobs_part = parts[1]

# 2. Add if statements to jobs (only in jobs_part)
job_replacements = {
    '\n  build_apk:\n': "\n  build_apk:\n    if: ${{ github.event.inputs.build_android == 'true' }}\n",
    '\n  build_tar_x86_64:\n': "\n  build_tar_x86_64:\n    if: ${{ github.event.inputs.build_linux == 'true' }}\n",
    '\n  build_tar_arm_64:\n': "\n  build_tar_arm_64:\n    if: ${{ github.event.inputs.build_linux == 'true' }}\n",
    '\n  build_deb_x86_64:\n': "\n  build_deb_x86_64:\n    if: ${{ github.event.inputs.build_linux == 'true' }}\n",
    '\n  build_deb_arm_64:\n': "\n  build_deb_arm_64:\n    if: ${{ github.event.inputs.build_linux == 'true' }}\n",
    '\n  build_appimage_x86_64:\n': "\n  build_appimage_x86_64:\n    if: ${{ github.event.inputs.build_linux == 'true' }}\n",
    '\n  build_windows_zip_x86_64:\n': "\n  build_windows_zip_x86_64:\n    if: ${{ github.event.inputs.build_windows == 'true' }}\n",
    '\n  build_windows_zip_arm_64:\n': "\n  build_windows_zip_arm_64:\n    if: ${{ github.event.inputs.build_windows == 'true' }}\n",
    '\n  build_windows_exe_x86_64:\n': "\n  build_windows_exe_x86_64:\n    if: ${{ github.event.inputs.build_windows == 'true' }}\n",
    '\n  build_cli_linux:\n': "\n  build_cli_linux:\n    if: ${{ github.event.inputs.build_linux == 'true' }}\n",
    '\n  build_cli_windows_exe:\n': "\n  build_cli_windows_exe:\n    if: ${{ github.event.inputs.build_windows == 'true' }}\n",
    '\n  build_macos:\n': "\n  build_macos:\n    if: ${{ github.event.inputs.build_macos == 'true' }}\n",
    '\n  build_ios:\n': "\n  build_ios:\n    if: ${{ github.event.inputs.build_macos == 'true' }}\n"
}

for old, new in job_replacements.items():
    jobs_part = jobs_part.replace(old, new)

content = header + '\njobs:\n' + jobs_part

# 3. Add if: always() ... to create_release
content = content.replace('  create_release:\n    needs:', "  create_release:\n    if: always() && !contains(needs.*.result, 'failure') && !contains(needs.*.result, 'cancelled')\n    needs:")

# 4. Add if conditions to the steps inside create_release
lines = content.split('\n')
out_lines = []
current_condition = None

for i, line in enumerate(lines):
    # Detect sections
    if line.strip() == '# APK':
        current_condition = "if: ${{ github.event.inputs.build_android == 'true' }}"
    elif line.strip() in ['# TAR.GZ (x86_64)', '# TAR.GZ (arm_64)', '# DEB (x86_64)', '# DEB (arm_64)', '# APPIMAGE (x86_64)', '# LINUX CLI (x86_64)', '# LINUX CLI (arm_64)']:
        current_condition = "if: ${{ github.event.inputs.build_linux == 'true' }}"
    elif line.strip() in ['# WINDOWS ZIP (x86_64)', '# WINDOWS ZIP (arm_64)', '# WINDOWS EXE (x86_64)', '# WINDOWS CLI EXE (x86_64)', '# WINDOWS CLI EXE (arm_64)']:
        current_condition = "if: ${{ github.event.inputs.build_windows == 'true' }}"
    elif line.strip() in ['# MACOS', '# IOS']:
        current_condition = "if: ${{ github.event.inputs.build_macos == 'true' }}"
    
    out_lines.append(line)
    
    # If we are at a step under a section and it starts with '- name: '
    if current_condition and line.startswith('      - name: ') and not ('Create Release Draft' in line or 'Get version' in line):
        out_lines.append('        ' + current_condition)

with open('.github/workflows/release.yml', 'w', encoding='utf-8') as f:
    f.write('\n'.join(out_lines))

print('Workflow customized safely!')
