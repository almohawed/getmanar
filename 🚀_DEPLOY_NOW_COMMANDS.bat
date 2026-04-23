@echo off
REM ========================================
REM نشر التطبيق على Firebase Hosting
REM الرابط: https://etisak-784d6.web.app/
REM ========================================

echo.
echo ========================================
echo 🚀 بدء عملية النشر
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
echo الخطوة 3/5: بناء التطبيق للويب...
flutter build web --release
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
echo ✅ تم النشر بنجاح!
echo ========================================
echo.
echo الرابط: https://etisak-784d6.web.app/
echo.
echo الميزات المنشورة:
echo ✨ 5 أزرار في كل خطة
echo ✨ الصف الأول: عرض ^| تقييم ^| توصيات
echo ✨ الصف الثاني: تعديل ^| حذف
echo ✨ زر التعديل يفتح صفحة التعديل مباشرة
echo ✨ زر الحذف مع تأكيد
echo.
pause
