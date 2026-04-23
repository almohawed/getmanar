@echo off
chcp 65001 >nul
color 0A

echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║          ⚡ نشر التحديثات على Firebase Hosting ⚡          ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo 📋 سيتم تنفيذ الخطوات التالية:
echo    1. تنظيف المشروع
echo    2. تحميل المكتبات
echo    3. بناء التطبيق (HTML renderer)
echo    4. النشر على Firebase
echo.
echo 🌐 الرابط: https://etisak-784d6.web.app/
echo.
pause

echo.
echo ════════════════════════════════════════════════════════════
echo 🧹 الخطوة 1/4: تنظيف المشروع...
echo ════════════════════════════════════════════════════════════
flutter clean
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ❌ فشل التنظيف!
    echo.
    pause
    exit /b 1
)
echo ✅ تم التنظيف بنجاح

echo.
echo ════════════════════════════════════════════════════════════
echo 📦 الخطوة 2/4: تحميل المكتبات...
echo ════════════════════════════════════════════════════════════
flutter pub get
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ❌ فشل تحميل المكتبات!
    echo.
    pause
    exit /b 1
)
echo ✅ تم تحميل المكتبات بنجاح

echo.
echo ════════════════════════════════════════════════════════════
echo 🔨 الخطوة 3/4: بناء التطبيق...
echo ════════════════════════════════════════════════════════════
echo ⚠️  هذه الخطوة قد تستغرق 2-3 دقائق...
echo.
flutter build web --release --web-renderer html
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ❌ فشل البناء!
    echo.
    pause
    exit /b 1
)
echo ✅ تم البناء بنجاح

echo.
echo ════════════════════════════════════════════════════════════
echo 🚀 الخطوة 4/4: النشر على Firebase...
echo ════════════════════════════════════════════════════════════
firebase deploy --only hosting
if %errorlevel% neq 0 (
    color 0C
    echo.
    echo ❌ فشل النشر!
    echo.
    echo 💡 تأكد من:
    echo    - تسجيل الدخول إلى Firebase: firebase login
    echo    - اتصالك بالإنترنت
    echo.
    pause
    exit /b 1
)

color 0A
echo.
echo ╔════════════════════════════════════════════════════════════╗
echo ║                                                            ║
echo ║              ✅ تم النشر بنجاح! ✅                         ║
echo ║                                                            ║
echo ╚════════════════════════════════════════════════════════════╝
echo.
echo 🌐 الرابط: https://etisak-784d6.web.app/
echo.
echo 📝 ملاحظات مهمة:
echo    ✓ تم استخدام HTML renderer (يحل مشكلة التعليق)
echo    ✓ تم تحديث جميع الملفات
echo    ✓ الموقع جاهز الآن
echo.
echo 🔄 بعد فتح الموقع:
echo    1. اضغط Ctrl+Shift+R لمسح الكاش
echo    2. يجب أن يفتح التطبيق مباشرة
echo.
echo 📋 التحديثات المنشورة:
echo    ✓ شاشة الخطط النشطة (5 أزرار)
echo    ✓ شاشة تعديل الخطة
echo    ✓ شاشة تفاصيل الخطة
echo    ✓ زر الحذف في جميع الشاشات
echo.
pause
