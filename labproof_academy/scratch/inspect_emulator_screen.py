import os
import struct

def get_image_info(filepath):
    try:
        with open(filepath, 'rb') as f:
            head = f.read(24)
            if head.startswith(b'\x89PNG\r\n\x1a\n'):
                w, h = struct.unpack('>ii', head[16:24])
                return w, h, 'PNG'
            elif head.startswith(b'\xff\xd8'):
                f.seek(0)
                data = f.read()
                i = 0
                while i < len(data) - 8:
                    if data[i] == 0xFF and data[i+1] in [0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF]:
                        h, w = struct.unpack('>HH', data[i+5:i+9])
                        return w, h, 'JPEG'
                    i += 1
    except Exception as e:
        return str(e)
    return None

workspace_root = '/Users/macbookairm1/Documents/New project 3'
print("emulator_screen.png:", get_image_info(os.path.join(workspace_root, 'emulator_screen.png')))
