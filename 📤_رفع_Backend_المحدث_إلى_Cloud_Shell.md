# 📤 رفع Backend V2 المحدث إلى Cloud Shell

## المشكلة
المشروع غير موجود في Cloud Shell

## الحل السريع

### الطريقة 1: رفع مجلد backend_v2 كامل

1. **ضغط المجلد محلياً**
   - في Windows، اذهب إلى: `C:\Users\asus\my\almadrasah`
   - انقر بزر الماوس الأيمن على مجلد `backend_v2`
   - اختر "Send to" → "Compressed (zipped) folder"
   - سيتم إنشاء `backend_v2.zip`

2. **رفع إلى Cloud Shell**
   - افتح Cloud Shell: https://console.cloud.google.com/cloudshell
   - اضغط على أيقونة "⋮" (ثلاث نقاط) في الأعلى
   - اختر "Upload"
   - ارفع ملف `backend_v2.zip`

3. **فك الضغط والنشر**
   ```bash
   # تعيين المشروع
   gcloud config set project etisak-784d6
   
   # فك الضغط
   unzip backend_v2.zip
   
   # النشر
   cd backend_v2
   gcloud run deploy schedule-solver \
     --source . \
     --region us-central1 \
     --allow-unauthenticated \
     --timeout 300 \
     --memory 2Gi \
     --cpu 2
   ```

---

### الطريقة 2: رفع ملف واحد فقط (الأسرع)

إذا كان Backend V2 موجود مسبقاً في Cloud Shell، فقط حدّث ملف واحد:

1. **افتح Cloud Shell Editor**
   - https://console.cloud.google.com/cloudshell/editor

2. **اذهب إلى الملف**
   - `backend_v2/app/services/precheck_service.py`

3. **استبدل المحتوى**
   - انسخ محتوى الملف من: `backend_v2/UPDATED_precheck_service.py`
   - الصق في Cloud Shell Editor
   - احفظ (Ctrl+S)

4. **نشر من Terminal**
   ```bash
   gcloud config set project etisak-784d6
   cd backend_v2
   gcloud run deploy schedule-solver \
     --source . \
     --region us-central1 \
     --allow-unauthenticated \
     --timeout 300 \
     --memory 2Gi \
     --cpu 2
   ```

---

### الطريقة 3: إنشاء المشروع من الصفر في Cloud Shell

```bash
# تعيين المشروع
gcloud config set project etisak-784d6

# إنشاء المجلد
mkdir -p backend_v2/app/services
mkdir -p backend_v2/app/models
mkdir -p backend_v2/app/api

# سيتم رفع الملفات واحداً تلو الآخر عبر Cloud Shell Editor
```

ثم ارفع الملفات التالية:
- `backend_v2/requirements.txt`
- `backend_v2/Dockerfile`
- `backend_v2/app/main.py`
- `backend_v2/app/config.py`
- `backend_v2/app/api/routes.py`
- `backend_v2/app/models/school.py`
- `backend_v2/app/models/schedule.py`
- `backend_v2/app/services/precheck_service.py` (المحدث)
- `backend_v2/app/services/solver_service.py`
- `backend_v2/app/services/firebase_service.py`

---

## الأوامر الكاملة

بعد رفع المجلد بأي طريقة:

```bash
# 1. تعيين المشروع
gcloud config set project etisak-784d6

# 2. الذهاب للمجلد
cd backend_v2

# 3. النشر
gcloud run deploy schedule-solver \
  --source . \
  --region us-central1 \
  --allow-unauthenticated \
  --timeout 300 \
  --memory 2Gi \
  --cpu 2
```

---

## التحقق بعد النشر

```bash
# اختبار Health
curl https://schedule-solver-979291699789.us-central1.run.app/api/v2/health
```

يجب أن تحصل على:
```json
{
  "status": "healthy",
  "name": "School Schedule Solver V2",
  "version": "2.0.0"
}
```

---

## ملاحظات مهمة

- ✅ الملف المحدث موجود في: `backend_v2/UPDATED_precheck_service.py`
- ✅ التغيير الوحيد في ملف `precheck_service.py`
- ✅ بعد النشر، Flutter سيعمل تلقائياً
- ✅ لا حاجة لتحديثات إضافية

---

## إذا واجهت مشاكل

أرسل لي:
1. الأمر الذي نفذته
2. رسالة الخطأ كاملة
3. نتيجة: `gcloud config get-value project`
