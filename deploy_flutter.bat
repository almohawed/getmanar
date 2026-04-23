@echo off
echo ========================================
echo Deploying Flutter App to Firebase
echo ========================================
echo.

echo Building Flutter web app...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Build failed!
    pause
    exit /b 1
)

echo.
echo Deploying to Firebase Hosting...
call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Deployment failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ Deployment Complete!
echo ========================================
echo.
echo App URL: https://etisak-784d6.web.app
echo.
pause
