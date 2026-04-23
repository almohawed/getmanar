# 🚀 انشر الآن - Deploy Now

## المشكلة
أنت الآن في مجلد `backend_v2` و `gcloud` غير متاح في PowerShell الحالي.

## الحل السريع

### الخطوة 1: ارجع للمجلد الرئيسي
```powershell
cd ..
```

### الخطوة 2: انشر Backend
```powershell
cd backend_v2
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

انتظر 2-3 دقائق حتى يكتمل النشر.

### الخطوة 3: انشر Flutter
```powershell
cd ..
flutter build web --release
firebase deploy --only hosting
```

---

## أو استخدم Google Cloud Console

إذا لم يعمل `gcloud` في PowerShell:

### 1. افتح Google Cloud Console
https://console.cloud.google.com/run?project=etisak-784d6

### 2. اضغط على "schedule-solver"

### 3. اضغط "EDIT & DEPLOY NEW REVISION"

### 4. في قسم "Container image URL":
- اختر "Deploy one revision from an existing container image"
- أو ارفع الكود مباشرة

### 5. اضغط "DEPLOY"

---

## أو استخدم Cloud Shell

### 1. افتح Cloud Shell في Google Cloud Console
https://console.cloud.google.com/?cloudshell=true

### 2. استنسخ المشروع (إذا لم يكن موجوداً):
```bash
git clone [YOUR_REPO_URL]
cd almadrasah
```

### 3. انشر Backend:
```bash
cd backend_v2
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

---

## الطريقة الأسهل: نشر Flutter فقط الآن

إذا كان Backend يعمل بالفعل (revision schedule-solver-00003-mcl)، يمكنك نشر Flutter فقط:

```powershell
# تأكد أنك في المجلد الرئيسي
cd C:\Users\asus\my\almadrasah

# انشر Flutter
flutter build web --release
firebase deploy --only hosting
```

هذا سيحدث Flutter مع الإصلاحات الجديدة، و Backend الموجود سيعمل معه.

---

## التحقق من Backend الحالي

افتح في المتصفح:
```
https://schedule-solver-979291699789.us-central1.run.app/api/v2/health
```

إذا رأيت:
```json
{"status": "healthy", "version": "2.0-simple"}
```

معناه Backend يعمل! يمكنك نشر Flutter فقط.

---

## الأوامر النهائية (من المجلد الرئيسي)

```powershell
# 1. ارجع للمجلد الرئيسي
cd C:\Users\asus\my\almadrasah

# 2. انشر Flutter
flutter build web --release
firebase deploy --only hosting

# 3. اختبر
# افتح: https://etisak-784d6.web.app
```

---

## إذا أردت نشر Backend أيضاً

افتح PowerShell جديد (كمسؤول) وجرب:

```powershell
cd C:\Users\asus\my\almadrasah\backend_v2
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

إذا لم يعمل `gcloud`، استخدم Cloud Shell كما هو موضح أعلاه.
