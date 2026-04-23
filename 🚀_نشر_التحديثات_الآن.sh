#!/bin/bash

echo "========================================"
echo "   نشر التحديثات على Firebase Hosting"
echo "========================================"
echo ""

echo "[1/4] تنظيف المشروع..."
flutter clean
if [ $? -ne 0 ]; then
    echo "❌ فشل التنظيف"
    exit 1
fi
echo "✅ تم التنظيف"

echo ""
echo "[2/4] تحميل المكتبات..."
flutter pub get
if [ $? -ne 0 ]; then
    echo "❌ فشل تحميل المكتبات"
    exit 1
fi
echo "✅ تم تحميل المكتبات"

echo ""
echo "[3/4] بناء التطبيق للويب..."
flutter build web --release
if [ $? -ne 0 ]; then
    echo "❌ فشل البناء"
    exit 1
fi
echo "✅ تم البناء بنجاح"

echo ""
echo "[4/4] نشر على Firebase..."
firebase deploy --only hosting
if [ $? -ne 0 ]; then
    echo "❌ فشل النشر"
    exit 1
fi

echo ""
echo "========================================"
echo "✅ تم النشر بنجاح!"
echo "========================================"
echo ""
echo "🌐 الرابط: https://etisak-784d6.web.app/"
echo ""
echo "التحديثات المنشورة:"
echo "  ✅ إصلاح الكليشة السعودية في PDF"
echo "  ✅ نقل أزرار التصدير إلى AppBar"
echo "  ✅ إضافة معالجة أخطاء أفضل"
echo ""
