import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        if not line.strip():
            continue
        try:
            data = json.loads(line)
            if data.get('type') == 'USER_INPUT':
                print("--- USER INPUT ---")
                print(json.dumps(data, indent=2))
        except Exception as e:
            print("Error parsing line:", e)
