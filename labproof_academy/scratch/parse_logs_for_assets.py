import re

log_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.system_generated/logs/overview.txt'

with open(log_path, 'r', encoding='utf-8') as f:
    lines = f.readlines()

print("Searching for media mappings or copying operations...")
for i, line in enumerate(lines):
    if any(keyword in line for keyword in ['media_', 'onboarding_1', 'onboarding_2', 'onboarding_3', 'onboarding_welcome']):
        # print line preview
        print(f"Line {i}: {line[:200]}...")
