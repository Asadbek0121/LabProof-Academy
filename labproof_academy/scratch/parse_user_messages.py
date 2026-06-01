import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    text = f.read()

print("Scanning for user messages and media...")
for line in text.split('\n'):
    if not line.strip():
        continue
    try:
        data = json.loads(line)
        # Check if this is a USER message
        if data.get('source') == 'USER' or 'parts' in data or 'MediaPaths' in data:
            print(f"\n--- Turn at {data.get('created_at')} ---")
            if 'text' in data:
                print(f"Text: {data['text']}")
            if 'MediaPaths' in data:
                print(f"MediaPaths: {data['MediaPaths']}")
            # Also check if it's within nested structures
            for key, val in data.items():
                if isinstance(val, dict) and 'MediaPaths' in val:
                    print(f"Nested MediaPaths: {val['MediaPaths']}")
    except Exception as e:
        pass
