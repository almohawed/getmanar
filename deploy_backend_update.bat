@echo off
echo ========================================
echo تحديث ونشر Backend V2
echo ========================================
echo.

echo الخطوة 1: فتح Google Cloud Console
echo -----------------------------------
start https://console.cloud.google.com/?cloudshell=true
echo.
echo تم فتح Cloud Shell في المتصفح...
echo.

echo الخطوة 2: انسخ هذه الأوامر والصقها في Cloud Shell
echo -------------------------------------------------------
echo.
echo === انسخ من هنا ===
echo.
echo cd ~/backend_v2/app/services
echo cat ^> solver_service.py ^<^< 'EOF'
type backend_v2\UPDATED_solver_service.py
echo EOF
echo cd ~/backend_v2
echo gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated --timeout 300 --memory 2Gi --cpu 2 --project etisak-784d6
echo.
echo === إلى هنا ===
echo.

pause
