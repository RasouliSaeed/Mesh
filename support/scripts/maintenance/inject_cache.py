import os
import glob

workflow_dir = '.github/workflows/'

for filepath in glob.glob(os.path.join(workflow_dir, 'build_*.yml')):
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()
        
    if 'uses: Swatinem/rust-cache@v2' in content:
        continue
        
    lines = content.split('\n')
    out_lines = []
    inserted = False
    
    for line in lines:
        if not inserted and ('- name: Dependencies' in line or '- name: Compile' in line or '- name: Install Rust' in line or '- uses: subosito/flutter-action' in line):
            indent = line.split('-')[0]
            out_lines.append(indent + '- name: Cache Rust')
            out_lines.append(indent + '  uses: Swatinem/rust-cache@v2')
            out_lines.append('')
            inserted = True
        
        out_lines.append(line)
        
    with open(filepath, 'w', encoding='utf-8') as f:
        f.write('\n'.join(out_lines))
        
print('Cache steps injected')
