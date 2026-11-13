import yaml
try:
    with open('.github/workflows/release.yml', 'r') as f:
        yaml.safe_load(f)
    print("YAML is perfectly valid!")
except Exception as e:
    print(f"YAML Syntax Error: {e}")
