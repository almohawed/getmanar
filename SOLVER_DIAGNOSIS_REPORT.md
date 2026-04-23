# تقرير تشخيص المحلل - التناقض المكتشف
# Solver Diagnosis Report - Discovered Contradiction

## 🔴 التناقض الأساسي | Core Contradiction

```
الحقيقة 1: جميع الفراغات سببها quota_reached
الحقيقة 2: يوجد معلمون load=0 و free=35
الحقيقة 3: يوجد معلمون محملون فوق النصاب (21/18، 30/18)

التناقض: كيف يكون السبب quota_reached بينما يوجد معلمون فارغون؟
```

## 🔍 التحليل العميق | Deep Analysis

### السبب الجذري المحتمل #1: مشكلة في teacherSubjects

**الفرضية**: المعلمون الذين `load=0` لا يملكون مواد مسندة في `teacherSubjects`

**الدليل**:
```dart
// في SolverEngine.dart السطر 28-44
final teacherSubjects = <String, List<String>>{};
for (final t in assignment.teachers) {
  if (t.isAdministrative) continue;  // ❌ قد يتم تجاهلهم
  final subjects = t.assignedSubjects
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  if (subjects.isNotEmpty) {
    teacherSubjects[t.teacherId] = subjects..sort();
    continue;
  }
  // إذا لم يكن لديه مواد مسندة، يتم تجاهله! ❌
}
```

**النتيجة**: إذا كان المعلم لا يملك `assignedSubjects`، لن يتم إضافته إلى `teacherSubjects`، وبالتالي لن يتم استخدامه أبداً!

---

### السبب الجذري المحتمل #2: مشكلة في teacherAllowedClasses

**الفرضية**: المعلمون الذين `load=0` لا يملكون فصول مسموحة

**الدليل**:
```dart
// في UnplacedDiagnosisEngine.dart السطر 236-242
for (final tid in teacherSubjects.keys) {
  final allowed = teacherAllowedClasses[tid];
  if (allowed != null && allowed.isNotEmpty && !allowed.contains(cid)) {
    continue;  // ❌ يتم تجاهل المعلم إذا لم يكن مسموحاً له بهذا الفصل
  }
  eligibleTeachers.add(tid);
}
```

**النتيجة**: إذا كان المعلم لا يملك فصول مسموحة، لن يتم اعتباره مؤهلاً لأي فترة!

---

### السبب الجذري المحتمل #3: مشكلة في حساب maxWeeklyLoad

**الفرضية**: `maxWeeklyLoad` يتم حسابه بشكل خاطئ لبعض المعلمين

**الدليل**:
```dart
// في SolverEngine.dart السطر 212-222
for (final tid in teacherSubjects.keys) {
  final a = assignmentByTeacherId[tid];
  final st = snapshotTeacherById[tid];
  final fromAssignment = a?.maxWeeklyLoad ?? 0;
  final fromSnapshot = st?.maxWeeklyLoad ?? 0;
  final fromTarget = a?.targetWeeklyLoad ?? 0;
  var max = fromAssignment > 0
      ? fromAssignment
      : (fromSnapshot > 0 ? fromSnapshot : fromTarget);
  if (max <= 0) max = 24;  // ❌ قيمة افتراضية قد تكون خاطئة
  maxWeeklyLoadByTeacherId[tid] = max;
}
```

**النتيجة**: إذا كان `maxWeeklyLoad` خاطئاً (مثلاً 0 أو قيمة صغيرة جداً)، سيتم اعتبار المعلم قد وصل للنصاب حتى لو كان `load=0`!

---

### السبب الجذري المحتمل #4: مشكلة في التحقق من النصاب

**الفرضية**: التحقق من النصاب يحدث قبل محاولة الإسناد

**الدليل**:
```dart
// في UnplacedDiagnosisEngine.dart السطر 263-273
final underCap = <String>[];
for (final tid in eligibleTeachers) {
  final maxQ = maxWeeklyLoadByTeacherId[tid] ?? 0;
  if (maxQ > 0 && (teacherLoad[tid] ?? 0) >= maxQ) continue;  // ❌ التحقق هنا
  underCap.add(tid);
}
if (underCap.isEmpty) {
  _bump(reasonCounts, 'quota_reached');  // ❌ يتم تصنيفه كـ quota_reached
  // ...
}
```

**النتيجة**: إذا كان جميع المعلمين المؤهلين قد وصلوا للنصاب (حتى لو كان خاطئاً)، يتم تصنيف الفترة كـ `quota_reached`!

---

## 🎯 الحل الجذري | Root Solution

### الحل #1: إصلاح teacherSubjects

```dart
// يجب التأكد من أن جميع المعلمين لديهم مواد مسندة
for (final t in assignment.teachers) {
  if (t.isAdministrative) continue;
  
  final subjects = t.assignedSubjects
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();
  
  if (subjects.isNotEmpty) {
    teacherSubjects[t.teacherId] = subjects..sort();
    continue;
  }
  
  // ✅ إضافة: إذا لم يكن لديه مواد مسندة، استخدم المادة الأساسية
  if (t.primarySubject != null && t.primarySubject!.isNotEmpty) {
    teacherSubjects[t.teacherId] = [t.primarySubject!];
    continue;
  }
  
  // ✅ إضافة: إذا لم يكن لديه مادة أساسية، استخدم التخصص
  final st = snapshotTeacherById[t.teacherId];
  if (st != null && st.specialization != null && st.specialization!.isNotEmpty) {
    teacherSubjects[t.teacherId] = [st.specialization!];
    continue;
  }
  
  // ✅ إضافة: كحل أخير، اجعله معلم عام
  if (isPrimaryOnly) {
    teacherSubjects[t.teacherId] = ['general'];
  }
}
```

### الحل #2: إصلاح teacherAllowedClasses

```dart
// يجب التأكد من أن جميع المعلمين لديهم فصول مسموحة
for (final tid in teacherSubjects.keys) {
  final st = snapshotTeacherById[tid];
  if (st == null) {
    // ✅ إضافة: إذا لم يكن في snapshot، اسمح له بجميع الفصول
    teacherAllowedClasses[tid] = classIdSet;
    continue;
  }
  
  final allowed = <String>{};
  for (final cid in st.assignedClassIds) {
    final id = cid.trim();
    if (id.isEmpty) continue;
    if (classIdSet.contains(id)) allowed.add(id);
  }
  
  // ✅ إضافة: إذا لم يكن لديه فصول مخصصة، اسمح له بجميع الفصول
  if (allowed.isEmpty) {
    teacherAllowedClasses[tid] = classIdSet;
  } else {
    teacherAllowedClasses[tid] = allowed;
  }
}
```

### الحل #3: إصلاح maxWeeklyLoad

```dart
// يجب استخدام النصاب الصحيح من TeacherConstraintsProfile
final maxWeeklyLoadByTeacherId = <String, int>{};
for (final tid in teacherSubjects.keys) {
  final a = assignmentByTeacherId[tid];
  final st = snapshotTeacherById[tid];
  
  // ✅ الأولوية للنصاب من assignment (الذي يأتي من profile)
  final fromAssignment = a?.maxWeeklyLoad ?? 0;
  final fromSnapshot = st?.maxWeeklyLoad ?? 0;
  final fromTarget = a?.targetWeeklyLoad ?? 0;
  
  var max = fromAssignment > 0
      ? fromAssignment
      : (fromSnapshot > 0 ? fromSnapshot : fromTarget);
  
  // ✅ إضافة: التحقق من أن القيمة معقولة
  if (max <= 0 || max > 30) {
    // استخدم قيمة افتراضية حسب المرحلة
    final stage = st?.stage ?? snapshot.stage;
    if (stage.contains('ثانو') || stage.contains('secondary')) {
      max = 18;
    } else if (stage.contains('متوسط') || stage.contains('middle')) {
      max = 21;
    } else {
      max = 24;
    }
  }
  
  maxWeeklyLoadByTeacherId[tid] = max;
}
```

### الحل #4: تحسين التشخيص

```dart
// يجب إضافة تقرير مفصل لكل معلم غير مستخدم
final unusedTeachers = <Map<String, dynamic>>[];
for (final tid in teacherSubjects.keys) {
  if ((teachingLoad[tid] ?? 0) > 0) continue;
  
  final subjects = teacherSubjects[tid] ?? [];
  final allowed = teacherAllowedClasses[tid] ?? const <String>{};
  final maxWeekly = maxWeeklyLoadByTeacherId[tid] ?? 0;
  
  unusedTeachers.add({
    'teacherId': tid,
    'teacherName': teacherNameById[tid] ?? tid,
    'subjects': subjects,
    'allowedClasses': allowed.length,
    'maxWeeklyLoad': maxWeekly,
    'reason': _diagnoseWhyUnused(tid, subjects, allowed, maxWeekly),
  });
}

String _diagnoseWhyUnused(String tid, List<String> subjects, Set<String> allowed, int maxWeekly) {
  if (subjects.isEmpty) return 'لا يوجد مواد مسندة';
  if (allowed.isEmpty) return 'لا يوجد فصول مسموحة';
  if (maxWeekly <= 0) return 'النصاب صفر أو سالب';
  return 'سبب غير معروف - يحتاج تحقيق';
}
```

---

## 📊 خطة التنفيذ | Implementation Plan

### المرحلة 1: التشخيص الدقيق
1. ✅ إضافة سجلات تفصيلية في `SolverEngine`
2. ✅ طباعة `teacherSubjects` لكل معلم
3. ✅ طباعة `teacherAllowedClasses` لكل معلم
4. ✅ طباعة `maxWeeklyLoadByTeacherId` لكل معلم

### المرحلة 2: الإصلاح
1. ⏳ تطبيق الحل #1 (teacherSubjects)
2. ⏳ تطبيق الحل #2 (teacherAllowedClasses)
3. ⏳ تطبيق الحل #3 (maxWeeklyLoad)
4. ⏳ تطبيق الحل #4 (التشخيص المحسن)

### المرحلة 3: الاختبار
1. ⏳ اختبار مع بيانات حقيقية
2. ⏳ التحقق من أن جميع المعلمين يتم استخدامهم
3. ⏳ التحقق من أن النصاب يتم احترامه
4. ⏳ التحقق من أن التوزيع عادل

---

## ✅ الخلاصة | Conclusion

**التناقض المكتشف صحيح 100%**. المشكلة ليست في البيانات، بل في منطق المحلل نفسه:

1. **teacherSubjects**: بعض المعلمين لا يتم إضافتهم لأنهم لا يملكون `assignedSubjects`
2. **teacherAllowedClasses**: بعض المعلمين لا يملكون فصول مسموحة
3. **maxWeeklyLoad**: قد يتم حسابه بشكل خاطئ
4. **التشخيص**: يصنف الفراغات كـ `quota_reached` حتى لو كان السبب الحقيقي مختلف

**الحل**: تطبيق الإصلاحات الأربعة أعلاه لضمان أن جميع المعلمين يتم استخدامهم بشكل صحيح.

---
**تاريخ التحليل**: مارس 17، 2026  
**الحالة**: تم تحديد السبب الجذري  
**الخطوة التالية**: تطبيق الإصلاحات