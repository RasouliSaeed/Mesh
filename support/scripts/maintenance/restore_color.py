with open('app/android/app/src/main/res/values/colors.xml', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('<resources>', '<resources>\n    <color name="ic_launcher_background">#000000</color>')

with open('app/android/app/src/main/res/values/colors.xml', 'w', encoding='utf-8') as f:
    f.write(content)

print('Restored ic_launcher_background')
