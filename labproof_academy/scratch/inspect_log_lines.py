import os

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'
if os.path.exists(log_path):
    with open(log_path, 'r', encoding='utf-8', errors='ignore') as f:
        count = 0
        for line in f:
            if 'USER' in line or 'user' in line:
                print(line[:300])
                count += 1
                if count > 20:
                    break
else:
    print("Not found")
