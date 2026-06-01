import json

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    for line in f:
        if '"step_index":5017' in line or '"step_index": 5017' in line:
            data = json.loads(line)
            tool_calls = data.get('tool_calls', [])
            for call in tool_calls:
                if call.get('name') == 'run_command':
                    print("CommandLine:")
                    print(call['args'].get('CommandLine'))
            break
