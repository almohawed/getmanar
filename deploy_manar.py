import os
import shutil
import datetime

source_dir = r"C:\Users\asus\my\almadrasah\build\web"
dest_dir = r"C:\Users\asus\my\almadrasah\manar01"
log_file = r"C:\Users\asus\my\almadrasah\deploy_log.txt"

def log(msg):
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line)
    with open(log_file, "a", encoding="utf-8") as f:
        f.write(line + "\n")

def deploy():
    log("Starting deployment...")
    
    if not os.path.exists(source_dir):
        log(f"ERROR: Source directory {source_dir} does not exist!")
        return

    # Clean destination
    if os.path.exists(dest_dir):
        log(f"Cleaning destination {dest_dir}...")
        try:
            shutil.rmtree(dest_dir)
        except Exception as e:
            log(f"Warning: Could not delete destination: {e}")

    # Copy
    try:
        log(f"Copying from {source_dir} to {dest_dir}...")
        shutil.copytree(source_dir, dest_dir, dirs_exist_ok=True)
        log("Copy completed successfully.")
        
        # Verify
        files = os.listdir(dest_dir)
        log(f"Destination now contains {len(files)} items: {files}")
        
        if "index.html" in files:
            log("SUCCESS: index.html found in destination.")
        else:
            log("ERROR: index.html MISSING in destination.")
            
    except Exception as e:
        log(f"CRITICAL ERROR during copy: {e}")

if __name__ == "__main__":
    deploy()
