import os
import struct

def parse_png(filepath):
    try:
        with open(filepath, 'rb') as f:
            sig = f.read(8)
            if sig != b'\x89PNG\r\n\x1a\n':
                return None
            f.read(4) # length
            f.read(4) # type
            w, h = struct.unpack('>II', f.read(8))
            return w, h
    except:
        return None

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
for f in sorted(os.listdir(media_dir)):
    if f.endswith('.png'):
        path = os.path.join(media_dir, f)
        dim = parse_png(path)
        if dim:
            print(f"{f}: {dim[0]}x{dim[1]} ({os.path.getsize(path)} bytes)")
