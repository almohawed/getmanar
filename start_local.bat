@echo off
echo ========================================
echo تشغيل نظام الجدولة الذكي محلياً
echo ========================================
echo.

echo [1/2] تشغيل Backend...
start "Backend V2" cmd /k "cd backend_v2 && python -m app.main"

timeout /t 3 /nobreak >nul

echo.
echo [2/2] تشغيل Flutter...
start "Flutter App" cmd /k "flutter run -d chrome"

echo.
echo ========================================
echo تم تشغيل النظام!
echo ========================================
echo.
echo Backend: http://localhost:8000
echo Flutter: سيفتح تلقائياً في Chrome
echo.
echo لإيقاف النظام: أغلق نوافذ Terminal
echo.
pause
