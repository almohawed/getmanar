import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../academic/data/school_repository.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../academic/domain/classroom.dart';
import 'behavior_charts.dart';

class BehaviorEnhancementStudentRow {
  final String studentId;
  final String studentName;
  final String className;
  final double behaviorScore;
  final String riskLabel;
  final String topDriver;
  final String predictedNextIssue;
  final String weekKey;
  final String personaKey;

  BehaviorEnhancementStudentRow({
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.behaviorScore,
    required this.riskLabel,
    required this.topDriver,
    required this.predictedNextIssue,
    required this.weekKey,
    required this.personaKey,
  });
}

class BehaviorEnhancementDashboardData {
  final int excellentCount;
  final int veryGoodCount;
  final int needsSupportCount;
  final double excellentPercent;
  final double veryGoodPercent;
  final double needsSupportPercent;
  final String smartNotice;
  final List<BehaviorEnhancementStudentRow> topStudents;
  final String weekKey;
  final Map<String, int> classRiskCounts;
  final Map<String, int> topBehaviorDrivers;

  BehaviorEnhancementDashboardData({
    required this.excellentCount,
    required this.veryGoodCount,
    required this.needsSupportCount,
    required this.excellentPercent,
    required this.veryGoodPercent,
    required this.needsSupportPercent,
    required this.smartNotice,
    required this.topStudents,
    required this.weekKey,
    required this.classRiskCounts,
    required this.topBehaviorDrivers,
  });

  factory BehaviorEnhancementDashboardData.empty() {
    return BehaviorEnhancementDashboardData(
      excellentCount: 0,
      veryGoodCount: 0,
      needsSupportCount: 0,
      excellentPercent: 0,
      veryGoodPercent: 0,
      needsSupportPercent: 0,
      smartNotice:
          'لا توجد بيانات سلوكية كافية حتى الآن.\nسيتم تحديث المؤشرات تلقائيًا بعد أول عملية رصد سلوك للطلاب.',
      topStudents: const [],
      weekKey: '',
      classRiskCounts: const {},
      topBehaviorDrivers: const {},
    );
  }
}

class BehaviorEnhancementFilters {
  final String? classId;
  final String? studentId;

  const BehaviorEnhancementFilters({this.classId, this.studentId});

  @override
  bool operator ==(Object other) {
    return other is BehaviorEnhancementFilters &&
        other.classId == classId &&
        other.studentId == studentId;
  }

  @override
  int get hashCode => Object.hash(classId, studentId);
}

final behaviorEnhancementDashboardFilteredProvider = FutureProvider.autoDispose
    .family<BehaviorEnhancementDashboardData, BehaviorEnhancementFilters>((
      ref,
      filters,
    ) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null) {
        return BehaviorEnhancementDashboardData.empty();
      }

      final studentsAsync = ref.watch(studentsProvider);
      final students = studentsAsync.value ?? const <User>[];
      final classesAsync = ref.watch(classesProvider);
      final classes = classesAsync.value ?? const [];
      final classesById = {for (final c in classes) c.id: c};
      final studentsById = {for (final s in students) s.id: s};

      final firestore = FirebaseFirestore.instance;

      // تحديد الطلاب المؤهلين حسب الدور
      List<String> eligibleStudentIds;
      if (user.role == UserRole.teacher) {
        final allowed = (user.assignedClassIds ?? []).toSet();
        eligibleStudentIds = students
            .where((s) => (s.assignedClassIds ?? []).any(allowed.contains))
            .map((s) => s.id)
            .toList();
      } else {
        eligibleStudentIds = students.map((s) => s.id).toList();
      }

      // تطبيق فلتر الفصل
      final filterClassId = (filters.classId ?? '').trim();
      if (filterClassId.isNotEmpty) {
        eligibleStudentIds = eligibleStudentIds.where((id) {
          final s = studentsById[id];
          return s != null && (s.assignedClassIds ?? []).contains(filterClassId);
        }).toList();
      }

      // تطبيق فلتر الطالب
      final filterStudentId = (filters.studentId ?? '').trim();
      if (filterStudentId.isNotEmpty) {
        eligibleStudentIds = eligibleStudentIds
            .where((id) => id == filterStudentId)
            .toList();
      }

      try {
        // جلب المخالفات والسلوك الإيجابي والحالات مباشرة
        final results = await Future.wait([
          firestore.collection('behavioral_violations').get(),
          firestore.collection('positive_behavior').get(),
          firestore.collection('behavioral_cases').get(),
        ]);

        final allViolations = results[0].docs;
        final allPositive = results[1].docs;
        final allCases = results[2].docs;

        // بناء خريطة بيانات لكل طالب
        final Map<String, Map<String, dynamic>> studentStats = {};

        // دالة مساعدة للحصول على إحصائيات طالب
        Map<String, dynamic> getStats(String sid) {
          return studentStats.putIfAbsent(sid, () => {
            'violationPoints': 0,
            'positivePoints': 0,
            'violationCount': 0,
            'positiveCount': 0,
            'violationTypes': <String>[],
          });
        }

        // معالجة المخالفات
        for (final doc in allViolations) {
          final data = doc.data() as Map<String, dynamic>;
          final sid = (data['studentId'] ?? '').toString();
          final sname = (data['studentName'] ?? '').toString();

          // البحث بالـ id أو الاسم
          String? matchId;
          if (sid.isNotEmpty && eligibleStudentIds.contains(sid)) {
            matchId = sid;
          } else if (sname.isNotEmpty) {
            matchId = studentsById.values
                .where((s) => s.name == sname && eligibleStudentIds.contains(s.id))
                .map((s) => s.id)
                .firstOrNull;
            // إذا لم نجد في قائمة الطلاب، نضيف بالاسم مباشرة
            if (matchId == null && eligibleStudentIds.isEmpty) {
              matchId = sname;
            }
          }

          if (matchId == null && eligibleStudentIds.isNotEmpty) continue;
          final key = matchId ?? sname;
          if (key.isEmpty) continue;

          final stats = getStats(key);
          stats['violationPoints'] = (stats['violationPoints'] as int) + ((data['points'] as int?) ?? 1);
          stats['violationCount'] = (stats['violationCount'] as int) + 1;
          (stats['violationTypes'] as List<String>).add(data['violationType'] ?? '');
        }

        // معالجة السلوك الإيجابي
        for (final doc in allPositive) {
          final data = doc.data() as Map<String, dynamic>;
          final sid = (data['studentId'] ?? '').toString();
          final sname = (data['studentName'] ?? '').toString();

          String? matchId;
          if (sid.isNotEmpty && eligibleStudentIds.contains(sid)) {
            matchId = sid;
          } else if (sname.isNotEmpty) {
            matchId = studentsById.values
                .where((s) => s.name == sname && eligibleStudentIds.contains(s.id))
                .map((s) => s.id)
                .firstOrNull;
          }

          if (matchId == null && eligibleStudentIds.isNotEmpty) continue;
          final key = matchId ?? sname;
          if (key.isEmpty) continue;

          final stats = getStats(key);
          stats['positivePoints'] = (stats['positivePoints'] as int) + ((data['points'] as int?) ?? 1);
          stats['positiveCount'] = (stats['positiveCount'] as int) + 1;
        }

        // إذا لم يكن هناك طلاب مسجلون، نبني القائمة من البيانات السلوكية
        final Set<String> allKeys = eligibleStudentIds.isNotEmpty
            ? eligibleStudentIds.toSet()
            : studentStats.keys.toSet();

        // تصنيف الطلاب
        int excellent = 0, veryGood = 0, needsSupport = 0;
        final Map<String, int> classRiskCounts = {};
        final Map<String, int> violationTypeCounts = {};
        final List<Map<String, dynamic>> riskStudents = [];

        for (final key in allKeys) {
          final stats = studentStats[key];
          final vPoints = (stats?['violationPoints'] as int?) ?? 0;
          final pPoints = (stats?['positivePoints'] as int?) ?? 0;
          final netScore = pPoints - vPoints;

          String level;
          if (netScore >= 10) {
            level = 'ممتاز';
            excellent++;
          } else if (netScore >= 0) {
            level = 'جيد جدًا';
            veryGood++;
          } else {
            level = 'يحتاج تعزيز';
            needsSupport++;

            // إضافة للمخاطر
            final student = studentsById[key];
            final name = student?.name ?? key;
            final classId = student?.assignedClassIds?.firstOrNull;
            final cls = classId != null ? classesById[classId] : null;
            if (cls != null) {
              classRiskCounts[cls.name] = (classRiskCounts[cls.name] ?? 0) + 1;
            }
            riskStudents.add({
              'id': key,
              'name': name,
              'netScore': netScore,
              'vPoints': vPoints,
              'pPoints': pPoints,
              'className': cls?.name ?? '',
              'violationTypes': stats?['violationTypes'] ?? [],
            });
          }

          // تجميع أنواع المخالفات
          for (final t in (stats?['violationTypes'] as List<String>? ?? [])) {
            if (t.isNotEmpty) violationTypeCounts[t] = (violationTypeCounts[t] ?? 0) + 1;
          }
        }

        final total = excellent + veryGood + needsSupport;
        double p(int v) => total == 0 ? 0 : (v / total) * 100;

        // ترتيب الطلاب الأكثر خطورة
        riskStudents.sort((a, b) => (a['netScore'] as int).compareTo(b['netScore'] as int));
        final topRisk = riskStudents.take(5).toList();

        final smartNotice = needsSupport == 0
            ? 'ممتاز: لا توجد حالات تستدعي تدخلًا الآن.'
            : 'تنبيه: $needsSupport طالب يحتاج متابعة ودعم سلوكي.';

        // بناء صفوف الطلاب
        final rows = topRisk.map((s) => BehaviorEnhancementStudentRow(
          studentId: s['id'] as String,
          studentName: s['name'] as String,
          className: s['className'] as String,
          behaviorScore: (s['netScore'] as int).toDouble(),
          riskLabel: 'مرتفع',
          topDriver: ((s['violationTypes'] as List).isNotEmpty)
              ? (s['violationTypes'] as List).first.toString()
              : '',
          predictedNextIssue: '',
          weekKey: '',
          personaKey: 'HIGH_يحتاج تعزيز',
        )).toList();

        final sortedViolations = Map.fromEntries(
          violationTypeCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        );
        final sortedClasses = Map.fromEntries(
          classRiskCounts.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)),
        );

        return BehaviorEnhancementDashboardData(
          excellentCount: excellent,
          veryGoodCount: veryGood,
          needsSupportCount: needsSupport,
          excellentPercent: p(excellent),
          veryGoodPercent: p(veryGood),
          needsSupportPercent: p(needsSupport),
          smartNotice: smartNotice,
          topStudents: rows,
          weekKey: '',
          classRiskCounts: sortedClasses,
          topBehaviorDrivers: sortedViolations,
        );
      } catch (e) {
        debugPrint('Error loading behavior dashboard: $e');
        return BehaviorEnhancementDashboardData.empty();
      }
    });

final behaviorEnhancementDashboardProvider =
    behaviorEnhancementDashboardFilteredProvider(
      const BehaviorEnhancementFilters(),
    );

String _buildSmartNotice(int atRiskCount, int risingCount) {
  if (atRiskCount == 0 && risingCount == 0) {
    return "ممتاز: لا توجد حالات تستدعي تدخلًا الآن.";
  }
  if (risingCount == 1 && atRiskCount <= 3) {
    return "ملاحظة: طالب واحد ظهرت لديه مؤشرات تصاعد خلال آخر 7 أيام.";
  }
  if (atRiskCount > 0) {
    return "تنبيه هادئ: $atRiskCount طلاب يحتاجون متابعة مبكرة هذا الأسبوع.";
  }
  return "تنبيه هادئ: توجد مؤشرات تحتاج متابعة خلال هذا الأسبوع.";
}

String _riskLabel(String tier) {
  switch (tier) {
    case 'HIGH':
      return 'مرتفع';
    case 'MED':
      return 'متوسط';
    default:
      return 'منخفض';
  }
}

String _prettyWeekLabel(String weekKey) {
  final parts = weekKey.split('-W');
  if (parts.length == 2) {
    final year = parts[0];
    final week = parts[1];
    return 'أسبوع $week / $year';
  }
  return 'أسبوع حالي';
}

class BehaviorEnhancementDashboardScreen extends ConsumerStatefulWidget {
  const BehaviorEnhancementDashboardScreen({super.key});

  @override
  ConsumerState<BehaviorEnhancementDashboardScreen> createState() =>
      _BehaviorEnhancementDashboardScreenState();
}

class _BehaviorEnhancementDashboardScreenState
    extends ConsumerState<BehaviorEnhancementDashboardScreen> {
  String? _selectedClassId;
  String? _selectedStudentId;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolAsync = ref.watch(schoolProvider(user?.schoolId ?? ''));
    final classes = ref.watch(classesProvider).value ?? const <Classroom>[];
    final students = ref.watch(studentsProvider).value ?? const <User>[];

    final teacherClassIds = user?.role == UserRole.teacher
        ? (user?.assignedClassIds ?? const <String>[])
        : classes.map((c) => c.id).toList();

    final teacherClasses =
        classes.where((c) => teacherClassIds.contains(c.id)).toList()
          ..sort((a, b) => a.preferredLabel.compareTo(b.preferredLabel));

    if (_selectedClassId != null &&
        teacherClasses.every((c) => c.id != _selectedClassId)) {
      _selectedClassId = null;
      _selectedStudentId = null;
    }

    final eligibleStudents = user?.role == UserRole.teacher
        ? students.where((s) {
            final classIds = s.assignedClassIds ?? const <String>[];
            return classIds.any((id) => teacherClassIds.contains(id));
          }).toList()
        : students.toList();

    final filteredStudents = (_selectedClassId == null)
        ? eligibleStudents
        : eligibleStudents.where((s) {
            final classIds = s.assignedClassIds ?? const <String>[];
            return classIds.contains(_selectedClassId);
          }).toList();

    filteredStudents.sort((a, b) => a.name.compareTo(b.name));

    if (_selectedStudentId != null &&
        filteredStudents.every((s) => s.id != _selectedStudentId)) {
      _selectedStudentId = null;
    }

    final filters = BehaviorEnhancementFilters(
      classId: _selectedClassId,
      studentId: _selectedStudentId,
    );

    final dashboardAsync = ref.watch(
      behaviorEnhancementDashboardFilteredProvider(filters),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FF),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFFF3F6FF),
        title: schoolAsync.when(
          data: (school) => Text(
            school != null
                ? 'منصة منار | ${school.name}'
                : 'منصة منار | تعزيز سلوك الطالب',
          ),
          loading: () => const Text('منصة منار'),
          error: (_, __) => const Text('منصة منار'),
        ),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 720;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: dashboardAsync.when(
                skipLoadingOnReload: true,
                data: (data) => SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(context, data),
                      SizedBox(height: 14.h),
                      _buildFiltersCard(
                        context,
                        isMobile: isMobile,
                        classes: teacherClasses,
                        students: filteredStudents,
                      ),
                      SizedBox(height: 16.h),
                      // عرض بيانات الطالب المختار مباشرة
                      if (_selectedStudentId != null) ...[
                        _StudentDirectDataCard(
                          studentId: _selectedStudentId!,
                          studentName: filteredStudents
                              .where((s) => s.id == _selectedStudentId)
                              .map((s) => s.name)
                              .firstOrNull ?? '',
                        ),
                        SizedBox(height: 16.h),
                      ] else ...[
                      if (isMobile) ...[
                        _buildTopKpis(context, data, isMobile: true),
                        SizedBox(height: 12.h),
                        _buildSummaryCard(context, data),
                        SizedBox(height: 12.h),
                        _buildSmartNoticeCard(context, data.smartNotice),
                      ] else ...[
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                children: [
                                  _buildTopKpis(context, data),
                                  SizedBox(height: 16.h),
                                  _buildSmartNoticeCard(
                                    context,
                                    data.smartNotice,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: 16.w),
                            Expanded(
                              flex: 2,
                              child: _buildSummaryCard(context, data),
                            ),
                          ],
                        ),
                      ],
                      SizedBox(height: 20.h),
                      _buildAnalyticsSection(context, data, isMobile: isMobile),
                      SizedBox(height: 20.h),
                      _buildTopStudentsSection(context, ref, data),
                      ],
                    ],
                  ),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Text(
                    'تعذر تحميل بيانات التعزيز السلوكي.\n$e',
                    textAlign: TextAlign.center,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.red),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFiltersCard(
    BuildContext context, {
    required bool isMobile,
    required List<Classroom> classes,
    required List<User> students,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: isMobile
            ? Column(
                children: [
                  DropdownButtonFormField<String?>(
                    value: _selectedClassId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('الكل'),
                      ),
                      ...classes.map(
                        (c) => DropdownMenuItem<String?>(
                          value: c.id,
                          child: Text(c.preferredLabel),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() {
                      _selectedClassId = v;
                      _selectedStudentId = null;
                    }),
                    decoration: const InputDecoration(
                      labelText: 'الفصل',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String?>(
                    value: _selectedStudentId,
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('كل الطلاب'),
                      ),
                      ...students.map(
                        (s) => DropdownMenuItem<String?>(
                          value: s.id,
                          child: Text(s.name),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _selectedStudentId = v),
                    decoration: const InputDecoration(
                      labelText: 'الطالب',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedClassId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('الكل'),
                        ),
                        ...classes.map(
                          (c) => DropdownMenuItem<String?>(
                            value: c.id,
                            child: Text(c.preferredLabel),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _selectedClassId = v;
                        _selectedStudentId = null;
                      }),
                      decoration: const InputDecoration(
                        labelText: 'الفصل',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: DropdownButtonFormField<String?>(
                      value: _selectedStudentId,
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('كل الطلاب'),
                        ),
                        ...students.map(
                          (s) => DropdownMenuItem<String?>(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedStudentId = v),
                      decoration: const InputDecoration(
                        labelText: 'الطالب',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    BehaviorEnhancementDashboardData data,
  ) {
    final total =
        data.excellentCount + data.veryGoodCount + data.needsSupportCount;
    return Container(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF4A6BFF), Color(0xFF6C8BFF)],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.18),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52.w,
            height: 52.w,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: const Icon(
              Icons.emoji_events,
              color: Colors.white,
              size: 30,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'لوحة تعزيز سلوك الطالب',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  'رؤية سريعة لمستويات السلوك لطلابك مع رصد مبكر للحالات التي تحتاج دعمًا.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$total',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4.h),
              Text(
                'عدد الطلاب في التحليل',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.white.withOpacity(0.9),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTopKpis(
    BuildContext context,
    BehaviorEnhancementDashboardData data, {
    bool isMobile = false,
  }) {
    if (isMobile) {
      return Column(
        children: [
          _KpiCard(
            title: 'ممتاز',
            count: data.excellentCount,
            percent: data.excellentPercent,
            color: Colors.green,
          ),
          SizedBox(height: 12.h),
          _KpiCard(
            title: 'جيد جدًا',
            count: data.veryGoodCount,
            percent: data.veryGoodPercent,
            color: Colors.blue,
          ),
          SizedBox(height: 12.h),
          _KpiCard(
            title: 'يحتاج تعزيز',
            count: data.needsSupportCount,
            percent: data.needsSupportPercent,
            color: Colors.orange,
          ),
        ],
      );
    }
    return Row(
      children: [
        Expanded(
          child: _KpiCard(
            title: 'ممتاز',
            count: data.excellentCount,
            percent: data.excellentPercent,
            color: Colors.green,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _KpiCard(
            title: 'جيد جدًا',
            count: data.veryGoodCount,
            percent: data.veryGoodPercent,
            color: Colors.blue,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _KpiCard(
            title: 'يحتاج تعزيز',
            count: data.needsSupportCount,
            percent: data.needsSupportPercent,
            color: Colors.orange,
          ),
        ),
      ],
    );
  }

  Widget _buildSmartNoticeCard(BuildContext context, String notice) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.indigo.shade50),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: Colors.indigo.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.indigo),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              notice,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsSection(
    BuildContext context,
    BehaviorEnhancementDashboardData data, {
    required bool isMobile,
  }) {
    if (isMobile) {
      return Column(
        children: [
          SimpleBarChart(
            data: data.classRiskCounts,
            title: 'الفصول الأكثر احتياجاً للدعم',
            barColor: Colors.orange.shade300,
          ),
          SizedBox(height: 16.h),
          SimpleBarChart(
            data: data.topBehaviorDrivers,
            title: 'أكثر السلوكيات تكراراً',
            barColor: Colors.indigo.shade300,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SimpleBarChart(
            data: data.classRiskCounts,
            title: 'الفصول الأكثر احتياجاً للدعم',
            barColor: Colors.orange.shade300,
          ),
        ),
        SizedBox(width: 16.w),
        Expanded(
          child: SimpleBarChart(
            data: data.topBehaviorDrivers,
            title: 'أكثر السلوكيات تكراراً',
            barColor: Colors.indigo.shade300,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context,
    BehaviorEnhancementDashboardData data,
  ) {
    final total =
        data.excellentCount + data.veryGoodCount + data.needsSupportCount;
    final needs = data.needsSupportCount;
    final safe = data.excellentCount + data.veryGoodCount;
    final needsPercent = total == 0 ? 0 : (needs / total) * 100;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'نظرة سريعة',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.indigo.shade50,
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Icon(Icons.timeline, size: 16.sp, color: Colors.indigo),
                    SizedBox(width: 4.w),
                    Text(
                      data.weekKey.isEmpty
                          ? 'أسبوع حالي'
                          : _prettyWeekLabel(data.weekKey),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.indigo,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          BehaviorDistributionChart(
            excellent: data.excellentCount,
            veryGood: data.veryGoodCount,
            needsSupport: data.needsSupportCount,
          ),
          SizedBox(height: 8.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLegendItem(
                context,
                color: Colors.green,
                label: 'ممتاز / جيد جدًا',
                value: safe,
              ),
              _buildLegendItem(
                context,
                color: Colors.orange,
                label: 'يحتاج تعزيز',
                value: needs,
                trailing: '${needsPercent.toStringAsFixed(1)}%',
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context, {
    required Color color,
    required String label,
    required int value,
    String? trailing,
  }) {
    return Row(
      children: [
        Container(
          width: 10.w,
          height: 10.w,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4.r),
          ),
        ),
        SizedBox(width: 6.w),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade800),
        ),
        SizedBox(width: 4.w),
        Text(
          '($value)',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
        if (trailing != null) ...[
          SizedBox(width: 4.w),
          Text(
            trailing,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ],
    );
  }

  Widget _buildTopStudentsSection(
    BuildContext context,
    WidgetRef ref,
    BehaviorEnhancementDashboardData data,
  ) {
    if (data.topStudents.isEmpty) {
      return Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Text(
          'لا توجد حالياً حالات مرتفعة الخطورة تحتاج تعزيزًا خاصًا.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'طلاب يحتاجون تعزيز (أعلى ٥ حسب درجة السلوك)',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.h),
        ...data.topStudents.map(
          (s) => _StudentCard(
            row: s,
            onPlanTapped: () => _showStudentPlanDialog(context, ref, s),
          ),
        ),
      ],
    );
  }

  Future<void> _showStudentPlanDialog(
    BuildContext context,
    WidgetRef ref,
    BehaviorEnhancementStudentRow row,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('خطة تعزيز لـ ${row.studentName}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'درجة السلوك الحالية: ${row.behaviorScore.toStringAsFixed(1)}',
              ),
              SizedBox(height: 8.h),
              Text('مستوى الخطورة: ${row.riskLabel}'),
              SizedBox(height: 8.h),
              if (row.topDriver.isNotEmpty)
                Text('أهم دافع سلوكي: ${row.topDriver}'),
              SizedBox(height: 8.h),
              if (row.predictedNextIssue.isNotEmpty)
                Text('توقع الأسبوع القادم: ${row.predictedNextIssue}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('إغلاق'),
            ),
            ElevatedButton(
              onPressed: () async {
                await _logAction(ref, row);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تم تسجيل تنفيذ خطة التعزيز بنجاح.'),
                    ),
                  );
                }
              },
              child: const Text('تم التنفيذ'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _logAction(
    WidgetRef ref,
    BehaviorEnhancementStudentRow row,
  ) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance
          .collection('behavior_enhancement_actions')
          .add({
        'schoolId': user.schoolId ?? '',
        'studentId': row.studentId,
        'studentName': row.studentName,
        'actionType': 'enhancement_plan',
        'riskLabel': row.riskLabel,
        'topDriver': row.topDriver,
        'executedBy': user.name,
        'executedAt': Timestamp.now(),
      });
    } catch (e) {
      debugPrint('Error logging action: $e');
      // نتجاهل الخطأ ونكمل
    }
  }
}

class _KpiCard extends StatelessWidget {
  final String title;
  final int count;
  final double percent;
  final Color color;

  const _KpiCard({
    required this.title,
    required this.count,
    required this.percent,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 12.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            '$count طالب',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            '${percent.toStringAsFixed(1)}%',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class _StudentCard extends StatelessWidget {
  final BehaviorEnhancementStudentRow row;
  final VoidCallback onPlanTapped;

  const _StudentCard({required this.row, required this.onPlanTapped});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22.r,
              backgroundColor: Colors.indigo.shade50,
              child: Text(
                row.studentName.isNotEmpty
                    ? row.studentName.characters.first
                    : '?',
                style: TextStyle(
                  color: Colors.indigo.shade800,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    row.studentName,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    row.className,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade700,
                    ),
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Text(
                        'درجة السلوك: ${row.behaviorScore.toStringAsFixed(1)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      SizedBox(width: 8.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 2.h,
                          horizontal: 8.w,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Text(
                          'خطورة ${row.riskLabel}',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: Colors.orange.shade800),
                        ),
                      ),
                    ],
                  ),
                  if (row.topDriver.isNotEmpty) SizedBox(height: 4.h),
                  if (row.topDriver.isNotEmpty)
                    Text(
                      'أهم مؤشر: ${row.topDriver}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade800,
                      ),
                    ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              onPressed: onPlanTapped,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
              child: const Text('خطة تعزيز'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget يعرض بيانات الطالب المختار مباشرة من Firebase
class _StudentDirectDataCard extends StatefulWidget {
  final String studentId;
  final String studentName;

  const _StudentDirectDataCard({
    required this.studentId,
    required this.studentName,
  });

  @override
  State<_StudentDirectDataCard> createState() => _StudentDirectDataCardState();
}

class _StudentDirectDataCardState extends State<_StudentDirectDataCard> {
  bool _isLoading = true;
  int _violationCount = 0;
  int _violationPoints = 0;
  int _positiveCount = 0;
  int _positivePoints = 0;
  int _casesCount = 0;
  int _activeCasesCount = 0;
  List<Map<String, dynamic>> _recentViolations = [];
  List<Map<String, dynamic>> _recentPositive = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(_StudentDirectDataCard old) {
    super.didUpdateWidget(old);
    if (old.studentId != widget.studentId) _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final fs = FirebaseFirestore.instance;
      final name = widget.studentName;
      final id = widget.studentId;

      // دالة مساعدة لدمج نتائج استعلامين بدون تكرار
      Future<List<QueryDocumentSnapshot>> fetchMerged(
        String collection,
        String idField,
        String nameField,
      ) async {
        final byId = await fs.collection(collection)
            .where(idField, isEqualTo: id)
            .get();
        final byName = name.isNotEmpty
            ? await fs.collection(collection)
                .where(nameField, isEqualTo: name)
                .get()
            : null;

        final seen = <String>{};
        final merged = <QueryDocumentSnapshot>[];
        for (final d in byId.docs) {
          if (seen.add(d.id)) merged.add(d);
        }
        if (byName != null) {
          for (final d in byName.docs) {
            if (seen.add(d.id)) merged.add(d);
          }
        }
        return merged;
      }

      // جلب المخالفات
      final vDocs = await fetchMerged('behavioral_violations', 'studentId', 'studentName');
      vDocs.sort((a, b) {
        final at = ((a.data() as Map)['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final bt = ((b.data() as Map)['timestamp'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return bt.compareTo(at);
      });
      int vPoints = 0;
      for (final d in vDocs) {
        vPoints += ((d.data() as Map)['points'] as int?) ?? 1;
      }

      // جلب السلوك الإيجابي
      final pDocs = await fetchMerged('positive_behavior', 'studentId', 'studentName');
      int pPoints = 0;
      for (final d in pDocs) {
        pPoints += ((d.data() as Map)['points'] as int?) ?? 1;
      }

      // جلب الحالات
      final cDocs = await fetchMerged('behavioral_cases', 'studentId', 'studentName');
      final activeCases = cDocs.where((d) => (d.data() as Map)['status'] == 'active').length;

      if (mounted) {
        setState(() {
          _violationCount = vDocs.length;
          _violationPoints = vPoints;
          _positiveCount = pDocs.length;
          _positivePoints = pPoints;
          _casesCount = cDocs.length;
          _activeCasesCount = activeCases;
          _recentViolations = vDocs.take(3).map((d) {
            final data = Map<String, dynamic>.from(d.data() as Map);
            data['id'] = d.id;
            return data;
          }).toList();
          _recentPositive = pDocs.take(3).map((d) {
            final data = Map<String, dynamic>.from(d.data() as Map);
            data['id'] = d.id;
            return data;
          }).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final netScore = _positivePoints - _violationPoints;
    Color scoreColor = netScore >= 10
        ? Colors.green
        : netScore >= 0
            ? Colors.blue
            : netScore >= -5
                ? Colors.orange
                : Colors.red;
    String scoreLabel = netScore >= 10
        ? 'ممتاز'
        : netScore >= 0
            ? 'جيد'
            : netScore >= -5
                ? 'يحتاج متابعة'
                : 'حرج';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scoreColor.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: Colors.indigo.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: _isLoading
          ? const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // رأس البطاقة
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: scoreColor.withOpacity(0.15),
                        radius: 24,
                        child: Icon(Icons.person, color: scoreColor, size: 28),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(widget.studentName,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: scoreColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(scoreLabel,
                                  style: TextStyle(color: scoreColor, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          Text('$netScore',
                              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: scoreColor)),
                          Text('النقاط الصافية', style: TextStyle(fontSize: 10, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),

                  // الإحصائيات
                  Row(
                    children: [
                      _statChip('مخالفات', '$_violationCount', '${_violationPoints}ن', Colors.red),
                      const SizedBox(width: 8),
                      _statChip('إيجابي', '$_positiveCount', '${_positivePoints}ن', Colors.green),
                      const SizedBox(width: 8),
                      _statChip('حالات', '$_casesCount', '$_activeCasesCount نشطة', Colors.orange),
                    ],
                  ),

                  // آخر المخالفات
                  if (_recentViolations.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text('آخر المخالفات:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._recentViolations.map((v) => _recordRow(
                      icon: Icons.warning,
                      color: Colors.red,
                      title: v['violationType'] ?? 'مخالفة',
                      subtitle: v['level'] ?? '',
                      points: '${v['points'] ?? 1} نقطة',
                      timestamp: (v['timestamp'] as Timestamp?)?.toDate(),
                    )),
                  ],

                  // آخر السلوك الإيجابي
                  if (_recentPositive.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('آخر السلوك الإيجابي:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    ..._recentPositive.map((p) => _recordRow(
                      icon: Icons.star,
                      color: Colors.green,
                      title: p['behaviorType'] ?? 'سلوك إيجابي',
                      subtitle: p['description'] ?? '',
                      points: '+${p['points'] ?? 1} نقطة',
                      timestamp: (p['timestamp'] as Timestamp?)?.toDate(),
                    )),
                  ],

                  if (_violationCount == 0 && _positiveCount == 0 && _casesCount == 0)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                        child: Text('لا توجد سجلات سلوكية لهذا الطالب بعد',
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _statChip(String label, String count, String sub, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(count, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: const TextStyle(fontSize: 11)),
            Text(sub, style: TextStyle(fontSize: 10, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _recordRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String points,
    DateTime? timestamp,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(points, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold)),
              if (timestamp != null)
                Text(
                  '${timestamp.day}/${timestamp.month}/${timestamp.year}',
                  style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
