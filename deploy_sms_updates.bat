@echo off
chcp 65001 >nul
echo.
echo ═══════════════════════════════════════════════════════════
echo   🚀 نشر تحديثات نظام SMS
echo ═══════════════════════════════════════════════════════════
echo.

echo 📦 الخطوة 1: نشر Cloud Functions...
echo.
cd functions
call firebase deploy --only functions:processSmsOutbox
if %errorlevel% neq 0 (
    echo.
    echo ❌ فشل نشر Cloud Functions!
    echo.
    pause
    exit /b 1
)
cd ..

echo.
echo ═══════════════════════════════════════════════════════════
echo   ✅ تم نشر التحديثات بنجاح!
echo ═══════════════════════════════════════════════════════════
echo.
echo 📋 الخطوات التالية:
echo.
echo 1️⃣  افتح التطبيق: flutter run
echo 2️⃣  اذهب إلى: الإعدادات → إعدادات SMS
echo 3️⃣  اختر المزود المناسب
echo 4️⃣  أدخل البيانات المطلوبة
echo 5️⃣  احفظ وجرب الإرسال
echo.
echo 📚 للمزيد من المعلومات، اقرأ:
echo    - ⚡_ابدأ_من_هنا_SMS.md
echo    - 🎯_الحل_الجذري_لمشكلة_SMS.md
echo    - ✅_تم_تحديث_نظام_SMS_الكامل.md
echo.
pause
