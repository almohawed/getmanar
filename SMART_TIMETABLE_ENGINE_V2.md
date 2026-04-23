# Smart Timetable Engine v2 (منار) — Architecture Spec

هذا المستند مخطط تنفيذي للمبرمج (Implementation-ready) لبناء محرك جدول ذكي جديد بالكامل داخل منار.

## 1) الأهداف (Non‑Negotiables)

- زمن التوليد: ≤ 30 ثانية لمدرسة كاملة (ابتدائي/متوسط/ثانوي/مسارات/مجمع).
- لا تعارضات: معلم واحد لا يدرّس حصتين بنفس الوقت، والفصل لا يملك حصتين بنفس الوقت.
- يوازن الأنصبة: لا يكون الفرق الكبير إلا بسبب ندرة التخصص.
- يمنع اليوم الفارغ (Hard) قدر الإمكان مع مسار إصلاح.
- عدالة الانتظار: توزيع متوازن وضمن حدود المرحلة.
- واجهة بسيطة: زر واحد “إنشاء الجدول الذكي” ثم اعتماد (publish) تلقائي.
- فهم المدرسة تلقائيًا: بلا أسئلة يدوية قدر الإمكان.
- قيود قابلة للتدرّج: Hard / Soft / Preferred لتجنب الفشل.

## 2) المخرجات (Outputs)

### 2.1 جداول

- TeacherTimetable: `Map<TeacherId, List<ScheduleSlot>>`
- ClassTimetable: `Map<ClassId, List<ScheduleSlot>>`
- WaitingSchedule: مشتق من TeacherTimetable (حصص subject = منتظر)
- ActivitySchedule: حسب السياسة (ActivityPeriod ثابت أو نشاط موزع)

### 2.2 تقرير المحرك (Engine Report)

يُعاد مع كل تشغيل، ويُخزن مع نسخة الجدول:

- `schoolFingerprint`: بصمة المدرسة (أيام/حصص/عدد فصول/عدد معلمين/مراحل/مسارات)
- `policyId`: السياسة المختارة تلقائيًا
- `runtimeMs`: إجمالي الزمن + لكل مرحلة
- `constraintsSummary`: عدد القيود الصلبة والمرنة
- `quality`: نقاط جودة/عدالة/التزام النصاب/توازن الانتظار
- `warnings`: تحذيرات قابلة للفهم (مثل نقص معلمين مادة معينة)
- `debug`: بيانات تشخيصية (اختيارية)

## 3) نماذج البيانات (Core Models)

### 3.1 Snapshot المدرسة (SchoolSnapshot)

```dart
class SchoolSnapshot {
  final String schoolId;
  final String stage; // ابتدائي/متوسط/ثانوي/مجمع
  final int daysPerWeek; // غالباً 5
  final int periodsPerDay; // غالباً 7
  final int? activityPeriod; // null أو رقم الحصة
  final List<ClassroomRef> classes;
  final List<TeacherRef> teachers;
  final SubjectCatalog subjectCatalog;
  final Map<String, dynamic> raw; // نسخة خام عند الحاجة
}

class ClassroomRef {
  final String id;
  final String name;
  final int gradeLevel;
  final String? secondaryProgramType; // مسارات/عام
  final String? secondaryTrack;
}

class TeacherRef {
  final String id;
  final String name;
  final String? stage;
  final String? primarySubjectId;
  final List<SubjectAssignment> subjectAssignments;
  final List<String> assignedClassIds;
  final int weeklyQuota; // من maxWeeklyClasses + policy cap
  final TeacherConstraintsProfile constraints; // blocked/preferred/etc
}

class SubjectCatalog {
  final Map<String, String> subjectNameById;
  final Map<String, String> subjectIdByAlias; // تطبيع عربي/إنجليزي
  final Map<String, int> subjectWeight; // ثقيلة/عادية
}
```

### 3.2 السياسة (PolicyProfile)

```dart
enum ConstraintStrength { hard, soft, preferred }

class PolicyProfile {
  final String id;
  final String stageKey; // primary/middle/secondary/combined
  final int periodsPerDay;
  final List<String> days;

  final int maxPerDayPerSubjectForClass;
  final int maxConsecutiveLessonsPerTeacher;
  final ConstraintStrength preventEmptyTeacherDay;
  final ConstraintStrength preventZeroTeaching;

  final WaitingPolicy waiting;
  final ActivityPolicy activity;
  final LoadBalancePolicy loadBalance;
  final SolverBudgets budgets;
}

class SolverBudgets {
  final int totalSeconds; // 30
  final Map<String, int> stageSeconds; // لكل مرحلة ≤ 3
}

class WaitingPolicy {
  final int waitingSlotsPerPeriod;
  final int maxWaitingPerTeacherPerWeek;
  final int maxWaitingPerTeacherPerDay;
  final bool disallowDuringActivityPeriod;
  final bool disallowIfEmptyDay; // لا انتظار في يوم فارغ
  final List<String> priorityOrder; // أقل حصص ثم أقل انتظار ثم قرب ثم تخصص
}

class ActivityPolicy {
  final bool enabled;
  final int? fixedPeriod; // إن كان النشاط ثابت
  final ConstraintStrength disallowTeacherDuringActivity;
}

class LoadBalancePolicy {
  final int maxLoadDiff; // <= 2
  final ConstraintStrength enforceTeacherQuota;
  final ConstraintStrength enforceClassMapping; // ربط فصول المعلم
}
```

### 3.3 نموذج الطلب (DemandModel)

الطلب يُبنى تلقائيًا من خطة الوزارة (مثل `saudi_subject_plans.json`) مع تسوية لتطابق سعة الأسبوع.

```dart
class DemandModel {
  final Map<String, Map<String, int>> weeklyDemandByClass; // classId -> subjectId -> count
  final Map<String, int> totalDemandBySubject;
}
```

## 4) البنية: 6 محركات (Engines)

### 4.1 SchoolAnalyzer

المسؤول عن “فهم المدرسة تلقائيًا”.

**Classes**

```dart
class SchoolAnalyzer {
  Future<SchoolSnapshot> buildSnapshot(String schoolId);
  Future<SchoolFingerprint> fingerprint(SchoolSnapshot s);
  StageProfile detectStageProfile(SchoolSnapshot s);
  ProgramProfile detectProgramProfile(SchoolSnapshot s);
}

enum StageProfile { primaryOnly, middleOnly, secondaryOnly, primaryMiddle, middleSecondary, allStages }
enum ProgramProfile { primaryLower, primaryUpper, masarat, general, mixed }
```

**وظائف أساسية**

- `detectStageProfile`: من gradeLevel + stage + secondaryProgramType
- `detectProgramProfile`: من المسارات/المجمع
- `buildSubjectCatalog`: تطبيع أسماء المواد/المعرّفات
- `buildTeacherRefs`: دمج `User.maxWeeklyClasses` + `TeacherConstraintsProfile.weeklyQuota` + policy cap

### 4.2 PolicyEngine

يختار سياسة JSON مناسبة تلقائيًا.

```dart
class PolicyEngine {
  Future<PolicyProfile> loadPolicy({
    required StageProfile stageProfile,
    required ProgramProfile programProfile,
    required SchoolSnapshot snapshot,
  });
}
```

مع قاعدة اختيار:

- primary_only → primary_policy.json
- middle_only → middle_policy.json
- secondary_only → secondary_policy.json
- combined → combined_policy.json مع تفرعات masarat/general

### 4.3 AssignmentEngine

يبني خريطة “من يحق له تدريس ماذا وأين” (Candidates).

```dart
class AssignmentEngine {
  AssignmentModel build({
    required SchoolSnapshot snapshot,
    required PolicyProfile policy,
    required DemandModel demand,
    AssignmentMode mode = AssignmentMode.rebuildFull,
  });
}

enum AssignmentMode { fillMissing, rebuildFull }

class AssignmentModel {
  final Map<String, Set<String>> allowedSubjectsByTeacher; // teacherId -> subjectIds
  final Map<String, Set<String>> allowedClassesByTeacher;  // teacherId -> classIds
  final CandidateMatrix candidates; // subject+class -> teachers ranked
  final Map<String, int> teacherQuota; // teacherId -> weeklyQuota
}

class CandidateMatrix {
  List<String> candidatesFor({required String classId, required String subjectId});
}
```

**قواعد أساسية**

- إن كان `assignedClassIds` للمعلم غير فارغ → هذا Hard/Soft حسب policy.
- تخصص المعلم (primarySubjectId/subjectAssignments) هي الأساس.
- “المادة” تُطبع عبر SubjectCatalog (لا تعتمد على Arabic/Math ثابتة).
- بناء مراتب candidates:
  - primary > additional > emergency
  - الأقل حملاً أولاً
  - الأقرب للفصول (إن توفر مفهوم المبنى/الدور لاحقًا)

### 4.4 SolverEngine (قلب السرعة)

يبني جدول التدريس (بدون انتظار) على مراحل محددة، كل مرحلة ميزانيتها ≤ 3 ثوانٍ.

```dart
class SolverEngine {
  Future<SolverResult> solve({
    required SchoolSnapshot snapshot,
    required PolicyProfile policy,
    required DemandModel demand,
    required AssignmentModel assignment,
    required SolverOptions options,
  });
}

class SolverOptions {
  final int seed;
  final DateTime deadline;
  final bool strictNoConflict; // Hard
}

class SolverResult {
  final Map<String, List<ScheduleSlot>> teacherSchedule;
  final Map<String, List<ScheduleSlot>> classSchedule;
  final Map<String, dynamic> report;
}
```

**ترتيب التوليد (Stages)**

1. HeavySubjectsPlacement (≤ 3s)
2. NormalSubjectsPlacement (≤ 3s)
3. ActivityPlacement (≤ 3s)
4. EmptyDayRepair (≤ 3s)
5. ZeroTeachingRepair (≤ 3s)
6. LoadBalanceRepair (≤ 3s)
7. WaitingDistribution (≤ 3s)
8. LocalOptimization (≤ 3s)

### 4.5 BalancerEngine (العدل)

لا يبني الجدول من الصفر؛ يشتغل على جدول موجود لتحسينه.

```dart
class BalancerEngine {
  BalanceResult balance({
    required SchoolSnapshot snapshot,
    required PolicyProfile policy,
    required AssignmentModel assignment,
    required Map<String, List<ScheduleSlot>> teacherSchedule,
  });
}

class BalanceResult {
  final Map<String, List<ScheduleSlot>> teacherSchedule;
  final Map<String, dynamic> report;
}
```

**قواعد العدل**

- عدل التدريس: `maxLoadDiff <= 2` (Soft/Preferred)
- لا يوم فارغ: Hard ثم Soft ثم Preferred
- عدل الانتظار: توزيع متساوٍ ضمن `maxWaiting*`
- النشاط: لا يتعارض مع الانتظار ولا يحمّل نفس المعلم دائمًا

### 4.6 PublisherEngine (النشر التلقائي)

ينفذ كل خطوات الحفظ والنشر دون أزرار إضافية.

```dart
class PublisherEngine {
  Future<PublishResult> publish({
    required String schoolId,
    required TimetableBundle bundle,
    required Map<String, dynamic> engineReport,
  });
}

class TimetableBundle {
  final Map<String, List<ScheduleSlot>> teacherSchedule;
  final Map<String, List<ScheduleSlot>> classSchedule;
  final Map<String, List<ScheduleSlot>> roomSchedule;
  final List<ScheduleSlot> waitingSlots;
  final List<ScheduleSlot> activitySlots;
}

class PublishResult {
  final String scheduleRunId;
  final String variant; // base/emergency
}
```

**خطوات النشر**

1) `saveFullSchedule(schoolId, teacherSchedule)`
2) بناء `classSchedule` وحفظه لكل فصل
3) بناء `waiting` وحفظه
4) بناء `rooms` إن وجد نظام غرف
5) `setActiveScheduleVariant(...)`
6) `publishSchedule(schoolId)`
7) Trigger إشعارات (Push/Inbox/SMS حسب إعدادات المدرسة) للمعلم/الطالب/ولي الأمر

## 5) خط الإنتاج (Orchestrator)

المنفذ الوحيد الذي تستدعيه الواجهة.

```dart
class SmartTimetableEngineV2 {
  final SchoolAnalyzer analyzer;
  final PolicyEngine policyEngine;
  final AssignmentEngine assignmentEngine;
  final SolverEngine solver;
  final BalancerEngine balancer;
  final PublisherEngine publisher;

  Future<ScheduleGenerationResultV2> generateAndPublish({
    required String schoolId,
    required int seed,
    required bool publish,
  });
}

class ScheduleGenerationResultV2 {
  final TimetableBundle bundle;
  final Map<String, dynamic> report;
}
```

**تسلسل التنفيذ**

1) `snapshot = analyzer.buildSnapshot(schoolId)`
2) `stageProfile/programProfile = analyzer.detect*`
3) `policy = policyEngine.loadPolicy(...)`
4) `demand = DemandBuilder.fromSaudiPlans(snapshot, policy)`
5) `assignment = assignmentEngine.build(snapshot, policy, demand)`
6) `solverResult = solver.solve(...)` (بحد زمني)
7) `balanced = balancer.balance(...)`
8) `waiting = WaitingDistributor.distribute(...)`
9) `bundle = BundleBuilder.build(...)`
10) إذا publish:
   - `publisher.publish(...)`

## 6) واجهة المستخدم (UI) — بسيطة جدًا

شاشة واحدة:

- تحليل المدرسة ✔
- الإسناد الذكي ✔
- القيود ✔
- زر واحد: **إنشاء الجدول الذكي**

بعد الضغط:

- شريط تقدم بمراحل (8 مراحل)
- تقرير مختصر (3 مؤشرات + تحذيرات)
- زر واحد: **اعتماد الجدول** (ينفذ PublisherEngine بالكامل)

## 7) سياسات Hard/Soft/Preferred (لا للفشل)

### 7.1 أمثلة

- noConflict = Hard
- activityPeriodNoTeach = Hard/Soft حسب المرحلة
- noEmptyDay = Hard ثم downgrade إلى Soft بعد مهلة زمنية
- balanceLoad = Soft
- perfectBalance = Preferred

### 7.2 سياسة التدرّج (Constraint Downgrading)

داخل SolverEngine:

- إذا اقتربنا من deadline:
  - downgrade `balance` و `perfectBalance` أولاً
  - ثم downgrade `noEmptyDay` من Hard → Soft
  - لا يتم downgrade `noConflict`

## 8) ملفات يجب إضافتها (مقترحة)

مسار مقترح:

- `lib/src/features/intelligence/domain/scheduling/v2/`
  - `smart_timetable_engine_v2.dart`
  - `school_analyzer.dart`
  - `policy_engine.dart`
  - `assignment_engine.dart`
  - `solver_engine.dart`
  - `balancer_engine.dart`
  - `publisher_engine.dart`
  - `models/*.dart`

وسياسات:

- `assets/config/timetable_policies_v2/primary_policy.json`
- `assets/config/timetable_policies_v2/middle_policy.json`
- `assets/config/timetable_policies_v2/secondary_policy.json`
- `assets/config/timetable_policies_v2/combined_policy.json`

