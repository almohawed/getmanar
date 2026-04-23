$ErrorActionPreference = "Stop"

Write-Host "Starting Artifact Copy Process..."

# 1. Copy APK
$apkSource = "Z:\getmanarV1.0.0\source_code\build\app\outputs\flutter-apk\app-release.apk"
$apkDestDir = "C:\Users\asus\my\almadrasah\getmanar-V1.0.0\manual_install"
$apkDest = "$apkDestDir\app-release.apk"

if (Test-Path $apkSource) {
    if (-not (Test-Path $apkDestDir)) { New-Item -ItemType Directory -Path $apkDestDir -Force }
    Copy-Item -Path $apkSource -Destination $apkDest -Force
    Write-Host "✅ APK copied successfully to $apkDest"
} else {
    Write-Warning "⚠️ APK source not found at $apkSource"
}

# 2. Copy AppBundle
$aabSource = "Z:\getmanarV1.0.0\source_code\build\app\outputs\bundle\release\app-release.aab"
$aabDestDir = "C:\Users\asus\my\almadrasah\getmanar-V1.0.0\google_play_upload"
$aabDest = "$aabDestDir\app-release.aab"

if (Test-Path $aabSource) {
    if (-not (Test-Path $aabDestDir)) { New-Item -ItemType Directory -Path $aabDestDir -Force }
    Copy-Item -Path $aabSource -Destination $aabDest -Force
    Write-Host "✅ AppBundle copied successfully to $aabDest"
} else {
    Write-Warning "⚠️ AppBundle source not found at $aabSource"
}

# 3. Copy Web Files
$webSource = "Z:\getmanarV1.0.0\source_code\build\web\*"
$webDestDir = "C:\Users\asus\my\almadrasah\getmanar-V1.0.0\web_files"

if (Test-Path "Z:\getmanarV1.0.0\source_code\build\web\index.html") {
    if (-not (Test-Path $webDestDir)) { New-Item -ItemType Directory -Path $webDestDir -Force }
    Copy-Item -Path $webSource -Destination $webDestDir -Recurse -Force
    Write-Host "✅ Web files copied successfully to $webDestDir"
} else {
    Write-Warning "⚠️ Web build source not found at $webSource"
}

Write-Host "Artifact copy process finished."
