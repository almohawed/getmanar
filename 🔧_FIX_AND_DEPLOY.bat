@echo off
REM ========================================
REM حل مشكلة التعليق وإعادة النشر
REM ========================================

echo.
echo ========================================
echo 🔧 حل مشكلة التعليق
echo ========================================
echo.

echo الخطوة 1/5: تنظيف المشروع...
flutter clean
if %errorlevel% neq 0 (
    echo ❌ فشل التنظيف
    pause
    exit /b 1
)

echo.
echo الخطوة 2/5: تحميل المكتبات...
flutter pub get
if %errorlevel% neq 0 (
    echo ❌ فشل تحميل المكتبات
    pause
    exit /b 1
)

echo.
echo الخطوة 3/5: بناء التطبيق بـ HTML renderer...
flutter build web --release --web-renderer html
if %errorlevel% neq 0 (
    echo ❌ فشل البناء
    pause
    exit /b 1
)

echo.
echo الخطوة 4/5: تسجيل الدخول إلى Firebase...
firebase login
if %errorlevel% neq 0 (
    echo ❌ فشل تسجيل الدخول
    pause
    exit /b 1
)

echo.
echo الخطوة 5/5: النشر على Firebase...
firebase deploy --only hosting
if %errorlevel% neq 0 (
    echo ❌ فشل النشر
    pause
    exit /b 1
)

echo.
echo ========================================
echo ✅ تم حل المشكلة والنشر بنجاح!
echo ========================================
echo.
echo الرابط: https://etisak-784d6.web.app/
echo.
echo ملاحظة: تم استخدام HTML renderer بدلاً من CanvasKit
echo هذا يحل مشكلة التعليق على شاشة التحميل
echo.
pause
