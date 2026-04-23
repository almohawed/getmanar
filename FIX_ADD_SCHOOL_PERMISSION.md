# إصلاح مشكلة صلاحيات إضافة المدرسة

## المشكلة
عند محاولة إضافة مدرسة جديدة، يظهر الخطأ التالي:
```
This operation is restricted to administrators only [firebase_auth/admin-restricted-operation]
```

## السبب
Cloud Function `registerNewSchool` كانت تسمح لأي مستخدم بإنشاء مدارس جديدة دون التحقق من صلاحيات Super Admin.

## الحل

### 1. تحديث Cloud Function
تم إضافة التحقق من صلاحيات Super Admin في `functions/src/auth.ts`:

```typescript
// التحقق من أن المستخدم مسجل دخول
if (!context.auth) {
  throw new functions.https.HttpsError("unauthenticated", "يجب تسجيل الدخول أولاً");
}

// التحقق من أن المستخدم هو Super Admin
const callerUid = context.auth.uid;
const callerDoc = await db.collection("GlobalUsers").doc(callerUid).get();
const callerRole = callerDoc.data()?.role;
const callerEmail = context.auth.token.email;

const isSuperAdmin = 
  callerRole === 'superAdmin' || 
  callerRole === 'Owner' || 
  callerRole === 'owner' ||
  callerEmail === 'mohwed32@getmanar.com' ||
  // ... بقية الإيميلات المصرح بها

if (!isSuperAdmin) {
  throw new functions.https.HttpsError(
    "permission-denied", 
    "هذه العملية مقتصرة على مدير التطبيق فقط"
  );
}
```

### 2. تحسين رسائل الخطأ
تم تحسين معالجة الأخطاء في:
- `lib/src/features/super_admin/data/super_admin_repository.dart`
- `lib/src/features/super_admin/presentation/add_school_screen.dart`

الآن يتم عرض رسائل خطأ واضحة للمستخدم:
- "هذه العملية مقتصرة على مدير التطبيق فقط" - عند عدم وجود صلاحيات
- "يجب تسجيل الدخول أولاً" - عند عدم تسجيل الدخول
- "رقم الهوية أو البريد الإلكتروني مستخدم بالفعل" - عند وجود تكرار

## خطوات النشر

### 1. نشر Cloud Functions
قم بتشغيل الملف التالي لنشر التحديثات:
```bash
deploy_functions.bat
```

أو يدوياً:
```bash
cd functions
npm install
npm run build
cd ..
firebase deploy --only functions
```

### 2. التحقق من الصلاحيات
تأكد من أن المستخدم الذي يحاول إضافة المدرسة لديه أحد الأدوار التالية في `GlobalUsers`:
- `role: 'superAdmin'`
- `role: 'Owner'`
- `role: 'owner'`

أو أحد الإيميلات المصرح بها:
- mohwed32@getmanar.com
- mohawed32@manar.com
- mohwed32@manar.com
- mohawed32@getmanar.com

### 3. اختبار الحل
1. سجل دخول كمستخدم Super Admin
2. انتقل إلى شاشة إضافة مدرسة جديدة
3. املأ البيانات المطلوبة
4. اضغط على "إضافة المدرسة"
5. يجب أن تتم العملية بنجاح

## ملاحظات مهمة

### للمستخدمين العاديين
إذا حاول مستخدم عادي (غير Super Admin) الوصول إلى شاشة إضافة المدرسة، سيظهر له رسالة خطأ واضحة تفيد بأن هذه العملية مقتصرة على مدير التطبيق فقط.

### للمطورين
- تأكد من أن Firebase Admin SDK مهيأ بشكل صحيح في Cloud Functions
- تأكد من أن قواعد Firestore Security Rules تسمح بقراءة `GlobalUsers` للتحقق من الصلاحيات
- يمكن إضافة المزيد من الإيميلات المصرح بها في Cloud Function حسب الحاجة

## الملفات المعدلة
1. `functions/src/auth.ts` - إضافة التحقق من صلاحيات Super Admin وإنشاء الدوال المفقودة:
   - `registerNewSchool` - تحديث للتحقق من الصلاحيات
   - `createSchoolAdminProvision` - دالة جديدة لإنشاء المستخدمين
   - `deleteSchoolDeep` - دالة جديدة لحذف المدارس
2. `functions/src/index.ts` - تصدير الدوال الجديدة
3. `lib/src/features/super_admin/data/super_admin_repository.dart` - تحسين معالجة الأخطاء
4. `lib/src/features/super_admin/presentation/add_school_screen.dart` - تحسين عرض رسائل الخطأ
5. `deploy_functions.bat` - ملف جديد لتسهيل نشر Cloud Functions

## الدوال الجديدة المضافة

### createSchoolAdminProvision
دالة لإنشاء مستخدمين جدد (مدراء، موظفين، معلمين، إلخ) مع التحقق من الصلاحيات:
- يمكن لـ Super Admin إنشاء مستخدمين لأي مدرسة
- يمكن لمدير المدرسة إنشاء مستخدمين لمدرسته فقط
- تتحقق من عدم تكرار رقم الهوية أو البريد الإلكتروني

### deleteSchoolDeep
دالة لحذف المدرسة وجميع المستخدمين المرتبطين بها:
- مقتصرة على Super Admin فقط
- تحذف المدرسة من Firestore
- تحذف جميع المستخدمين المرتبطين من GlobalUsers
- تحذف حسابات المستخدمين من Firebase Auth
