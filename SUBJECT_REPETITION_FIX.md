# إصلاح تكرار المواد في نفس اليوم

## المشكلة
كان الجدول الناتج يضع نفس المادة أكثر من مرة في نفس اليوم لنفس الفصل (مثل 3 حصص رياضيات في يوم واحد)، وهذا غير منطقي تربوياً في المرحلة الثانوية.

## الحل المطبق
تم تطبيق حل بسيط ومباشر كما طلب المستخدم:

### 1. استعادة النسخة المستقرة
- تم إزالة محاولة إعادة الكتابة الكاملة للخوارزمية (`_distributeSubjectsAcrossWeek`)
- تم إصلاح الأخطاء في الملف (duplicate classes, missing braces)
- تم استعادة الهيكل البسيط والمستقر للكود

### 2. تطبيق التعديل الوحيد
تم تغيير `maxSubjectPerDay` من 2 إلى 1 في جميع استدعاءات `_pickSubjectForClass`:

```dart
final subjectId = _pickSubjectForClass(
  cid: cid,
  teacherId: chosenTeacher,
  teacherSubjects: teacherSubjects,
  usageByClass: usageByClass,
  coreSubjectSet: coreSubjectSet,
  fallbackSubjectIds: availableSubjectIds,
  subjectRarity: subjectRarity,
  currentDay: day,
  maxSubjectPerDay: 1,  // ✅ تم التغيير من 2 إلى 1
  lessonByClass: lessonByClass,
);
```

### 3. تحسين منطق اختيار المادة
تم تحديث دالة `_pickSubjectForClass` لتتضمن:

- **تتبع المواد المستخدمة اليوم**: جمع جميع المواد الموضوعة في نفس اليوم
- **منع التكرار**: تخطي المواد التي وصلت للحد الأقصى (`maxSubjectPerDay`)
- **إعطاء أولوية**: المواد غير المستخدمة اليوم تحصل على أولوية أعلى

```dart
// جمع المواد المستخدمة في هذا اليوم
final subjectsUsedToday = <String>{};
if (lessonByClass != null && lessonByClass.containsKey(cid)) {
  final daySchedule = lessonByClass[cid]![currentDay];
  if (daySchedule != null) {
    for (final lesson in daySchedule.values) {
      subjectsUsedToday.add(lesson.subjectId);
    }
  }
}

// تحقق من عدد مرات استخدام المادة اليوم
final usedTodayCount = subjectsUsedToday.where((sub) => sub == s).length;
if (usedTodayCount >= maxSubjectPerDay) continue; // تخطي

// إعطاء أولوية للمواد غير المستخدمة اليوم
final todayPenalty = subjectsUsedToday.contains(s) ? 1000 : 0;
final adjustedCount = c + todayPenalty;
```

## الملفات المعدلة
- `lib/src/features/intelligence/domain/scheduling/v2/solver/solver_engine.dart`

## النتيجة المتوقعة
- كل مادة تظهر مرة واحدة فقط في اليوم لكل فصل
- توزيع أفضل للمواد على أيام الأسبوع
- جدول أكثر واقعية وملاءمة تربوياً

## الخطوات التالية
1. اختبار الجدول الناتج على نفس البيانات
2. التحقق من عدم وجود تكرار للمواد في نفس اليوم
3. إذا ظهرت مشاكل جديدة، تقييم الحاجة لتحسينات إضافية

## ملاحظات
- تم اتباع نهج تدريجي بسيط كما طلب المستخدم
- لم يتم إجراء إعادة هيكلة كبيرة
- التركيز على الاستقرار والتحسين المباشر
- النسخة المنشورة: https://etisak-784d6.web.app

---
**تاريخ التطبيق**: 2026-03-18
**الحالة**: ✅ تم النشر بنجاح
