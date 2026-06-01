import os
import struct

def parse_png(filepath):
    try:
        with open(filepath, 'rb') as f:
            sig = f.read(8)
            if sig != b'\x89PNG\r\n\x1a\n':
                return "Not a PNG file"
            # Read IHDR chunk
            length_bytes = f.read(4)
            chunk_type = f.read(4)
            if chunk_type != b'IHDR':
                return "IHDR chunk not first"
            width, height, bit_depth, color_type, compression, filter_method, interlace = struct.unpack('>IIBBBBB', f.read(13))
            return {
                "width": width,
                "height": height,
                "bit_depth": bit_depth,
                "color_type": color_type,
                "compression": compression,
                "filter_method": filter_method,
                "interlace": interlace
            }
    except Exception as e:
        return f"Error: {e}"

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = [
    'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779105720318.png',
    'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779105723727.png',
    'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779105727309.png',
    'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779105731454.png'
]

print("PNG properties:")
for f in files:
    path = os.path.join(media_dir, f)
    if os.path.exists(path):
        res = parse_png(path)
        print(f"File: {f}")
        print(f"  Metadata: {res}")
    else:
        print(f"File {f} not found!")

