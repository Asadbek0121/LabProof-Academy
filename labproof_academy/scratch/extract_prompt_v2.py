import os
import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'
if os.path.exists(log_path):
    user_msgs = []
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line)
                if "USER" in data.get("source", "") or data.get("type") == "USER_INPUT":
                    user_msgs.append(data)
            except Exception as e:
                pass
    print(f"Found {len(user_msgs)} user messages:")
    for data in user_msgs[-10:]:
        print(f"Step: {data.get('step_index')}, Source: {data.get('source')}, Created: {data.get('created_at')}")
        print("Content keys:", list(data.keys()))
        if "content" in data:
            print("Content:", data["content"][:200])
        elif "prompt" in data:
            print("Prompt:", data["prompt"][:200])
        else:
            # print whole data
            print(json.dumps(data, indent=2)[:500])
        print("="*40)
else:
    print("overview.txt not found!")
