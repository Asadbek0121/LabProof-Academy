import os
from inspect_all_media import get_image_info, media_dir

html_content = """<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>User Media Inspector</title>
<style>
  body { font-family: sans-serif; background: #1a1a1a; color: #fff; padding: 20px; }
  h1 { text-align: center; color: #00e5ff; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(300px, 1fr)); gap: 20px; }
  .card { background: #2a2a2a; border-radius: 8px; padding: 15px; border: 1px solid #444; display: flex; flex-direction: column; align-items: center; }
  img { max-width: 100%; max-height: 250px; border-radius: 4px; object-fit: contain; background: #333; margin-bottom: 10px; }
  .info { font-size: 12px; word-break: break-all; margin-top: auto; width: 100%; }
</style>
</head>
<body>
<h1>User Media Inspector</h1>
<div class="grid">
"""

media_files = []
if os.path.exists(media_dir):
    for f in os.listdir(media_dir):
        path = os.path.join(media_dir, f)
        if os.path.isfile(path) and not f.startswith('.'):
            mtime = os.path.getmtime(path)
            size = os.path.getsize(path)
            media_files.append((f, size, mtime, path))

# Sort by modified time: newest first
media_files.sort(key=lambda x: x[2], reverse=True)

# Copy these files into a folder that can be loaded in browser
static_dir = '/Users/macbookairm1/Documents/New project 3/labproof_academy/scratch/static_media'
os.makedirs(static_dir, exist_ok=True)

import shutil
for name, size, mtime, path in media_files[:30]:
    dest = os.path.join(static_dir, name)
    shutil.copy2(path, dest)
    info = get_image_info(path)
    html_content += f"""
    <div class="card">
      <img src="static_media/{name}" alt="{name}">
      <div class="info">
        <strong>Filename:</strong> {name}<br>
        <strong>Size:</strong> {size} bytes<br>
        <strong>Info:</strong> {info}
      </div>
    </div>
    """

html_content += """
</div>
</body>
</html>
"""

viewer_path = '/Users/macbookairm1/Documents/New project 3/labproof_academy/scratch/image_viewer.html'
with open(viewer_path, 'w') as f:
    f.write(html_content)

print("Generated viewer at", viewer_path)
