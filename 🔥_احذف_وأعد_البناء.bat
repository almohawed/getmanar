@echo off
chcp 65001 >nul
cls
echo.
echo ═══════════════════════════════════════════════════════
echo    🔥 حذف كامل وإعادة بناء التطبيق
echo ═══════════════════════════════════════════════════════
echo.
echo هذا سيحذف جميع الملفات المؤقتة ويعيد البناء من الصفر
echo.
pause
echo.

echo [1/5] 🗑️ حذف مجلد build...
if exist "build" (
    rmdir /s /q "build"
    echo ✅ تم حذف build
) else (
    echo ⚠️ مجلد build غير موجود
)
echo.

echo [2/5] 🗑️ حذف مجلد .dart_tool...
if exist ".dart_tool" (
    rmdir /s /q ".dart_tool"
    echo ✅ تم حذف .dart_tool
) else (
    echo ⚠️ مجلد .dart_tool غير موجود
)
echo.

echo [3/5] 🧹 تنظيف Flutter...
call flutter clean
echo ✅ تم التنظيف
echo.

echo [4/5] 📦 جلب الحزم...
call flutter pub get
echo ✅ تم جلب الحزم
echo.

echo [5/5] 🚀 تشغيل التطبيق...
echo.
echo ═══════════════════════════════════════════════════════
echo    التطبيق يعمل الآن - انتظر حتى يفتح
echo ═══════════════════════════════════════════════════════
echo.
echo بعد فتح التطبيق:
echo 1. سجل دخول كمدير
echo 2. افتح: إعدادات خدمة SMS
echo 3. يجب أن ترى 4 تبويبات الآن!
echo.
echo ═══════════════════════════════════════════════════════
echo.

call flutter run

pause
