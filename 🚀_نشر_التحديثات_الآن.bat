@echo off
echo ========================================
echo    نشر التحديثات على Firebase Hosting
echo ========================================
echo.

echo [1/4] تنظيف المشروع...
call flutter clean
if errorlevel 1 (
    echo ❌ فشل التنظيف
    pause
    exit /b 1
)
echo ✅ تم التنظيف

echo.
echo [2/4] تحميل المكتبات...
call flutter pub get
if errorlevel 1 (
    echo ❌ فشل تحميل المكتبات
    pause
    exit /b 1
)
echo ✅ تم تحميل المكتبات

echo.
echo [3/4] بناء التطبيق للويب...
call flutter build web --release
if errorlevel 1 (
    echo ❌ فشل البناء
    pause
    exit /b 1
)
echo ✅ تم البناء بنجاح

echo.
echo [4/4] نشر على Firebase...
call firebase deploy --only hosting
if errorlevel 1 (
    echo ❌ فشل النشر
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ تم النشر بنجاح!
echo ========================================
echo.
echo 🌐 الرابط: https://etisak-784d6.web.app/
echo.
echo التحديثات المنشورة:
echo   ✅ إصلاح الكليشة السعودية في PDF
echo   ✅ نقل أزرار التصدير إلى AppBar
echo   ✅ إضافة معالجة أخطاء أفضل
echo.
pause
