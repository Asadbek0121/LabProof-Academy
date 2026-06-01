import os
import hashlib

def get_md5(filepath):
    hasher = hashlib.md5()
    with open(filepath, 'rb') as f:
        buf = f.read()
        hasher.update(buf)
    return hasher.hexdigest()

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = sorted([f for f in os.listdir(media_dir) if f.endswith(('.png', '.jpg', '.jpeg'))])

hashes = {}
for f in files:
    path = os.path.join(media_dir, f)
    h = get_md5(path)
    if h not in hashes:
        hashes[h] = []
    hashes[h].append(f)

print("Unique file groups by hash:")
group_idx = 1
for h, fs in hashes.items():
    print(f"Group {group_idx} (hash={h}):")
    for f in fs:
        print(f"  {f}")
    group_idx += 1
