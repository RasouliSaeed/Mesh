with open('.github/workflows/release.yml', 'r', encoding='utf-8') as f:
    content = f.read()

content = content.replace('  release:\n    needs:', "  release:\n    if: always() && !contains(needs.*.result, 'failure') && !contains(needs.*.result, 'cancelled')\n    needs:")

with open('.github/workflows/release.yml', 'w', encoding='utf-8') as f:
    f.write(content)

print("release job updated")
