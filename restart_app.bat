@echo off
chcp 65001 >nul
echo.
echo ═══════════════════════════════════════
echo    Restarting Flutter App
echo ═══════════════════════════════════════
echo.

echo [1/3] Cleaning project...
call flutter clean
if %errorlevel% neq 0 (
    echo Error cleaning project!
    pause
    exit /b 1
)

echo.
echo [2/3] Getting packages...
call flutter pub get
if %errorlevel% neq 0 (
    echo Error getting packages!
    pause
    exit /b 1
)

echo.
echo [3/3] Running app...
echo.
echo ═══════════════════════════════════════
echo    App is starting...
echo ═══════════════════════════════════════
echo.
call flutter run

pause
