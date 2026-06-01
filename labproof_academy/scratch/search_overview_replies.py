import os
import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'
if os.path.exists(log_path):
    responses = []
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line)
                if data.get("source") == "MODEL" and "content" in data:
                    responses.append(data)
            except Exception as e:
                pass
    print("Found model responses:")
    for data in responses[-15:]:
        print(f"Step: {data.get('step_index')}, Created: {data.get('created_at')}")
        print("Content:", data["content"][:300])
        print("="*40)
else:
    print("overview.txt not found!")
