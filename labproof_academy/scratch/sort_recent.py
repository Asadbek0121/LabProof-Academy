import os
import time

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = [os.path.join(media_dir, f) for f in os.listdir(media_dir) if f.startswith('media_')]
files.sort(key=os.path.getmtime, reverse=True)

print("Recent files sorted by modification time:")
for f in files[:15]:
    mtime = time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(os.path.getmtime(f)))
    size = os.path.getsize(f)
    print(f"{os.path.basename(f)}: size={size} bytes, modified={mtime}")
