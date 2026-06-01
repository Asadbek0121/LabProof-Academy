import os
try:
    from PIL import Image
    print("Pillow is installed!")
    
    media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
    f = 'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779122666338.jpg'
    path = os.path.join(media_dir, f)
    if os.path.exists(path):
        img = Image.open(path)
        print(f"Format: {img.format}, Size: {img.size}, Mode: {img.mode}")
    else:
        print("Image not found!")
except Exception as e:
    print(f"Error: {e}")
