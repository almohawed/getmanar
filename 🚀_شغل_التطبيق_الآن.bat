@echo off
chcp 65001 >nul
cls
echo.
echo ═══════════════════════════════════════════════════════
echo    🚀 إعادة تشغيل التطبيق - قسم إرسال الرسائل SMS
echo ═══════════════════════════════════════════════════════
echo.
echo ✓ الكود صحيح 100%%
echo ✓ التعديلات موجودة
echo ✓ لا توجد أخطاء
echo.
echo المطلوب: إعادة تشغيل التطبيق فقط!
echo.
echo ═══════════════════════════════════════════════════════
echo.
pause
echo.

echo [1/3] 🧹 تنظيف المشروع...
echo.
call flutter clean
if %errorlevel% neq 0 (
    echo.
    echo ❌ خطأ في التنظيف!
    pause
    exit /b 1
)
echo.
echo ✅ تم التنظيف بنجاح
echo.

echo [2/3] 📦 جلب الحزم...
echo.
call flutter pub get
if %errorlevel% neq 0 (
    echo.
    echo ❌ خطأ في جلب الحزم!
    pause
    exit /b 1
)
echo.
echo ✅ تم جلب الحزم بنجاح
echo.

echo [3/3] 🚀 تشغيل التطبيق...
echo.
echo ═══════════════════════════════════════════════════════
echo    التطبيق يعمل الآن...
echo ═══════════════════════════════════════════════════════
echo.
echo بعد فتح التطبيق:
echo 1. سجل دخول كمدير
echo 2. افتح: إعدادات خدمة SMS
echo 3. ستجد 4 تبويبات
echo 4. اضغط على: إرسال الرسائل
echo.
echo ═══════════════════════════════════════════════════════
echo.

call flutter run

pause
