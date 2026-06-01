import os
import struct

def parse_image(filepath):
    try:
        with open(filepath, 'rb') as f:
            sig = f.read(8)
            if sig == b'\x89PNG\r\n\x1a\n':
                # Read IHDR
                f.read(4) # length
                f.read(4) # type
                w, h = struct.unpack('>II', f.read(8))
                return f"PNG: {w}x{h}"
            elif sig.startswith(b'\xff\xd8'):
                # JPEG
                f.seek(0)
                size = os.path.getsize(filepath)
                f.read(2)
                while True:
                    marker, length = struct.unpack('>HH', f.read(4))
                    if marker & 0xff00 != 0xff00:
                        break
                    if marker in (0xffc0, 0xffc2): # SOF0, SOF2
                        f.read(1) # precision
                        h, w = struct.unpack('>HH', f.read(4))
                        return f"JPEG: {w}x{h}"
                    f.seek(length - 2, 1)
                return "JPEG: unknown size"
    except Exception as e:
        return f"Error: {e}"

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
for f in sorted(os.listdir(media_dir)):
    if '1779122' in f:
        path = os.path.join(media_dir, f)
        print(f"{f}: {parse_image(path)} ({os.path.getsize(path)} bytes)")
