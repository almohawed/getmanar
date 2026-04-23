import shutil
import os
import sys

log_file = r"c:\Users\asus\my\almadrasah\copy_log.txt"

def log(msg):
    print(msg)
    try:
        with open(log_file, "a", encoding="utf-8") as f:
            f.write(msg + "\n")
    except Exception as e:
        print(f"Failed to log: {e}")

def main():
    if os.path.exists(log_file):
        os.remove(log_file)
        
    log("Starting Copy Process...")
    
    web_src = r"c:\Users\asus\my\almadrasah\build\web"
    apk_src = r"c:\Users\asus\my\almadrasah\build\app\outputs\apk\release\app-release.apk"
    dest_dir = r"c:\Users\asus\my\almadrasah\manar01"
    
    # 1. Check Sources
    if not os.path.exists(web_src):
        log(f"ERROR: Web build missing at {web_src}")
        return
        
    if not os.path.exists(apk_src):
        log(f"WARNING: APK build missing at {apk_src}")
        # Continue anyway for web files
        
    # 2. Clean Destination
    if os.path.exists(dest_dir):
        log(f"Cleaning {dest_dir}...")
        try:
            for filename in os.listdir(dest_dir):
                file_path = os.path.join(dest_dir, filename)
                try:
                    if os.path.isfile(file_path) or os.path.islink(file_path):
                        os.unlink(file_path)
                    elif os.path.isdir(file_path):
                        shutil.rmtree(file_path)
                except Exception as e:
                    log(f"Failed to delete {file_path}: {e}")
        except Exception as e:
            log(f"Error listing directory: {e}")
    else:
        os.makedirs(dest_dir)
        
    # 3. Copy Web Files
    try:
        log("Copying Web files...")
        shutil.copytree(web_src, dest_dir, dirs_exist_ok=True)
        log("Web files copied successfully.")
    except Exception as e:
        log(f"ERROR copying Web files: {e}")
        return

    # 4. Copy APK
    if os.path.exists(apk_src):
        try:
            apk_dest = os.path.join(dest_dir, "app-release.apk")
            shutil.copy2(apk_src, apk_dest)
            log(f"APK copied to {apk_dest}")
        except Exception as e:
            log(f"ERROR copying APK: {e}")
    
    log("Copy Process Complete.")

if __name__ == "__main__":
    main()
