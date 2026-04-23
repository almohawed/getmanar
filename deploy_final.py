import shutil
import os

# Paths
apk_src = r"c:\Users\asus\my\almadrasah\build\app\outputs\apk\release\app-release.apk"
web_src = r"c:\Users\asus\my\almadrasah\build\web"
dest_root = r"c:\Users\asus\my\almadrasah\manar01"
apk_dest = os.path.join(dest_root, "app-release.apk")

print("Starting deployment...")

# 1. Copy APK
if os.path.exists(apk_src):
    print(f"Found APK at {apk_src}")
    try:
        shutil.copy2(apk_src, apk_dest)
        print(f"Successfully copied APK to {apk_dest}")
    except Exception as e:
        print(f"Error copying APK: {e}")
else:
    print(f"Error: APK source not found at {apk_src}")

# 2. Copy Web Files
if os.path.exists(web_src):
    print(f"Found Web build at {web_src}")
    try:
        # Copy content of build/web to manar01
        for item in os.listdir(web_src):
            s = os.path.join(web_src, item)
            d = os.path.join(dest_root, item)
            if os.path.isdir(s):
                if os.path.exists(d):
                    shutil.rmtree(d)
                shutil.copytree(s, d)
            else:
                shutil.copy2(s, d)
        print(f"Successfully deployed Web build to {dest_root}")
    except Exception as e:
        print(f"Error copying Web files: {e}")
else:
    print(f"Error: Web source not found at {web_src}")

print("Deployment complete.")
