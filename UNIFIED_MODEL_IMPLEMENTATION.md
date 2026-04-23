# تنفيذ النموذج الموحد للجدول الدراسي

## التاريخ
19 مارس 2026

## الهدف
توحيد مصدر البيانات أثناء توليد الجدول لتجنب التعارضات والقراءة المتفرقة من مصادر متعددة.

## التسلسل الجديد
```
Firestore → SchoolDataCollector → UnifiedScheduleModel → SimpleCleanSolver → DemandModel
```

## الملفات المنشأة

### 1. UnifiedScheduleModel
**المسار**: `lib/src/features/intelligence/domain/scheduling/v2/models/unified_schedule_model.dart`

**المكونات**:
- `UnifiedScheduleModel`: النموذج الرئيسي الذي يحتوي على كل البيانات
- `TeacherData`: بيانات المعلم (الاسم، المواد، الفصول المسندة، النصاب)
- `ClassData`: بيانات الفصل (الاسم، المرحلة، المواد المطلوبة)
- `SubjectData`: بيانات المادة (الاسم، الاسم الموحد، الحد الأقصى في اليوم)
- `ScheduleConstraints`: القيود (عدد الأيام، الحصص، أسماء الأيام)

### 2. SchoolDataCollector
**المسار**: `lib/src/features/intelligence/domain/scheduling/v2/collector/school_data_collector.dart`

**الوظيفة**: جمع البيانات من مصادر متعددة وتوحيدها

**المصادر**:
- `SchoolSnapshot`: بيانات المدرسة والمعلمين والفصول
- `AssignmentModel`: الإسنادات والنصاب
- `saudi_subject_plans.json`: الخطة الدراسية السعودية
- `SubjectNormalizer`: توحيد أسماء المواد

**العمليات**:
1. `_collectTeachers()`: جمع بيانات المعلمين مع توحيد المواد
2. `_collectClasses()`: جمع بيانات الفصول مع الخطة الدراسية
3. `_collectSubjects()`: جمع بيانات المواد مع التوحيد
4. `_collectConstraints()`: جمع القيود الزمنية

### 3. SimpleCleanSolver (محدّث)
**المسار**: `lib/src/features/intelligence/domain/scheduling/v2/solver/simple_clean_solver.dart`

**التغيير الرئيسي**:
```dart
// قبل
Future<DemandModel> solve(
  SchoolSnapshot snapshot,
  PolicyProfile policy,
  AssignmentModel assignment,
  {onProgress}
)

// بعد
Future<DemandModel> solve(
  UnifiedScheduleModel model,
  {onProgress}
)
```

**الفائدة**: المحرك الآن يقرأ من مصدر واحد فقط بدلاً من ثلاثة مصادر

### 4. UltraFastSolver (محدّث)
**المسار**: `lib/src/features/intelligence/domain/scheduling/v2/solver/ultra_fast_solver.dart`

**الدور الجديد**: جسر بين الواجهة القديمة والنموذج الموحد

```dart
Future<DemandModel> solve(
  SchoolSnapshot snapshot,
  PolicyProfile policy,
  AssignmentModel assignment,
  {onProgress}
) async {
  // جمع البيانات في نموذج موحد
  final collector = SchoolDataCollector();
  final unifiedModel = await collector.collect(
    snapshot: snapshot,
    assignment: assignment,
  );

  // تمرير النموذج الموحد للمحرك
  return const SimpleCleanSolver().solve(
    unifiedModel,
    onProgress: onProgress,
  );
}
```

## المزايا

### 1. استقرار أعلى
- قراءة البيانات مرة واحدة في البداية
- لا توجد قراءات متعددة أثناء التوليد
- تجنب التعارضات بين المصادر

### 2. أداء أفضل
- تقليل عمليات القراءة من Firestore
- تقليل عمليات التوحيد والتحويل
- كل البيانات جاهزة في الذاكرة

### 3. صيانة أسهل
- مصدر بيانات واحد واضح
- سهولة تتبع البيانات
- سهولة إضافة حقول جديدة

### 4. اختبار أسهل
- يمكن إنشاء `UnifiedScheduleModel` للاختبار مباشرة
- لا حاجة لإنشاء `SchoolSnapshot` و `PolicyProfile` و `AssignmentModel`

## القواعد المحفوظة

المحرك لا يزال يحترم جميع القواعد:

### قواعد صارمة (لا تُخرق أبداً)
1. منع تعارض المعلم (معلم واحد في وقت واحد)
2. احترام نصاب المعلم
3. احترام الفصول المسندة للمعلم
4. معلم واحد لكل مادة في كل فصل

### قواعد مرنة (يمكن تخفيفها)
1. منع تكرار المادة في نفس اليوم
   - المرحلة 1: منع صارم
   - المرحلة 2: السماح بتكرار محدود
   - المرحلة 3: السماح بأي تكرار

## الاختبار

### البناء
```bash
flutter clean
flutter build web --release
```
✅ نجح البناء بدون أخطاء

### النشر
```bash
firebase deploy --only hosting
```
✅ تم النشر بنجاح على: https://etisak-784d6.web.app

## الخطوات التالية

1. اختبار توليد الجدول على المدرسة الحقيقية
2. التحقق من أن المعلمين يُسندون للفصول الصحيحة
3. التحقق من عدم وجود تعارضات
4. مراجعة نسبة الإكمال

## ملاحظات مهمة

- لم يتم تغيير الخوارزمية نفسها
- لم يتم إضافة retry أو swap
- لم يتم إضافة مراحل تسمح بتعارض المعلم
- التغيير فقط في طريقة جمع وتمرير البيانات

## التوافق

النظام متوافق تماماً مع الكود الموجود:
- `UltraFastSolver` يحافظ على نفس الواجهة
- باقي الكود لا يحتاج لأي تعديل
- التغيير داخلي فقط
