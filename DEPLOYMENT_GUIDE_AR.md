# دليل النشر الكامل - نظام الجدولة الذكي V2

## 📋 نظرة عامة

هذا الدليل يشرح كيفية نشر النظام الكامل على الإنترنت:
- **Backend V2**: على Railway أو Render (مجاني)
- **Flutter Web**: على Firebase Hosting

---

## 🚀 الخطوة 1: نشر Backend V2

### الطريقة الأولى: Railway (موصى بها - مجانية)

1. **إنشاء حساب على Railway**
   - اذهب إلى: https://railway.app
   - سجل دخول باستخدام GitHub

2. **إنشاء مشروع جديد**
   - اضغط "New Project"
   - اختر "Deploy from GitHub repo"
   - اختر repository الخاص بك
   - اختر مجلد `backend_v2`

3. **إضافة متغيرات البيئة**
   في Railway Dashboard:
   ```
   PORT=8000
   FIREBASE_CREDENTIALS=<محتوى serviceAccountKey.json كامل>
   ```

4. **الحصول على URL**
   - بعد النشر، ستحصل على URL مثل:
   - `https://backend-v2-production-xxxx.up.railway.app`
   - احفظ هذا الرابط

### الطريقة الثانية: Render (بديل مجاني)

1. **إنشاء حساب على Render**
   - اذهب إلى: https://render.com
   - سجل دخول باستخدام GitHub

2. **إنشاء Web Service جديد**
   - اضغط "New +"
   - اختر "Web Service"
   - اختر repository الخاص بك
   - Root Directory: `backend_v2`
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`

3. **إضافة متغيرات البيئة**
   ```
   FIREBASE_CREDENTIALS=<محتوى serviceAccountKey.json>
   ```

4. **الحصول على URL**
   - ستحصل على URL مثل:
   - `https://backend-v2-xxxx.onrender.com`

### الطريقة الثالثة: Google Cloud Run (احترافية)

```bash
cd backend_v2

# Build Docker image
gcloud builds submit --tag gcr.io/etisak-784d6/schedule-backend-v2

# Deploy to Cloud Run
gcloud run deploy schedule-backend-v2 \
  --image gcr.io/etisak-784d6/schedule-backend-v2 \
  --platform managed \
  --region us-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_CREDENTIALS="$(cat serviceAccountKey.json)"
```

---

## 🔧 الخطوة 2: تحديث Flutter API URL

بعد الحصول على URL من Railway/Render، قم بتحديث الملف:

**ملف: `lib/src/features/ortools_v2/data/schedule_api_v2.dart`**

```dart
class ScheduleApiV2 {
  // غير هذا إلى رابط backend_v2 المنشور
  static const String baseUrl = 'https://backend-v2-production-xxxx.up.railway.app/api/v2';
  
  // أو إذا استخدمت Render:
  // static const String baseUrl = 'https://backend-v2-xxxx.onrender.com/api/v2';
  
  // باقي الكود...
}
```

---

## 🌐 الخطوة 3: نشر Flutter على Firebase Hosting

### 1. تثبيت Firebase CLI (إذا لم يكن مثبتاً)

```bash
npm install -g firebase-tools
```

### 2. تسجيل الدخول

```bash
firebase login
```

### 3. بناء Flutter للويب

```bash
flutter clean
flutter pub get
flutter build web --release
```

### 4. نشر على Firebase Hosting

```bash
firebase deploy --only hosting
```

### 5. الوصول للتطبيق

بعد النشر، سيكون التطبيق متاحاً على:
```
https://etisak-784d6.web.app/
```

---

## ✅ الخطوة 4: التحقق من النظام

### 1. اختبار Backend

افتح في المتصفح:
```
https://your-backend-url.railway.app/
```

يجب أن ترى:
```json
{
  "message": "School Schedule Generator API v2",
  "version": "2.0.0",
  "status": "production"
}
```

### 2. اختبار Health Check

```
https://your-backend-url.railway.app/api/v2/health
```

### 3. اختبار Flutter

1. افتح: `https://etisak-784d6.web.app/`
2. سجل دخول كمدير
3. اذهب إلى "الجدول الذكي V2 (Production)"
4. جرب Precheck ثم Generate

---

## 🔐 الخطوة 5: إعداد Firebase Credentials

### للـ Backend على Railway/Render:

1. **احصل على محتوى serviceAccountKey.json**
   ```bash
   cat backend_v2/serviceAccountKey.json
   ```

2. **انسخ المحتوى كاملاً**

3. **أضفه كمتغير بيئة**
   - في Railway: Settings → Variables
   - في Render: Environment → Environment Variables
   - الاسم: `FIREBASE_CREDENTIALS`
   - القيمة: المحتوى الكامل للملف

---

## 📊 الخطوة 6: مراقبة الأداء

### Railway Dashboard
- عرض Logs
- مراقبة CPU/Memory
- إعادة التشغيل التلقائي

### Firebase Console
- Hosting metrics
- Performance monitoring
- Error tracking

---

## 🐛 استكشاف الأخطاء

### Backend لا يعمل؟

1. **تحقق من Logs**
   ```bash
   # Railway
   railway logs
   
   # Render
   # اذهب إلى Dashboard → Logs
   ```

2. **تحقق من Environment Variables**
   - تأكد من وجود `FIREBASE_CREDENTIALS`
   - تأكد من صحة JSON

3. **تحقق من Dependencies**
   ```bash
   pip install -r requirements.txt
   ```

### Flutter لا يتصل بـ Backend؟

1. **تحقق من CORS**
   - Backend يسمح بـ `allow_origins=["*"]`

2. **تحقق من URL**
   - تأكد من تحديث `baseUrl` في `schedule_api_v2.dart`
   - تأكد من إضافة `/api/v2` في النهاية

3. **تحقق من Network**
   - افتح Developer Tools → Network
   - شاهد الطلبات والأخطاء

---

## 💰 التكلفة

### Railway (Free Tier)
- 500 ساعة تشغيل شهرياً
- 512 MB RAM
- 1 GB Disk
- كافي للاختبار والاستخدام المتوسط

### Render (Free Tier)
- 750 ساعة تشغيل شهرياً
- 512 MB RAM
- يتوقف بعد 15 دقيقة من عدم الاستخدام

### Firebase Hosting (Free Tier)
- 10 GB تخزين
- 360 MB/يوم نقل بيانات
- كافي للاستخدام المدرسي

---

## 🎯 الخطوات التالية

بعد النشر الناجح:

1. ✅ اختبر النظام مع بيانات حقيقية
2. ✅ راقب الأداء والأخطاء
3. ✅ أضف المزيد من المدارس
4. ✅ جمع feedback من المستخدمين
5. ✅ حسّن الخوارزميات بناءً على النتائج

---

## 📞 الدعم

إذا واجهت أي مشاكل:
1. تحقق من Logs
2. راجع هذا الدليل
3. تحقق من Firebase Console
4. تحقق من Railway/Render Dashboard

---

## 🎉 تهانينا!

نظام الجدولة الذكي V2 الآن منشور ومتاح على الإنترنت! 🚀
