@echo off
echo ========================================
echo نشر Flutter فقط
echo Deploy Flutter Only
echo ========================================
echo.

echo التحقق من المجلد الحالي...
echo Current directory: %CD%
echo.

echo بناء Flutter...
echo Building Flutter...
call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل البناء!
    echo ❌ Build failed!
    pause
    exit /b 1
)

echo.
echo نشر إلى Firebase...
echo Deploying to Firebase...
call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل النشر!
    echo ❌ Deployment failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ تم النشر بنجاح!
echo ✅ Deployment Complete!
echo ========================================
echo.
echo App URL: https://etisak-784d6.web.app
echo.
echo الآن اختبر التطبيق
echo Now test the application
echo.
pause
