# ✅ تم نشر Flutter بنجاح!

## ما تم إنجازه
- ✅ بناء Flutter بنجاح
- ✅ نشر Flutter إلى Firebase Hosting
- ✅ التطبيق متاح على: https://etisak-784d6.web.app

## الخطوات التالية (يجب أن تقوم بها أنت)

### الخطوة 2: تنظيف البيانات في Firestore

#### 2.1 افتح Firebase Console
https://console.firebase.google.com/project/etisak-784d6/firestore/data

#### 2.2 اذهب إلى بيانات المدرسة
```
Schools → [اختر مدرستك] → SubjectAssignments
```

#### 2.3 تحقق من كل إسناد
لكل إسناد، تأكد من وجود:
- ✓ `teacherId` - معرف المعلم (ليس فارغاً)
- ✓ `classId` - معرف الفصل (ليس فارغاً)
- ✓ `subjectName` - اسم المادة (ليس فارغاً)
- ✓ `weeklyHours` - عدد الحصص (رقم > 0)

#### 2.4 احذف الإسنادات الفارغة
إذا وجدت أي إسناد بحقول فارغة، احذفه.

#### 2.5 أعد إنشاء الإسنادات
من التطبيق، أعد إنشاء الإسنادات بعناية:
1. اذهب إلى "إسناد المواد"
2. اختر المعلم
3. اختر الفصل
4. اختر المادة
5. أدخل عدد الحصص
6. احفظ

---

### الخطوة 3: نشر Backend المحدث

#### 3.1 افتح Google Cloud Shell
https://console.cloud.google.com/?cloudshell=true

#### 3.2 غير المشروع
في Cloud Shell، اكتب:
```bash
gcloud config set project etisak-784d6
```

#### 3.3 أنشئ مجلد للكود
```bash
mkdir -p ~/backend_v2
cd ~/backend_v2
```

#### 3.4 ارفع الملفات
1. في Cloud Shell، اضغط على أيقونة "⋮" (ثلاث نقاط) في الأعلى
2. اختر "Upload"
3. من جهازك، اذهب إلى: `C:\Users\asus\my\almadrasah\backend_v2`
4. حدد جميع الملفات والمجلدات داخل `backend_v2`
5. ارفعها

#### 3.5 انشر Backend
بعد رفع الملفات، في Cloud Shell:
```bash
cd ~/backend_v2
gcloud run deploy schedule-solver --source . --region us-central1 --allow-unauthenticated
```

انتظر 2-3 دقائق حتى يكتمل النشر.

---

### الخطوة 4: اختبر النظام

#### 4.1 افتح التطبيق
https://etisak-784d6.web.app

#### 4.2 حدّث الصفحة
اضغط `Ctrl + Shift + R` (أو `Ctrl + F5`) لتحديث كامل

#### 4.3 تحقق من البيانات
- ✓ يوجد فصول دراسية
- ✓ يوجد معلمون
- ✓ يوجد إسنادات مواد (كاملة)

#### 4.4 جرب التوليد
1. اضغط "توليد الجدول"
2. انتظر 5-15 ثانية
3. يجب أن ترى: "تم توليد الجدول بنجاح" ✅

---

## إذا استمرت المشكلة

### افحص سجلات Backend
في Cloud Shell أو PowerShell:
```bash
gcloud run services logs read schedule-solver --region us-central1 --limit 30
```

ابحث عن:
- رسائل ERROR
- حالة HTTP (422, 500)
- تفاصيل الخطأ

### افحص Console في المتصفح
1. افتح التطبيق
2. اضغط F12 لفتح Developer Tools
3. اذهب إلى تبويب "Console"
4. جرب التوليد مرة أخرى
5. انظر إلى رسائل الخطأ

---

## ملخص الحالة الحالية

### ✅ تم إنجازه:
- Flutter محدث ومنشور
- الكود يحتوي على التحقق من البيانات
- الإسنادات الفارغة سيتم تخطيها تلقائياً

### ⏳ يحتاج إلى إنجاز:
- تنظيف البيانات في Firestore (يدوياً)
- نشر Backend المحدث (من Cloud Shell)
- اختبار النظام

---

## نصائح مهمة

### عند تنظيف البيانات:
- احذف جميع الإسنادات القديمة
- أعد إنشاءها واحدة تلو الأخرى
- تأكد من ملء جميع الحقول

### عند نشر Backend:
- تأكد من رفع جميع الملفات
- انتظر حتى يكتمل النشر
- تحقق من رسالة النجاح

### عند الاختبار:
- ابدأ ببيانات بسيطة (2-3 فصول، 3-5 معلمين)
- تأكد من أن مجموع الحصص منطقي
- لا تتجاوز 35 حصة في الأسبوع

---

## روابط مهمة

- **التطبيق**: https://etisak-784d6.web.app
- **Firebase Console**: https://console.firebase.google.com/project/etisak-784d6
- **Cloud Shell**: https://console.cloud.google.com/?cloudshell=true
- **Cloud Run**: https://console.cloud.google.com/run?project=etisak-784d6

---

**الخطوة التالية**: نظف البيانات في Firestore، ثم انشر Backend من Cloud Shell.
