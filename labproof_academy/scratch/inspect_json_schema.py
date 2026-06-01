import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    for i in range(15):
        line = f.readline()
        if not line:
            break
        try:
            data = json.loads(line)
            print(f"Keys: {list(data.keys())}")
            if 'type' in data:
                print(f"Type: {data['type']}")
            if 'source' in data:
                print(f"Source: {data['source']}")
        except:
            print("Not JSON:", line[:100])
