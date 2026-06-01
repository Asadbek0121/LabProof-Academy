import os
import struct

def analyze_png_transparency(filepath):
    """Analyzes a PNG file to see if it is transparent (has alpha channel)."""
    try:
        with open(filepath, 'rb') as f:
            signature = f.read(8)
            if signature != b'\x89PNG\r\n\x1a\n':
                return "Not a PNG"
            # Read chunks
            has_alpha = False
            has_trns = False
            while True:
                length_bytes = f.read(4)
                if not length_bytes or len(length_bytes) < 4:
                    break
                length = struct.unpack('>I', length_bytes)[0]
                chunk_type = f.read(4)
                if chunk_type == b'IHDR':
                    ihdr_data = f.read(13)
                    color_type = ihdr_data[9]
                    # Color types: 4 (grayscale+alpha), 6 (truecolor+alpha)
                    if color_type in [4, 6]:
                        has_alpha = True
                    f.read(length - 13 + 4) # Skip rest and CRC
                elif chunk_type == b'tRNS':
                    has_trns = True
                    f.read(length + 4)
                elif chunk_type == b'IEND':
                    break
                else:
                    f.read(length + 4)
            
            if has_alpha:
                return "Has Alpha Channel (color type 4 or 6)"
            elif has_trns:
                return "Has tRNS chunk (transparency palette)"
            else:
                return "No transparency"
    except Exception as e:
        return f"Error: {e}"

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
files = sorted([f for f in os.listdir(media_dir) if f.endswith('.png')])

print("PNG Transparency Analysis:")
for f in files:
    path = os.path.join(media_dir, f)
    result = analyze_png_transparency(path)
    print(f"  {f}: {result}")
