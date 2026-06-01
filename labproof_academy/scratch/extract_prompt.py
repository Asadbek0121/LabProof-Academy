import os
import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'
if os.path.exists(log_path):
    user_msgs = []
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line)
                if data.get("source") == "USER":
                    user_msgs.append((data.get("created_at"), data.get("content")))
            except Exception as e:
                pass
    print("Found user messages:")
    for t, content in user_msgs[-10:]:
        print(f"[{t}] {content}")
        print("="*40)
else:
    print("overview.txt not found!")
