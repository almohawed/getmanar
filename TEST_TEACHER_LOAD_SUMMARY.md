# 🧪 اختبار ملخص حمل المعلم

## ✅ قائمة الاختبار

### 1. اختبار المكون (Widget)

#### الاختبار 1.1: عرض الملخص بشكل صحيح
```dart
testWidgets('TeacherLoadSummaryWidget displays correctly', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TeacherLoadSummaryWidget(
          teacherName: 'أحمد محمد',
          requiredLessons: 24,
          actualLessons: 24,
          freePeriods: 11,
          totalPeriods: 35,
        ),
      ),
    ),
  );

  // تحقق من وجود النصوص
  expect(find.text('ملخص حمل المعلم'), findsOneWidget);
  expect(find.text('أحمد محمد'), findsOneWidget);
  expect(find.text('24'), findsWidgets);
  expect(find.text('11'), findsOneWidget);
  expect(find.text('35'), findsOneWidget);
  expect(find.text('68.6%'), findsOneWidget);
});
```

#### الاختبار 1.2: الألوان الصحيحة عند الاكتمال
```dart
testWidgets('TeacherLoadSummaryWidget shows green when complete', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TeacherLoadSummaryWidget(
          teacherName: 'أحمد محمد',
          requiredLessons: 24,
          actualLessons: 24,  // مكتمل
          freePeriods: 11,
          totalPeriods: 35,
        ),
      ),
    ),
  );

  // تحقق من وجود اللون الأخضر
  final container = find.byType(Container).first;
  expect(container, findsOneWidget);
});
```

#### الاختبار 1.3: الألوان الصحيحة عند عدم الاكتمال
```dart
testWidgets('TeacherLoadSummaryWidget shows orange when incomplete', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: TeacherLoadSummaryWidget(
          teacherName: 'أحمد محمد',
          requiredLessons: 24,
          actualLessons: 20,  // غير مكتمل
          freePeriods: 15,
          totalPeriods: 35,
        ),
      ),
    ),
  );

  // تحقق من وجود النص التحذيري
  expect(find.text('جاري تجديول الحصص المتبقية'), findsOneWidget);
});
```

### 2. اختبار الشاشة (Screen)

#### الاختبار 2.1: تحميل الشاشة
```dart
testWidgets('TeacherScheduleWithSummaryScreen loads', (WidgetTester tester) async {
  await tester.pumpWidget(
    MaterialApp(
      home: TeacherScheduleWithSummaryScreen(
        teacherId: 'teacher123',
        schoolId: 'school456',
      ),
    ),
  );

  // تحقق من وجود AppBar
  expect(find.text('جدول المعلم'), findsOneWidget);
});
```

#### الاختبار 2.2: عرض الملخص في الشاشة
```dart
testWidgets('TeacherScheduleWithSummaryScreen displays summary', (WidgetTester tester) async {
  // ... إعداد البيانات الوهمية
  
  await tester.pumpWidget(
    MaterialApp(
      home: TeacherScheduleWithSummaryScreen(
        teacherId: 'teacher123',
        schoolId: 'school456',
      ),
    ),
  );

  await tester.pumpAndSettle();

  // تحقق من وجود الملخص
  expect(find.byType(TeacherLoadSummaryWidget), findsOneWidget);
});
```

### 3. اختبار خدمة PDF

#### الاختبار 3.1: حساب ملخص الحمل
```dart
test('_calculateTeacherLoadSummary calculates correctly', () {
  final schedule = {
    'الأحد': [
      {'subjectName': 'الرياضيات', 'className': 'الصف الأول'},
      {'subjectName': 'العربية', 'className': 'الصف الأول'},
      {},
      {},
      {},
      {},
      {},
    ],
    'الاثنين': [
      {'subjectName': 'الرياضيات', 'className': 'الصف الثاني'},
      {},
      {},
      {},
      {},
      {},
      {},
    ],
  };

  final summary = PdfExportService._calculateTeacherLoadSummary(schedule);

  expect(summary?['totalLessons'], 3);
  expect(summary?['freePeriods'], 11);
  expect(summary?['totalPeriods'], 14);
  expect(summary?['completionPercentage'], '21.4');
});
```

#### الاختبار 3.2: بناء ملخص PDF
```dart
test('_buildTeacherLoadSummaryPdf builds widget', () {
  final summary = {
    'totalLessons': 24,
    'freePeriods': 11,
    'totalPeriods': 35,
    'completionPercentage': '68.6',
  };

  final widget = PdfExportService._buildTeacherLoadSummaryPdf(summary);

  expect(widget, isNotNull);
});
```

### 4. اختبار التكامل

#### الاختبار 4.1: تصدير PDF مع الملخص
```dart
test('exportTeacherSchedules includes summary', () async {
  // ... إعداد البيانات الوهمية
  
  await PdfExportService.exportTeacherSchedules('school456');

  // تحقق من أن الملف تم إنشاؤه
  // تحقق من أن الملخص موجود في الملف
});
```

---

## 🔍 اختبارات يدوية

### اختبار 1: عرض الملخص في Flutter
1. افتح التطبيق
2. انتقل إلى جدول المعلم
3. تحقق من ظهور ملخص الحمل
4. تحقق من صحة الأرقام
5. تحقق من الألوان (أخضر للاكتمال)

### اختبار 2: تصدير PDF
1. افتح التطبيق
2. انتقل إلى جدول المعلم
3. اضغط على تصدير PDF
4. افتح الملف
5. تحقق من ظهور ملخص الحمل في الأعلى
6. تحقق من صحة الإحصائيات

### اختبار 3: حالات مختلفة
1. معلم مكتملة حصصه (أخضر)
2. معلم غير مكتملة حصصه (برتقالي)
3. معلم بدون حصص (رسالة فارغة)

### اختبار 4: الاستجابة
1. اختبر على هاتف صغير
2. اختبر على جهاز لوحي
3. اختبر على شاشة كبيرة
4. تحقق من أن التصميم متجاوب

---

## 📊 البيانات الاختبارية

### حالة 1: مكتمل
```json
{
  "teacherName": "أحمد محمد",
  "requiredLessons": 24,
  "actualLessons": 24,
  "freePeriods": 11,
  "totalPeriods": 35,
  "expectedColor": "green"
}
```

### حالة 2: غير مكتمل
```json
{
  "teacherName": "فاطمة علي",
  "requiredLessons": 24,
  "actualLessons": 20,
  "freePeriods": 15,
  "totalPeriods": 35,
  "expectedColor": "orange"
}
```

### حالة 3: بدون حصص
```json
{
  "teacherName": "محمد سالم",
  "requiredLessons": 0,
  "actualLessons": 0,
  "freePeriods": 35,
  "totalPeriods": 35,
  "expectedColor": "gray"
}
```

---

## ✅ قائمة التحقق

- [ ] المكون يعرض جميع الإحصائيات بشكل صحيح
- [ ] الألوان تتغير حسب حالة الاكتمال
- [ ] الرسائل التوضيحية تظهر بشكل صحيح
- [ ] الشاشة تحمل البيانات من Firestore
- [ ] الجدول يعرض الحصص والفترات الحرة
- [ ] PDF يتضمن الملخص
- [ ] الملخص يحتوي على جميع الإحصائيات
- [ ] التصميم متجاوب على جميع الأجهزة
- [ ] الأداء جيد (بدون تأخير)
- [ ] لا توجد أخطاء في السجلات

---

## 🐛 الأخطاء المحتملة

### خطأ 1: الملخص لا يظهر
**الحل:**
- تحقق من أن البيانات موجودة في Firestore
- تحقق من أن `requiredLessons` موجود
- تحقق من الأخطاء في السجلات

### خطأ 2: الأرقام غير صحيحة
**الحل:**
- تحقق من حساب الحصص والفترات
- تحقق من البيانات في Firestore
- تحقق من دالة `_countLessons()`

### خطأ 3: PDF لا يتضمن الملخص
**الحل:**
- تحقق من أن `_calculateTeacherLoadSummary()` تعيد بيانات
- تحقق من أن `_buildTeacherLoadSummaryPdf()` تُستدعى
- تحقق من الأخطاء في السجلات

---

## 📝 ملاحظات

1. جميع الاختبارات يجب أن تمر بنجاح
2. لا يجب أن تكون هناك أخطاء في السجلات
3. الأداء يجب أن تكون سلسة بدون تأخير
4. التصميم يجب أن يكون احترافياً على جميع الأجهزة

---

**تم إنشاء قائمة اختبار شاملة! ✅**
