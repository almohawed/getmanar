import os

files = [
    r"c:\Users\asus\my\almadrasah\build\web\flutter_service_worker.js",
    r"c:\Users\asus\my\almadrasah\build\web\assets\fonts\MaterialIcons-Regular.otf",
    r"c:\Users\asus\my\almadrasah\build\web\assets\packages\cupertino_icons\assets\CupertinoIcons.ttf",
    r"c:\Users\asus\my\almadrasah\build\web\assets\shaders\ink_sparkle.frag",
    r"c:\Users\asus\my\almadrasah\build\web\assets\NOTICES",
    r"c:\Users\asus\my\almadrasah\build\web\assets\FontManifest.json",
    r"c:\Users\asus\my\almadrasah\build\web\assets\AssetManifest.json",
    r"c:\Users\asus\my\almadrasah\build\web\assets\AssetManifest.bin.json",
    r"c:\Users\asus\my\almadrasah\build\web\assets\AssetManifest.bin",
    r"c:\Users\asus\my\almadrasah\build\web\version.json",
    r"c:\Users\asus\my\almadrasah\build\web\main.dart.js",
    r"c:\Users\asus\my\almadrasah\build\web\index.html",
    r"c:\Users\asus\my\almadrasah\build\web\flutter_bootstrap.js",
    r"c:\Users\asus\my\almadrasah\build\web\.last_build_id",
    r"c:\Users\asus\my\almadrasah\build\web\assets\assets\templet\schedule_template.xlsx",
    r"c:\Users\asus\my\almadrasah\build\web\assets\assets\templet\tetchar.xlsx",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\logo1.png",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\%D8%AA%D9%86%D8%B2%D9%8A%D9%84.png",
    r"c:\Users\asus\my\almadrasah\build\web\app_download.html",
    r"c:\Users\asus\my\almadrasah\build\web\manifest.json",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\backweb.png",
    r"c:\Users\asus\my\almadrasah\build\web\web.config",
    r"c:\Users\asus\my\almadrasah\build\web\.htaccess",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\iconeapps.png",
    r"c:\Users\asus\my\almadrasah\build\web\logo.png",
    r"c:\Users\asus\my\almadrasah\build\web\icons\Icon-maskable-512.png",
    r"c:\Users\asus\my\almadrasah\build\web\icons\Icon-maskable-192.png",
    r"c:\Users\asus\my\almadrasah\build\web\icons\Icon-512.png",
    r"c:\Users\asus\my\almadrasah\build\web\icons\Icon-192.png",
    r"c:\Users\asus\my\almadrasah\build\web\favicon.png",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\mylogo.png",
    r"c:\Users\asus\my\almadrasah\build\web\assets\assets\templet\ww.xlsx",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\logokshuf.webp",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\icone.png",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\loco1cone.png",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\logo.png",
    r"c:\Users\asus\my\almadrasah\build\web\assets\images\logoicone.png",
    r"c:\Users\asus\my\almadrasah\build\web\flutter.js",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\skwasm.wasm",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\skwasm.js.symbols",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\skwasm.js",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\chromium\canvaskit.wasm",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\chromium\canvaskit.js.symbols",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\chromium\canvaskit.js",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\canvaskit.wasm",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\canvaskit.js.symbols",
    r"c:\Users\asus\my\almadrasah\build\web\canvaskit\canvaskit.js"
]

dst_root = r"c:\Users\asus\my\almadrasah\manar01"
src_root = r"c:\Users\asus\my\almadrasah\build\web"

try:
    with open("copy_manual.bat", "w", encoding="utf-8") as f:
        f.write("@echo off\n")
        f.write("echo Starting Batch Copy...\n")
        f.write(f'if not exist "{dst_root}" mkdir "{dst_root}"\n')
        
        # We need to sort files to ensure directories are created in order, 
        # or just handle directory creation for each file.
        # Set to track created dirs
        dirs_seen = set()
        dirs_seen.add(dst_root)

        for src in files:
            try:
                rel = os.path.relpath(src, src_root)
                dst = os.path.join(dst_root, rel)
                dst_dir = os.path.dirname(dst)
                
                # Walk up to create all parents if needed (mkdir -p logic)
                # But 'mkdir "a\b\c"' in cmd creates intermediates automatically usually?
                # Actually `mkdir a\b\c` works.
                
                if dst_dir not in dirs_seen:
                     f.write(f'if not exist "{dst_dir}" mkdir "{dst_dir}"\n')
                     dirs_seen.add(dst_dir)
                
                f.write(f'copy /Y "{src}" "{dst}" >nul\n')
            except Exception as e:
                print(f"Skipping {src}: {e}")
                
        f.write("echo Copy Batch Completed.\n")
    print("Batch file generated successfully.")
except Exception as e:
    print(f"Error generating batch: {e}")
