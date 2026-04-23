import os
import sys

src = r"c:\Users\asus\my\almadrasah\build\app\outputs\apk\release\app-release.apk"
dst = r"c:\Users\asus\my\almadrasah\manar01\app-release.apk"
log_file = r"c:\Users\asus\my\almadrasah\copy_log.txt"

def log(msg):
    print(msg)
    try:
        with open(log_file, "a") as f:
            f.write(msg + "\n")
    except:
        pass

log(f"Starting manual copy from {src} to {dst}")

try:
    with open(src, 'rb') as f_src:
        with open(dst, 'wb') as f_dst:
            log("Files opened. Copying...")
            while True:
                chunk = f_src.read(1024*1024) # 1MB chunks
                if not chunk:
                    break
                f_dst.write(chunk)
    
    log("Copy loop finished.")
    
    if os.path.exists(dst):
        size = os.path.getsize(dst)
        log(f"SUCCESS: File copied. Size: {size} bytes")
    else:
        log("ERROR: File not found at destination after copy.")
        
except Exception as e:
    log(f"EXCEPTION: {e}")
