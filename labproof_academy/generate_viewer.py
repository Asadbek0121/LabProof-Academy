import os
import datetime

def main():
    dirs = [
        '/Users/macbookairm1/.gemini/antigravity/brain/156efca1-8b29-4d5f-9eea-8414f280a23f',
        '/Users/macbookairm1/.gemini/antigravity/brain/156efca1-8b29-4d5f-9eea-8414f280a23f/.tempmediaStorage'
    ]
    
    items = []
    for d in dirs:
        if not os.path.exists(d):
            continue
        for f in os.listdir(d):
            if f.endswith(('.png', '.jpg', '.jpeg')):
                full_path = os.path.join(d, f)
                mtime = os.path.getmtime(full_path)
                items.append((f, full_path, mtime))
                
    # Sort by mtime descending
    items.sort(key=lambda x: x[2], reverse=True)
    
    html = """<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <title>All Media Files</title>
  <style>
    body { font-family: sans-serif; background: #0f172a; color: #cbd5e1; padding: 20px; }
    h1 { text-align: center; color: #a78bfa; }
    .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(320px, 1fr)); gap: 20px; }
    .card { background: #1e293b; border-radius: 12px; padding: 12px; border: 1px solid #334155; display: flex; flex-direction: column; align-items: center; }
    .card img { max-width: 100%; max-height: 500px; border-radius: 8px; margin-bottom: 8px; object-fit: contain; background: #000; }
    .name { font-size: 13px; font-weight: bold; word-break: break-all; text-align: center; color: #f8fafc; }
    .time { font-size: 11px; color: #94a3b8; margin-top: 4px; }
    .path { font-size: 10px; color: #64748b; margin-top: 4px; word-break: break-all; text-align: center; }
  </style>
</head>
<body>
  <h1>All Media Files (Sorted by Newest)</h1>
  <div class="grid">
"""
    
    for f, path, mtime in items:
        dt = datetime.datetime.fromtimestamp(mtime).strftime('%Y-%m-%d %H:%M:%S')
        # We need a file:// URL that is absolute
        file_url = f"file://{path}"
        html += f"""
    <div class="card">
      <img src="{file_url}" alt="{f}">
      <div class="name">{f}</div>
      <div class="time">{dt}</div>
      <div class="path">{path}</div>
    </div>
"""
        
    html += """
  </div>
</body>
</html>
"""
    
    out_path = '/Users/macbookairm1/Documents/New project 3/labproof_academy/my_media_viewer.html'
    with open(out_path, 'w') as f:
        f.write(html)
        
    print(f"Generated {out_path} with {len(items)} media files.")

if __name__ == '__main__':
    main()
