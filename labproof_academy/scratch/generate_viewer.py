import os

temp_images_dir = 'scratch/temp_images'
files = sorted([f for f in os.listdir(temp_images_dir) if f.endswith(('.png', '.jpg', '.jpeg'))])

html_content = """<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>LabProof Academy Media Viewer</title>
  <style>
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Helvetica, Arial, sans-serif;
      background-color: #0f172a;
      color: #e2e8f0;
      padding: 40px;
    }
    h1 {
      text-align: center;
      margin-bottom: 40px;
      color: #7c3aed;
    }
    .grid {
      display: grid;
      grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
      gap: 30px;
    }
    .card {
      background-color: #1e293b;
      border-radius: 12px;
      padding: 16px;
      border: 1px solid #334155;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .card img {
      max-width: 100%;
      max-height: 250px;
      border-radius: 8px;
      margin-bottom: 12px;
      object-fit: contain;
      background-color: #0b0f19;
    }
    .filename {
      font-size: 14px;
      font-weight: bold;
      word-break: break-all;
      text-align: center;
      margin-bottom: 8px;
      color: #f1f5f9;
    }
  </style>
</head>
<body>
  <h1>LabProof Academy Media Viewer</h1>
  <div class="grid">
"""

for f in files:
    html_content += f"""    <div class="card">
      <img src="temp_images/{f}" alt="{f}">
      <div class="filename">{f}</div>
    </div>
"""

html_content += """  </div>
</body>
</html>
"""

with open('scratch/media_viewer.html', 'w') as out:
    out.write(html_content)

print(f"Successfully generated scratch/media_viewer.html with {len(files)} files.")
