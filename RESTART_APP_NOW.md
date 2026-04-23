# ⚠️ يجب إعادة تشغيل التطبيق الآن

## التغييرات التي تم إجراؤها:

### 1. ✅ تم تحديث `active_plans_screen.dart`
- تم تبسيط الشاشة بدون Riverpod
- استخدام `StreamBuilder` مباشرة من Firebase
- إضافة ثلاث أزرار: **عرض | تعديل | حذف**

### 2. ✅ تم تحديث `plan_edit_screen.dart`
- إضافة دالة `_delete()` الكاملة
- ثلاث أزرار: **إلغاء | حفظ | حذف**

### 3. ✅ تم تحديث `plan_details_screen.dart`
- عرض تفاصيل الخطة بشكل صحيح
- زر تعديل وزر حذف

---

## 🔴 **ما يجب فعله الآن:**

### الخطوة 1: إيقاف التطبيق
اضغط `Ctrl+C` في Terminal لإيقاف التطبيق الحالي

### الخطوة 2: تنظيف المشروع
```bash
flutter clean
```

### الخطوة 3: إعادة تشغيل التطبيق
```bash
flutter run
```

---

## ✅ بعد إعادة التشغيل ستظهر:

1. **قائمة الخطط** مع جميع الخطط من Firebase
2. **ثلاث أزرار** لكل خطة:
   - 👁️ **عرض** - لعرض التفاصيل
   - ✏️ **تعديل** - لتعديل الخطة
   - 🗑️ **حذف** - لحذف الخطة

3. **في شاشة التعديل:**
   - حقول للتعديل
   - ثلاث أزرار: إلغاء | حفظ | حذف

---

## 🐛 إذا لم تظهر الخطط:

تأكد من:
1. وجود بيانات في مجموعة `education_plans` في Firebase
2. أن البيانات تحتوي على الحقول: `planName` و `studentName`
3. فحص Console للأخطاء

---

**الملفات المعدلة:**
- `lib/src/features/academic/presentation/active_plans_screen.dart`
- `lib/src/features/academic/presentation/plan_edit_screen.dart`
- `lib/src/features/academic/presentation/plan_details_screen.dart`
