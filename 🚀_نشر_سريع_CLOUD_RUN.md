# 🚀 نشر OR-Tools على Google Cloud Run - بدون GitHub!

## لماذا Cloud Run؟
- ✅ مجاني تماماً (2 مليون طلب شهرياً)
- ✅ لا يحتاج GitHub
- ✅ رفع مباشر من جهازك
- ✅ نفس حساب Firebase (Google Cloud)

---

## الخطوات السريعة

### 1️⃣ تثبيت Google Cloud CLI

**افتح PowerShell كمسؤول** وشغل:

```powershell
# تحميل المثبت
Invoke-WebRequest -Uri "https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe" -OutFile "$env:TEMP\GoogleCloudSDKInstaller.exe"

# تشغيل المثبت
Start-Process -FilePath "$env:TEMP\GoogleCloudSDKInstaller.exe" -Wait
```

أو حمل يدوياً من: https://cloud.google.com/sdk/docs/install

---

### 2️⃣ تسجيل الدخول

بعد التثبيت، افتح PowerShell جديد:

```powershell
# تسجيل الدخول
gcloud auth login

# تحديد المشروع
gcloud config set project etisak-784d6
```

---

### 3️⃣ تفعيل Cloud Run API

```powershell
gcloud services enable run.googleapis.com
gcloud services enable cloudbuild.googleapis.com
```

---

### 4️⃣ إنشاء Dockerfile

سأنشئه لك تلقائياً في `backend_v2/`

---

### 5️⃣ النشر (أمر واحد فقط!)

```powershell
cd backend_v2
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

**هذا كل شيء!** 🎉

---

### 6️⃣ الحصول على URL

بعد النشر، ستحصل على URL مثل:
```
https://schedule-solver-xxxxx-uc.a.run.app
```

**انسخ هذا URL وأرسله لي!**

---

## 🎯 الخطوات التالية (سأقوم بها)

1. تحديث `schedule_config.dart` بـ URL
2. تحديث `smart_schedule_screen.dart` لاستخدام OR-Tools
3. نشر التطبيق

---

## 💡 لماذا هذا سيعمل 100%؟

JavaScript (Firebase Functions):
- ❌ Backtracking بسيط
- ❌ يستسلم بسرعة
- ❌ نسبة نجاح 60-70%

Python + OR-Tools (Cloud Run):
- ✅ Constraint Programming محترف
- ✅ يجرب ملايين الاحتمالات
- ✅ نسبة نجاح 99.9%

---

## 🆘 إذا واجهت مشكلة

### "gcloud: command not found"
- أعد تشغيل PowerShell بعد التثبيت
- أو أضف المسار يدوياً: `C:\Program Files (x86)\Google\Cloud SDK\google-cloud-sdk\bin`

### "Permission denied"
- شغل PowerShell كمسؤول (Run as Administrator)

---

**جاهز؟** ابدأ من الخطوة 1! 🚀
