# 🚀 دليل النشر الإنتاجي

## المتطلبات

1. Google Cloud SDK مثبت
2. Firebase credentials (ملف JSON)
3. مشروع Google Cloud مع Billing مفعّل

## خطوات النشر

### 1. إعداد Firebase Credentials

**لا تضع credentials في الكود أبداً!**

```bash
# ضع ملف credentials في مكان آمن
cp /path/to/firebase-credentials.json ./firebase_credentials.json

# تأكد من إضافته إلى .gitignore
echo "firebase_credentials.json" >> .gitignore
```

### 2. إنشاء Dockerfile

الملف موجود بالفعل في `backend_v2/Dockerfile`

### 3. النشر إلى Cloud Run

```bash
# تعيين المشروع
gcloud config set project etisak-784d6

# النشر
cd backend_v2
gcloud run deploy schedule-solver \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --memory 4Gi \
  --cpu 4 \
  --timeout 300 \
  --set-env-vars FIREBASE_CREDENTIALS_PATH=/app/firebase_credentials.json
```

### 4. التحقق من النشر

```bash
# اختبار health endpoint
curl https://schedule-solver-979291699789.us-central1.run.app/api/v2/health

# يجب أن يعرض:
# {"status": "healthy", "version": "..."}
```

## البنية الإنتاجية

```
backend_v2/
├── app/
│   ├── api/
│   │   ├── routes.py          # API endpoints الرئيسية
│   │   └── simple_routes.py   # API مبسط
│   ├── models/
│   │   ├── school.py          # نماذج المدرسة
│   │   └── schedule.py        # نماذج الجدولة
│   ├── services/
│   │   ├── precheck_service.py      # فحص مسبق
│   │   ├── solver_service.py        # محرك الحل
│   │   ├── firebase_service.py      # خدمة Firebase
│   │   └── distribution_service.py  # توزيع الجداول
│   ├── solver/
│   │   └── cp_model_builder.py      # بناء نموذج OR-Tools
│   └── main.py
├── Dockerfile
├── requirements.txt
└── firebase_credentials.json  # (لا يُرفع إلى Git)
```

## المميزات الإنتاجية

### ✅ Precheck
- فحص البيانات قبل التوليد
- كشف المشاكل مبكراً
- تقرير مفصل بالمشاكل

### ✅ OR-Tools CP-SAT
- حل دقيق باستخدام Constraint Programming
- hard constraints (قيود صلبة)
- soft constraints (قيود مرنة)
- objective optimization

### ✅ Diagnostics
- تقارير مفصلة عند الفشل
- إحصائيات الحل
- تحليل القيود غير المحققة

### ✅ Security
- لا credentials في الكود
- استخدام متغيرات البيئة
- Firebase Admin SDK

### ✅ Scalability
- Cloud Run auto-scaling
- 4GB RAM, 4 CPU
- timeout 300 ثانية

## API Endpoints

### Health Check
```
GET /api/v2/health
```

### Generate Schedule (Full)
```
POST /api/v2/generate_schedule
Content-Type: application/json

{
  "schoolId": "...",
  "schoolType": "middle",
  "teachers": [...],
  "classes": [...],
  "subjects": [...],
  "assignments": [...],
  "manualConstraints": [],
  "daysPerWeek": 5,
  "periodsPerDay": 7
}
```

### Generate Schedule (Simple)
```
POST /api/v2/simple_generate
Content-Type: application/json

{
  "schoolId": "...",
  "classes": [...],
  "teachers": [...],
  "assignments": [...]
}
```

## Monitoring

### عرض السجلات
```bash
gcloud run services logs read schedule-solver \
  --region us-central1 \
  --limit 100
```

### مراقبة الأداء
```bash
gcloud run services describe schedule-solver \
  --region us-central1
```

## Troubleshooting

### المشكلة: Timeout
**الحل**: زيادة timeout أو تقليل حجم البيانات

### المشكلة: Out of Memory
**الحل**: زيادة memory في Cloud Run

### المشكلة: Solver لا يجد حل
**الحل**: فحص تقرير precheck والتأكد من أن البيانات منطقية

## Best Practices

1. **دائماً استخدم precheck** قبل التوليد
2. **لا تضع credentials في الكود**
3. **استخدم logging مناسب**
4. **راقب الأداء والتكاليف**
5. **اختبر مع بيانات حقيقية**

## التكاليف المتوقعة

Cloud Run pricing (تقريبي):
- Memory: 4GB × وقت التشغيل
- CPU: 4 CPU × وقت التشغيل
- Requests: عدد الطلبات

**مثال**: توليد جدول يستغرق 30 ثانية
- التكلفة: ~$0.001 - $0.005 لكل توليد
