import os
import time

brain_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1'
now = time.time()
recent_files = []

for root, dirs, files in os.walk(brain_dir):
    for f in files:
        path = os.path.join(root, f)
        try:
            mtime = os.path.getmtime(path)
            if now - mtime < 600: # 10 minutes
                recent_files.append((path, os.path.getsize(path), mtime))
        except Exception:
            pass

print("Files modified in the last 10 minutes:")
for path, size, mtime in sorted(recent_files, key=lambda x: x[2], reverse=True):
    print(f"{path}: size={size} bytes, modified={time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(mtime))}")
