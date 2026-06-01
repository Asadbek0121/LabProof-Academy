import os
import subprocess

media_dir = '/Users/macbookairm1/.gemini/antigravity/brain/2cca9ccc-8994-47e7-bfdd-d44b8a7d25b1/.tempmediaStorage'
ocr_bin = '/Users/macbookairm1/Documents/New project 3/labproof_academy/scratch/ocr'

# Find the files starting with 1779122
files = []
if os.path.exists(media_dir):
    for f in os.listdir(media_dir):
        if '1779122' in f:
            files.append(f)

# Sort files to match the chronological order
files.sort()

# Check if ocr exists, if not wait a bit
if not os.path.exists(ocr_bin):
    print("OCR binary not found yet. Running swiftc directly via python to see output...")
    # Let's compile synchronously to see errors if any
    res = subprocess.run(['swiftc', 'run_ocr.swift', '-o', 'ocr'], cwd='/Users/macbookairm1/Documents/New project 3/labproof_academy/scratch', capture_output=True, text=True)
    print("STDOUT:", res.stdout)
    print("STDERR:", res.stderr)

if os.path.exists(ocr_bin):
    print(f"Running OCR on {len(files)} files...")
    for f in files:
        path = os.path.join(media_dir, f)
        print("\n" + "="*50)
        print(f"FILE: {f}")
        print("="*50)
        res = subprocess.run([ocr_bin, path], capture_output=True, text=True)
        print(res.stdout)
        if res.stderr:
            print("ERR:", res.stderr)
else:
    print("OCR binary compilation failed.")
