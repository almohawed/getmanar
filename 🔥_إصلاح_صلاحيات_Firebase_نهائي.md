# 🔥 إصلاح صلاحيات Firebase - الحل النهائي

## ❌ المشكلة:
البيانات لا تُحمّل بسبب صلاحيات Firestore غير صحيحة.

**رسالة الخطأ المتوقعة**:
```
Missing or insufficient permissions
[cloud_firestore/permission-denied]
```

---

## ✅ الحل (خطوة بخطوة):

### الخطوة 1: افتح Firebase Console
1. اذهب إلى: https://console.firebase.google.com/
2. اختر مشروع **etisak-784d6**
3. من القائمة الجانبية، اختر **Firestore Database**
4. اضغط على تبويب **Rules** (القواعد)

---

### الخطوة 2: استبدل القواعد الحالية

احذف القواعد الموجودة واستبدلها بهذه القواعد:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // قاعدة عامة: السماح للمستخدمين المسجلين بالقراءة والكتابة
    match /{document=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // قواعد محددة للمدارس
    match /Schools/{schoolId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && 
                      (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.schoolId == schoolId ||
                       get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin');
      
      // السماح بالوصول لجميع المجموعات الفرعية
      match /{subcollection=**} {
        allow read: if request.auth != null;
        allow write: if request.auth != null;
      }
    }
    
    // سجلات الحضور
    match /StudentAttendance/{recordId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // سجلات السلوك
    match /behavior_records/{recordId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // بيانات المستخدمين
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // بيانات الطلاب
    match /students/{studentId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // بيانات الفصول
    match /classes/{classId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
    
    // بيانات المعلمين
    match /teachers/{teacherId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null;
    }
  }
}
```

---

### الخطوة 3: انشر القواعد
1. اضغط على زر **Publish** (نشر) في الأعلى
2. انتظر رسالة التأكيد: "Rules published successfully"

---

### الخطوة 4: اختبر التطبيق
1. افتح الموقع: https://etisak-784d6.web.app/
2. امسح الـ Cache: **Ctrl + Shift + R**
3. سجل دخول كوكيل شؤون طلاب
4. يجب أن تظهر البيانات الآن! ✅

---

## 🔒 قواعد بديلة (للتطوير فقط):

إذا كنت تريد قواعد أبسط للتطوير والاختبار:

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

**⚠️ تحذير**: هذه القواعد تسمح بالوصول الكامل لجميع المستخدمين المسجلين. استخدمها فقط للتطوير!

---

## 🎯 التحقق من الصلاحيات:

### 1. تحقق من Authentication:
1. في Firebase Console، اذهب إلى **Authentication**
2. تأكد من وجود مستخدمين مسجلين
3. تأكد من أن المستخدم الذي تسجل دخوله موجود

### 2. تحقق من البيانات:
1. في Firebase Console، اذهب إلى **Firestore Database**
2. تأكد من وجود البيانات في المجموعات:
   - `Schools/{schoolId}/...`
   - `StudentAttendance`
   - `behavior_records`
   - `users`
   - `students`

### 3. تحقق من الأخطاء:
1. افتح الموقع: https://etisak-784d6.web.app/
2. اضغط **F12** لفتح Developer Tools
3. اذهب إلى تبويب **Console**
4. ابحث عن أخطاء Firestore

---

## 📊 الأخطاء الشائعة وحلولها:

### خطأ 1: "Missing or insufficient permissions"
**الحل**: حدّث قواعد Firestore كما هو موضح أعلاه

### خطأ 2: "User not authenticated"
**الحل**: تأكد من تسجيل الدخول بشكل صحيح

### خطأ 3: "Collection does not exist"
**الحل**: تأكد من وجود البيانات في Firestore

### خطأ 4: "Network error"
**الحل**: تحقق من الاتصال بالإنترنت

---

## 🔍 اختبار الصلاحيات:

بعد تحديث القواعد، اختبر كل قسم:

### 1. اختبار الحضور:
```dart
// يجب أن يعمل هذا الاستعلام:
FirebaseFirestore.instance
    .collection('StudentAttendance')
    .where('schoolId', isEqualTo: schoolId)
    .get();
```

### 2. اختبار السلوك:
```dart
// يجب أن يعمل هذا الاستعلام:
FirebaseFirestore.instance
    .collection('behavior_records')
    .where('schoolId', isEqualTo: schoolId)
    .get();
```

### 3. اختبار المدارس:
```dart
// يجب أن يعمل هذا الاستعلام:
FirebaseFirestore.instance
    .collection('Schools')
    .doc(schoolId)
    .collection('BathroomPasses')
    .get();
```

---

## ✅ قائمة التحقق:

- [ ] فتحت Firebase Console
- [ ] اخترت مشروع etisak-784d6
- [ ] ذهبت إلى Firestore Database → Rules
- [ ] استبدلت القواعد بالقواعد الجديدة
- [ ] ضغطت Publish
- [ ] انتظرت رسالة التأكيد
- [ ] مسحت الـ Cache (Ctrl + Shift + R)
- [ ] سجلت دخول في التطبيق
- [ ] البيانات تظهر الآن! ✅

---

## 🎉 النتيجة المتوقعة:

بعد تطبيق هذه الخطوات:
- ✅ البيانات تُحمّل بشكل صحيح
- ✅ لا توجد رسائل خطأ
- ✅ جميع الإحصائيات تظهر
- ✅ البطاقات تعرض الأرقام الصحيحة

---

## 📞 إذا لم تحل المشكلة:

1. **تحقق من Console**:
   - افتح Developer Tools (F12)
   - ابحث عن أخطاء في Console
   - أرسل لي رسالة الخطأ

2. **تحقق من Network**:
   - في Developer Tools، اذهب إلى Network
   - ابحث عن طلبات Firestore الفاشلة
   - تحقق من رسالة الخطأ

3. **تحقق من Authentication**:
   - تأكد من تسجيل الدخول
   - تحقق من وجود `user.schoolId`

---

**الخلاصة**: 
- ✅ حدّث قواعد Firestore
- ✅ انشر القواعد
- ✅ امسح الـ Cache
- ✅ البيانات ستظهر!

**الرابط**: https://etisak-784d6.web.app/

**ملاحظة**: تحديث القواعد يستغرق بضع ثوانٍ فقط!
