@echo off
chcp 65001 >nul
echo ========================================
echo   🚀 نشر التطبيق والحصول على رابط
echo ========================================
echo.

echo [1/4] تنظيف المشروع...
call flutter clean
echo.

echo [2/4] تحميل الحزم...
call flutter pub get
echo.

echo [3/4] بناء التطبيق للويب...
call flutter build web --release
echo.

echo [4/4] نشر على Firebase...
call firebase deploy --only hosting
echo.

echo ========================================
echo   ✅ تم النشر بنجاح!
echo ========================================
echo.
echo 🔗 الرابط سيظهر أعلاه بعد النشر
echo    مثال: https://your-project.web.app
echo.
echo 📋 للاختبار:
echo 1. افتح الرابط في المتصفح
echo 2. سجل دخول كمعلم
echo 3. اذهب إلى قسم التعاميم
echo 4. لاحظ التصميم الجديد الاحترافي!
echo.
pause
