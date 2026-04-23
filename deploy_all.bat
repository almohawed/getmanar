@echo off
echo ========================================
echo نشر النظام الكامل
echo Complete System Deployment
echo ========================================
echo.

echo [1/3] نشر Backend (Python + OR-Tools)...
echo [1/3] Deploying Backend (Python + OR-Tools)...
echo.

cd backend_v2
call gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل نشر Backend!
    echo ❌ Backend deployment failed!
    cd ..
    pause
    exit /b 1
)

cd ..

echo.
echo ========================================
echo [2/3] بناء تطبيق Flutter...
echo [2/3] Building Flutter app...
echo ========================================
echo.

call flutter build web --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل بناء Flutter!
    echo ❌ Flutter build failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo [3/3] نشر إلى Firebase Hosting...
echo [3/3] Deploying to Firebase Hosting...
echo ========================================
echo.

call firebase deploy --only hosting

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ فشل نشر Firebase!
    echo ❌ Firebase deployment failed!
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ تم النشر بنجاح!
echo ✅ Deployment Complete!
echo ========================================
echo.
echo Backend: https://schedule-solver-979291699789.us-central1.run.app
echo Frontend: https://etisak-784d6.web.app
echo.
echo يمكنك الآن اختبار النظام
echo You can now test the system
echo.
pause
