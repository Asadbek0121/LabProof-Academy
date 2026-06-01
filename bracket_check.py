import json

def read_last_user_messages(filename, num_messages=15):
    user_msgs = []
    with open(filename, 'r') as f:
        for line in f:
            try:
                data = json.loads(line)
                if data.get('source') == 'USER_EXPLICIT' or data.get('type') == 'USER_INPUT':
                    user_msgs.append((data.get('created_at'), data.get('content')))
            except Exception:
                pass
                
    print(f"Total user messages found: {len(user_msgs)}")
    for i, (ts, content) in enumerate(user_msgs[-num_messages:]):
        print(f"\n--- MESSAGE {len(user_msgs) - num_messages + i + 1} ({ts}) ---")
        print(content)

read_last_user_messages('/Users/macbookairm1/.gemini/antigravity/brain/156efca1-8b29-4d5f-9eea-8414f280a23f/.system_generated/logs/transcript.jsonl')
