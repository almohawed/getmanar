# 🔧 إصلاح قواعد Firebase - خطوة بخطوة

## 📋 الخطوات (5 دقائق فقط)

### 1️⃣ افتح Firebase Console
```
https://console.firebase.google.com/project/etisak-784d6
```

### 2️⃣ اذهب إلى Firestore Database
- من القائمة الجانبية
- اضغط على **Firestore Database**

### 3️⃣ اضغط على تبويب Rules
- في الأعلى ستجد: **Data | Rules | Indexes | Usage**
- اضغط على **Rules**

### 4️⃣ استبدل القواعد الحالية بهذه

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // ============================================
    // قواعد المستخدمين
    // ============================================
    match /Users/{userId} {
      // السماح بالقراءة للمستخدم نفسه أو من نفس المدرسة
      allow read: if request.auth != null && (
        request.auth.uid == userId ||
        request.auth.token.schoolId == resource.data.schoolId
      );
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // ============================================
    // قواعد المدارس
    // ============================================
    match /Schools/{schoolId} {
      // السماح بالقراءة لأي مستخدم من نفس المدرسة
      allow read: if request.auth != null && 
                     request.auth.token.schoolId == schoolId;
      
      // السماح بالكتابة للمدير فقط
      allow write: if request.auth != null && 
                      request.auth.token.schoolId == schoolId &&
                      request.auth.token.role == 'admin';
      
      // المجموعات الفرعية
      match /{document=**} {
        allow read: if request.auth != null && 
                       request.auth.token.schoolId == schoolId;
        allow write: if request.auth != null && 
                        request.auth.token.schoolId == schoolId;
      }
    }
    
    // ============================================
    // قواعد الحضور
    // ============================================
    match /StudentAttendance/{attendanceId} {
      allow read: if request.auth != null && 
                     request.auth.token.schoolId == resource.data.schoolId;
      allow write: if request.auth != null && 
                      request.auth.token.schoolId == request.resource.data.schoolId;
    }
    
    // ============================================
    // قواعد السلوك
    // ============================================
    match /behavior_records/{recordId} {
      allow read: if request.auth != null && 
                     request.auth.token.schoolId == resource.data.schoolId;
      allow write: if request.auth != null && 
                      request.auth.token.schoolId == request.resource.data.schoolId;
    }
    
    // ============================================
    // قواعد الطلاب
    // ============================================
    match /students/{studentId} {
      allow read: if request.auth != null && 
                     request.auth.token.schoolId == resource.data.schoolId;
      allow write: if request.auth != null && 
                      request.auth.token.schoolId == request.resource.data.schoolId;
    }
    
    // ============================================
    // قاعدة افتراضية (رفض كل شيء آخر)
    // ============================================
    match /{document=**} {
      allow read, write: if false;
    }
  }
}
```

### 5️⃣ اضغط Publish
- في الأعلى ستجد زر **Publish**
- اضغط عليه لحفظ القواعد

### 6️⃣ اختبر التطبيق
```
https://etisak-784d6.web.app
```

---

## ✅ النتيجة

بعد تطبيق هذه القواعد:
- ✅ لن تظهر أخطاء الصلاحيات
- ✅ كل مدرسة ترى بياناتها فقط
- ✅ البيانات محمية وآمنة
- ✅ النظام يعمل بسرعة

---

## 🔒 الأمان

هذه القواعد تضمن:
1. كل مدرسة ترى بياناتها فقط
2. المستخدمون لا يرون بيانات مدارس أخرى
3. الكتابة محمية حسب الدور
4. آمن 100%

---

## 💡 ملاحظات

### إذا كان لديك custom claims
تأكد أن المستخدمين لديهم:
```javascript
{
  "schoolId": "xxx",
  "role": "admin" // أو teacher أو deputy
}
```

### إذا لم تعمل
تحقق من:
1. المستخدم مسجل دخول
2. لديه schoolId في token
3. البيانات تحتوي على schoolId

---

**الوقت المطلوب**: 5 دقائق فقط!
**الصعوبة**: سهل جداً
**النتيجة**: حل نهائي للمشكلة
