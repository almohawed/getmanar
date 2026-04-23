@echo off
echo ========================================
echo نشر نظام الجدولة الذكي V2
echo ========================================
echo.

echo [1/3] بناء Flutter للويب...
call flutter clean
call flutter pub get
call flutter build web --release

echo.
echo [2/3] نشر على Firebase Hosting...
call firebase deploy --only hosting

echo.
echo [3/3] تم النشر بنجاح!
echo.
echo التطبيق متاح على: https://etisak-784d6.web.app/
echo.
echo ملاحظة: تأكد من نشر backend_v2 على Railway أو Render
echo راجع ملف DEPLOYMENT_GUIDE_AR.md للتفاصيل
echo.
pause
