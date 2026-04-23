@echo off
(
echo Starting Build Process...
echo [1/3] Building Flutter Web (Release)...
call flutter build web --release
if %errorlevel% neq 0 (
    echo Error building web!
    exit /b %errorlevel%
)

echo [2/3] Building Flutter APK (Release)...
call flutter build apk --release
if %errorlevel% neq 0 (
    echo Error building APK!
    exit /b %errorlevel%
)

echo [3/3] Deploying to manar01...
call copy_manual.bat

echo Build and Deploy Complete!
) > build_log.txt 2>&1
