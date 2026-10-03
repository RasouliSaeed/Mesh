import json

def update_json(file, new_items):
    # Try different encodings
    data = None
    for enc in ['utf-8-sig', 'utf-8', 'utf-16', 'windows-1256']:
        try:
            with open(file, 'r', encoding=enc) as f:
                data = json.load(f)
            break
        except Exception:
            continue
    
    if not data:
        print(f"Could not read {file}")
        return

    # Find aliasGenerator key
    target_key = None
    for k in data.keys():
        if k.startswith('aliasGenerator'):
            target_key = k
            break
            
    if target_key and 'fruits' in data[target_key]:
        data[target_key]['fruits'] = new_items
        with open(file, 'w', encoding='utf-8-sig') as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        print(f'Updated {file}')
    else:
        print(f'fruits not found in {file}')

en_items = ["Motherboard", "GPU", "CPU", "RAM", "SSD", "HDD", "Keyboard", "Mouse", "Monitor", "Router", "Switch", "Server", "Laptop", "Tablet", "Smartphone", "Printer", "Scanner", "Modem", "Hub", "Webcam", "Microphone", "Speaker", "Projector", "Joystick", "Gamepad", "Touchpad"]
fa_items = ["مادربورد", "گرافیک", "پردازنده", "رم", "اس‌اس‌دی", "هارد", "کیبورد", "موس", "مانیتور", "روتر", "سوییچ", "سرور", "لپ‌تاپ", "تبلت", "گوشی", "پرینتر", "اسکنر", "مودم", "هاب", "وب‌کم", "میکروفون", "اسپیکر", "پروژکتور", "دسته بازی", "گیم‌پد", "تاچ‌پد"]

update_json('app/assets/i18n/en.json', en_items)
update_json('app/assets/i18n/fa.json', fa_items)
