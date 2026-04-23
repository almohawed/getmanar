@echo off
echo ========================================
echo Deploying Firebase Cloud Functions
echo ========================================
echo.

echo Note: This project uses JavaScript directly (no build step needed)
echo.

cd functions
echo Installing dependencies...
call npm install
echo.

cd ..
echo Deploying to Firebase...
call firebase deploy --only functions
echo.

echo ========================================
echo Deployment Complete!
echo ========================================
pause
