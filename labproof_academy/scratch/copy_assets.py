import os
import shutil

src_path = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage/media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779122666338.jpg'
dest_path = '/Users/macbookairm1/Documents/New project 3/labproof_academy/assets/images/telegram_verification_illustration.jpg'

if os.path.exists(src_path):
    os.makedirs(os.path.dirname(dest_path), exist_ok=True)
    shutil.copy(src_path, dest_path)
    print(f"Successfully copied to {dest_path}")
    print(f"Size of copied file: {os.path.getsize(dest_path)} bytes")
else:
    print(f"Source file not found at {src_path}")
