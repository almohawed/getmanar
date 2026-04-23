#!/bin/bash

# ✅ نشر Backend V2 المحدث مع إصلاح توزيع الجدول

echo "🚀 نشر Backend V2 المحدث..."
echo ""
echo "التحديثات:"
echo "  ✓ إصلاح تكرار نفس الجدول عبر الأيام"
echo "  ✓ توزيع عادل ومتنوع للمواد"
echo "  ✓ ضمان اكتمال جداول المعلمين"
echo ""

# الانتقال إلى مجلد backend_v2
cd ~/backend_v2

# النشر إلى Cloud Run
gcloud run deploy schedule-solver \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --timeout 300 \
  --memory 2Gi \
  --cpu 2 \
  --project etisak-784d6

echo ""
echo "✅ تم النشر بنجاح!"
echo ""
echo "🔗 رابط الخدمة:"
echo "https://schedule-solver-979291699789.us-central1.run.app"
echo ""
echo "🧪 اختبر الآن من تطبيق Flutter"
