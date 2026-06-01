import os

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = []
for f in os.listdir(media_dir):
    path = os.path.join(media_dir, f)
    if os.path.isfile(path):
        files.append((f, os.path.getmtime(path), os.path.getsize(path)))

files.sort(key=lambda x: x[1], reverse=True)
print("Latest files in tempmediaStorage:")
for name, mtime, size in files[:15]:
    print(f"File: {name}, Modified: {mtime}, Size: {size} bytes")
