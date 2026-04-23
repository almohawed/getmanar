@echo off
echo ========================================
echo   نشر Backend إلى Cloud Run
echo ========================================
echo.

cd /d "%~dp0"

echo [1/3] التحقق من المشروع...
gcloud config set project etisak-784d6

echo.
echo [2/3] بناء ونشر الحاوية...
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated --timeout 300 --memory 1Gi --cpu 1

echo.
echo [3/3] اختبار الخدمة...
curl https://schedule-solver-979291699789.us-central1.run.app/health

echo.
echo ========================================
echo   تم النشر بنجاح!
echo ========================================
echo.
echo URL: https://schedule-solver-979291699789.us-central1.run.app
echo.
pause
