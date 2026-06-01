import os
import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'
if os.path.exists(log_path):
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        for line in f:
            try:
                data = json.loads(line)
                step = data.get("step_index")
                if step in [8542, 8566]:
                    print(f"Step {step}:")
                    print(data.get("content"))
                    print("=" * 60)
            except Exception:
                pass
else:
    print("Not found")
