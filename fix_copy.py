import os
import shutil
import sys

source_dir = r"C:\Users\asus\my\almadrasah\build\web"
dest_dir = r"C:\Users\asus\my\almadrasah\manar01"

print(f"Source: {source_dir}")
print(f"Destination: {dest_dir}")

# 1. Verify Source
if not os.path.exists(source_dir):
    print("ERROR: Source directory does not exist!")
    sys.exit(1)

files = os.listdir(source_dir)
print(f"Source contains {len(files)} items.")
if len(files) == 0:
    print("ERROR: Source directory is empty!")
    sys.exit(1)

# 2. Prepare Destination
if os.path.exists(dest_dir):
    print("Cleaning destination...")
    try:
        shutil.rmtree(dest_dir)
    except Exception as e:
        print(f"Error removing destination: {e}")
        # Try to continue anyway
else:
    print("Destination does not exist, creating...")

# 3. Copy
print("Copying...")
try:
    shutil.copytree(source_dir, dest_dir)
    print("Copy completed successfully.")
except FileExistsError:
    # Fallback if rmtree failed partialy
    print("Destination exists, trying copy with dirs_exist_ok=True...")
    shutil.copytree(source_dir, dest_dir, dirs_exist_ok=True)
except Exception as e:
    print(f"CRITICAL ERROR COPYING: {e}")
    sys.exit(1)

# 4. Verify Destination
if os.path.exists(dest_dir):
    dest_files = os.listdir(dest_dir)
    print(f"Destination now contains {len(dest_files)} items.")
    print("Listing first 10 items:")
    for f in dest_files[:10]:
        print(f" - {f}")
else:
    print("ERROR: Destination directory not found after copy!")
