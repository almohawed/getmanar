import shutil
import os

src = r"c:\Users\asus\my\almadrasah\build\app\outputs\apk\release\app-release.apk"
dst = r"c:\Users\asus\my\almadrasah\manar01\app-release.apk"

print(f"Copying from {src} to {dst}")
try:
    shutil.copy2(src, dst)
    print("Copy successful")
    print(f"Destination size: {os.path.getsize(dst)}")
except Exception as e:
    print(f"Error: {e}")
