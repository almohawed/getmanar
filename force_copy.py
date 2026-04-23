import os
import shutil

source_dir = r"C:\Users\asus\my\almadrasah\build\web"
dest_dir = r"C:\Users\asus\my\almadrasah\manar01"
log_file = r"C:\Users\asus\my\almadrasah\manar01\force_copy_log.txt"

def log(message):
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(message + "\n")
    except:
        pass
    print(message)

if not os.path.exists(dest_dir):
    try:
        os.makedirs(dest_dir)
        log(f"Created directory: {dest_dir}")
    except Exception as e:
        log(f"Failed to create directory {dest_dir}: {e}")

if not os.path.exists(source_dir):
    log(f"Source directory does not exist: {source_dir}")
    exit(1)

count = 0
errors = 0

for root, dirs, files in os.walk(source_dir):
    # Create corresponding dirs in dest
    rel_path = os.path.relpath(root, source_dir)
    dest_root = os.path.join(dest_dir, rel_path)
    
    if not os.path.exists(dest_root):
        try:
            os.makedirs(dest_root)
        except Exception as e:
            log(f"Failed to create dir {dest_root}: {e}")
            continue

    for file in files:
        src_file = os.path.join(root, file)
        dst_file = os.path.join(dest_root, file)
        
        try:
            # Read and write explicitly
            with open(src_file, 'rb') as f_src:
                content = f_src.read()
            with open(dst_file, 'wb') as f_dst:
                f_dst.write(content)
            count += 1
            if count % 10 == 0:
                log(f"Copied {count} files...")
        except Exception as e:
            log(f"Failed to copy {src_file} to {dst_file}: {e}")
            errors += 1

log(f"Finished. Copied: {count}, Errors: {errors}")
