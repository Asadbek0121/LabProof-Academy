import os
import hashlib

def get_sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        h.update(f.read())
    return h.hexdigest()

assets_dir = '/Users/macbookairm1/Documents/New project 3/labproof_academy/assets/images'
media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'

current_logo_path = os.path.join(assets_dir, 'telegram_logo.png')
if os.path.exists(current_logo_path):
    logo_sha = get_sha256(current_logo_path)
    print(f"Current logo sha256: {logo_sha} (size: {os.path.getsize(current_logo_path)} bytes)")
    found = False
    for f in os.listdir(media_dir):
        path = os.path.join(media_dir, f)
        if os.path.exists(path) and get_sha256(path) == logo_sha:
            print(f"Matches temp file: {f}")
            found = True
    if not found:
        print("Does not match any temp file!")
else:
    print("telegram_logo.png does not exist in assets!")
