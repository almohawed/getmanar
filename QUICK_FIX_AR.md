# 🔧 الحل السريع للخطأ 422

## المشكلة
عند الضغط على "توليد الجدول"، يظهر خطأ ولا يتم توليد الجدول.

## الحل (3 خطوات فقط)

### 1️⃣ نشر Backend المحدث
افتح PowerShell في مجلد المشروع:
```powershell
cd backend_v2
.\deploy.bat
```
انتظر 2-3 دقائق حتى يكتمل النشر.

### 2️⃣ نشر Flutter المحدث
في نفس PowerShell:
```powershell
cd ..
.\deploy_flutter.bat
```
انتظر 1-2 دقيقة حتى يكتمل النشر.

### 3️⃣ اختبار النظام
1. افتح: https://etisak-784d6.web.app
2. سجل دخول
3. تأكد من وجود بيانات (فصول، معلمين، إسنادات)
4. اضغط "توليد الجدول"

## أو استخدم أمر واحد فقط!

```powershell
.\deploy_all.bat
```

هذا الأمر سينشر Backend و Flutter معاً.

## ماذا تم إصلاحه؟

### في Backend:
- ✅ معالجة أفضل للبيانات الفارغة
- ✅ سجلات تفصيلية للتشخيص
- ✅ تحمل الحقول الناقصة

### في Flutter:
- ✅ التحقق من اكتمال البيانات
- ✅ تخطي الإسنادات الفارغة
- ✅ رسائل خطأ واضحة

## إذا استمر الخطأ

### افحص البيانات في Firestore:
1. افتح Firebase Console
2. اذهب إلى Firestore Database
3. تحقق من مجموعة `SubjectAssignments`
4. تأكد من أن كل إسناد يحتوي على:
   - `teacherId` ✓
   - `classId` ✓
   - `subjectName` ✓
   - `weeklyHours` ✓

### افحص سجلات الخادم:
```powershell
gcloud run services logs read schedule-solver --region us-central1 --limit 30
```

ابحث عن رسائل ERROR أو 422.

## اختبار سريع

لاختبار Backend مباشرة:
```powershell
cd backend_v2
python test_simple_api.py
```

يجب أن ترى: ✅ Success!

## الدعم

إذا لم يعمل الحل:
1. أرسل آخر 30 سطر من سجلات Cloud Run
2. أرسل لقطة شاشة من الخطأ
3. أرسل عدد الفصول والمعلمين والإسنادات
