import os
import struct

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'

def get_image_info(path):
    size = os.path.getsize(path)
    # read start of file
    with open(path, 'rb') as f:
        head = f.read(30)
    
    if head.startswith(b'\x89PNG\r\n\x1a\n'):
        # parse PNG dimensions
        width, height = struct.unpack('>II', head[16:24])
        return f"PNG, {width}x{height}, {size} bytes"
    elif head.startswith(b'\xff\xd8'):
        # Just return JPEG and size
        return f"JPEG, {size} bytes"
    else:
        return f"Unknown format, {size} bytes (sig: {head[:4]})"

if os.path.exists(media_dir):
    files = sorted(os.listdir(media_dir))
    print(f"Total files in tempmediaStorage: {len(files)}")
    for f in files:
        if f.startswith('.'):
            continue
        path = os.path.join(media_dir, f)
        info = get_image_info(path)
        print(f"{f}: {info}")
else:
    print("Directory does not exist!")
