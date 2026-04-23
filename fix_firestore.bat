@echo off
chcp 65001 >nul
echo.
echo ═══════════════════════════════════════════════════
echo 🤖 الإصلاح التلقائي لقواعد Firestore
echo ═══════════════════════════════════════════════════
echo.

REM التحقق من وجود Node.js
where node >nul 2>nul
if %ERRORLEVEL% NEQ 0 (
    echo ❌ خطأ: Node.js غير مثبت
    echo.
    echo 📝 يرجى تثبيت Node.js من:
    echo https://nodejs.org
    echo.
    pause
    exit /b 1
)

echo ✅ Node.js مثبت
echo.

REM التحقق من وجود serviceAccountKey.json
if not exist "serviceAccountKey.json" (
    echo ❌ خطأ: لم يتم العثور على serviceAccountKey.json
    echo.
    echo 📝 للحصول على الملف:
    echo 1. افتح: https://console.firebase.google.com
    echo 2. اختر مشروع: etisak-784d6
    echo 3. اذهب إلى: Project Settings ^> Service Accounts
    echo 4. اضغط "Generate new private key"
    echo 5. احفظ الملف باسم: serviceAccountKey.json
    echo 6. ضعه في نفس مجلد هذا الملف
    echo.
    pause
    exit /b 1
)

echo ✅ تم العثور على serviceAccountKey.json
echo.

REM تثبيت المكتبات المطلوبة
echo 📦 جاري تثبيت المكتبات المطلوبة...
echo.
call npm install google-auth-library
if %ERRORLEVEL% NEQ 0 (
    echo ❌ فشل تثبيت المكتبات
    pause
    exit /b 1
)

echo.
echo ✅ تم تثبيت المكتبات
echo.

REM تشغيل السكريبت
echo 🚀 جاري تشغيل السكريبت...
echo.
node auto_fix_firestore.js

echo.
echo ═══════════════════════════════════════════════════
echo.

if %ERRORLEVEL% EQU 0 (
    echo ✅ تم الإصلاح بنجاح!
    echo.
    echo 📝 الخطوات التالية:
    echo 1. افتح: https://etisak-784d6.web.app
    echo 2. سجل الدخول كوكيل شؤون طلاب
    echo 3. تحقق من عدم وجود أخطاء
) else (
    echo ❌ فشل الإصلاح التلقائي
    echo.
    echo 📝 الحل البديل ^(يدوي - دقيقتان^):
    echo 1. افتح: https://console.firebase.google.com/project/etisak-784d6/firestore/rules
    echo 2. انسخ القواعد من: firestore_rules_backup.txt
    echo 3. الصقها في محرر القواعد
    echo 4. اضغط "Publish"
)

echo.
pause
