import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        if '"step_index": 5065' in line or '"step_index":5065' in line:
            data = json.loads(line)
            content = data.get('content', '')
            print("Content:")
            print(content)
            # Find the mentioned item in metadata
            break
