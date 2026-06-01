import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        if any(f'"step_index":{idx}' in line for idx in range(4960, 5025)):
            try:
                data = json.loads(line)
                print(f"Step {data.get('step_index')}: {data.get('type')}")
                if 'content' in data:
                    print(f"  Content: {data['content'][:500]}")
                if 'tool_calls' in data:
                    print(f"  Tool Calls: {data['tool_calls']}")
            except:
                pass
