@echo off
echo ========================================
echo رفع إصلاح Precheck إلى Cloud Run
echo ========================================
echo.

cd backend_v2

echo نشر Backend V2 المحدث...
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated --timeout 300 --memory 2Gi --cpu 2

echo.
echo ========================================
echo تم النشر بنجاح!
echo ========================================
echo.
echo اختبر الآن:
echo https://schedule-solver-979291699789.us-central1.run.app/api/v2/health
echo.
pause
