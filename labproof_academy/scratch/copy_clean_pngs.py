import os
import shutil

brain_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1'
assets_dir = '/Users/macbookairm1/Documents/New project 3/labproof_academy/assets/images'

os.makedirs(assets_dir, exist_ok=True)

mappings = {
    'media__1779122849126.png': 'onboarding_1.png', # Microscope
    'media__1779122837114.png': 'onboarding_2.png', # Video/Laptop
    'media__1779122856253.png': 'onboarding_3.png', # Certificate
    'media__1779122864037.png': 'onboarding_welcome.png' # Welcome
}

for src_name, dest_name in mappings.items():
    src_path = os.path.join(brain_dir, src_name)
    dest_path = os.path.join(assets_dir, dest_name)
    if os.path.exists(src_path):
        shutil.copy2(src_path, dest_path)
        print(f"Copied {src_name} to {dest_name} successfully!")
    else:
        print(f"Source file {src_name} not found in brain directory!")
