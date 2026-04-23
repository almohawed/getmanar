@echo off
chcp 65001 >nul
echo ========================================
echo   🔥 اختبار قسم التعاميم الجديد
echo ========================================
echo.

echo [1/4] تنظيف المشروع...
call flutter clean
echo.

echo [2/4] تحميل الحزم...
call flutter pub get
echo.

echo [3/4] إعادة بناء المشروع...
call flutter build web --release
echo.

echo [4/4] تشغيل التطبيق...
echo.
echo ✨ سيتم فتح التطبيق في المتصفح
echo.
call flutter run -d chrome --release
echo.

echo ========================================
echo   ✅ تم تشغيل التطبيق بنجاح!
echo ========================================
echo.
echo 📋 للاختبار:
echo 1. سجل دخول كمعلم
echo 2. اذهب إلى قسم التعاميم
echo 3. لاحظ التصميم الجديد:
echo    ✨ Header بـ Gradient indigo
echo    ✨ مؤشر التعاميم الجديدة (برتقالي)
echo    ✨ فلاتر جميلة بألوان مختلفة
echo    ✨ بطاقات احترافية مع Gradient
echo    ✨ Badge "جديد" للتعاميم الجديدة
echo    ✨ أيقونات كبيرة ملونة
echo.
pause
