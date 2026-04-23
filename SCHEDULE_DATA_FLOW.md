# تدفق بيانات الجدول - التحليل والتحسين

## الوضع الحالي

### مصادر البيانات المتعددة:
1. **Firestore** → `Schools/{schoolId}/Teachers`
2. **Firestore** → `Schools/{schoolId}/Classes`
3. **Asset File** → `saudi_subject_plans.json`
4. **Snapshot** → `SchoolSnapshot` (يحتوي على نسخة من البيانات)
5. **Assignment** → `AssignmentModel` (يحتوي على إسنادات المعلمين)

### المشاكل:
- قراءة متفرقة أثناء التوليد
- احتمال عدم تطابق البيانات بين المصادر
- صعوبة التتبع والتشخيص
- `assignedClassIds` موجود في `SnapshotTeacher` لكن غير موجود في `TeacherAssignment`

## الحل المقترح

### البنية الجديدة:

```
Firestore (Teachers, Classes, Subjects)
    ↓
SchoolDataCollector
    ↓
UnifiedScheduleModel (نموذج موحد)
    ├── teachers: List<TeacherData>
    │   ├── id, name
    │   ├── subjects: List<String>
    │   ├── assignedClassIds: List<String>
    │   ├── maxLoad, currentLoad
    │   └── isAdministrative
    ├── classes: List<ClassData>
    │   ├── id, name, gradeLevel
    │   └── requiredSubjects: Map<String, int>
    ├── subjects: List<SubjectData>
    │   └── id, name, normalizedName
    └── constraints:
        ├── daysPerWeek, periodsPerDay
        └── allowedRepetitions: Map<String, int>
    ↓
SimpleCleanSolver (يقرأ من UnifiedScheduleModel فقط)
    ↓
ScheduleResult
```

## التنفيذ

### 1. إنشاء UnifiedScheduleModel

```dart
class UnifiedScheduleModel {
  final List<TeacherData> teachers;
  final List<ClassData> classes;
  final List<SubjectData> subjects;
  final ScheduleConstraints constraints;
  
  const UnifiedScheduleModel({
    required this.teachers,
    required this.classes,
    required this.subjects,
    required this.constraints,
  });
}

class TeacherData {
  final String id;
  final String name;
  final List<String> subjects; // مواد موحدة
  final List<String> assignedClassIds;
  final int maxWeeklyLoad;
  final int currentLoad;
  final bool isAdministrative;
  
  const TeacherData({
    required this.id,
    required this.name,
    required this.subjects,
    required this.assignedClassIds,
    required this.maxWeeklyLoad,
    this.currentLoad = 0,
    this.isAdministrative = false,
  });
}

class ClassData {
  final String id;
  final String name;
  final int gradeLevel;
  final Map<String, int> requiredSubjects; // subject -> weekly count
  
  const ClassData({
    required this.id,
    required this.name,
    required this.gradeLevel,
    required this.requiredSubjects,
  });
}

class SubjectData {
  final String id;
  final String name;
  final String normalizedName;
  final int maxPerDay; // 1 for most, 2 for Arabic/Islamic
  
  const SubjectData({
    required this.id,
    required this.name,
    required this.normalizedName,
    required this.maxPerDay,
  });
}

class ScheduleConstraints {
  final int daysPerWeek;
  final int periodsPerDay;
  final List<String> days;
  
  const ScheduleConstraints({
    required this.daysPerWeek,
    required this.periodsPerDay,
    required this.days,
  });
}
```

### 2. إنشاء SchoolDataCollector

```dart
class SchoolDataCollector {
  static Future<UnifiedScheduleModel> collect({
    required String schoolId,
    required SchoolSnapshot snapshot,
    required AssignmentModel assignment,
  }) async {
    // 1. جمع بيانات المعلمين
    final teachers = <TeacherData>[];
    for (final t in assignment.teachers) {
      if (t.isAdministrative) continue;
      
      final snapshotTeacher = snapshot.teachers
          .where((st) => st.id == t.teacherId)
          .firstOrNull;
      
      teachers.add(TeacherData(
        id: t.teacherId,
        name: t.teacherName,
        subjects: _normalizeSubjects(t.assignedSubjects),
        assignedClassIds: snapshotTeacher?.assignedClassIds ?? [],
        maxWeeklyLoad: t.maxWeeklyLoad,
        isAdministrative: t.isAdministrative,
      ));
    }
    
    // 2. جمع بيانات الفصول مع الخطة الدراسية
    final classes = <ClassData>[];
    final plans = await _loadSubjectPlans();
    
    for (final c in snapshot.classes) {
      final requiredSubjects = plans.weeklyDemandForGrade(
        gradeLevel: c.gradeLevel,
        secondaryProgramType: snapshot.secondaryProgramType,
        secondaryTrack: c.secondaryTrack,
      );
      
      classes.add(ClassData(
        id: c.id,
        name: c.name,
        gradeLevel: c.gradeLevel,
        requiredSubjects: requiredSubjects,
      ));
    }
    
    // 3. جمع بيانات المواد
    final subjects = <SubjectData>[];
    for (final s in snapshot.subjects) {
      subjects.add(SubjectData(
        id: s.id,
        name: s.name,
        normalizedName: SubjectNormalizer.normalize(s.name),
        maxPerDay: _getMaxPerDay(s.name),
      ));
    }
    
    // 4. القيود
    final constraints = ScheduleConstraints(
      daysPerWeek: snapshot.daysPerWeek,
      periodsPerDay: snapshot.periodsPerDay,
      days: _getDays(snapshot),
    );
    
    return UnifiedScheduleModel(
      teachers: teachers,
      classes: classes,
      subjects: subjects,
      constraints: constraints,
    );
  }
  
  static List<String> _normalizeSubjects(List<String> subjects) {
    return subjects
        .map((s) => SubjectNormalizer.normalize(s.trim()))
        .where((s) => s.isNotEmpty)
        .toList();
  }
  
  static int _getMaxPerDay(String subjectName) {
    final normalized = subjectName.toLowerCase();
    final allowedToRepeat = [
      'arabic', 'عربي', 'لغة عربية',
      'islamic', 'إسلامية', 'دراسات إسلامية',
      'fiqh', 'فقه', 'tafsir', 'تفسير',
      'hadith', 'حديث',
    ];
    
    return allowedToRepeat.any((a) => normalized.contains(a)) ? 2 : 1;
  }
}
```

### 3. تعديل SimpleCleanSolver

```dart
class SimpleCleanSolver {
  Future<DemandModel> solve(
    UnifiedScheduleModel model, {
    void Function(...)? onProgress,
  }) async {
    // الآن كل البيانات من model فقط
    final teachers = model.teachers;
    final classes = model.classes;
    final subjects = model.subjects;
    final constraints = model.constraints;
    
    // باقي المنطق يستخدم model فقط
    // لا قراءة من Firestore أو Assets
  }
}
```

### 4. تعديل الاستدعاء

```dart
// في schedule_management_screen.dart
Future<void> _generateSchedule() async {
  // 1. جمع البيانات
  final model = await SchoolDataCollector.collect(
    schoolId: schoolId,
    snapshot: snapshot,
    assignment: assignment,
  );
  
  // 2. حفظ النموذج (اختياري للتشخيص)
  await _saveModelSnapshot(model);
  
  // 3. التوليد
  final result = await SimpleCleanSolver().solve(model);
  
  // 4. النشر
  await _publishSchedule(result);
}
```

## الفوائد

1. ✅ مصدر بيانات واحد أثناء التوليد
2. ✅ سهولة التشخيص (يمكن حفظ النموذج وإعادة التوليد)
3. ✅ عدم تعارض البيانات
4. ✅ سهولة الاختبار (mock model)
5. ✅ إمكانية التصدير/الاستيراد
6. ✅ وضوح تام في تدفق البيانات

## خطوات التنفيذ

1. إنشاء ملف `unified_schedule_model.dart`
2. إنشاء ملف `school_data_collector.dart`
3. تعديل `simple_clean_solver.dart` لاستخدام النموذج الموحد
4. تعديل `smart_timetable_orchestrator.dart`
5. اختبار التوليد
6. إزالة القراءات المتفرقة القديمة

## ملاحظات

- النموذج الموحد يمكن حفظه كـ JSON للتشخيص
- يمكن إضافة validation للنموذج قبل التوليد
- يمكن إنشاء "dry run" لاختبار البيانات قبل التوليد الفعلي
