import os
import zlib
import struct

def png_to_rgb(filepath):
    with open(filepath, 'rb') as f:
        sig = f.read(8)
        if sig != b'\x89PNG\r\n\x1a\n':
            raise ValueError("Not a PNG file")
        
        chunks = []
        while True:
            len_bytes = f.read(4)
            if not len_bytes:
                break
            length = struct.unpack('>I', len_bytes)[0]
            chunk_type = f.read(4)
            chunk_data = f.read(length)
            f.read(4) # CRC
            chunks.append((chunk_type, chunk_data))
            if chunk_type == b'IEND':
                break
                
        ihdr = next(data for name, data in chunks if name == b'IHDR')
        width, height, depth, color, _, _, _ = struct.unpack('>IIBBBBB', ihdr)
        
        idat = b''.join(data for name, data in chunks if name == b'IDAT')
        decompressed = zlib.decompress(idat)
        
        if color == 2:
            bpp = 3
        elif color == 6:
            bpp = 4
        else:
            raise ValueError(f"Unsupported color type {color}")
            
        pixels = []
        scanline_width = width * bpp + 1
        prev_scanline = [0] * (width * bpp)
        
        for y in range(height):
            scanline = decompressed[y * scanline_width : (y + 1) * scanline_width]
            filter_type = scanline[0]
            current_scanline = []
            
            for x in range(width * bpp):
                val = scanline[1 + x]
                if filter_type == 0:
                    recon = val
                elif filter_type == 1:
                    recon = (val + (current_scanline[x - bpp] if x >= bpp else 0)) & 0xFF
                elif filter_type == 2:
                    recon = (val + prev_scanline[x]) & 0xFF
                elif filter_type == 3:
                    left = current_scanline[x - bpp] if x >= bpp else 0
                    up = prev_scanline[x]
                    recon = (val + ((left + up) // 2)) & 0xFF
                elif filter_type == 4:
                    left = current_scanline[x - bpp] if x >= bpp else 0
                    up = prev_scanline[x]
                    left_up = prev_scanline[x - bpp] if x >= bpp else 0
                    
                    p = left + up - left_up
                    pa = abs(p - left)
                    pb = abs(p - up)
                    pc = abs(p - left_up)
                    
                    if pa <= pb and pa <= pc:
                        paeth = left
                    elif pb <= pc:
                        paeth = up
                    else:
                        paeth = left_up
                        
                    recon = (val + paeth) & 0xFF
                current_scanline.append(recon)
            prev_scanline = current_scanline
            pixels.append(current_scanline)
            
        return width, height, bpp, pixels

def analyze_image(filepath):
    print(f"\nAnalyzing: {os.path.basename(filepath)}")
    try:
        w, h, bpp, pixels = png_to_rgb(filepath)
        print(f"  Dimensions: {w}x{h}, bpp: {bpp}")
        
        # Analyze background at corners
        top_left = pixels[10][:3]
        top_right = pixels[10][(w-11)*bpp : (w-10)*bpp]
        bottom_left = pixels[h-11][:3]
        bottom_right = pixels[h-11][(w-11)*bpp : (w-10)*bpp]
        print(f"  Top-Left Color: {top_left}")
        print(f"  Top-Right Color: {top_right}")
        print(f"  Bottom-Left Color: {bottom_left}")
        print(f"  Bottom-Right Color: {bottom_right}")
        
        # Print a simple vertical profile of darkness to find components
        # Calculate average intensity per scanline
        profile = []
        for y in range(0, h, h // 20):
            row_sum = 0
            for x in range(w):
                idx = x * bpp
                r, g, b = pixels[y][idx:idx+3]
                row_sum += (r + g + b) / 3.0
            profile.append(row_sum / w)
            
        print("  Vertical intensity profile (0=dark, 255=white):")
        for i, val in enumerate(profile):
            percentage_height = int((i * (h // 20) / h) * 100)
            bar = '#' * int(val / 10)
            print(f"    {percentage_height:3d}% height: {val:6.1f} | {bar}")
            
    except Exception as e:
        print(f"  Error: {e}")

def main():
    media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
    img1 = os.path.join(media_dir, 'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779216220038.png')
    img2 = os.path.join(media_dir, 'media_2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1_1779216653789.png')
    
    if os.path.exists(img1):
        analyze_image(img1)
    if os.path.exists(img2):
        analyze_image(img2)

if __name__ == '__main__':
    main()
