import os
import struct

def get_image_info(path):
    with open(path, 'rb') as f:
        data = f.read(100)
        # Check if PNG
        if data.startswith(b'\x89PNG\r\n\x1a\n'):
            w, h = struct.unpack('>ii', data[16:24])
            return 'PNG', w, h
        # Check if JPEG
        elif data.startswith(b'\xff\xd8'):
            f.seek(0)
            size = os.path.getsize(path)
            f.read(2)
            while True:
                marker, = struct.unpack('>H', f.read(2))
                if marker == 0xffd9 or marker == 0x0000: # EOI or invalid
                    break
                length, = struct.unpack('>H', f.read(2))
                if 0xffc0 <= marker <= 0xffc3: # SOF0 - SOF3
                    f.read(1) # precision
                    h, w = struct.unpack('>HH', f.read(4))
                    return 'JPEG', w, h
                else:
                    f.seek(length - 2, 1)
    return 'Unknown', 0, 0

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
latest_prefixes = ['media__']
for f in sorted(os.listdir(os.path.dirname(media_dir))):
    if any(prefix in f for prefix in latest_prefixes):
        path = os.path.join(os.path.dirname(media_dir), f)
        try:
            fmt, w, h = get_image_info(path)
            print(f"{f}: {fmt} {w}x{h} ({os.path.getsize(path)} bytes)")
        except Exception as e:
            print(f"{f}: Error {e}")
