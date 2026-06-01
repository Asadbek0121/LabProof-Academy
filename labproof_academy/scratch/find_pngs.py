import os

brain_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1'
png_files = []

for root, dirs, files in os.walk(brain_dir):
    for f in files:
        if f.endswith('.png'):
            path = os.path.join(root, f)
            png_files.append((path, os.path.getsize(path)))

print("PNG files found in brain directory:")
for path, size in sorted(png_files, key=lambda x: x[1]):
    print(f"{path}: {size} bytes")
