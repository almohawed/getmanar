@echo off
mkdir "c:\Users\asus\my\almadrasah\manar01" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\fonts" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\packages" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\packages\cupertino_icons" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\packages\cupertino_icons\assets" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\shaders" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\assets" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\assets\templet" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\assets\images" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\icons" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\canvaskit" 2>nul
mkdir "c:\Users\asus\my\almadrasah\manar01\canvaskit\chromium" 2>nul

copy /Y "c:\Users\asus\my\almadrasah\build\app\outputs\apk\release\app-release.apk" "c:\Users\asus\my\almadrasah\manar01\app-release.apk"
copy /Y "c:\Users\asus\my\almadrasah\build\web\flutter_service_worker.js" "c:\Users\asus\my\almadrasah\manar01\flutter_service_worker.js"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\fonts\MaterialIcons-Regular.otf" "c:\Users\asus\my\almadrasah\manar01\assets\fonts\MaterialIcons-Regular.otf"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\packages\cupertino_icons\assets\CupertinoIcons.ttf" "c:\Users\asus\my\almadrasah\manar01\assets\packages\cupertino_icons\assets\CupertinoIcons.ttf"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\shaders\ink_sparkle.frag" "c:\Users\asus\my\almadrasah\manar01\assets\shaders\ink_sparkle.frag"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\NOTICES" "c:\Users\asus\my\almadrasah\manar01\assets\NOTICES"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\FontManifest.json" "c:\Users\asus\my\almadrasah\manar01\assets\FontManifest.json"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\AssetManifest.json" "c:\Users\asus\my\almadrasah\manar01\assets\AssetManifest.json"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\AssetManifest.bin.json" "c:\Users\asus\my\almadrasah\manar01\assets\AssetManifest.bin.json"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\AssetManifest.bin" "c:\Users\asus\my\almadrasah\manar01\assets\AssetManifest.bin"
copy /Y "c:\Users\asus\my\almadrasah\build\web\version.json" "c:\Users\asus\my\almadrasah\manar01\version.json"
copy /Y "c:\Users\asus\my\almadrasah\build\web\main.dart.js" "c:\Users\asus\my\almadrasah\manar01\main.dart.js"
copy /Y "c:\Users\asus\my\almadrasah\build\web\index.html" "c:\Users\asus\my\almadrasah\manar01\index.html"
copy /Y "c:\Users\asus\my\almadrasah\build\web\flutter_bootstrap.js" "c:\Users\asus\my\almadrasah\manar01\flutter_bootstrap.js"
copy /Y "c:\Users\asus\my\almadrasah\build\web\.last_build_id" "c:\Users\asus\my\almadrasah\manar01\.last_build_id"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\assets\templet\schedule_template.xlsx" "c:\Users\asus\my\almadrasah\manar01\assets\assets\templet\schedule_template.xlsx"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\assets\templet\tetchar.xlsx" "c:\Users\asus\my\almadrasah\manar01\assets\assets\templet\tetchar.xlsx"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\logo1.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\logo1.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\%%D8%%AA%%D9%%86%%D8%%B2%%D9%%8A%%D9%%84.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\%%D8%%AA%%D9%%86%%D8%%B2%%D9%%8A%%D9%%84.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\app_download.html" "c:\Users\asus\my\almadrasah\manar01\app_download.html"
copy /Y "c:\Users\asus\my\almadrasah\build\web\manifest.json" "c:\Users\asus\my\almadrasah\manar01\manifest.json"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\backweb.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\backweb.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\web.config" "c:\Users\asus\my\almadrasah\manar01\web.config"
copy /Y "c:\Users\asus\my\almadrasah\build\web\.htaccess" "c:\Users\asus\my\almadrasah\manar01\.htaccess"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\iconeapps.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\iconeapps.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\logo.png" "c:\Users\asus\my\almadrasah\manar01\logo.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\icons\Icon-maskable-512.png" "c:\Users\asus\my\almadrasah\manar01\icons\Icon-maskable-512.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\icons\Icon-maskable-192.png" "c:\Users\asus\my\almadrasah\manar01\icons\Icon-maskable-192.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\icons\Icon-512.png" "c:\Users\asus\my\almadrasah\manar01\icons\Icon-512.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\icons\Icon-192.png" "c:\Users\asus\my\almadrasah\manar01\icons\Icon-192.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\favicon.png" "c:\Users\asus\my\almadrasah\manar01\favicon.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\mylogo.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\mylogo.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\assets\templet\ww.xlsx" "c:\Users\asus\my\almadrasah\manar01\assets\assets\templet\ww.xlsx"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\logokshuf.webp" "c:\Users\asus\my\almadrasah\manar01\assets\images\logokshuf.webp"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\icone.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\icone.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\loco1cone.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\loco1cone.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\logo.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\logo.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\assets\images\logoicone.png" "c:\Users\asus\my\almadrasah\manar01\assets\images\logoicone.png"
copy /Y "c:\Users\asus\my\almadrasah\build\web\flutter.js" "c:\Users\asus\my\almadrasah\manar01\flutter.js"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\skwasm.wasm" "c:\Users\asus\my\almadrasah\manar01\canvaskit\skwasm.wasm"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\skwasm.js.symbols" "c:\Users\asus\my\almadrasah\manar01\canvaskit\skwasm.js.symbols"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\skwasm.js" "c:\Users\asus\my\almadrasah\manar01\canvaskit\skwasm.js"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\chromium\canvaskit.wasm" "c:\Users\asus\my\almadrasah\manar01\canvaskit\chromium\canvaskit.wasm"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\chromium\canvaskit.js.symbols" "c:\Users\asus\my\almadrasah\manar01\canvaskit\chromium\canvaskit.js.symbols"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\chromium\canvaskit.js" "c:\Users\asus\my\almadrasah\manar01\canvaskit\chromium\canvaskit.js"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\canvaskit.wasm" "c:\Users\asus\my\almadrasah\manar01\canvaskit\canvaskit.wasm"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\canvaskit.js.symbols" "c:\Users\asus\my\almadrasah\manar01\canvaskit\canvaskit.js.symbols"
copy /Y "c:\Users\asus\my\almadrasah\build\web\canvaskit\canvaskit.js" "c:\Users\asus\my\almadrasah\manar01\canvaskit\canvaskit.js"
