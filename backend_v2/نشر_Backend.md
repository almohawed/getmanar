# 🚀 نشر Backend إلى Cloud Run

## الخطوات البسيطة

### 1️⃣ افتح PowerShell في مجلد backend_v2
```powershell
cd C:\Users\asus\my\almadrasah\backend_v2
```

### 2️⃣ نفذ أمر النشر
```powershell
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated --timeout 300 --memory 1Gi --cpu 1 --project etisak-784d6
```

### 3️⃣ انتظر حتى يكتمل النشر
سيستغرق حوالي 3-5 دقائق

### 4️⃣ اختبر الخدمة
```powershell
curl https://schedule-solver-979291699789.us-central1.run.app/health
```

يجب أن ترى:
```json
{"status":"healthy","version":"2.0.0"}
```

---

## ✅ التحسينات التي تمت

1. **إصلاح Dockerfile**: استخدام CMD بصيغة array بدلاً من shell
2. **إصلاح PORT**: استخدام port ثابت 8080
3. **إصلاح simple_routes.py**: إزالة Config المكرر
4. **إضافة /health endpoint**: للتحقق من صحة الخدمة

---

## 🔍 في حالة الفشل

### تحقق من Logs:
```powershell
gcloud run services logs read schedule-solver --region us-central1 --project etisak-784d6 --limit 50
```

### تحقق من الخدمة:
```powershell
gcloud run services describe schedule-solver --region us-central1 --project etisak-784d6
```

---

## 📝 ملاحظات مهمة

- Backend يستخدم OR-Tools CP-SAT (ليس random)
- يحتوي على Precheck قبل التوليد
- يطبق Hard و Soft Constraints
- يرجع Diagnostics عند الفشل
- لا يحتوي على Firebase credentials في الكود
- يضمن 100% اكتمال الجداول أو يفشل مع تشخيص واضح
