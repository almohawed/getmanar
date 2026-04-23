#!/bin/bash
# نشر Backend المحدث إلى Cloud Run

echo "========================================="
echo "نشر Backend المحدث"
echo "========================================="
echo ""

# تعيين المشروع
echo "1. تعيين المشروع..."
gcloud config set project etisak-784d6

# الانتقال إلى مجلد backend_v2
echo ""
echo "2. الانتقال إلى مجلد backend_v2..."
cd backend_v2

# نشر إلى Cloud Run
echo ""
echo "3. نشر إلى Cloud Run..."
gcloud run deploy schedule-solver \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --platform managed \
  --memory 2Gi \
  --cpu 2 \
  --timeout 300

echo ""
echo "========================================="
echo "✅ تم النشر بنجاح!"
echo "========================================="
echo ""
echo "Backend URL: https://schedule-solver-979291699789.us-central1.run.app"
echo ""
echo "اختبر الآن: https://etisak-784d6.web.app"
echo ""
