import os
import shutil
import struct

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
dest_dir = '/Users/macbookairm1/Documents/New project 3/labproof_academy/scratch/gallery_images'
html_path = '/Users/macbookairm1/Documents/New project 3/labproof_academy/scratch/gallery.html'

os.makedirs(dest_dir, exist_ok=True)

def get_image_info(path):
    size = os.path.getsize(path)
    with open(path, 'rb') as f:
        head = f.read(30)
    if head.startswith(b'\x89PNG\r\n\x1a\n'):
        width, height = struct.unpack('>II', head[16:24])
        return "PNG", f"{width}x{height}", size
    elif head.startswith(b'\xff\xd8'):
        return "JPEG", "unknown", size
    else:
        return "Unknown", "unknown", size

html_content = """
<!DOCTYPE html>
<html>
<head>
    <title>Media Gallery</title>
    <style>
        body { font-family: sans-serif; background: #121212; color: #fff; margin: 20px; }
        h1 { border-bottom: 1px solid #333; padding-bottom: 10px; }
        .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
        .card { background: #1e1e1e; border: 1px solid #333; border-radius: 8px; overflow: hidden; padding: 10px; }
        .card img { max-width: 100%; height: auto; display: block; border-radius: 4px; background: #000; }
        .info { margin-top: 10px; font-size: 13px; line-height: 1.4; }
        .filename { font-weight: bold; word-break: break-all; color: #00bcd4; }
    </style>
</head>
<body>
    <h1>Media Storage Gallery</h1>
    <div class="grid">
"""

files = sorted(os.listdir(media_dir))
for f in files:
    if f.startswith('.'):
        continue
    src_path = os.path.join(media_dir, f)
    if not os.path.isfile(src_path):
        continue
    
    # Get image info
    fmt, dims, size = get_image_info(src_path)
    
    # Copy to scratch destination
    dest_path = os.path.join(dest_dir, f)
    shutil.copy2(src_path, dest_path)
    
    # Add to HTML
    html_content += f"""
        <div class="card">
            <img src="gallery_images/{f}" alt="{f}">
            <div class="info">
                <div class="filename">{f}</div>
                <div>Format: {fmt}</div>
                <div>Dimensions: {dims}</div>
                <div>Size: {size:,} bytes</div>
            </div>
        </div>
    """

html_content += """
    </div>
</body>
</html>
"""

with open(html_path, 'w', encoding='utf-8') as f:
    f.write(html_content)

print(f"Gallery HTML generated at {html_path}")
