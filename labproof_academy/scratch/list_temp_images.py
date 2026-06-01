import os

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
if os.path.exists(media_dir):
    files = sorted(os.listdir(media_dir))
    print(f"Total files: {len(files)}")
    for f in files:
        path = os.path.join(media_dir, f)
        print(f"- {f} ({os.path.getsize(path)} bytes)")
else:
    print("media_dir not found!")
