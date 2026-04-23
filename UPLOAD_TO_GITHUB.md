# 📤 رفع التحديثات إلى GitHub

## الملفات المحدثة:

```
✅ lib/src/features/academic/presentation/active_plans_screen.dart
✅ lib/src/features/academic/presentation/plan_edit_screen.dart
✅ lib/src/features/academic/presentation/plan_details_screen.dart
```

---

## 🚀 خطوات الرفع:

### الخطوة 1: فتح Terminal في مجلد المشروع

```bash
cd path/to/your/project
```

### الخطوة 2: التحقق من الحالة

```bash
git status
```

### الخطوة 3: إضافة التحديثات

```bash
git add lib/src/features/academic/presentation/
```

### الخطوة 4: كتابة رسالة التحديث

```bash
git commit -m "✨ إضافة أزرار الحذف والتعديل لقائمة الخطط

- تحديث active_plans_screen.dart: إضافة ثلاث أزرار (عرض | تعديل | حذف)
- تحديث plan_edit_screen.dart: إضافة دالة _delete() الكاملة
- تحديث plan_details_screen.dart: تحسين عرض البيانات
- استخدام StreamBuilder بدلاً من Riverpod للأداء الأفضل"
```

### الخطوة 5: الرفع إلى GitHub

```bash
git push origin main
```

أو إذا كان الفرع مختلف:
```bash
git push origin <branch_name>
```

---

## ✅ بعد الرفع:

ستجد الرابط في GitHub:
```
https://github.com/your-username/your-repo/commits/main
```

أو الرابط المباشر للملفات:
```
https://github.com/your-username/your-repo/tree/main/lib/src/features/academic/presentation
```

---

## 🔍 إذا لم تكن قد أعددت Git:

### الخطوة 1: تهيئة Git

```bash
git init
git add .
git commit -m "Initial commit"
```

### الخطوة 2: إضافة Remote

```bash
git remote add origin https://github.com/your-username/your-repo.git
```

### الخطوة 3: الرفع

```bash
git branch -M main
git push -u origin main
```

---

## 📝 ملخص التحديثات:

### 1️⃣ **active_plans_screen.dart**
- ✅ تحميل الخطط من Firebase مباشرة
- ✅ ثلاث أزرار: عرض | تعديل | حذف
- ✅ معالجة الأخطاء والحالات الفارغة

### 2️⃣ **plan_edit_screen.dart**
- ✅ شاشة تعديل احترافية
- ✅ ثلاث أزرار: إلغاء | حفظ | حذف
- ✅ دالة `_delete()` كاملة مع تأكيد

### 3️⃣ **plan_details_screen.dart**
- ✅ عرض تفاصيل الخطة
- ✅ أزرار تعديل وحذف
- ✅ معالجة البيانات المرنة

---

## 🎯 الميزات الجديدة:

✨ **قائمة الخطط:**
- عرض جميع الخطط من Firebase
- ثلاث أزرار واضحة لكل خطة
- تحديث فوري عند الحذف

✨ **شاشة التعديل:**
- تحميل البيانات تلقائياً
- حفظ التغييرات
- حذف الخطة مع تأكيد

✨ **شاشة التفاصيل:**
- عرض كامل معلومات الخطة
- أزرار سهلة الاستخدام

---

**هل تحتاج مساعدة في أي خطوة؟** 🤔
