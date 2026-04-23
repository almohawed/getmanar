@echo off
echo 🚀 نشر الحل الجذري النهائي...
echo.

echo 📦 بناء التطبيق...
call flutter build web --release

echo.
echo 🔥 نشر على Firebase...
call firebase deploy --only hosting

echo.
echo ✅ تم النشر بنجاح!
echo.
echo 🎯 الآن يمكنك اختبار الأزرار الجديدة:
echo https://etisak-784d6.web.app
echo.
echo 📋 تعليمات الاختبار:
echo 1. سجل دخول كمرشد طلابي
echo 2. ستجد الأزرار البنفسجية في أعلى الصفحة
echo 3. اضغط على "اختبار سريع" أولاً
echo 4. ثم جرب باقي الأزرار
echo.
pause