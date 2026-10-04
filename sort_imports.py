import re

def sort_imports(filepath):
    with open(filepath, 'r', encoding='utf-8') as f:
        lines = f.readlines()
        
    imports = []
    other_lines = []
    
    in_imports = True
    for line in lines:
        if line.startswith('import ') or line.startswith('// [FOSS'):
            imports.append(line)
        elif line.strip() == '' and in_imports:
            continue
        else:
            in_imports = False
            other_lines.append(line)
            
    # Sort: dart: first, package: second, relative last
    dart_imports = sorted([i for i in imports if i.startswith('import \'dart:')])
    pkg_imports = sorted([i for i in imports if i.startswith('import \'package:')])
    rel_imports = sorted([i for i in imports if not i.startswith('import \'dart:') and not i.startswith('import \'package:') and i.startswith('import')])
    
    # Handle FOSS comments if any (hacky, let's just keep them sorted as strings if needed, or better, just rely on the standard sorted order)
    
    sorted_imports = dart_imports + pkg_imports + rel_imports
    
    with open(filepath, 'w', encoding='utf-8') as f:
        for imp in sorted_imports:
            f.write(imp)
        f.write('\n')
        for line in other_lines:
            f.write(line)

sort_imports('app/lib/pages/progress_page.dart')
sort_imports('app/lib/pages/tabs/receive_tab.dart')
print('Imports sorted')
