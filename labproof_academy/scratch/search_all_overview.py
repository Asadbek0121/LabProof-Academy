import os
import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'
if os.path.exists(log_path):
    print("Searching log from index 6000 to 6800:")
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line)
                step = data.get("step_index", 0)
                if 6000 <= step <= 6800:
                    source = data.get("source")
                    dtype = data.get("type")
                    if source == "USER_EXPLICIT" or (source == "MODEL" and dtype == "PLANNER_RESPONSE"):
                        content = data.get("content", "")
                        print(f"Step {step} [{source}]: {content[:200]}...")
            except Exception as e:
                pass
else:
    print("overview.txt not found!")
