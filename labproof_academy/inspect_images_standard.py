import os
import struct

def get_image_info(filepath):
    """Returns (width, height, format) of an image using standard libraries."""
    try:
        with open(filepath, 'rb') as f:
            head = f.read(24)
            if len(head) < 24:
                return None
            if head.startswith(b'\x89PNG\r\n\x1a\n'):
                w, h = struct.unpack('>ii', head[16:24])
                return w, h, 'PNG'
            elif head.startswith(b'\xff\xd8'):
                f.seek(0)
                # Read all file bytes to find SOF markers robustly
                data = f.read()
                i = 0
                while i < len(data) - 8:
                    if data[i] == 0xFF and data[i+1] in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]:
                        # SOF marker found
                        h, w = struct.unpack('>HH', data[i+5:i+9])
                        return w, h, 'JPEG'
                    i += 1
    except Exception as e:
        pass
    return None

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = sorted([f for f in os.listdir(media_dir) if f.endswith(('.png', '.jpg', '.jpeg'))])

print(f"Found {len(files)} files:")
for f in files:
    path = os.path.join(media_dir, f)
    info = get_image_info(path)
    if info:
        print(f"  {f}: format={info[2]}, size={info[0]}x{info[1]}")
    else:
        print(f"  {f}: Unknown format")
