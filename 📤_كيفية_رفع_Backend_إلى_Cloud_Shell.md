# 📤 كيفية رفع Backend إلى Cloud Shell

## الطريقة 1: رفع الملفات من واجهة Cloud Shell (الأسهل)

### الخطوة 1: افتح Cloud Shell
https://console.cloud.google.com/?cloudshell=true

### الخطوة 2: غير المشروع
في Cloud Shell، اكتب:
```bash
gcloud config set project etisak-784d6
```

### الخطوة 3: أنشئ المجلد
```bash
mkdir -p ~/backend_v2
cd ~/backend_v2
```

### الخطوة 4: ارفع الملفات

#### أ) باستخدام واجهة Cloud Shell:
1. في Cloud Shell، اضغط على أيقونة **⋮** (ثلاث نقاط عمودية) في الزاوية العلوية اليمنى
2. اختر **"Upload"** أو **"Upload file"**
3. ستظهر نافذة لاختيار الملفات
4. اذهب إلى: `C:\Users\asus\my\almadrasah\backend_v2`
5. حدد جميع الملفات والمجلدات:
   - `app/` (المجلد بالكامل)
   - `Dockerfile`
   - `requirements.txt`
   - `firebase_credentials.json`
   - أي ملفات أخرى
6. اضغط "Open" أو "Upload"
7. انتظر حتى يكتمل الرفع

**ملاحظة**: قد تحتاج لرفع المجلدات بشكل منفصل. إذا لم يسمح برفع مجلد `app/`، ارفع الملفات الفردية.

#### ب) أو باستخدام الأمر (إذا كانت الملفات في مستودع Git):
```bash
# إذا كان المشروع على GitHub
git clone https://github.com/YOUR_USERNAME/almadrasah.git
cd almadrasah/backend_v2
```

### الخطوة 5: تحقق من الملفات
```bash
ls -la
```

يجب أن ترى:
```
app/
Dockerfile
requirements.txt
firebase_credentials.json
...
```

### الخطوة 6: انشر
```bash
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

---

## الطريقة 2: استخدام gcloud من جهازك (إذا كان متاحاً)

إذا كان `gcloud` يعمل على جهازك:

```powershell
cd C:\Users\asus\my\almadrasah\backend_v2
gcloud config set project etisak-784d6
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

---

## الطريقة 3: رفع ملف مضغوط

### على جهازك:
1. اذهب إلى: `C:\Users\asus\my\almadrasah`
2. اضغط بزر الماوس الأيمن على مجلد `backend_v2`
3. اختر "Send to" → "Compressed (zipped) folder"
4. سيتم إنشاء ملف `backend_v2.zip`

### في Cloud Shell:
1. ارفع ملف `backend_v2.zip` باستخدام أيقونة Upload
2. فك الضغط:
```bash
cd ~
unzip backend_v2.zip
cd backend_v2
```
3. انشر:
```bash
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

---

## الملفات المطلوبة (تأكد من رفعها جميعاً)

```
backend_v2/
├── app/
│   ├── __init__.py
│   ├── main.py
│   ├── api/
│   │   ├── __init__.py
│   │   ├── routes.py
│   │   └── simple_routes.py  ← مهم جداً!
│   ├── models/
│   │   ├── __init__.py
│   │   ├── school.py
│   │   └── schedule.py
│   ├── services/
│   │   ├── __init__.py
│   │   ├── solver_service.py
│   │   ├── firebase_service.py
│   │   ├── precheck_service.py
│   │   └── distribution_service.py
│   └── solver/
│       ├── __init__.py
│       └── cp_model_builder.py
├── Dockerfile
├── requirements.txt
└── firebase_credentials.json  ← مهم جداً!
```

---

## التحقق من نجاح النشر

بعد النشر، يجب أن ترى:
```
✓ Creating Revision...
✓ Routing traffic...
✓ Setting IAM Policy...
Done.
Service [schedule-solver] revision [schedule-solver-00004-xxx] has been deployed
Service URL: https://schedule-solver-979291699789.us-central1.run.app
```

### اختبر Backend:
افتح في المتصفح:
```
https://schedule-solver-979291699789.us-central1.run.app/api/v2/health
```

يجب أن ترى:
```json
{"status": "healthy", "version": "2.0-simple"}
```

---

## إذا واجهت مشاكل

### مشكلة: "No such file or directory"
**الحل**: تأكد من أنك في المجلد الصحيح:
```bash
cd ~/backend_v2
pwd  # يجب أن يعرض: /home/YOUR_USERNAME/backend_v2
ls   # يجب أن يعرض الملفات
```

### مشكلة: "Billing not enabled"
**الحل**: تأكد من أنك في المشروع الصحيح:
```bash
gcloud config get-value project  # يجب أن يعرض: etisak-784d6
```

إذا كان خطأ:
```bash
gcloud config set project etisak-784d6
```

### مشكلة: "Permission denied"
**الحل**: تأكد من أن لديك صلاحيات:
```bash
gcloud auth list  # تحقق من الحساب المستخدم
```

---

## ملخص الأوامر

```bash
# 1. غير المشروع
gcloud config set project etisak-784d6

# 2. أنشئ المجلد
mkdir -p ~/backend_v2
cd ~/backend_v2

# 3. ارفع الملفات (من واجهة Cloud Shell)

# 4. تحقق من الملفات
ls -la

# 5. انشر
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated

# 6. اختبر
curl https://schedule-solver-979291699789.us-central1.run.app/api/v2/health
```

---

**الخطوة التالية**: بعد نشر Backend، اختبر التطبيق على https://etisak-784d6.web.app
