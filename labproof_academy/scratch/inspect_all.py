import os
import struct

def get_image_info(filepath):
    try:
        size = os.path.getsize(filepath)
        with open(filepath, 'rb') as f:
            head = f.read(24)
            # Check if PNG
            if head.startswith(b'\x89PNG\r\n\x1a\n'):
                width, height = struct.unpack('>II', head[16:24])
                return {"type": "PNG", "width": width, "height": height, "size": size}
            # Check if JPEG
            elif head.startswith(b'\xff\xd8'):
                f.seek(0)
                f.read(2)
                b = f.read(1)
                while b and ord(b) != 0xda: # start of scan
                    while ord(b) != 0xff: b = f.read(1)
                    while ord(b) == 0xff: b = f.read(1)
                    if 0xc0 <= ord(b) <= 0xc3: # SOF0, SOF1, SOF2
                        f.read(3)
                        h, w = struct.unpack('>HH', f.read(4))
                        return {"type": "JPEG", "width": w, "height": h, "size": size}
                    else:
                        l = struct.unpack('>H', f.read(2))[0]
                        f.read(l - 2)
                    b = f.read(1)
                return {"type": "JPEG", "size": size}
            else:
                return {"type": "Unknown", "size": size}
    except Exception as e:
        return {"error": str(e), "size": os.path.getsize(filepath) if os.path.exists(filepath) else 0}

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = sorted(os.listdir(media_dir))

for f in files:
    if f.startswith('media_'):
        path = os.path.join(media_dir, f)
        info = get_image_info(path)
        print(f"{f}: {info}")
