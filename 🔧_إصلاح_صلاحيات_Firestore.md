# 🔧 إصلاح صلاحيات Firestore

## المشكلة
رسالة الخطأ: `Missing or [cloud_firestore/permission-denied] insufficient permissions`

## الحل

### الخطوة 1: افتح Firebase Console
1. اذهب إلى: https://console.firebase.google.com/
2. اختر مشروع **etisak-784d6**
3. من القائمة الجانبية، اختر **Firestore Database**
4. اضغط على تبويب **Rules** (القواعد)

### الخطوة 2: حدّث القواعد
استبدل القواعد الحالية بهذه القواعد:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // السماح للمستخدمين المسجلين بقراءة بيانات مدرستهم
    match /Schools/{schoolId}/{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      (request.auth.token.schoolId == schoolId || 
                       request.auth.token.role == 'admin');
    }
    
    // السماح بقراءة سجلات السلوك
    match /behavior_records/{recordId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // السماح بقراءة سجلات الحضور
    match /attendance/{recordId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // السماح بقراءة بيانات المستخدمين
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // السماح بقراءة بيانات الطلاب
    match /students/{studentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // السماح بقراءة بيانات الفصول
    match /classes/{classId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // السماح بقراءة بيانات المعلمين
    match /teachers/{teacherId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

### الخطوة 3: انشر القواعد
1. اضغط على زر **Publish** (نشر)
2. انتظر بضع ثوانٍ حتى يتم تطبيق القواعد

### الخطوة 4: اختبر التطبيق
1. افتح الموقع: https://etisak-784d6.web.app/
2. سجل دخول كوكيل شؤون طلاب
3. يجب أن تختفي رسالة الخطأ وتظهر البيانات

---

## ✅ ما تم إصلاحه في التصميم (يظهر الآن):

من الصورة التي أرسلتها، أرى أن:

1. ✅ **البطاقات أصغر** - التصميم الجديد يعمل!
2. ✅ **الأيقونات أجمل** - البطاقات البنفسجية في الأسفل
3. ✅ **التنسيق أفضل** - Grid layout يعمل بشكل صحيح

**المشكلة الوحيدة المتبقية**: صلاحيات Firestore تمنع تحميل البيانات

---

## 🎯 بعد تحديث القواعد، ستظهر:

1. ✅ **خطر اليوم**: عدد الطلاب في نطاق الخطر
2. ✅ **مؤشر ضغط الانضباط**: إحصائيات المخالفات
3. ✅ **الغياب اليومي**: قائمة الطلاب الغائبين
4. ✅ **البطاقات الصغيرة**: الطلاب، الغياب، التأخر، المخالفات

---

## ⚠️ إذا لم تستطع تحديث القواعد:

يمكنك استخدام هذه القواعد المؤقتة (للتطوير فقط):

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

**تحذير**: هذه القواعد تسمح بالوصول الكامل لجميع المستخدمين المسجلين. استخدمها فقط للاختبار!

---

**الخلاصة**: 
- ✅ التصميم تم إصلاحه (يظهر في الصورة)
- ❌ البيانات لا تظهر بسبب صلاحيات Firestore
- 🔧 الحل: تحديث قواعد Firestore كما هو موضح أعلاه
