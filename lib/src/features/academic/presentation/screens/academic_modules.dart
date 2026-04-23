import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';
import '../academic_supervision_tabs.dart';
import '../../../../core/domain/models/user.dart';
import '../../../exams/presentation/tabs/exam_schedule_tab.dart';
import '../../../exams/presentation/tabs/exam_committees_tab.dart';
import '../../../exams/presentation/tabs/grades_tracking_tab.dart';
import '../../../exams/presentation/tabs/exam_absence_tab.dart';
import '../../../intelligence/presentation/tabs/academic_analysis_tabs.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../admin/data/mock_teacher_repository.dart' as mock_teachers;
import '../students_provider.dart';
import '../academic_actions_providers.dart';
import '../export_academic_reports_tab.dart';
import '../teacher_performance_report_tab.dart';
import '../teacher_follow_up_providers.dart';
import '../../../schedule/data/schedule_repository.dart';
import '../../../schedule/domain/schedule_stats.dart';
import '../../../schedule/presentation/current_schedule_screen.dart';
import '../../../intelligence/presentation/school_intelligence_providers.dart';
import '../../../intelligence/data/firestore_school_intelligence_repository.dart';
import '../../../admin/data/mock_class_repository.dart';
import '../../domain/classroom.dart';
import '../../domain/teacher_follow_up.dart';

enum TimetableCreationMode { quickSmart, collaborative }

// ==============================================================================
// 1. Academic Progress Module
// ==============================================================================
class AcademicProgressModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const AcademicProgressModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget innerContent;
    String title;
    String description;

    switch (initialIndex) {
      case 0:
        title = 'الجاهزية التعليمية والتخطيط التدريسي';
        description =
            'قياس جاهزية المعلمين والفصول من حيث تحضير الدروس وخطط التدريس للأسبوع الحالي.';
        innerContent = const LessonPrepTab();
        break;
      case 1:
        title = 'مستوى الالتزام بالخطة الدراسية';
        description =
            'تحليل التزام المواد بالخطة الدراسية المعتمدة ورصد المواد التي تحتاج متابعة أو دعم.';
        innerContent = const CurriculumProgressTab();
        break;
      case 2:
      default:
        title = 'مؤشرات تحسين الأداء التعليمي';
        description =
            'لوحة قيادية لمتابعة مؤشرات أداء المعلمين والفرص التطويرية وفق بيانات المدرسة.';
        innerContent = const EducationalPerformanceTab();
        break;
    }

    return UnifiedPageScaffold(
      requiredDeputyType: 'academic',
      requiredPermission: 'academic_affairs',
      title: title,
      showAppBar: false,
      body: SafeArea(child: innerContent),
    );
  }
}

class EducationalPerformanceTab extends ConsumerStatefulWidget {
  const EducationalPerformanceTab({super.key});

  @override
  ConsumerState<EducationalPerformanceTab> createState() =>
      _EducationalPerformanceTabState();
}

class _TeacherPerformanceInfo {
  final User teacher;
  final int currentLoad;
  final int maxLoad;
  final double avgExcellence;
  final TeacherFollowUp followUp;

  _TeacherPerformanceInfo({
    required this.teacher,
    required this.currentLoad,
    required this.maxLoad,
    required this.avgExcellence,
    required this.followUp,
  });
}

class _EducationalPerformanceTabState
    extends ConsumerState<EducationalPerformanceTab> {
  bool _isLoading = false;
  List<_TeacherPerformanceInfo> _items = [];
  String _searchQuery = '';
  String _followUpFilter = 'all';
  String? _hoverTeacherId;
  String? _hoverHeatTeacherId;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      final followUps = await ref
          .read(teacherFollowUpsProvider.future)
          .timeout(const Duration(seconds: 12));
      final teachers = await ref.read(mock_teachers.teachersProvider.future);
      final classes = await ref.read(classesProvider.future);
      final students = await ref.read(studentsProvider.future);
      final scheduleRepo = ref.read(scheduleRepositoryProvider);

      final List<_TeacherPerformanceInfo> items = [];

      for (final t in teachers) {
        if (t.role != UserRole.teacher) continue;

        final sid = (t.schoolId ?? '').trim().isNotEmpty
            ? t.schoolId!.trim()
            : schoolId;
        final load = await scheduleRepo.getTeacherLoad(sid, t.id);
        final max = t.maxWeeklyClasses ?? 24;

        final teacherClassIds = t.assignedClassIds ?? [];
        final relevantClasses = classes
            .where((c) => teacherClassIds.contains(c.id))
            .toList();

        if (relevantClasses.isEmpty) {
          items.add(
            _TeacherPerformanceInfo(
              teacher: t,
              currentLoad: load,
              maxLoad: max,
              avgExcellence: 0,
              followUp: followUps[t.id] ?? TeacherFollowUp.empty(t.id),
            ),
          );
          continue;
        }

        final classStudentIds = <String>{};
        for (final c in relevantClasses) {
          classStudentIds.addAll(c.studentIds);
        }
        final classStudents = students
            .where((s) => classStudentIds.contains(s.id))
            .toList();
        final scores = classStudents
            .map((s) => s.excellenceScore.toDouble())
            .toList();
        final avgExcellence = scores.isEmpty
            ? 0.0
            : scores.reduce((a, b) => a + b) / scores.length;

        items.add(
          _TeacherPerformanceInfo(
            teacher: t,
            currentLoad: load,
            maxLoad: max,
            avgExcellence: avgExcellence,
            followUp: followUps[t.id] ?? TeacherFollowUp.empty(t.id),
          ),
        );
      }

      items.sort((a, b) => a.avgExcellence.compareTo(b.avgExcellence));

      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<_TeacherPerformanceInfo> get _visibleItems {
    var list = _items;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim();
      list = list
          .where(
            (i) =>
                i.teacher.name.contains(q) ||
                (i.teacher.identityNumber?.contains(q) ?? false),
          )
          .toList();
    }
    if (_followUpFilter != 'all') {
      list = list.where((i) => i.followUp.status == _followUpFilter).toList();
    }
    return list;
  }

  Color _heatColor(double value) {
    if (value >= 85) return Colors.green.shade600;
    if (value >= 70) return Colors.orange.shade600;
    if (value >= 50) return Colors.deepOrange.shade400;
    return Colors.red.shade600;
  }

  String _normalizeTeacherEmailForDisplay(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    var local = email.substring(0, at);
    final domain = email.substring(at + 1);

    while (local.toLowerCase().startsWith('tctc')) {
      local = local.substring(2);
    }

    if (local.toLowerCase().startsWith('tc') && local.length >= 2) {
      local = 'TC${local.substring(2)}';
    }

    return '$local@$domain';
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    final canEditFollowUp = () {
      final u = ref.watch(authStateProvider).value;
      if (u == null) return false;
      return u.role == UserRole.deputy ||
          u.role == UserRole.admin ||
          u.role == UserRole.superAdmin ||
          u.role == UserRole.technicalSupport ||
          u.role == UserRole.supportAdmin;
    }();

    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);
    const bg = Color(0xFFF8FAFC);
    const success = Color(0xFF22C55E);
    const warn = Color(0xFFF59E0B);
    const danger = Color(0xFFEF4444);

    int countNone = 0;
    int countInProgress = 0;
    int countDone = 0;
    for (final i in visible) {
      if (i.followUp.status == 'done') {
        countDone++;
      } else if (i.followUp.status == 'in_progress') {
        countInProgress++;
      } else {
        countNone++;
      }
    }

    Widget glass({required Widget child, double? radius}) {
      final r = radius ?? 22.r;
      return ClipRRect(
        borderRadius: BorderRadius.circular(r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    Widget statCard({
      required String label,
      required int value,
      required IconData icon,
      required Color tone,
    }) {
      return glass(
        child: Padding(
          padding: EdgeInsets.all(14.w),
          child: Row(
            children: [
              Container(
                width: 42.w,
                height: 42.w,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16.r),
                  color: tone.withValues(alpha: 0.14),
                ),
                child: Icon(icon, color: tone),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 250),
                      child: _isLoading
                          ? Container(
                              key: const ValueKey('sk'),
                              width: 68.w,
                              height: 22.h,
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                            )
                          : TweenAnimationBuilder<int>(
                              key: const ValueKey('val'),
                              tween: IntTween(begin: 0, end: value),
                              duration: const Duration(milliseconds: 700),
                              builder: (context, v, _) {
                                return Text(
                                  v.toString(),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    fontSize: 20.sp,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    Widget legend(String label, Color c) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          SizedBox(width: 6.w),
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade700,
              fontSize: 11.sp,
            ),
          ),
        ],
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.insights,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مؤشرات تحسين الأداء التعليمي',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'لوحة متابعة احترافية لأداء المعلمين مع متابعة وتوثيق إجراءات.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _HeaderBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'بحث وفلترة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 240.w,
                            child: TextField(
                              decoration: InputDecoration(
                                labelText: 'ابحث باسم المعلم أو اليوزر',
                                prefixIcon: const Icon(Icons.search),
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              onChanged: (val) =>
                                  setState(() => _searchQuery = val),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          SizedBox(
                            width: 190.w,
                            child: DropdownButtonFormField<String>(
                              value: _followUpFilter,
                              decoration: InputDecoration(
                                labelText: 'حالة المتابعة',
                                filled: true,
                                fillColor: Colors.white.withValues(alpha: 0.7),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('الكل'),
                                ),
                                DropdownMenuItem(
                                  value: 'none',
                                  child: Text('غير متابع'),
                                ),
                                DropdownMenuItem(
                                  value: 'in_progress',
                                  child: Text('قيد المتابعة'),
                                ),
                                DropdownMenuItem(
                                  value: 'done',
                                  child: Text('مكتمل'),
                                ),
                              ],
                              onChanged: (v) =>
                                  setState(() => _followUpFilter = v ?? 'all'),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: _isLoading ? null : _loadData,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final wide = constraints.maxWidth >= 900;
                  final w = wide
                      ? (constraints.maxWidth - 36.w) / 4
                      : (constraints.maxWidth - 12.w) / 2;
                  return Wrap(
                    runSpacing: 12.h,
                    spacing: 12.w,
                    children: [
                      SizedBox(
                        width: w,
                        child: statCard(
                          label: 'غير متابع',
                          value: countNone,
                          icon: Icons.remove_red_eye_outlined,
                          tone: Colors.blueGrey.shade700,
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: statCard(
                          label: 'قيد المتابعة',
                          value: countInProgress,
                          icon: Icons.pending_actions,
                          tone: warn,
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: statCard(
                          label: 'مكتمل',
                          value: countDone,
                          icon: Icons.verified,
                          tone: success,
                        ),
                      ),
                      SizedBox(
                        width: w,
                        child: statCard(
                          label: 'إجمالي المعلمين',
                          value: visible.length,
                          icon: Icons.people_alt_outlined,
                          tone: primary,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 0),
            sliver: SliverToBoxAdapter(
              child: glass(
                child: Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38.w,
                            height: 38.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              gradient: const LinearGradient(
                                colors: [primaryDark, primary],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: const Icon(
                              Icons.grid_view_rounded,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'خريطة الأداء',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.5.sp,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                                SizedBox(height: 2.h),
                                Text(
                                  'تفاعل مع أي معلم لفتح نافذة تحديث المتابعة والسجل.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Wrap(
                            spacing: 8.w,
                            children: [
                              legend('ممتاز', success),
                              legend('متوسط', warn),
                              legend('يحتاج دعم إشرافي', danger),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      if (_isLoading)
                        Wrap(
                          spacing: 10.w,
                          runSpacing: 10.h,
                          children: List.generate(8, (i) {
                            return Container(
                              width: 140.w,
                              height: 88.h,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18.r),
                                color: Colors.black.withValues(alpha: 0.05),
                              ),
                            );
                          }),
                        ),
                      if (!_isLoading && visible.isEmpty)
                        SizedBox(
                          height: 120.h,
                          child: Center(
                            child: Text(
                              'لا توجد بيانات كافية لعرض خريطة الأداء حالياً.',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      if (!_isLoading && visible.isNotEmpty)
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final cell = 130.w;
                            final crossAxisCount = (constraints.maxWidth / cell)
                                .floor()
                                .clamp(2, 8);
                            final rows = (visible.length / crossAxisCount)
                                .ceil();
                            final height = (rows * 92.h) + ((rows - 1) * 10.h);

                            return SizedBox(
                              height: height.clamp(160.h, 420.h),
                              child: GridView.builder(
                                physics: const NeverScrollableScrollPhysics(),
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                      childAspectRatio: 1.55,
                                    ),
                                itemCount: visible.length,
                                itemBuilder: (context, index) {
                                  final item = visible[index];
                                  final score = item.avgExcellence.clamp(
                                    0.0,
                                    100.0,
                                  );
                                  final heat = _heatColor(score);
                                  final isHover =
                                      _hoverHeatTeacherId == item.teacher.id;
                                  return MouseRegion(
                                    onEnter: (_) => setState(
                                      () =>
                                          _hoverHeatTeacherId = item.teacher.id,
                                    ),
                                    onExit: (_) => setState(
                                      () => _hoverHeatTeacherId = null,
                                    ),
                                    child: AnimatedScale(
                                      scale: isHover ? 1.02 : 1,
                                      duration: const Duration(
                                        milliseconds: 140,
                                      ),
                                      curve: Curves.easeOut,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(
                                          18.r,
                                        ),
                                        onTap: () => _openTeacherSheet(
                                          context,
                                          item,
                                          canEditFollowUp: canEditFollowUp,
                                        ),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              18.r,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                heat.withValues(alpha: 0.18),
                                                Colors.white.withValues(
                                                  alpha: 0.65,
                                                ),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            border: Border.all(
                                              color: heat.withValues(
                                                alpha: 0.45,
                                              ),
                                            ),
                                          ),
                                          padding: EdgeInsets.all(12.w),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.teacher.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color:
                                                      Colors.blueGrey.shade900,
                                                  fontSize: 12.sp,
                                                ),
                                              ),
                                              SizedBox(height: 6.h),
                                              Row(
                                                children: [
                                                  Text(
                                                    score.toStringAsFixed(1),
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: heat,
                                                      fontSize: 14.sp,
                                                    ),
                                                  ),
                                                  Text(
                                                    ' / 100',
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors
                                                          .blueGrey
                                                          .shade600,
                                                      fontSize: 12.sp,
                                                    ),
                                                  ),
                                                  const Spacer(),
                                                  _followUpMiniTag(
                                                    item.followUp,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: _isLoading
                ? SliverList.builder(
                    itemCount: 6,
                    itemBuilder: (context, index) => Padding(
                      padding: EdgeInsets.only(bottom: 10.h),
                      child: glass(
                        child: Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46.w,
                                    height: 46.w,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16.r),
                                      color: Colors.black.withValues(
                                        alpha: 0.07,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          height: 14.h,
                                          width: 180.w,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 8.h),
                                        Container(
                                          height: 12.h,
                                          width: 120.w,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            color: Colors.black.withValues(
                                              alpha: 0.05,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.h),
                              Container(
                                height: 10.h,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(999),
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              SizedBox(height: 14.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      height: 42.h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        color: Colors.black.withValues(
                                          alpha: 0.05,
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: Container(
                                      height: 42.h,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        color: Colors.black.withValues(
                                          alpha: 0.06,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  )
                : visible.isEmpty
                ? SliverToBoxAdapter(
                    child: SizedBox(
                      height: 180.h,
                      child: Center(
                        child: Text(
                          'لا توجد بيانات متاحة حالياً',
                          style: TextStyle(
                            color: Colors.blueGrey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  )
                : SliverList.builder(
                    itemCount: visible.length,
                    itemBuilder: (context, index) {
                      final item = visible[index];
                      final score = item.avgExcellence.clamp(0.0, 100.0);
                      final progress = (score / 100.0)
                          .clamp(0.0, 1.0)
                          .toDouble();
                      final loadPercent = item.maxLoad == 0
                          ? 0
                          : (item.currentLoad / item.maxLoad) * 100;

                      final devLabel = score >= 85
                          ? 'ممتاز'
                          : score >= 70
                          ? 'جيد'
                          : 'يحتاج دعم إشرافي';

                      final devColor = score >= 85
                          ? success
                          : score >= 70
                          ? warn
                          : danger;

                      final followUpMeta = _followUpMeta(item.followUp);
                      final contact = item.teacher.email.isNotEmpty
                          ? _normalizeTeacherEmailForDisplay(item.teacher.email)
                          : (item.teacher.phoneNumber?.isNotEmpty == true
                                ? item.teacher.phoneNumber!
                                : '');
                      final isHover = _hoverTeacherId == item.teacher.id;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 10.h),
                        child: MouseRegion(
                          onEnter: (_) =>
                              setState(() => _hoverTeacherId = item.teacher.id),
                          onExit: (_) => setState(() => _hoverTeacherId = null),
                          child: AnimatedScale(
                            scale: isHover ? 1.01 : 1,
                            duration: const Duration(milliseconds: 140),
                            curve: Curves.easeOut,
                            child: glass(
                              child: Padding(
                                padding: EdgeInsets.all(14.w),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          width: 46.w,
                                          height: 46.w,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                            gradient: LinearGradient(
                                              colors: [
                                                devColor.withValues(alpha: 0.9),
                                                devColor.withValues(
                                                  alpha: 0.55,
                                                ),
                                              ],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.person,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.teacher.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      Colors.blueGrey.shade900,
                                                  fontSize: 14.sp,
                                                ),
                                              ),
                                              if (contact.isNotEmpty) ...[
                                                SizedBox(height: 4.h),
                                                Text(
                                                  contact,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade600,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 11.5.sp,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: followUpMeta.color
                                                .withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: followUpMeta.color
                                                  .withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Text(
                                            followUpMeta.label,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: followUpMeta.color,
                                              fontSize: 11.sp,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12.h),
                                    Row(
                                      children: [
                                        Text(
                                          '${score.toStringAsFixed(1)} / 100',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: devColor,
                                            fontSize: 13.sp,
                                          ),
                                        ),
                                        SizedBox(width: 10.w),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 5.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: devColor.withValues(
                                              alpha: 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                            border: Border.all(
                                              color: devColor.withValues(
                                                alpha: 0.35,
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            devLabel,
                                            style: TextStyle(
                                              color: devColor,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 11.sp,
                                            ),
                                          ),
                                        ),
                                        const Spacer(),
                                        Text(
                                          'النصاب: ${item.currentLoad}/${item.maxLoad} (${loadPercent.toStringAsFixed(1)}٪)',
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade700,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 11.5.sp,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10.h),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(999),
                                      child: LinearProgressIndicator(
                                        value: progress,
                                        minHeight: 8.h,
                                        backgroundColor: Colors.black
                                            .withValues(alpha: 0.06),
                                        valueColor: AlwaysStoppedAnimation(
                                          devColor,
                                        ),
                                      ),
                                    ),
                                    if (item.followUp.note.trim().isNotEmpty ||
                                        item.followUp.nextReviewAt != null) ...[
                                      SizedBox(height: 12.h),
                                      glass(
                                        radius: 16.r,
                                        child: Padding(
                                          padding: EdgeInsets.all(12.w),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              if (item.followUp.note
                                                  .trim()
                                                  .isNotEmpty)
                                                Text(
                                                  item.followUp.note.trim(),
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade800,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                              if (item.followUp.note
                                                      .trim()
                                                      .isNotEmpty &&
                                                  item.followUp.nextReviewAt !=
                                                      null)
                                                SizedBox(height: 6.h),
                                              if (item.followUp.nextReviewAt !=
                                                  null)
                                                Text(
                                                  'المراجعة القادمة: ${DateFormat('yyyy-MM-dd').format(item.followUp.nextReviewAt!)}',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade700,
                                                    fontWeight: FontWeight.w700,
                                                    fontSize: 12.sp,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                    SizedBox(height: 12.h),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            onPressed: () => context.push(
                                              '/teacher-details',
                                              extra: item.teacher,
                                            ),
                                            icon: const Icon(Icons.open_in_new),
                                            label: const Text('تفاصيل'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor:
                                                  Colors.blueGrey.shade900,
                                              side: BorderSide(
                                                color: Colors.black.withValues(
                                                  alpha: 0.14,
                                                ),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: 12.h,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                              ),
                                            ),
                                          ),
                                        ),
                                        if (canEditFollowUp)
                                          SizedBox(width: 10.w),
                                        if (canEditFollowUp)
                                          Expanded(
                                            child: ElevatedButton.icon(
                                              onPressed: () =>
                                                  _openTeacherSheet(
                                                    context,
                                                    item,
                                                    canEditFollowUp:
                                                        canEditFollowUp,
                                                  ),
                                              icon: const Icon(Icons.edit_note),
                                              label: const Text('تحديث'),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: primary,
                                                foregroundColor: Colors.white,
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 12.h,
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        16.r,
                                                      ),
                                                ),
                                                elevation: 0,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCountChip(String label, int count, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        '$label: $count',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color,
          fontSize: 12.sp,
        ),
      ),
    );
  }

  ({String label, Color color}) _followUpMeta(TeacherFollowUp f) {
    switch (f.status) {
      case 'done':
        return (label: 'مكتمل', color: const Color(0xFF22C55E));
      case 'in_progress':
        return (label: 'قيد المتابعة', color: const Color(0xFFF59E0B));
      default:
        return (label: 'غير متابع', color: Colors.blueGrey);
    }
  }

  Widget _followUpMiniTag(TeacherFollowUp f) {
    final meta = _followUpMeta(f);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: meta.color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: meta.color.withValues(alpha: 0.35)),
      ),
      child: Text(
        meta.label,
        style: TextStyle(
          fontSize: 10.sp,
          color: meta.color,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _openTeacherSheet(
    BuildContext context,
    _TeacherPerformanceInfo item, {
    required bool canEditFollowUp,
  }) async {
    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);
    const success = Color(0xFF22C55E);
    const warn = Color(0xFFF59E0B);
    const danger = Color(0xFFEF4444);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.r)),
      builder: (ctx) {
        String status = item.followUp.status;
        final noteCtrl = TextEditingController(text: item.followUp.note);
        DateTime? nextReviewAt = item.followUp.nextReviewAt;
        final tags = <String>[
          'زيارة صفية',
          'خطة تطوير',
          'تدريب',
          'جلسة توجيهية',
          'لقاء تطويري',
          'متابعة تحضير',
        ];
        final selected = <String>{};
        final assigneeCtrl = TextEditingController();

        return StatefulBuilder(
          builder: (context, setModalState) {
            Widget glass(Widget child) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(18.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.78),
                      borderRadius: BorderRadius.circular(18.r),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: child,
                  ),
                ),
              );
            }

            final score = item.avgExcellence.clamp(0.0, 100.0);
            final scoreColor = score >= 85
                ? success
                : score >= 70
                ? warn
                : danger;
            final statusMeta = status == 'done'
                ? (label: 'مكتمل', color: success)
                : status == 'in_progress'
                ? (label: 'قيد المتابعة', color: warn)
                : (label: 'غير متابع', color: Colors.blueGrey);

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  12.w,
                  0,
                  12.w,
                  12.h + MediaQuery.of(context).viewInsets.bottom,
                ),
                child: glass(
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [primaryDark, primary],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.vertical(
                            top: Radius.circular(18.r),
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44.w,
                              height: 44.w,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(16.r),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.24),
                                ),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.teacher.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 14.5.sp,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 5.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.22,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          'التميز: ${score.toStringAsFixed(1)}/100',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 8.w),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 5.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.16,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.22,
                                            ),
                                          ),
                                        ),
                                        child: Text(
                                          statusMeta.label,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: (score / 100.0)
                                    .clamp(0.0, 1.0)
                                    .toDouble(),
                                minHeight: 10.h,
                                backgroundColor: Colors.black.withValues(
                                  alpha: 0.06,
                                ),
                                valueColor: AlwaysStoppedAnimation(scoreColor),
                              ),
                            ),
                            SizedBox(height: 14.h),
                            if (canEditFollowUp) ...[
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: status.isEmpty ? 'none' : status,
                                      decoration: InputDecoration(
                                        labelText: 'حالة المتابعة',
                                        filled: true,
                                        fillColor: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                      ),
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'none',
                                          child: Text('غير متابع'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'in_progress',
                                          child: Text('قيد المتابعة'),
                                        ),
                                        DropdownMenuItem(
                                          value: 'done',
                                          child: Text('مكتمل'),
                                        ),
                                      ],
                                      onChanged: (v) => setModalState(
                                        () => status = v ?? 'none',
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: TextField(
                                      controller: assigneeCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'مسؤول المتابعة (اختياري)',
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                        ),
                                        filled: true,
                                        fillColor: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              glass(
                                Padding(
                                  padding: EdgeInsets.all(12.w),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        'وسوم المتابعة',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blueGrey.shade900,
                                        ),
                                      ),
                                      SizedBox(height: 10.h),
                                      Wrap(
                                        spacing: 8.w,
                                        runSpacing: 8.h,
                                        children: tags.map((t) {
                                          final isOn = selected.contains(t);
                                          return FilterChip(
                                            selected: isOn,
                                            label: Text(t),
                                            selectedColor: primary.withValues(
                                              alpha: 0.16,
                                            ),
                                            checkmarkColor: primaryDark,
                                            labelStyle: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              color: isOn
                                                  ? primaryDark
                                                  : Colors.blueGrey.shade800,
                                            ),
                                            onSelected: (v) =>
                                                setModalState(() {
                                                  if (v) {
                                                    selected.add(t);
                                                  } else {
                                                    selected.remove(t);
                                                  }
                                                }),
                                          );
                                        }).toList(),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              TextField(
                                controller: noteCtrl,
                                minLines: 3,
                                maxLines: 6,
                                decoration: InputDecoration(
                                  labelText: 'ملاحظة/إجراء',
                                  prefixIcon: const Icon(Icons.edit_note),
                                  filled: true,
                                  fillColor: Colors.white.withValues(
                                    alpha: 0.92,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16.r),
                                  ),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        final picked = await showDatePicker(
                                          context: context,
                                          firstDate: DateTime(2020),
                                          lastDate: DateTime(2100),
                                          initialDate:
                                              nextReviewAt ?? DateTime.now(),
                                        );
                                        if (picked == null) return;
                                        setModalState(
                                          () => nextReviewAt = picked,
                                        );
                                      },
                                      icon: const Icon(Icons.event),
                                      label: Text(
                                        nextReviewAt == null
                                            ? 'تاريخ المراجعة'
                                            : 'المراجعة: ${DateFormat('yyyy-MM-dd').format(nextReviewAt!)}',
                                      ),
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        final tagPrefix = selected.isEmpty
                                            ? ''
                                            : 'وسوم: ${selected.join('، ')}';
                                        final ownerPrefix =
                                            assigneeCtrl.text.trim().isEmpty
                                            ? ''
                                            : 'مسؤول: ${assigneeCtrl.text.trim()}';
                                        final prefix = [
                                          if (tagPrefix.isNotEmpty) tagPrefix,
                                          if (ownerPrefix.isNotEmpty)
                                            ownerPrefix,
                                        ].join(' • ');
                                        final note =
                                            [
                                                  if (prefix.isNotEmpty) prefix,
                                                  noteCtrl.text.trim(),
                                                ]
                                                .where(
                                                  (e) => e.trim().isNotEmpty,
                                                )
                                                .join('\n');

                                        final p = UpsertTeacherFollowUpParams(
                                          teacherId: item.teacher.id,
                                          status: status,
                                          note: note,
                                          nextReviewAt: nextReviewAt,
                                        );
                                        await ref.read(
                                          upsertTeacherFollowUpProvider(
                                            p,
                                          ).future,
                                        );
                                        ref.invalidate(
                                          teacherFollowUpsProvider,
                                        );
                                        if (!mounted) return;
                                        await _loadData();
                                        if (!context.mounted) return;
                                        Navigator.pop(context);
                                      },
                                      icon: const Icon(Icons.save),
                                      label: const Text('حفظ'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryDark,
                                        foregroundColor: Colors.white,
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                            ],
                            Text(
                              'سجل المتابعة',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            glass(
                              Padding(
                                padding: EdgeInsets.all(12.w),
                                child: FutureBuilder<List<Map<String, dynamic>>>(
                                  future: ref.read(
                                    teacherFollowUpLogsProvider(
                                      item.teacher.id,
                                    ).future,
                                  ),
                                  builder: (context, snap) {
                                    final logs = snap.data ?? const [];
                                    if (logs.isEmpty) {
                                      return Text(
                                        'لا يوجد سجل بعد.',
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade700,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      );
                                    }
                                    return SizedBox(
                                      height: 220.h,
                                      child: ListView.separated(
                                        itemCount: logs.length,
                                        separatorBuilder: (_, __) =>
                                            Divider(height: 16.h),
                                        itemBuilder: (context, i) {
                                          final m = logs[i];
                                          final note = (m['note'] ?? '')
                                              .toString()
                                              .trim();
                                          final st = (m['status'] ?? '')
                                              .toString()
                                              .trim();
                                          final who = (m['createdByName'] ?? '')
                                              .toString()
                                              .trim();
                                          final whenRaw = m['createdAt'];
                                          DateTime? when;
                                          try {
                                            if (whenRaw != null &&
                                                whenRaw.toDate != null) {
                                              when =
                                                  whenRaw.toDate() as DateTime;
                                            }
                                          } catch (_) {}
                                          final meta = _followUpMeta(
                                            TeacherFollowUp(
                                              teacherId: item.teacher.id,
                                              status: st,
                                              note: '',
                                              nextReviewAt: null,
                                              updatedAt: null,
                                              updatedByUid: '',
                                              updatedByName: '',
                                            ),
                                          );

                                          return Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Container(
                                                width: 10,
                                                height: 10,
                                                margin: EdgeInsets.only(
                                                  top: 6.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: meta.color,
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      note.isEmpty
                                                          ? meta.label
                                                          : note,
                                                      maxLines: 3,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color: Colors
                                                            .blueGrey
                                                            .shade900,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      [
                                                        if (who.isNotEmpty) who,
                                                        if (when != null)
                                                          DateFormat(
                                                            'yyyy-MM-dd HH:mm',
                                                          ).format(when),
                                                      ].join(' • '),
                                                      style: TextStyle(
                                                        color: Colors
                                                            .blueGrey
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 10.w),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10.w,
                                                  vertical: 6.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: meta.color.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                  border: Border.all(
                                                    color: meta.color
                                                        .withValues(
                                                          alpha: 0.35,
                                                        ),
                                                  ),
                                                ),
                                                child: Text(
                                                  meta.label,
                                                  style: TextStyle(
                                                    color: meta.color,
                                                    fontWeight: FontWeight.w900,
                                                    fontSize: 11.sp,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        },
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _HeaderBackButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HeaderBackButton({required this.onPressed});

  @override
  State<_HeaderBackButton> createState() => _HeaderBackButtonState();
}

class _HeaderBackButtonState extends State<_HeaderBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    SizedBox(width: 8.w),
                    Text(
                      'العودة للوحة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          SizedBox(width: 8.w),
          Text(
            '$label: $value',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5.sp,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsetsDirectional.only(end: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade900,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 16, color: Colors.blueGrey.shade700),
          ),
        ],
      ),
    );
  }
}

class TeacherLoadDistributionTab extends ConsumerStatefulWidget {
  const TeacherLoadDistributionTab({super.key});

  @override
  ConsumerState<TeacherLoadDistributionTab> createState() =>
      _TeacherLoadDistributionTabState();
}

class _TeacherLoadDistributionTabState
    extends ConsumerState<TeacherLoadDistributionTab> {
  bool _isLoading = false;
  List<_TeacherLoadInfo> _items = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) {
        setState(() {
          _items = [];
        });
        return;
      }
      final teachers = await ref.read(mock_teachers.teachersProvider.future);
      final repo = ref.read(scheduleRepositoryProvider);
      final result = <_TeacherLoadInfo>[];
      for (final t in teachers) {
        if (t.role != UserRole.teacher) {
          continue;
        }
        if (t.schoolId != null &&
            t.schoolId!.isNotEmpty &&
            t.schoolId != schoolId) {
          continue;
        }
        final load = await repo.getTeacherLoad(schoolId, t.id);
        final max = t.maxWeeklyClasses ?? 24;
        result.add(
          _TeacherLoadInfo(
            id: t.id,
            name: t.name,
            specialization: t.specialization,
            currentLoad: load,
            maxLoad: max,
          ),
        );
      }
      result.sort((a, b) => b.currentLoad.compareTo(a.currentLoad));
      setState(() {
        _items = result;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<_TeacherLoadInfo> get _visibleItems {
    if (_searchQuery.trim().isEmpty) {
      return _items;
    }
    final query = _searchQuery.trim();
    return _items
        .where(
          (t) =>
              t.name.contains(query) ||
              (t.specialization != null && t.specialization!.contains(query)),
        )
        .toList();
  }

  double get _averageRatio {
    if (_items.isEmpty) {
      return 0;
    }
    final sum = _items.fold<double>(0, (s, t) => s + t.ratio);
    return sum / _items.length;
  }

  int get _overLoadedCount {
    return _items.where((t) => t.currentLoad > t.maxLoad).length;
  }

  int get _underLoadedCount {
    return _items
        .where((t) => t.maxLoad > 0 && t.currentLoad < t.maxLoad - 3)
        .length;
  }

  @override
  Widget build(BuildContext context) {
    final visible = _visibleItems;
    Widget listContent;
    if (_isLoading) {
      listContent = const Center(child: CircularProgressIndicator());
    } else if (visible.isEmpty) {
      listContent = const Center(
        child: Text('لم يتم تسجيل أنصبة للمعلمين حتى الآن'),
      );
    } else {
      listContent = ListView.separated(
        itemCount: visible.length,
        separatorBuilder: (_, __) => SizedBox(height: 8.h),
        itemBuilder: (context, index) {
          final item = visible[index];
          return Card(
            elevation: 1,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: item.statusColor.withValues(alpha: 0.12),
                child: Text(
                  item.currentLoad.toString(),
                  style: TextStyle(
                    color: item.statusColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(item.name),
              subtitle: Text(
                [
                  if (item.specialization != null &&
                      item.specialization!.isNotEmpty)
                    item.specialization!,
                  'الحصص: ${item.currentLoad}/${item.maxLoad}',
                  'الحالة: ${item.statusLabel}',
                ].join(' • '),
              ),
              trailing: Icon(Icons.circle, color: item.statusColor, size: 14),
            ),
          );
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'نظرة سريعة على توزيع الأنصبة',
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: _SummaryCard(
                title: 'متوسط استغلال النصاب',
                value: _items.isEmpty
                    ? '-'
                    : '${(_averageRatio * 100).round()}٪',
                color: Colors.indigo,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _SummaryCard(
                title: 'معلمون متجاوزون للنصاب',
                value: _overLoadedCount.toString(),
                color: Colors.red.shade600,
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _SummaryCard(
                title: 'معلمون يمكن زيادتهم',
                value: _underLoadedCount.toString(),
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'بحث باسم المعلم أو التخصص',
            border: OutlineInputBorder(),
          ),
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        SizedBox(height: 16.h),
        Expanded(child: listContent),
        SizedBox(height: 8.h),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _isLoading ? null : _loadData,
            icon: const Icon(Icons.refresh),
            label: const Text('تحديث البيانات من الجدول الحالي'),
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
          ),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherLoadInfo {
  final String id;
  final String name;
  final String? specialization;
  final int currentLoad;
  final int maxLoad;

  _TeacherLoadInfo({
    required this.id,
    required this.name,
    required this.specialization,
    required this.currentLoad,
    required this.maxLoad,
  });

  double get ratio {
    if (maxLoad <= 0) {
      return 0;
    }
    return currentLoad / maxLoad;
  }

  String get statusLabel {
    if (maxLoad <= 0) {
      return 'نصاب غير محدد';
    }
    if (currentLoad > maxLoad + 2) {
      return 'متجاوز للنصاب بشكل كبير';
    }
    if (currentLoad > maxLoad) {
      return 'متجاوز النصاب';
    }
    final diff = maxLoad - currentLoad;
    if (diff <= 2) {
      return 'قريب من الاكتمال';
    }
    if (ratio >= 0.6) {
      return 'متوازن';
    }
    return 'منخفض ويمكن زيادته';
  }

  Color get statusColor {
    if (maxLoad <= 0) {
      return Colors.grey;
    }
    if (currentLoad > maxLoad) {
      return Colors.red.shade600;
    }
    final diff = maxLoad - currentLoad;
    if (diff <= 2) {
      return Colors.orange.shade700;
    }
    if (ratio >= 0.6) {
      return Colors.green.shade700;
    }
    return Colors.blue.shade700;
  }
}

// ==============================================================================
// 2. Timetable Module
// ==============================================================================
class TimetableModuleScreen extends ConsumerWidget {
  final int initialIndex;
  final TimetableCreationMode? creationMode;

  const TimetableModuleScreen({
    super.key,
    this.initialIndex = 0,
    this.creationMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body;
    String title;
    String description;
    switch (initialIndex) {
      case 1:
        title = 'معالجة تعارض الجدول';
        description =
            'تحليل حالة الجدول الحالي ورصد المؤشرات التي تساعد في اكتشاف التعارضات.';
        body = const _ScheduleConflictsTab();
        break;
      case 2:
        title = 'توزيع نصاب المعلمين';
        description =
            'موازنة أنصبة المعلمين بعدالة مع مراعاة الظروف والمهام الإدارية.';
        body = const TeacherLoadDistributionTab();
        break;
      case 3:
        title = 'سجل تعديلات الجدول';
        description =
            'مؤشرات عن آخر تحديث للجدول وحالة النشر وعدد الجداول النشطة.';
        body = const _ScheduleChangeLogTab();
        break;
      case 0:
      default:
        title = 'عرض جدول الحصص';
        description =
            'عرض جداول الفصول والمعلمين بشكل احترافي حسب الحصة أو اليوم أو الأسبوع.';
        body = const ScheduleViewSection();
        break;
    }
    return UnifiedPageScaffold(
      requiredDeputyType: 'academic',
      requiredPermission: 'academic_affairs',
      title: title,
      showAppBar: false,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: LinearGradient(
                    colors: [Colors.indigo.shade700, Colors.indigo.shade400],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.indigo.withValues(alpha: 0.25),
                      blurRadius: 12.r,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(padding: EdgeInsets.all(12.w), child: body),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleConflictsTab extends ConsumerWidget {
  const _ScheduleConflictsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return Column(
      children: [
        UnifiedToolbar(
          onSearch: () {},
          onFilter: () {},
          extraActions: const [],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: schoolId.isEmpty
                ? const UnifiedEmptyState(
                    message: 'لم يتم ربط المستخدم بأي مدرسة حالياً.',
                  )
                : FutureBuilder<ScheduleStats>(
                    future: ref
                        .read(scheduleRepositoryProvider)
                        .getScheduleStats(schoolId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final stats = snapshot.data ?? ScheduleStats.empty();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _ConflictMetricCard(
                                  label: 'عدد الفصول',
                                  value: stats.classesCount.toString(),
                                  icon: Icons.meeting_room,
                                  color: Colors.indigo,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _ConflictMetricCard(
                                  label: 'عدد المعلمين',
                                  value: stats.teachersCount.toString(),
                                  icon: Icons.person,
                                  color: Colors.teal,
                                ),
                              ),
                              SizedBox(width: 12.w),
                              Expanded(
                                child: _ConflictMetricCard(
                                  label: 'جداول نشطة',
                                  value: stats.activeSchedulesCount.toString(),
                                  icon: Icons.schedule,
                                  color: Colors.deepOrange,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 20.h),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ملخص حالة الجدول',
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(height: 8.h),
                                  Text(
                                    stats.hasActiveSchedule
                                        ? 'تم نشر جدول الحصص لهذه المدرسة، ويمكن البدء في مراجعة التعارضات بين الجداول باستخدام هذه المؤشرات.'
                                        : 'لم يتم نشر جدول فعّال حتى الآن. عند نشر الجدول ستظهر هنا مؤشرات تساعد في التحقق من التعارضات المحتملة.',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  if (stats.lastUpdate != null) ...[
                                    SizedBox(height: 12.h),
                                    Row(
                                      children: [
                                        const Icon(Icons.update, size: 18),
                                        SizedBox(width: 6.w),
                                        Text(
                                          'آخر تحديث: ${DateFormat('yyyy-MM-dd HH:mm').format(stats.lastUpdate!)}',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ScheduleChangeLogTab extends ConsumerWidget {
  const _ScheduleChangeLogTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return Column(
      children: [
        UnifiedToolbar(
          onSearch: () {},
          onFilter: () {},
          extraActions: const [],
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: schoolId.isEmpty
                ? const UnifiedEmptyState(
                    message: 'لم يتم ربط المستخدم بأي مدرسة حالياً.',
                  )
                : FutureBuilder<ScheduleStats>(
                    future: ref
                        .read(scheduleRepositoryProvider)
                        .getScheduleStats(schoolId),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final stats = snapshot.data ?? ScheduleStats.empty();
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مؤشرات سجل التعديلات',
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            child: Padding(
                              padding: EdgeInsets.all(16.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    stats.hasActiveSchedule
                                        ? 'يوجد جدول منشور لهذه المدرسة. عدد الجداول النشطة: ${stats.activeSchedulesCount}.'
                                        : 'لا يوجد جدول منشور حتى الآن، ولن يظهر سجل تعديلات قبل إنشاء أول جدول ونشره.',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey.shade700,
                                    ),
                                  ),
                                  SizedBox(height: 12.h),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.event_note,
                                        color: Colors.indigo.shade700,
                                      ),
                                      SizedBox(width: 8.w),
                                      Expanded(
                                        child: Text(
                                          stats.lastUpdate != null
                                              ? 'آخر عملية تعديل أو نشر تمت في ${DateFormat('yyyy-MM-dd HH:mm').format(stats.lastUpdate!)}.'
                                              : 'لم يتم تسجيل أي عمليات تعديل على الجدول حتى اللحظة.',
                                          style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _ConflictMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _ConflictMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(icon, color: color, size: 22.sp),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ScheduleViewSection extends StatefulWidget {
  const ScheduleViewSection({super.key});

  @override
  State<ScheduleViewSection> createState() => _ScheduleViewSectionState();
}

class _ScheduleViewSectionState extends State<ScheduleViewSection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () => context.go('/dashboard'),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              size: 18,
              color: Colors.indigo,
            ),
            label: const Text(
              'العودة للوحة الرئيسية',
              style: TextStyle(
                color: Colors.indigo,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        SizedBox(height: 8.h),
        TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: Colors.indigo,
          tabs: const [
            Tab(text: 'حصة'),
            Tab(text: 'يوم دراسي'),
            Tab(text: 'الأسبوع'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [PeriodViewTab(), DayViewTab(), WeekViewTab()],
          ),
        ),
      ],
    );
  }
}

class ScheduleCreationTab extends ConsumerStatefulWidget {
  final TimetableCreationMode? mode;

  const ScheduleCreationTab({super.key, this.mode});

  @override
  ConsumerState<ScheduleCreationTab> createState() =>
      _ScheduleCreationTabState();
}

class _ScheduleCreationTabState extends ConsumerState<ScheduleCreationTab> {
  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}

/*
    if (_isQuickGenerating) {
      return;
    }
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إنشاء الجدول قبل اختيار مدرسة'),
          ),
        );
      }
      return;
    }

    setState(() {
      _isQuickGenerating = true;
    });

    try {
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);
      final classRepo = ref.read(classRepositoryProvider);
      final teachers = await teacherRepo.getTeachersForSchool(schoolId);
      final classes = await classRepo.getClasses(schoolId);

      if (teachers.isEmpty || classes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'يجب إضافة المعلمين والفصول قبل إنشاء الجدول الذكي',
              ),
            ),
          );
        }
        return;
      }

      final school = await _loadSchool(schoolId);
      if (school == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحميل بيانات المدرسة لإنشاء الجدول'),
            ),
          );
        }
        return;
      }

      final smartService = ref.read(smartScheduleServiceProvider);
      ScheduleGenerationResult result;
      try {
        result = await smartService.generateSchedule(
          teachers: teachers,
          classIds: classes.map((c) => c.id).toList(),
          school: school,
          waitingPolicy: 'tiers',
        );
      } on ScheduleGenerationImpossibleException catch (e) {
        final blocking = e.blockingTeachers;
        final buffer = StringBuffer();
        buffer.writeln(
          'تعذر إنشاء جدول كامل بسبب قيود أو نقص أوقات لبعض المعلمين:',
        );
        for (final item in blocking) {
          final id = item['teacherId'] as String? ?? '';
          final teacher = teachers.firstWhere(
            (t) => t.id == id,
            orElse: () => User(
              id: id,
              name: 'معلم غير معروف',
              email: '',
              role: UserRole.teacher,
            ),
          );
          final required = item['required'];
          final assigned = item['assigned'];
          buffer.writeln(
            '- ${teacher.name} (مطلوب: $required حصة، الممكن: $assigned حصص)',
          );
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(buffer.toString()),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final timetableId = await scheduleRepo.saveFullSchedule(
        schoolId,
        result.schedule,
      );

      final classNameById = {for (final c in classes) c.id: c.name};
      final classIdByName = {for (final c in classes) c.name: c.id};

      final Map<String, List<ScheduleSlot>> classSchedules = {};

      result.schedule.forEach((teacherId, slots) {
        for (final slot in slots) {
          if (slot.className.isEmpty) continue;

          String targetClassId;
          String resolvedName;

          if (slot.className.startsWith('Class ')) {
            targetClassId = slot.className.substring(6);
            resolvedName = classNameById[targetClassId] ?? targetClassId;
          } else {
            // Try to find ID from name
            resolvedName = slot.className;
            targetClassId = classIdByName[resolvedName] ?? resolvedName;
          }

          classSchedules.putIfAbsent(targetClassId, () => []);
          classSchedules[targetClassId]!.add(
            ScheduleSlot(
              day: slot.day,
              period: slot.period,
              className: resolvedName,
              subject: slot.subject,
              teacherId: slot.teacherId,
            ),
          );
        }
      });

      // Save class schedules using ID as the document key
      for (final entry in classSchedules.entries) {
        await scheduleRepo.saveClassSchedule(schoolId, entry.key, entry.value);
      }

      // Auto-publish schedule to ensure students can see it immediately
      await scheduleRepo.publishSchedule(schoolId);

      final durationMs = result.metrics['duration'] is int
          ? result.metrics['duration'] as int
          : 0;
      final seconds = (durationMs / 1000).toStringAsFixed(1);

      final runRepo = ref.read(scheduleRunRepositoryProvider);
      final userId = user!.id;
      final run = ScheduleRun(
        id: '',
        schoolId: schoolId,
        mode: ScheduleMode.smart_quick,
        status: ScheduleStatus.completed,
        collectUntil: null,
        waitingCoverageMode: WaitingCoverageMode.tiers,
        waitingSlotsPerPeriod: 2,
        waitingPolicy: 'tiers',
        createdBy: userId,
        createdAt: DateTime.now(),
        fairnessReport: result.fairnessReport,
        timetableId: timetableId,
        generationDurationMs: durationMs,
        teacherCountExpected: teachers.length,
        submittedCount: null,
        missingTeacherIds: null,
      );
      await runRepo.createScheduleRun(run);
      await _loadRecentSmartRuns();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء نسخة مسودة من الجدول الذكي في $seconds ثانية تقريباً.\nيمكنك مراجعتها ثم اعتمادها من شاشة إدارة الجدول.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      // لالتقاط السبب الحقيقي للمشكلة، نعرض نص الخطأ التقني بالكامل
      String message = 'حدث خطأ أثناء إنشاء الجدول الذكي:\n$e';
      if (e is FirebaseException) {
        message = 'خطأ من Firebase (${e.code}): ${e.message ?? e.toString()}';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isQuickGenerating = false;
        });
      }
    }
  }

  Future<void> _startCollaborativeSession() async {
    if (_isCollaborativeStarting) {
      return;
    }
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن بدء الجلسة بدون مدرسة')),
        );
      }
      return;
    }

    setState(() {
      _isCollaborativeStarting = true;
    });

    try {
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);
      final teachers = await teacherRepo.getTeachersForSchool(schoolId);

      final now = DateTime.now();
      final until = now.add(Duration(minutes: _collectMinutes));

      final run = ScheduleRun(
        id: '',
        schoolId: schoolId,
        mode: ScheduleMode.collaborative,
        status: ScheduleStatus.collecting,
        collectUntil: until,
        waitingCoverageMode: WaitingCoverageMode.tiers,
        waitingSlotsPerPeriod: 2,
        waitingPolicy: 'tiers',
        createdBy: user!.id,
        createdAt: now,
        fairnessReport: null,
        teacherCountExpected: teachers.length,
        submittedCount: 0,
        missingTeacherIds: teachers.map((t) => t.id).toList(),
      );

      final runRepo = ref.read(scheduleRunRepositoryProvider);
      final runId = await runRepo.createScheduleRun(run);

      setState(() {
        _activeRunId = runId;
        _collectUntil = until;
      });

      final notificationRepo = ref.read(notificationRepositoryProvider);
      final notification = NotificationRecord(
        id: const Uuid().v4(),
        userId: null,
        title: 'رغبات جدول الحصص الجديد',
        body:
            'نحن الآن في مرحلة إعداد جدول الحصص للفصل القادم. إذا كان لديك حصص لا تفضل التدريس فيها، فضلاً اضغط على هذا التنبيه وحدد الأوقات غير المناسبة لك قبل انتهاء المهلة المحددة. في حال لم تُحدث رغباتك قبل انتهاء الوقت سيُعتبر أنه لا مانع لديك من أي توزيع، وسيتم بناء الجدول آلياً مع مراعاة العدالة بين جميع الزملاء، وقد لا تتحقق بعض الطلبات الفردية حفاظاً على مصلحة المدرسة والعدالة العامة. شكراً لتفهمك وتعاونك.',
        timestamp: DateTime.now(),
        isRead: false,
        route: '/teacher-schedule-preferences/$runId',
        data: {'scheduleRunId': runId},
        schoolId: schoolId,
        targetRole: UserRole.teacher.name,
        targetClassId: null,
      );

      await notificationRepo.sendNotification(notification);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال إشعار للمعلمين لتعبئة رغبات الجدول'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء بدء الجلسة التشاركية: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCollaborativeStarting = false;
        });
      }
    }
  }

  Future<void> _generateCollaborativeSchedule() async {
    if (_isCollaborativeGenerating || _activeRunId == null) {
      return;
    }
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن إنشاء الجدول بدون مدرسة')),
        );
      }
      return;
    }

    setState(() {
      _isCollaborativeGenerating = true;
    });

    try {
      final teacherRepo = ref.read(firestoreTeacherRepositoryProvider);
      final classRepo = ref.read(classRepositoryProvider);
      final teachers = await teacherRepo.getTeachersForSchool(schoolId);
      final classes = await classRepo.getClasses(schoolId);

      if (teachers.isEmpty || classes.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'يجب وجود معلمين وفصول مسجلة قبل إنشاء الجدول التشاركي',
              ),
            ),
          );
        }
        return;
      }

      final school = await _loadSchool(schoolId);
      if (school == null) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر تحميل بيانات المدرسة لإنشاء الجدول'),
            ),
          );
        }
        return;
      }

      final runRepo = ref.read(scheduleRunRepositoryProvider);
      final existingRun = await runRepo.getScheduleRun(schoolId, _activeRunId!);

      if (existingRun != null) {
        final now = DateTime.now();
        final isBeforeDeadline =
            existingRun.collectUntil != null &&
            now.isBefore(existingRun.collectUntil!);
        if (existingRun.status == ScheduleStatus.collecting &&
            isBeforeDeadline) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'لا يمكن إنشاء الجدول التشاركي قبل انتهاء مهلة استقبال الرغبات.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
          return;
        }
      }

      final prefs = await runRepo.getAllPreferences(schoolId, _activeRunId!);
      final preferencesMap = <String, TeacherPreferenceEntity>{};
      for (final p in prefs) {
        preferencesMap[p.teacherId] = p;
      }

      final smartService = ref.read(smartScheduleServiceProvider);
      ScheduleGenerationResult result;
      try {
        result = await smartService.generateSchedule(
          teachers: teachers,
          classIds: classes.map((c) => c.id).toList(),
          school: school,
          teacherPreferences: preferencesMap,
          waitingPolicy: 'tiers',
        );
      } on ScheduleGenerationImpossibleException catch (e) {
        final blocking = e.blockingTeachers;
        final buffer = StringBuffer();
        buffer.writeln(
          'تعذر إنشاء جدول كامل بسبب قيود أو نقص أوقات لبعض المعلمين:',
        );
        for (final item in blocking) {
          final id = item['teacherId'] as String? ?? '';
          final teacher = teachers.firstWhere(
            (t) => t.id == id,
            orElse: () => User(
              id: id,
              name: 'معلم غير معروف',
              email: '',
              role: UserRole.teacher,
            ),
          );
          final required = item['required'];
          final assigned = item['assigned'];
          buffer.writeln(
            '- ${teacher.name} (مطلوب: $required حصة، الممكن: $assigned حصص)',
          );
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(buffer.toString()),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      final timetableId = await scheduleRepo.saveFullSchedule(
        schoolId,
        result.schedule,
      );

      final classNameById = {for (final c in classes) c.id: c.name};
      final Map<String, List<ScheduleSlot>> classSchedules = {};
      result.schedule.forEach((teacherId, slots) {
        for (final slot in slots) {
          if (slot.className.isEmpty) continue;
          var raw = slot.className;
          String resolvedName;
          if (raw.startsWith('Class ')) {
            final id = raw.substring(6);
            resolvedName = classNameById[id] ?? id;
          } else {
            resolvedName = raw;
          }
          classSchedules.putIfAbsent(resolvedName, () => []);
          classSchedules[resolvedName]!.add(
            ScheduleSlot(
              day: slot.day,
              period: slot.period,
              className: resolvedName,
              subject: slot.subject,
              teacherId: slot.teacherId,
            ),
          );
        }
      });
      for (final entry in classSchedules.entries) {
        await scheduleRepo.saveClassSchedule(schoolId, entry.key, entry.value);
      }

      final teacherIds = teachers.map((t) => t.id).toList();
      final submittedIds = prefs.map((p) => p.teacherId).toSet();
      final missing = teacherIds
          .where((id) => !submittedIds.contains(id))
          .toList();

      final updatedRun =
          (existingRun ??
                  ScheduleRun(
                    id: _activeRunId!,
                    schoolId: schoolId,
                    mode: ScheduleMode.collaborative,
                    status: ScheduleStatus.collecting,
                    collectUntil: _collectUntil,
                    waitingCoverageMode: WaitingCoverageMode.tiers,
                    waitingSlotsPerPeriod: 2,
                    waitingPolicy: 'tiers',
                    createdBy: user!.id,
                    createdAt: DateTime.now(),
                  ))
              .copyWith(
                status: ScheduleStatus.completed,
                fairnessReport: result.fairnessReport,
                timetableId: timetableId,
                generationDurationMs: result.metrics['duration'] is int
                    ? result.metrics['duration'] as int
                    : null,
                teacherCountExpected: teacherIds.length,
                submittedCount: prefs.length,
                missingTeacherIds: missing,
              );

      await runRepo.updateScheduleRun(updatedRun);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إنشاء جدول تشاركي مع خصم رغبات ${prefs.length} معلم من أصل ${teacherIds.length}',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء إنشاء الجدول التشاركي: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isCollaborativeGenerating = false;
        });
      }
    }
  }

  Future<void> _publishCollaborativeSchedule() async {
    if (_activeRunId == null) {
      return;
    }
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لا يمكن اعتماد الجدول بدون مدرسة')),
        );
      }
      return;
    }

    try {
      final scheduleRepo = ref.read(scheduleRepositoryProvider);
      await scheduleRepo.publishSchedule(schoolId);

      final runRepo = ref.read(scheduleRunRepositoryProvider);
      final existingRun = await runRepo.getScheduleRun(schoolId, _activeRunId!);
      if (existingRun != null) {
        await runRepo.updateScheduleRun(
          existingRun.copyWith(status: ScheduleStatus.published),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم اعتماد الجدول ونشره للمعلمين والفصول'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء اعتماد الجدول: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
*/

// ==============================================================================
// 3. Exams Module
// ==============================================================================
class ExamsModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const ExamsModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body;
    String title;
    switch (initialIndex) {
      case 1:
        title = 'إدارة لجان الاختبارات';
        body = const ExamCommitteesTab();
        break;
      case 2:
        title = 'متابعة رصد الدرجات';
        body = const GradesTrackingTab();
        break;
      case 3:
        title = 'غياب الاختبارات';
        body = const ExamAbsenceTab();
        break;
      case 0:
      default:
        title = 'جدول الاختبارات';
        body = const ExamScheduleTab();
        break;
    }
    return UnifiedPageScaffold(
      requiredDeputyType: 'academic',
      title: title,
      showAppBar: initialIndex != 2 && initialIndex != 3,
      body: body,
    );
  }
}

// ==============================================================================
// 4. Academic Analytics Module
// ==============================================================================
class AcademicAnalyticsModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const AcademicAnalyticsModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body;
    String title;
    switch (initialIndex) {
      case 1:
        title = 'كشف منخفضي التحصيل';
        body = const LowAchieversDashboardTab();
        break;
      case 2:
        title = 'مقارنة الفصول';
        body = const ClassComparisonDashboardTab();
        break;
      case 3:
        title = 'توصيات التحسين';
        body = const ImprovementRecommendationsTab();
        break;
      case 0:
      default:
        title = 'تحليل النتائج (مادة)';
        body = const SubjectAnalysisDashboardTab();
        break;
    }
    return UnifiedPageScaffold(
      requiredDeputyType: 'academic',
      title: title,
      showAppBar: false,
      body: body,
    );
  }
}

class SubjectAnalysisDashboardTab extends ConsumerStatefulWidget {
  const SubjectAnalysisDashboardTab({super.key});

  @override
  ConsumerState<SubjectAnalysisDashboardTab> createState() =>
      _SubjectAnalysisDashboardTabState();
}

class _SubjectAnalysisDashboardTabState
    extends ConsumerState<SubjectAnalysisDashboardTab> {
  bool _isComputing = false;
  String? _error;

  Future<void> _runIntelligence() async {
    if (_isComputing) return;
    setState(() {
      _isComputing = true;
      _error = null;
    });
    try {
      await ref.read(
        computeIntelligenceProvider(
          ComputeIntelligenceParams('current'),
        ).future,
      );
      if (mounted) {
        ref.invalidate(riskPredictionsProvider);
        ref.invalidate(remedialPlansProvider(null));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تحديث تحليلات النتائج بناءً على أحدث الدرجات.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '').trim().isEmpty
              ? 'تعذر تشغيل التحليل الآلي حالياً'
              : 'تعذر تشغيل التحليل الآلي: ${e.toString().replaceFirst('Exception: ', '').trim()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isComputing = false;
        });
      }
    }
  }

  Future<void> _openAddActionSheet({
    String? suggestedTitle,
    String? suggestedDescription,
    String? subjectId,
  }) async {
    final titleCtrl = TextEditingController(
      text: (suggestedTitle ?? '').trim(),
    );
    final descCtrl = TextEditingController(
      text: (suggestedDescription ?? '').trim(),
    );
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12.w,
              12.h,
              12.w,
              12.h + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'إضافة إجراء تحليلي',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade900,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'العنوان',
                          prefixIcon: const Icon(Icons.edit_note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'الوصف',
                          prefixIcon: const Icon(Icons.subject_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final t = titleCtrl.text.trim();
                          final d = descCtrl.text.trim();
                          if (t.isEmpty) return;
                          try {
                            await ref.read(
                              upsertAcademicActionProvider(
                                UpsertAcademicActionParams(
                                  type: 'subject_analysis',
                                  title: t,
                                  description: d,
                                  subjectId: subjectId,
                                ),
                              ).future,
                            );
                            if (!mounted) return;
                            ref.invalidate(
                              academicActionsProvider(
                                const AcademicActionsFilters(
                                  type: 'subject_analysis',
                                ),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة الإجراء بنجاح'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تعذر إضافة الإجراء: $e'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('حفظ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF312E81),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final predsAsync = ref.watch(riskPredictionsProvider);
    final actionsAsync = ref.watch(
      academicActionsProvider(
        const AcademicActionsFilters(type: 'subject_analysis'),
      ),
    );

    const primaryDark = Color(0xFF312E81);
    const primary = Color(0xFF6366F1);
    const bg = Color(0xFFF8FAFC);

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.insights,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تحليل النتائج حسب المادة',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'قراءة إشارات الخطر لكل مادة واقتراح إجراءات تحسين مرتبطة ببيانات المدرسة.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _HeaderBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'إجراءات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _isComputing ? null : _runIntelligence,
                            icon: const Icon(Icons.auto_awesome),
                            label: Text(
                              _isComputing
                                  ? 'جاري التحليل...'
                                  : 'تحديث التحليل',
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () => _openAddActionSheet(
                              suggestedTitle: 'إجراء تحسين بناءً على التحليل',
                              suggestedDescription:
                                  'اقتراح إجراء مرتبط بنتائج التحليل حسب المادة.',
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة إجراء'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (_error != null)
            SliverPadding(
              padding: EdgeInsets.fromLTRB(16.w, 10.h, 16.w, 0),
              sliver: SliverToBoxAdapter(
                child: glass(
                  Padding(
                    padding: EdgeInsets.all(14.w),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: SliverToBoxAdapter(
              child: predsAsync.when(
                data: (predictions) {
                  if (predictions.isEmpty) {
                    return glass(
                      Padding(
                        padding: EdgeInsets.all(18.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'لا يوجد بيانات تحليلات للمادة حالياً.',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade900,
                              ),
                            ),
                            SizedBox(height: 10.h),
                            Text(
                              'قم بتحديث التحليل بعد إدخال الدرجات أو نشر نتائج الاختبارات.',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  final bySubject = <String, List<dynamic>>{};
                  for (final p in predictions) {
                    final subjectId = (p.subjectId ?? '').toString().trim();
                    final key = subjectId.isEmpty ? 'غير محدد' : subjectId;
                    bySubject.putIfAbsent(key, () => []).add(p);
                  }

                  final totalSubjects = bySubject.length;
                  final totalStudents = predictions
                      .map((p) => (p.studentId ?? '').toString())
                      .where((s) => s.isNotEmpty)
                      .toSet()
                      .length;
                  final highRiskCount = predictions
                      .where((p) => p.riskLevel == 'RED')
                      .length;
                  final red = predictions
                      .where((p) => p.riskLevel == 'RED')
                      .length;
                  final yellow = predictions
                      .where((p) => p.riskLevel == 'YELLOW')
                      .length;
                  final green = predictions.length - red - yellow;

                  final topSubject = bySubject.entries.toList()
                    ..sort((a, b) => b.value.length.compareTo(a.value.length));
                  final focusSubject = topSubject.isEmpty
                      ? null
                      : topSubject.first.key;

                  final recommendedTitle = focusSubject == null
                      ? 'خطة تدخل عام'
                      : 'خطة تدخل لمادة $focusSubject';
                  final recommendedDesc = focusSubject == null
                      ? 'تنفيذ متابعة أسبوعية على المواد الأكثر تعرضًا للخطر.'
                      : 'تنظيم مراجعة مركزة لمادة $focusSubject وربطها بخطة علاجية للطلاب المتأثرين.';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      glass(
                        Padding(
                          padding: EdgeInsets.all(14.w),
                          child: Wrap(
                            spacing: 10.w,
                            runSpacing: 10.h,
                            children: [
                              _HeaderStatPill(
                                icon: Icons.menu_book_outlined,
                                label: 'مواد',
                                value: '$totalSubjects',
                              ),
                              _HeaderStatPill(
                                icon: Icons.group_outlined,
                                label: 'طلاب',
                                value: '$totalStudents',
                              ),
                              _HeaderStatPill(
                                icon: Icons.warning_amber_rounded,
                                label: 'تنبيهات',
                                value: '$highRiskCount',
                              ),
                              _HeaderStatPill(
                                icon: Icons.local_fire_department,
                                label: 'أحمر',
                                value: '$red',
                              ),
                              _HeaderStatPill(
                                icon: Icons.circle_outlined,
                                label: 'أصفر',
                                value: '$yellow',
                              ),
                              _HeaderStatPill(
                                icon: Icons.check_circle_outline,
                                label: 'أخضر',
                                value: '$green',
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      glass(
                        Padding(
                          padding: EdgeInsets.all(16.w),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 42.w,
                                    height: 42.w,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16.r),
                                      color: primary.withValues(alpha: 0.12),
                                    ),
                                    child: const Icon(
                                      Icons.lightbulb_outline,
                                      color: primaryDark,
                                    ),
                                  ),
                                  SizedBox(width: 12.w),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'توصية سريعة',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blueGrey.shade900,
                                          ),
                                        ),
                                        SizedBox(height: 4.h),
                                        Text(
                                          recommendedDesc,
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade700,
                                            fontWeight: FontWeight.w600,
                                            height: 1.25,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  ElevatedButton.icon(
                                    onPressed: () => _openAddActionSheet(
                                      suggestedTitle: recommendedTitle,
                                      suggestedDescription: recommendedDesc,
                                      subjectId: focusSubject,
                                    ),
                                    icon: const Icon(Icons.add),
                                    label: const Text('اعتماد'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: primaryDark,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12.w,
                                        vertical: 10.h,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                      ),
                                      elevation: 0,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'تحليل حسب المادة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey.shade900,
                            ),
                      ),
                      SizedBox(height: 10.h),
                      ...bySubject.entries.map((entry) {
                        final subjectId = entry.key;
                        final list = entry.value;
                        int r = 0;
                        int y = 0;
                        int g = 0;
                        final students = <String>{};
                        for (final p in list) {
                          students.add((p.studentId ?? '').toString());
                          if (p.riskLevel == 'RED') {
                            r++;
                          } else if (p.riskLevel == 'YELLOW') {
                            y++;
                          } else {
                            g++;
                          }
                        }
                        final total = list.length;
                        final riskScore = total == 0
                            ? 0.0
                            : (r * 3 + y * 2 + g * 1) / (total * 3) * 100;
                        final tone = riskScore >= 70
                            ? const Color(0xFFEF4444)
                            : riskScore >= 40
                            ? const Color(0xFFF59E0B)
                            : const Color(0xFF22C55E);
                        return Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: glass(
                            Padding(
                              padding: EdgeInsets.all(14.w),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 46.w,
                                        height: 46.w,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                          color: tone.withValues(alpha: 0.12),
                                        ),
                                        child: Icon(
                                          Icons.menu_book,
                                          color: tone,
                                        ),
                                      ),
                                      SizedBox(width: 12.w),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'مادة $subjectId',
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: Colors.blueGrey.shade900,
                                              ),
                                            ),
                                            SizedBox(height: 4.h),
                                            Text(
                                              'طلاب متأثرون: ${students.where((s) => s.trim().isNotEmpty).length}',
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 6.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: tone.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          border: Border.all(
                                            color: tone.withValues(alpha: 0.35),
                                          ),
                                        ),
                                        child: Text(
                                          '${riskScore.toStringAsFixed(0)}% خطر',
                                          style: TextStyle(
                                            color: tone,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 11.sp,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                          child: LinearProgressIndicator(
                                            value: (riskScore / 100.0).clamp(
                                              0.0,
                                              1.0,
                                            ),
                                            minHeight: 10.h,
                                            backgroundColor: Colors.black
                                                .withValues(alpha: 0.06),
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                                  tone,
                                                ),
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: 10.w),
                                      Text(
                                        'مرتفع: $r • متوسط: $y • منخفض: $g',
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade700,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 11.sp,
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 10.h),
                                  Align(
                                    alignment: AlignmentDirectional.centerEnd,
                                    child: OutlinedButton.icon(
                                      onPressed: () => _openAddActionSheet(
                                        suggestedTitle:
                                            'إجراء لمادة $subjectId',
                                        suggestedDescription:
                                            'متابعة مادة $subjectId وتحديد الطلاب المتأثرين وإضافة خطة علاجية.',
                                        subjectId: subjectId == 'غير محدد'
                                            ? null
                                            : subjectId,
                                      ),
                                      icon: const Icon(Icons.add),
                                      label: const Text('إضافة إجراء'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: primaryDark,
                                        side: BorderSide(
                                          color: primaryDark.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 14.w,
                                          vertical: 10.h,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16.r,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      }),
                      SizedBox(height: 6.h),
                      Text(
                        'التنبؤات التفصيلية',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey.shade900,
                            ),
                      ),
                      SizedBox(height: 10.h),
                      glass(
                        SizedBox(height: 320.h, child: const PredictionsTab()),
                      ),
                      SizedBox(height: 12.h),
                      Text(
                        'إجراءات المدرسة',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: Colors.blueGrey.shade900,
                            ),
                      ),
                      SizedBox(height: 10.h),
                      actionsAsync.when(
                        data: (actions) {
                          if (actions.isEmpty) {
                            return glass(
                              Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  'لا توجد إجراءات مسجلة لهذا القسم بعد.',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            );
                          }
                          return Column(
                            children: actions.take(6).map((a) {
                              return Padding(
                                padding: EdgeInsets.only(bottom: 10.h),
                                child: glass(
                                  Padding(
                                    padding: EdgeInsets.all(14.w),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 44.w,
                                          height: 44.w,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              16.r,
                                            ),
                                            color: primary.withValues(
                                              alpha: 0.12,
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.task_alt,
                                            color: primaryDark,
                                          ),
                                        ),
                                        SizedBox(width: 12.w),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a.title,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  color:
                                                      Colors.blueGrey.shade900,
                                                ),
                                              ),
                                              if (a.description
                                                  .trim()
                                                  .isNotEmpty) ...[
                                                SizedBox(height: 4.h),
                                                Text(
                                                  a.description,
                                                  maxLines: 2,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade700,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 10.w,
                                            vertical: 6.h,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.black.withValues(
                                              alpha: 0.06,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              999,
                                            ),
                                          ),
                                          child: Text(
                                            a.status == 'done'
                                                ? 'مغلق'
                                                : 'مفتوح',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.blueGrey.shade900,
                                              fontSize: 11.sp,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          );
                        },
                        loading: () => glass(
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: const LinearProgressIndicator(),
                          ),
                        ),
                        error: (e, _) => glass(
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              'تعذر تحميل الإجراءات: $e',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'جاري تحميل التحليل...',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Container(
                      height: 220.h,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Container(
                      height: 220.h,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22.r),
                      ),
                    ),
                  ],
                ),
                error: (e, _) => UnifiedEmptyState(
                  message: 'تعذر تحميل تحليلات المادة: $e',
                  onRetry: () => ref.invalidate(riskPredictionsProvider),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LowAchieversDashboardTab extends ConsumerStatefulWidget {
  const LowAchieversDashboardTab({super.key});

  @override
  ConsumerState<LowAchieversDashboardTab> createState() =>
      _LowAchieversDashboardTabState();
}

class _LowAchieversDashboardTabState
    extends ConsumerState<LowAchieversDashboardTab> {
  bool _isLoading = false;
  List<User> _students = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final all = await ref.read(studentsProvider.future);
      if (mounted) {
        setState(() {
          _students = all.where((s) => s.role == UserRole.student).toList();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddActionSheet({
    required String title,
    required String description,
  }) async {
    final titleCtrl = TextEditingController(text: title.trim());
    final descCtrl = TextEditingController(text: description.trim());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12.w,
              12.h,
              12.w,
              12.h + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'إضافة إجراء علاجي',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade900,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'العنوان',
                          prefixIcon: const Icon(Icons.edit_note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'الوصف',
                          prefixIcon: const Icon(Icons.subject_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final t = titleCtrl.text.trim();
                          final d = descCtrl.text.trim();
                          if (t.isEmpty) return;
                          try {
                            await ref.read(
                              upsertAcademicActionProvider(
                                UpsertAcademicActionParams(
                                  type: 'low_achievers',
                                  title: t,
                                  description: d,
                                ),
                              ).future,
                            );
                            if (!mounted) return;
                            ref.invalidate(
                              academicActionsProvider(
                                const AcademicActionsFilters(
                                  type: 'low_achievers',
                                ),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة الإجراء بنجاح'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تعذر إضافة الإجراء: $e'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('حفظ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF9F1239),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF9F1239);
    const primary = Color(0xFFFB7185);
    const bg = Color(0xFFF8FAFC);

    final actionsAsync = ref.watch(
      academicActionsProvider(
        const AcademicActionsFilters(type: 'low_achievers'),
      ),
    );

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Text(
          'جاري تحميل بيانات الطلاب...',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey.shade700,
          ),
        ),
      );
    }

    if (_students.isEmpty) {
      return glass(
        Padding(
          padding: EdgeInsets.all(18.w),
          child: Text(
            'لا يوجد طلاب لعرض إحصاءات التحصيل.',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey.shade900,
            ),
          ),
        ),
      );
    }

    final scores = _students.map((s) => s.excellenceScore).toList()..sort();
    final total = scores.length;
    final low = scores.where((s) => s < 60).length;
    final avg = total == 0 ? 0.0 : scores.reduce((a, b) => a + b) / total;
    final minScore = scores.isEmpty ? 0.0 : scores.first;
    final maxScore = scores.isEmpty ? 0.0 : scores.last;
    final lowRate = total == 0 ? 0.0 : (low / total) * 100.0;

    final buckets = <String, _LevelBucket>{
      'ممتاز': _LevelBucket('ممتاز', 90, 100, const Color(0xFF22C55E)),
      'جيد جداً': _LevelBucket('جيد جداً', 80, 89, const Color(0xFF3B82F6)),
      'جيد': _LevelBucket('جيد', 70, 79, const Color(0xFF38BDF8)),
      'مقبول': _LevelBucket('مقبول', 60, 69, const Color(0xFFF59E0B)),
      'ضعيف': _LevelBucket('ضعيف', 0, 59, const Color(0xFFEF4444)),
    };
    for (final s in scores) {
      for (final b in buckets.values) {
        if (s >= b.min && s <= b.max) {
          b.count++;
          break;
        }
      }
    }

    final recommendationTitle = lowRate >= 30
        ? 'تدخل عاجل'
        : lowRate >= 15
        ? 'تدخل موجه'
        : 'متابعة دورية';
    final recommendationText = lowRate >= 30
        ? 'نسبة منخفضي التحصيل مرتفعة. نفّذ خطة علاجية أسبوعية مع متابعة حضور ودعم مهاري.'
        : lowRate >= 15
        ? 'حدد الطلاب الأقل أداءً لكل شعبة وربطهم بخطة علاجية قصيرة المدى.'
        : 'الوضع مطمئن. حافظ على متابعة دورية وتحديد حالات فردية فقط.';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.sentiment_dissatisfied,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'منخفضو التحصيل',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'تحليل مستوى التحصيل وتحديد الطلاب الذين يحتاجون إلى تدخل علاجي.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  _HeaderStatPill(
                                    icon: Icons.group_outlined,
                                    label: 'الطلاب',
                                    value: '$total',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.warning_amber_rounded,
                                    label: 'منخفض',
                                    value: '$low',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.percent,
                                    label: 'النسبة',
                                    value: '${lowRate.toStringAsFixed(0)}%',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.trending_up,
                                    label: 'المتوسط',
                                    value: avg.toStringAsFixed(1),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _HeaderBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'إجراءات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryDark,
                              side: BorderSide(
                                color: primaryDark.withValues(alpha: 0.35),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () => _openAddActionSheet(
                              title: '$recommendationTitle لتحسين التحصيل',
                              description: recommendationText,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة إجراء'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const RemedialPlansModuleScreen(),
                                ),
                              );
                            },
                            icon: const Icon(Icons.playlist_add_check),
                            label: const Text('الخطط العلاجية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  glass(
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46.w,
                            height: 46.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18.r),
                              color: primary.withValues(alpha: 0.12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: primaryDark,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'توصية',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  recommendationText,
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'الحد الأدنى: ${minScore.toStringAsFixed(1)} • الأعلى: ${maxScore.toStringAsFixed(1)}',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'توزيع المستويات',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  glass(
                    Padding(
                      padding: EdgeInsets.all(14.w),
                      child: Column(
                        children: buckets.values.map((b) {
                          final percent = total == 0
                              ? 0.0
                              : (b.count / total * 100).toDouble();
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 5.h),
                            child: Row(
                              children: [
                                SizedBox(
                                  width: 84.w,
                                  child: Text(
                                    b.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.blueGrey.shade900,
                                      fontSize: 12.sp,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(999.r),
                                    child: LinearProgressIndicator(
                                      value: (percent / 100).clamp(0.0, 1.0),
                                      minHeight: 10.h,
                                      backgroundColor: Colors.black.withValues(
                                        alpha: 0.06,
                                      ),
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        b.color,
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 10.w),
                                SizedBox(
                                  width: 58.w,
                                  child: Text(
                                    '${percent.toStringAsFixed(0)}%',
                                    textAlign: TextAlign.end,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      color: b.color,
                                      fontSize: 11.sp,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'قائمة الحالات ذات الأولوية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  glass(
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Column(
                        children: _students
                            .where((s) => s.excellenceScore < 60)
                            .toList()
                            .take(12)
                            .map((s) {
                              return ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: CircleAvatar(
                                  backgroundColor: const Color(
                                    0xFFEF4444,
                                  ).withValues(alpha: 0.12),
                                  child: Text(
                                    s.name.isEmpty
                                        ? '?'
                                        : s.name.characters.first,
                                    style: const TextStyle(
                                      color: Color(0xFFEF4444),
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                title: Text(
                                  s.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                subtitle: Text(
                                  'مؤشر التحصيل: ${s.excellenceScore.toStringAsFixed(1)}',
                                ),
                                trailing: const Icon(Icons.priority_high),
                              );
                            })
                            .toList(),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'إجراءات المدرسة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  actionsAsync.when(
                    data: (actions) {
                      if (actions.isEmpty) {
                        return glass(
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              'لا توجد إجراءات مسجلة لهذا القسم بعد.',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: actions.take(6).map((a) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: glass(
                              Padding(
                                padding: EdgeInsets.all(14.w),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44.w,
                                      height: 44.w,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        color: primary.withValues(alpha: 0.12),
                                      ),
                                      child: const Icon(
                                        Icons.task_alt,
                                        color: primaryDark,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.blueGrey.shade900,
                                            ),
                                          ),
                                          if (a.description
                                              .trim()
                                              .isNotEmpty) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              a.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => glass(
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: const LinearProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => glass(
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          'تعذر تحميل الإجراءات: $e',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ClassComparisonDashboardTab extends ConsumerStatefulWidget {
  const ClassComparisonDashboardTab({super.key});

  @override
  ConsumerState<ClassComparisonDashboardTab> createState() =>
      _ClassComparisonDashboardTabState();
}

class _ClassComparisonDashboardTabState
    extends ConsumerState<ClassComparisonDashboardTab> {
  bool _isLoading = false;
  List<_ClassSuccessInfo> _items = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final classes = await ref.read(classesProvider.future);
      final students = await ref.read(studentsProvider.future);

      final items = <_ClassSuccessInfo>[];
      for (final c in classes) {
        final classStudents = students
            .where((s) => c.studentIds.contains(s.id))
            .toList();
        if (classStudents.isEmpty) continue;

        final scores = classStudents
            .map((s) => s.excellenceScore.toDouble())
            .toList();
        final avgScore = scores.isEmpty
            ? 0.0
            : scores.reduce((a, b) => a + b) / scores.length;
        final goodCount = classStudents
            .where((s) => s.excellenceScore >= 80)
            .length;
        final riskCount = classStudents
            .where((s) => s.excellenceScore < 60)
            .length;

        items.add(
          _ClassSuccessInfo(
            classId: c.id,
            className: c.name,
            totalStudents: classStudents.length,
            avgScore: avgScore,
            goodCount: goodCount,
            riskCount: riskCount,
          ),
        );
      }

      items.sort((a, b) => b.avgScore.compareTo(a.avgScore));

      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openAddActionSheet({
    required String title,
    required String description,
    String? classId,
  }) async {
    final titleCtrl = TextEditingController(text: title.trim());
    final descCtrl = TextEditingController(text: description.trim());
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              12.w,
              12.h,
              12.w,
              12.h + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22.r),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(22.r),
                    border: Border.all(
                      color: Colors.black.withValues(alpha: 0.06),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'إضافة إجراء للفصول',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade900,
                                fontSize: 14.sp,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: titleCtrl,
                        decoration: InputDecoration(
                          labelText: 'العنوان',
                          prefixIcon: const Icon(Icons.edit_note),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      TextField(
                        controller: descCtrl,
                        minLines: 2,
                        maxLines: 4,
                        decoration: InputDecoration(
                          labelText: 'الوصف',
                          prefixIcon: const Icon(Icons.subject_outlined),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final t = titleCtrl.text.trim();
                          final d = descCtrl.text.trim();
                          if (t.isEmpty) return;
                          try {
                            await ref.read(
                              upsertAcademicActionProvider(
                                UpsertAcademicActionParams(
                                  type: 'class_comparison',
                                  title: t,
                                  description: d,
                                  classId: classId,
                                ),
                              ).future,
                            );
                            if (!mounted) return;
                            ref.invalidate(
                              academicActionsProvider(
                                const AcademicActionsFilters(
                                  type: 'class_comparison',
                                ),
                              ),
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تمت إضافة الإجراء بنجاح'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            Navigator.pop(context);
                          } catch (e) {
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('تعذر إضافة الإجراء: $e'),
                                behavior: SnackBarBehavior.floating,
                                backgroundColor: Colors.red,
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add),
                        label: const Text('حفظ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF065F46),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    titleCtrl.dispose();
    descCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF065F46);
    const primary = Color(0xFF10B981);
    const bg = Color(0xFFF8FAFC);

    final actionsAsync = ref.watch(
      academicActionsProvider(
        const AcademicActionsFilters(type: 'class_comparison'),
      ),
    );

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    if (_isLoading) {
      return Center(
        child: Text(
          'جاري تحميل بيانات الفصول...',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey.shade700,
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return glass(
        Padding(
          padding: EdgeInsets.all(18.w),
          child: Text(
            'لا يوجد بيانات لمقارنة الفصول حالياً.',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: Colors.blueGrey.shade900,
            ),
          ),
        ),
      );
    }

    final totalClasses = _items.length;
    final best = _items.first;
    final worst = _items.last;
    final overallAvg =
        _items.map((e) => e.avgScore).reduce((a, b) => a + b) / _items.length;
    final gap = (best.avgScore - worst.avgScore).abs();
    final needingSupportCount = _items
        .where(
          (c) => c.totalStudents == 0
              ? false
              : (c.riskCount / c.totalStudents) >= 0.25,
        )
        .length;

    final recommendationTitle = gap >= 15
        ? 'تقليص فجوة التحصيل'
        : gap >= 8
        ? 'تعزيز العدالة الصفية'
        : 'استدامة الجودة';
    final recommendationText = gap >= 15
        ? 'الفجوة بين أعلى وأقل فصل مرتفعة. ابدأ بدعم الفصل الأضعف بممارسات الفصل الأفضل وتكثيف المتابعة.'
        : gap >= 8
        ? 'يوصى بتبادل خبرات بين الفصول وتوحيد أدوات التقويم وتقارير المتابعة.'
        : 'الفجوة محدودة. حافظ على استراتيجيات التعلم النشط والمتابعة الدورية.';

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.compare_arrows,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مقارنة الفصول',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'مؤشرات مقارنة أداء الفصول لتحديد الفجوات وفرص التحسين.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  _HeaderStatPill(
                                    icon: Icons.class_outlined,
                                    label: 'الفصول',
                                    value: '$totalClasses',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.trending_up,
                                    label: 'المتوسط',
                                    value: overallAvg.toStringAsFixed(1),
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.swap_vert,
                                    label: 'الفجوة',
                                    value: gap.toStringAsFixed(1),
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.support,
                                    label: 'بحاجة دعم',
                                    value: '$needingSupportCount',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _HeaderBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'إجراءات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryDark,
                              side: BorderSide(
                                color: primaryDark.withValues(alpha: 0.35),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () => _openAddActionSheet(
                              title:
                                  '$recommendationTitle - ${worst.className}',
                              description:
                                  'تطبيق تدخل لتحسين فصل ${worst.className} بناءً على مقارنة الفصول. $recommendationText',
                              classId: worst.classId,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة إجراء'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  glass(
                    Padding(
                      padding: EdgeInsets.all(16.w),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 46.w,
                            height: 46.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18.r),
                              color: primary.withValues(alpha: 0.12),
                            ),
                            child: const Icon(
                              Icons.lightbulb_outline,
                              color: primaryDark,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'توصية',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                                SizedBox(height: 6.h),
                                Text(
                                  recommendationText,
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade700,
                                    fontWeight: FontWeight.w600,
                                    height: 1.25,
                                  ),
                                ),
                                SizedBox(height: 10.h),
                                Text(
                                  'الأفضل: ${best.className} (${best.avgScore.toStringAsFixed(1)}) • الأضعف: ${worst.className} (${worst.avgScore.toStringAsFixed(1)})',
                                  style: TextStyle(
                                    color: Colors.blueGrey.shade800,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'أفضل الفصول',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ..._items
                      .take(3)
                      .map(
                        (c) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: glass(
                            Padding(
                              padding: EdgeInsets.all(14.w),
                              child: _ClassComparisonTile(
                                info: c,
                                color: const Color(0xFF22C55E),
                              ),
                            ),
                          ),
                        ),
                      ),
                  SizedBox(height: 6.h),
                  Text(
                    'فصول بحاجة دعم',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ..._items.reversed
                      .take(3)
                      .map(
                        (c) => Padding(
                          padding: EdgeInsets.only(bottom: 10.h),
                          child: glass(
                            Padding(
                              padding: EdgeInsets.all(14.w),
                              child: _ClassComparisonTile(
                                info: c,
                                color: const Color(0xFFF59E0B),
                              ),
                            ),
                          ),
                        ),
                      ),
                  SizedBox(height: 12.h),
                  Text(
                    'إجراءات المدرسة',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  actionsAsync.when(
                    data: (actions) {
                      if (actions.isEmpty) {
                        return glass(
                          Padding(
                            padding: EdgeInsets.all(16.w),
                            child: Text(
                              'لا توجد إجراءات مسجلة لهذا القسم بعد.',
                              style: TextStyle(
                                color: Colors.blueGrey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        );
                      }
                      return Column(
                        children: actions.take(6).map((a) {
                          return Padding(
                            padding: EdgeInsets.only(bottom: 10.h),
                            child: glass(
                              Padding(
                                padding: EdgeInsets.all(14.w),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44.w,
                                      height: 44.w,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(
                                          16.r,
                                        ),
                                        color: primary.withValues(alpha: 0.12),
                                      ),
                                      child: const Icon(
                                        Icons.task_alt,
                                        color: primaryDark,
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            a.title,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              color: Colors.blueGrey.shade900,
                                            ),
                                          ),
                                          if (a.description
                                              .trim()
                                              .isNotEmpty) ...[
                                            SizedBox(height: 4.h),
                                            Text(
                                              a.description,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade700,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => glass(
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: const LinearProgressIndicator(),
                      ),
                    ),
                    error: (e, _) => glass(
                      Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Text(
                          'تعذر تحميل الإجراءات: $e',
                          style: TextStyle(
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassComparisonTile extends StatelessWidget {
  final _ClassSuccessInfo info;
  final Color color;

  const _ClassComparisonTile({required this.info, required this.color});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        child: Icon(Icons.class_, color: color),
      ),
      title: Text(
        info.className,
        style: const TextStyle(fontWeight: FontWeight.w900),
      ),
      subtitle: Text(
        'طلاب: ${info.totalStudents} • متوسط: ${info.avgScore.toStringAsFixed(1)}',
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'متميزون: ${info.goodCount}',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF22C55E),
            ),
          ),
          Text(
            'بحاجة دعم: ${info.riskCount}',
            style: TextStyle(
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFEF4444),
            ),
          ),
        ],
      ),
    );
  }
}

class ImprovementRecommendationsTab extends ConsumerWidget {
  const ImprovementRecommendationsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final predsAsync = ref.watch(riskPredictionsProvider);
    final plansAsync = ref.watch(remedialPlansProvider(null));
    final actionsAsync = ref.watch(
      academicActionsProvider(
        const AcademicActionsFilters(type: 'recommendations'),
      ),
    );

    const primaryDark = Color(0xFF92400E);
    const primary = Color(0xFFF59E0B);
    const bg = Color(0xFFF8FAFC);

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    Future<void> openAddActionSheet({
      required String title,
      required String description,
    }) async {
      final titleCtrl = TextEditingController(text: title.trim());
      final descCtrl = TextEditingController(text: description.trim());
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) {
          return SafeArea(
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                12.w,
                12.h,
                12.w,
                12.h + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22.r),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: EdgeInsets.all(16.w),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.82),
                      borderRadius: BorderRadius.circular(22.r),
                      border: Border.all(
                        color: Colors.black.withValues(alpha: 0.06),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'إضافة إجراء تحسين',
                                style: TextStyle(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blueGrey.shade900,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () => Navigator.pop(context),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        ),
                        SizedBox(height: 10.h),
                        TextField(
                          controller: titleCtrl,
                          decoration: InputDecoration(
                            labelText: 'العنوان',
                            prefixIcon: const Icon(Icons.edit_note),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        TextField(
                          controller: descCtrl,
                          minLines: 2,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'الوصف',
                            prefixIcon: const Icon(Icons.subject_outlined),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final t = titleCtrl.text.trim();
                            final d = descCtrl.text.trim();
                            if (t.isEmpty) return;
                            try {
                              await ref.read(
                                upsertAcademicActionProvider(
                                  UpsertAcademicActionParams(
                                    type: 'recommendations',
                                    title: t,
                                    description: d,
                                  ),
                                ).future,
                              );
                              ref.invalidate(
                                academicActionsProvider(
                                  const AcademicActionsFilters(
                                    type: 'recommendations',
                                  ),
                                ),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تمت إضافة الإجراء بنجاح'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              Navigator.pop(context);
                            } catch (e) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('تعذر إضافة الإجراء: $e'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('حفظ'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryDark,
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(vertical: 12.h),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.r),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      );
      titleCtrl.dispose();
      descCtrl.dispose();
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.lightbulb_outline,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'توصيات التحسين',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'توصيات قابلة للتنفيذ بناءً على تحليلات المدرسة والخطط العلاجية الحالية.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _HeaderBackButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'إجراءات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          ElevatedButton.icon(
                            onPressed: () async {
                              await ref.read(
                                computeIntelligenceProvider(
                                  ComputeIntelligenceParams('current'),
                                ).future,
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'تم تحديث التوصيات بناءً على أحدث تحليلات المدرسة.',
                                  ),
                                ),
                              );
                              ref.invalidate(riskPredictionsProvider);
                            },
                            icon: const Icon(Icons.auto_awesome),
                            label: const Text('تحديث'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () => openAddActionSheet(
                              title: 'إجراء تحسين',
                              description:
                                  'إضافة إجراء تحسين مرتبط بالتوصيات الحالية.',
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة إجراء'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: SliverToBoxAdapter(
              child: predsAsync.when(
                data: (predictions) {
                  return plansAsync.when(
                    data: (plans) {
                      final recommendations = _buildRecommendations(
                        predictions,
                        plans,
                      );

                      final coveredStudents = <String>{};
                      for (final plan in plans) {
                        coveredStudents.addAll(plan.studentIds);
                      }
                      final riskStudents = predictions
                          .map((p) => (p.studentId ?? '').toString())
                          .where((s) => s.isNotEmpty)
                          .toSet();
                      final uncovered = riskStudents.difference(
                        coveredStudents,
                      );
                      final redCount = predictions
                          .where((p) => p.riskLevel == 'RED')
                          .length;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          glass(
                            Padding(
                              padding: EdgeInsets.all(14.w),
                              child: Wrap(
                                spacing: 10.w,
                                runSpacing: 10.h,
                                children: [
                                  _HeaderStatPill(
                                    icon: Icons.lightbulb_outline,
                                    label: 'التوصيات',
                                    value: '${recommendations.length}',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.warning_amber_rounded,
                                    label: 'أحمر',
                                    value: '$redCount',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.group_outlined,
                                    label: 'طلاب خطر',
                                    value: '${riskStudents.length}',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.playlist_add_check,
                                    label: 'مغطّى',
                                    value: '${coveredStudents.length}',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.person_add_alt_1,
                                    label: 'غير مغطّى',
                                    value: '${uncovered.length}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          if (recommendations.isEmpty)
                            glass(
                              Padding(
                                padding: EdgeInsets.all(18.w),
                                child: Text(
                                  'لا توجد توصيات محددة حالياً. البيانات مستقرة.',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900,
                                    color: Colors.blueGrey.shade900,
                                  ),
                                ),
                              ),
                            )
                          else
                            Column(
                              children: recommendations.map((r) {
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 10.h),
                                  child: glass(
                                    Padding(
                                      padding: EdgeInsets.all(14.w),
                                      child: Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Container(
                                            width: 46.w,
                                            height: 46.w,
                                            decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(16.r),
                                              color: r.color.withValues(
                                                alpha: 0.12,
                                              ),
                                            ),
                                            child: Icon(r.icon, color: r.color),
                                          ),
                                          SizedBox(width: 12.w),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  r.title,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: Colors
                                                        .blueGrey
                                                        .shade900,
                                                  ),
                                                ),
                                                SizedBox(height: 6.h),
                                                Text(
                                                  r.description,
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade700,
                                                    fontWeight: FontWeight.w600,
                                                    height: 1.25,
                                                  ),
                                                ),
                                                SizedBox(height: 10.h),
                                                Align(
                                                  alignment:
                                                      AlignmentDirectional
                                                          .centerEnd,
                                                  child: OutlinedButton.icon(
                                                    onPressed: () =>
                                                        openAddActionSheet(
                                                          title: r.title,
                                                          description:
                                                              r.description,
                                                        ),
                                                    icon: const Icon(Icons.add),
                                                    label: const Text(
                                                      'اعتماد كإجراء',
                                                    ),
                                                    style: OutlinedButton.styleFrom(
                                                      foregroundColor:
                                                          primaryDark,
                                                      side: BorderSide(
                                                        color: primaryDark
                                                            .withValues(
                                                              alpha: 0.35,
                                                            ),
                                                      ),
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 14.w,
                                                            vertical: 10.h,
                                                          ),
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              16.r,
                                                            ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          SizedBox(height: 12.h),
                          Text(
                            'إجراءات المدرسة',
                            style: Theme.of(context).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: Colors.blueGrey.shade900,
                                ),
                          ),
                          SizedBox(height: 10.h),
                          actionsAsync.when(
                            data: (actions) {
                              if (actions.isEmpty) {
                                return glass(
                                  Padding(
                                    padding: EdgeInsets.all(16.w),
                                    child: Text(
                                      'لا توجد إجراءات مسجلة لهذا القسم بعد.',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                );
                              }
                              return Column(
                                children: actions.take(6).map((a) {
                                  return Padding(
                                    padding: EdgeInsets.only(bottom: 10.h),
                                    child: glass(
                                      Padding(
                                        padding: EdgeInsets.all(14.w),
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 44.w,
                                              height: 44.w,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(16.r),
                                                color: primary.withValues(
                                                  alpha: 0.12,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.task_alt,
                                                color: primaryDark,
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    a.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w900,
                                                      color: Colors
                                                          .blueGrey
                                                          .shade900,
                                                    ),
                                                  ),
                                                  if (a.description
                                                      .trim()
                                                      .isNotEmpty) ...[
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      a.description,
                                                      maxLines: 2,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: TextStyle(
                                                        color: Colors
                                                            .blueGrey
                                                            .shade700,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  );
                                }).toList(),
                              );
                            },
                            loading: () => glass(
                              Padding(
                                padding: EdgeInsets.all(16.w),
                                child: const LinearProgressIndicator(),
                              ),
                            ),
                            error: (e, _) => glass(
                              Padding(
                                padding: EdgeInsets.all(16.w),
                                child: Text(
                                  'تعذر تحميل الإجراءات: $e',
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, _) =>
                        UnifiedEmptyState(message: 'خطأ في تحميل الخطط: $e'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    UnifiedEmptyState(message: 'خطأ في تحميل التنبؤات: $e'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_RecommendationItem> _buildRecommendations(
    List<dynamic> predictions,
    List<RemedialPlan> plans,
  ) {
    final items = <_RecommendationItem>[];

    final bySubject = <String, int>{};
    final byStudentRisk = <String, int>{};

    for (final p in predictions) {
      final subject = p.subjectId ?? 'غير محدد';
      bySubject[subject] = (bySubject[subject] ?? 0) + 1;
      if (p.riskLevel == 'RED') {
        byStudentRisk[p.studentId] = (byStudentRisk[p.studentId] ?? 0) + 1;
      }
    }

    if (bySubject.isNotEmpty) {
      final sortedSubjects = bySubject.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sortedSubjects.first;
      items.add(
        _RecommendationItem(
          icon: Icons.menu_book,
          color: Colors.indigo,
          title: 'تركيز على مادة ${top.key}',
          description:
              'ظهرت أعلى إشارات خطر في مادة ${top.key} بعدد ${top.value} تنبيهات. يفضل مراجعة خطة التدريس والتقويم.',
        ),
      );
    }

    if (byStudentRisk.isNotEmpty) {
      final sortedStudents = byStudentRisk.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final top = sortedStudents.first;
      items.add(
        _RecommendationItem(
          icon: Icons.person_search,
          color: Colors.red.shade700,
          title: 'متابعة مركزة لعدد محدود من الطلاب',
          description:
              'يوجد طلاب لديهم أكثر من تنبيه خطر (أعلى رقم: ${top.value}). يوصى بفتح خطة علاجية فردية ومتابعة أسبوعية.',
        ),
      );
    }

    final coveredStudents = <String>{};
    for (final plan in plans) {
      coveredStudents.addAll(plan.studentIds);
    }

    final riskStudents = predictions.map((p) => p.studentId).toSet();
    final uncovered = riskStudents.difference(coveredStudents);

    if (uncovered.isNotEmpty) {
      items.add(
        _RecommendationItem(
          icon: Icons.medical_services,
          color: Colors.teal,
          title: 'توسيع نطاق الخطط العلاجية',
          description:
              'هناك ${uncovered.length} طلاب معرضين للخطر بدون خطة علاجية. يفضّل إنشاء خطط جديدة أو ربطهم بمعلمين داعمين.',
        ),
      );
    }

    if (items.isEmpty) {
      items.add(
        _RecommendationItem(
          icon: Icons.check_circle,
          color: Colors.green,
          title: 'الوضع مستقر',
          description:
              'لا توجد مؤشرات خطر مرتفعة حالياً. استمر في المتابعة بنفس الأسلوب.',
        ),
      );
    }

    return items;
  }
}

class _RecommendationItem {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  _RecommendationItem({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}

class _LevelBucket {
  final String label;
  final double min;
  final double max;
  final Color color;
  int count;

  _LevelBucket(this.label, this.min, this.max, this.color) : count = 0;
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11.sp)),
      ],
    );
  }
}

// ==============================================================================
// 5. Remedial Plans Module
// ==============================================================================
class RemedialPlansModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const RemedialPlansModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget innerContent;
    String title;
    String description;

    switch (initialIndex) {
      case 1:
        title = 'ربط الطالب بالمعلم';
        description =
            'اختيار الطالب والمعلم المناسب بناءً على التنبيهات والتحليل الذكي لبدء خطة علاجية مركزة.';
        innerContent = const LinkStudentTeacherTab();
        break;
      case 2:
        title = 'متابعة تنفيذ الخطط';
        description =
            'لوحة لمتابعة تقدم الخطط العلاجية وحالتها الحالية وتحديث مستوى الإنجاز لكل خطة.';
        innerContent = const RemedialPlansFollowupTab();
        break;
      case 3:
        title = 'قياس التحسن والأثر';
        description =
            'مؤشرات لقياس التحسن العام في أداء الطلاب المستهدفين بالخطط العلاجية.';
        innerContent = const MeasureImprovementTab();
        break;
      case 0:
      default:
        title = 'إنشاء خطة علاجية جديدة';
        description =
            'تجميع بيانات الطالب وأسباب الضعف، ثم اقتراح استراتيجية علاجية وخطة متابعة.';
        innerContent = const CreateRemedialPlanTab();
        break;
    }

    return UnifiedPageScaffold(
      requiredDeputyType: 'academic',
      title: 'الخطط العلاجية',
      showAppBar: false,
      body: SafeArea(
        child: Container(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.all(20.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20.r),
                  gradient: LinearGradient(
                    colors: [Colors.teal.shade700, Colors.teal.shade400],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.teal.withValues(alpha: 0.25),
                      blurRadius: 12.r,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: Card(
                  margin: EdgeInsets.zero,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(12.w),
                    child: innerContent,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CreateRemedialPlanTab extends ConsumerStatefulWidget {
  const CreateRemedialPlanTab({super.key});

  @override
  ConsumerState<CreateRemedialPlanTab> createState() =>
      _CreateRemedialPlanTabState();
}

class _CreateRemedialPlanTabState extends ConsumerState<CreateRemedialPlanTab> {
  User? _selectedStudent;
  User? _selectedTeacher;
  String _causeType = '';
  String _strategy = '';
  double _targetImprovement = 20;
  bool _isSaving = false;

  Future<void> _savePlan() async {
    if (_selectedStudent == null || _selectedTeacher == null) return;
    setState(() {
      _isSaving = true;
    });
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن إنشاء الخطة بدون ربط المستخدم بمدرسة.'),
          ),
        );
        return;
      }
      final repo = ref.read(schoolIntelligenceRepositoryProvider);
      final baseline = {'excellenceScore': _selectedStudent!.excellenceScore};
      final target = {'expectedIncrease': _targetImprovement};
      await repo.createRemedialPlan(schoolId, {
        'studentIds': [_selectedStudent!.id],
        'causeType': _causeType.isEmpty ? 'ضعف تحصيلي' : _causeType,
        'strategy': _strategy.isEmpty ? 'خطة دعم فردية قصيرة المدى' : _strategy,
        'teacherId': _selectedTeacher!.id,
        'baselineMetrics': baseline,
        'targetMetrics': target,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إنشاء الخطة العلاجية بنجاح.')),
      );
      setState(() {
        _causeType = '';
        _strategy = '';
        _targetImprovement = 20;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final teachersAsync = ref.watch(mock_teachers.teachersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'اختيار الطالب والمعلم',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: studentsAsync.when(
                data: (students) {
                  return DropdownButtonFormField<User>(
                    value: _selectedStudent,
                    decoration: const InputDecoration(
                      labelText: 'الطالب المستهدف',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: students
                        .where((s) => s.role == UserRole.student)
                        .map(
                          (s) =>
                              DropdownMenuItem(value: s, child: Text(s.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedStudent = v;
                      });
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Text('تعذر تحميل قائمة الطلاب حالياً'),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: teachersAsync.when(
                data: (teachers) {
                  return DropdownButtonFormField<User>(
                    value: _selectedTeacher,
                    decoration: const InputDecoration(
                      labelText: 'المعلم المسؤول',
                      border: OutlineInputBorder(),
                    ),
                    isExpanded: true,
                    items: teachers
                        .where((t) => t.role == UserRole.teacher)
                        .map(
                          (t) =>
                              DropdownMenuItem(value: t, child: Text(t.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      setState(() {
                        _selectedTeacher = v;
                      });
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) =>
                    const Text('تعذر تحميل قائمة المعلمين حالياً'),
              ),
            ),
          ],
        ),
        SizedBox(height: 16.h),
        Text(
          'سبب الضعف والاستراتيجية',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        TextField(
          decoration: const InputDecoration(
            labelText: 'نوع السبب (مثال: ضعف في المهارات الأساسية)',
            border: OutlineInputBorder(),
          ),
          onChanged: (v) {
            setState(() {
              _causeType = v;
            });
          },
        ),
        SizedBox(height: 8.h),
        TextField(
          decoration: const InputDecoration(
            labelText: 'ملخص الاستراتيجية العلاجية المقترحة',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          onChanged: (v) {
            setState(() {
              _strategy = v;
            });
          },
        ),
        SizedBox(height: 16.h),
        Text(
          'التحسن المستهدف في المؤشر',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: _targetImprovement,
                min: 5,
                max: 40,
                divisions: 7,
                label: '${_targetImprovement.toStringAsFixed(0)} نقطة',
                onChanged: (v) {
                  setState(() {
                    _targetImprovement = v;
                  });
                },
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '${_targetImprovement.toStringAsFixed(0)} نقطة',
              style: TextStyle(fontSize: 14.sp),
            ),
          ],
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isSaving ? null : _savePlan,
            icon: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check),
            label: const Text('حفظ الخطة العلاجية'),
          ),
        ),
      ],
    );
  }
}

class LinkStudentTeacherTab extends ConsumerStatefulWidget {
  const LinkStudentTeacherTab({super.key});

  @override
  ConsumerState<LinkStudentTeacherTab> createState() =>
      _LinkStudentTeacherTabState();
}

class _LinkStudentTeacherTabState extends ConsumerState<LinkStudentTeacherTab> {
  User? _selectedStudent;
  User? _selectedTeacher;
  bool _isLinking = false;

  Future<void> _link() async {
    if (_selectedStudent == null || _selectedTeacher == null) return;
    setState(() {
      _isLinking = true;
    });
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId ?? '';
      if (schoolId.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('لا يمكن الحفظ بدون ربط المستخدم بمدرسة.'),
          ),
        );
        return;
      }
      final repo = ref.read(schoolIntelligenceRepositoryProvider);
      await repo.createRemedialPlan(schoolId, {
        'studentIds': [_selectedStudent!.id],
        'causeType': 'ربط طالب بمعلم داعم',
        'strategy': 'جلسات دعم فردية أسبوعية مع المعلم المختار.',
        'teacherId': _selectedTeacher!.id,
        'baselineMetrics': {
          'excellenceScore': _selectedStudent!.excellenceScore,
        },
        'targetMetrics': {'expectedIncrease': 15},
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم ربط الطالب بالمعلم وإنشاء خطة مبدئية.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLinking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final teachersAsync = ref.watch(mock_teachers.teachersProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'اختيار طالب بحاجة دعم',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        studentsAsync.when(
          data: (students) {
            final candidates = students
                .where((s) => s.role == UserRole.student)
                .where((s) => s.excellenceScore < 80)
                .toList();
            if (candidates.isEmpty) {
              return const Text('لا يوجد طلاب في قائمة الاحتياج حالياً.');
            }
            return DropdownButtonFormField<User>(
              value: _selectedStudent,
              decoration: const InputDecoration(
                labelText: 'اختر الطالب',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: candidates
                  .map(
                    (s) => DropdownMenuItem(
                      value: s,
                      child: Text('${s.name} • مؤشر ${s.excellenceScore}'),
                    ),
                  )
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedStudent = v;
                });
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) =>
              const Text('تعذر تحميل قائمة الطلاب المحتاجين للدعم.'),
        ),
        SizedBox(height: 16.h),
        Text(
          'اختيار المعلم الداعم',
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 8.h),
        teachersAsync.when(
          data: (teachers) {
            final list = teachers
                .where((t) => t.role == UserRole.teacher)
                .toList(growable: false);
            if (list.isEmpty) {
              return const Text('لا يوجد معلمين متاحين حالياً.');
            }
            return DropdownButtonFormField<User>(
              value: _selectedTeacher,
              decoration: const InputDecoration(
                labelText: 'اختر المعلم',
                border: OutlineInputBorder(),
              ),
              isExpanded: true,
              items: list
                  .map((t) => DropdownMenuItem(value: t, child: Text(t.name)))
                  .toList(),
              onChanged: (v) {
                setState(() {
                  _selectedTeacher = v;
                });
              },
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const Text('تعذر تحميل قائمة المعلمين حالياً.'),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isLinking ? null : _link,
            icon: _isLinking
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.link),
            label: const Text('حفظ الربط وإنشاء خطة'),
          ),
        ),
      ],
    );
  }
}

class RemedialPlansFollowupTab extends ConsumerWidget {
  const RemedialPlansFollowupTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activePlansAsync = ref.watch(remedialPlansProvider('active'));
    final donePlansAsync = ref.watch(remedialPlansProvider('done'));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: activePlansAsync.when(
            data: (plans) {
              if (plans.isEmpty) {
                return const Center(
                  child: Text('لا يوجد خطط علاجية نشطة حالياً.'),
                );
              }
              return ListView.separated(
                itemCount: plans.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = plans[i];
                  return ListTile(
                    leading: const Icon(
                      Icons.medical_services,
                      color: Colors.teal,
                    ),
                    title: Text('${p.strategy}'),
                    subtitle: Text(
                      'طلاب: ${p.studentIds.join(", ")} • مسؤول: ${p.teacherId}',
                    ),
                    trailing: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'تحسن: ${p.improvementScore.toStringAsFixed(1)}',
                          style: const TextStyle(color: Colors.blue),
                        ),
                        TextButton(
                          onPressed: () {
                            ref
                                .read(
                                  updateRemedialProgressProvider(
                                    UpdateRemedialProgressParams(p.id, {
                                      'status': 'done',
                                    }),
                                  ).future,
                                )
                                .then((_) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'تم إنهاء الخطة وتحويلها إلى منجزة.',
                                      ),
                                    ),
                                  );
                                });
                          },
                          child: const Text('إنهاء الخطة'),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('خطأ في تحميل الخطط: $e')),
          ),
        ),
        SizedBox(height: 12.h),
        Text(
          'الخطط المنجزة مؤخراً',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(
          height: 120.h,
          child: donePlansAsync.when(
            data: (plans) {
              if (plans.isEmpty) {
                return const Center(child: Text('لا يوجد خطط منجزة بعد.'));
              }
              final recent = List.of(plans)
                ..sort(
                  (a, b) => b.improvementScore.compareTo(a.improvementScore),
                );
              return ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: recent.length.clamp(0, 10),
                separatorBuilder: (_, __) => SizedBox(width: 8.w),
                itemBuilder: (_, i) {
                  final p = recent[i];
                  return Container(
                    width: 220.w,
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.strategy,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'تحسن: ${p.improvementScore.toStringAsFixed(1)} نقطة',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) =>
                Center(child: Text('خطأ في تحميل الخطط المنجزة: $e')),
          ),
        ),
      ],
    );
  }
}

class MeasureImprovementTab extends ConsumerWidget {
  const MeasureImprovementTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allPlansAsync = ref.watch(remedialPlansProvider(null));

    return allPlansAsync.when(
      data: (plans) {
        if (plans.isEmpty) {
          return const Center(child: Text('لا يوجد بيانات لقياس التحسن بعد.'));
        }
        final total = plans.length;
        final activeCount = plans.where((p) => p.status == 'active').length;
        final doneCount = plans.where((p) => p.status == 'done').length;
        final avgImprovement =
            plans
                .map((p) => p.improvementScore)
                .fold<double>(0, (a, b) => a + b) /
            total;
        final topPlans = List.of(plans)
          ..sort((a, b) => b.improvementScore.compareTo(a.improvementScore));

        return SingleChildScrollView(
          padding: EdgeInsets.all(8.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      title: 'إجمالي الخطط',
                      value: total.toString(),
                      color: Colors.teal,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _MetricCard(
                      title: 'نشطة',
                      value: activeCount.toString(),
                      color: Colors.orange,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: _MetricCard(
                      title: 'منجزة',
                      value: doneCount.toString(),
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 12.h),
              _MetricCard(
                title: 'متوسط التحسن في المؤشر',
                value: '${avgImprovement.toStringAsFixed(1)} نقطة',
                color: Colors.blue,
              ),
              SizedBox(height: 16.h),
              Text(
                'أعلى الخطط تحسناً',
                style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8.h),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: topPlans.length.clamp(0, 10),
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = topPlans[i];
                  return ListTile(
                    leading: Icon(
                      Icons.trending_up,
                      color: Colors.green.shade700,
                    ),
                    title: Text(p.strategy),
                    subtitle: Text(
                      'سبب: ${p.causeType} • طلاب: ${p.studentIds.join(", ")}',
                    ),
                    trailing: Text(
                      '+${p.improvementScore.toStringAsFixed(1)}',
                      style: TextStyle(
                        color: Colors.green.shade800,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ في تحميل بيانات التحسن: $e')),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MetricCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
            ),
            SizedBox(height: 4.h),
            Text(
              value,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==============================================================================
// 6. Academic Reports Module
// ==============================================================================
class AcademicReportsModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const AcademicReportsModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget body;
    String title;
    switch (initialIndex) {
      case 1:
        title = 'تقرير الفجوات التعليمية';
        body = const LearningGapsReportTab();
        break;
      case 2:
        title = 'تقرير أداء المعلمين';
        body = const TeacherPerformanceReportTab();
        break;
      case 3:
        title = 'تصدير التقارير الأكاديمية';
        body = const ExportAcademicReportsTab();
        break;
      case 0:
      default:
        title = 'تقرير نسب النجاح';
        body = const SuccessRatesReportTab();
        break;
    }
    return UnifiedPageScaffold(
      requiredDeputyType: 'academic',
      requiredPermission: 'reports',
      title: title,
      body: body,
    );
  }
}

class SuccessRatesReportTab extends ConsumerStatefulWidget {
  const SuccessRatesReportTab({super.key});

  @override
  ConsumerState<SuccessRatesReportTab> createState() =>
      _SuccessRatesReportTabState();
}

class _ClassSuccessInfo {
  final String classId;
  final String className;
  final int totalStudents;
  final double avgScore;
  final int goodCount;
  final int riskCount;

  _ClassSuccessInfo({
    required this.classId,
    required this.className,
    required this.totalStudents,
    required this.avgScore,
    required this.goodCount,
    required this.riskCount,
  });
}

class _SuccessRatesReportTabState extends ConsumerState<SuccessRatesReportTab> {
  bool _isLoading = false;
  List<_ClassSuccessInfo> _items = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final classes = await ref.read(classesProvider.future);
      final students = await ref.read(studentsProvider.future);

      final items = <_ClassSuccessInfo>[];
      for (final c in classes) {
        final classStudents = students
            .where((s) => c.studentIds.contains(s.id))
            .toList();
        if (classStudents.isEmpty) continue;

        final scores = classStudents
            .map((s) => s.excellenceScore.toDouble())
            .toList();
        final avgScore = scores.isEmpty
            ? 0.0
            : scores.reduce((a, b) => a + b) / scores.length;
        final goodCount = classStudents
            .where((s) => s.excellenceScore >= 80)
            .length;
        final riskCount = classStudents
            .where((s) => s.excellenceScore < 60)
            .length;

        items.add(
          _ClassSuccessInfo(
            classId: c.id,
            className: c.name,
            totalStudents: classStudents.length,
            avgScore: avgScore,
            goodCount: goodCount,
            riskCount: riskCount,
          ),
        );
      }

      items.sort((a, b) => a.avgScore.compareTo(b.avgScore));

      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<_ClassSuccessInfo> get _visibleItems {
    if (_searchQuery.trim().isEmpty) {
      return _items;
    }
    final q = _searchQuery.trim();
    return _items
        .where((c) => c.className.contains(q) || c.classId.contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تقرير نسب النجاح حسب الفصول (مبني على مؤشر التميز السلوكي)',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث باسم الصف أو الرمز',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleItems.isEmpty
                  ? const Center(child: Text('لا توجد بيانات متاحة حالياً'))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: _visibleItems.length,
                        itemBuilder: (context, index) {
                          final item = _visibleItems[index];
                          final successRate = item.totalStudents == 0
                              ? 0
                              : (item.goodCount / item.totalStudents) * 100;
                          final riskRate = item.totalStudents == 0
                              ? 0
                              : (item.riskCount / item.totalStudents) * 100;
                          return Card(
                            margin: EdgeInsets.only(bottom: 8.h),
                            child: ListTile(
                              title: Text(item.className),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4.h),
                                  Text(
                                    'متوسط المؤشر: ${item.avgScore.toStringAsFixed(1)} من 100',
                                  ),
                                  SizedBox(height: 4.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'نسبة الطلاب في المنطقة الآمنة (80+): ${successRate.toStringAsFixed(1)}٪',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 2.h),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          'نسبة الطلاب المعرضين للخطر (< 60): ${riskRate.toStringAsFixed(1)}٪',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'عدد الطلاب: ${item.totalStudents}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class LearningGapsReportTab extends ConsumerStatefulWidget {
  const LearningGapsReportTab({super.key});

  @override
  ConsumerState<LearningGapsReportTab> createState() =>
      _LearningGapsReportTabState();
}

class _StudentGapInfo {
  final User student;
  final String className;
  final int score;

  _StudentGapInfo({
    required this.student,
    required this.className,
    required this.score,
  });
}

class _LearningGapsReportTabState extends ConsumerState<LearningGapsReportTab> {
  bool _isLoading = false;
  List<_StudentGapInfo> _items = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });
    try {
      final classes = await ref.read(classesProvider.future);
      final students = await ref.read(studentsProvider.future);

      final classById = {for (final c in classes) c.id: c};

      final items = <_StudentGapInfo>[];
      for (final s in students) {
        if (s.role != UserRole.student) continue;
        if (s.excellenceScore >= 80) continue;
        final className = classById.values
            .firstWhere(
              (c) => c.studentIds.contains(s.id),
              orElse: () => Classroom(
                id: '',
                name: 'غير مرتبط بفصل',
                gradeLevel: 0,
                studentIds: const [],
              ),
            )
            .name;
        items.add(
          _StudentGapInfo(
            student: s,
            className: className,
            score: s.excellenceScore,
          ),
        );
      }

      items.sort((a, b) => a.score.compareTo(b.score));

      if (mounted) {
        setState(() {
          _items = items;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<_StudentGapInfo> get _visibleItems {
    var list = _items;
    if (_searchQuery.trim().isNotEmpty) {
      final q = _searchQuery.trim();
      list = list
          .where(
            (i) =>
                i.student.name.contains(q) ||
                (i.student.identityNumber?.contains(q) ?? false) ||
                i.className.contains(q),
          )
          .toList();
    }
    return list;
  }

  Color _badgeColor(int score) {
    if (score < 60) return Colors.red.shade700;
    if (score < 80) return Colors.orange.shade700;
    return Colors.green.shade700;
  }

  String _badgeLabel(int score) {
    if (score < 60) return 'حالة حرجة';
    if (score < 80) return 'يحتاج دعم';
    return 'مستقر';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'رصد الطلاب ذوي المؤشر المنخفض لاكتشاف الفجوات التعليمية مبكراً',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث بالاسم أو اسم المستخدم أو الصف',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _visibleItems.isEmpty
                  ? const Center(child: Text('لا توجد حالات ظاهرة حالياً'))
                  : RefreshIndicator(
                      onRefresh: _loadData,
                      child: ListView.builder(
                        itemCount: _visibleItems.length,
                        itemBuilder: (context, index) {
                          final item = _visibleItems[index];
                          return Card(
                            margin: EdgeInsets.only(bottom: 8.h),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.indigo.shade50,
                                child: Text(
                                  item.student.name.isNotEmpty
                                      ? item.student.name[0]
                                      : '?',
                                  style: const TextStyle(color: Colors.indigo),
                                ),
                              ),
                              title: Text(item.student.name),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  SizedBox(height: 4.h),
                                  Text(
                                    item.className,
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text('مؤشر التميز: ${item.score} / 100'),
                                ],
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: _badgeColor(
                                    item.score,
                                  ).withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12.r),
                                ),
                                child: Text(
                                  _badgeLabel(item.score),
                                  style: TextStyle(
                                    color: _badgeColor(item.score),
                                    fontSize: 11.sp,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
