import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../academic/data/school_repository.dart';
import '../../subscription/domain/subscription_logic.dart';
import '../../assignments/data/firestore_assignments_repository.dart';
import '../../assignments/domain/assignment.dart';
import '../../exams/presentation/exams_providers.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../attendance/data/student_attendance_repository.dart';
import '../../system/presentation/system_settings_provider.dart';
import 'providers/student_performance_provider.dart';
import '../../academic/presentation/students_provider.dart';

class StudentDashboard extends ConsumerWidget {
  final User student;

  const StudentDashboard({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolvedStudent =
        ref.watch(studentByIdProvider(student.id)).value ?? student;
    final schoolAsync = ref.watch(
      schoolProvider(resolvedStudent.schoolId ?? student.schoolId ?? ''),
    );

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildMinisterialHeader(context, ref, resolvedStudent),
          SizedBox(height: 16.h),
          _buildPerformanceIndicators(context, ref),
          SizedBox(height: 24.h),
          Text(
            'خدمات الطالب',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
          SizedBox(height: 16.h),
          _buildQuickAccessGrid(context, schoolAsync),
          SizedBox(height: 24.h),
          Text(
            'آخر الأنشطة',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
          SizedBox(height: 16.h),
          _buildRecentActivitySection(ref),
        ],
      ),
    );
  }

  Widget _buildMinisterialHeader(
    BuildContext context,
    WidgetRef ref,
    User resolvedStudent,
  ) {
    final systemSettingsAsync = ref.watch(systemSettingsProvider);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30.r,
                  backgroundColor: Colors.blue.shade100,
                  child: Text(
                    resolvedStudent.name.isNotEmpty
                        ? resolvedStudent.name[0]
                        : '?',
                    style: TextStyle(
                      fontSize: 24.sp,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resolvedStudent.name,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'اسم المستخدم: ${resolvedStudent.identityNumber ?? '-'}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                // Term/Week Indicator
                systemSettingsAsync.when(
                  data: (settings) => Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12.w,
                      vertical: 6.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Text(
                      '${settings.currentWeek} - ${settings.currentTerm}',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ),
            Divider(height: 24.h),
            _buildMotivationalMessage(context),
          ],
        ),
      ),
    );
  }

  Widget _buildMotivationalMessage(BuildContext context) {
    final score = student.excellenceScore;
    String message = 'واصل تميزك، أنت في الطريق الصحيح! 🌟';
    if (score < 90) message = 'انتبه لمستوى انضباطك، يمكنك التحسن! 💪';
    if (score < 80) message = 'نحتاج منك مزيداً من الاهتمام والتركيز ⚠️';

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.blue.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'نسبة انضباطك هذا الأسبوع ${score}%',
            style: TextStyle(color: Colors.blue.shade700, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  Widget _buildPerformanceIndicators(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(
      studentAttendanceHistoryProvider(student),
    );
    final assignmentsAsync = ref.watch(
      studentAssignmentsStreamProvider(student.id),
    );
    final performanceAsync = ref.watch(studentPerformanceProvider(student));

    return Row(
      children: [
        Expanded(
          child: _buildIndicatorCard(
            'الإنضباط',
            '${student.excellenceScore}%',
            Colors.purple,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: attendanceAsync.when(
            data: (list) {
              final total = list.length;
              final present = list
                  .where((a) => a.status != StudentAttendanceStatus.absent)
                  .length;
              final pct = total == 0 ? 100 : (present / total * 100).toInt();
              return _buildIndicatorCard('الحضور', '$pct%', Colors.green);
            },
            loading: () => _buildIndicatorCard('الحضور', '...', Colors.grey),
            error: (_, __) => _buildIndicatorCard('الحضور', '-', Colors.red),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: assignmentsAsync.when(
            data: (list) {
              final now = DateTime.now();
              final dueAssignments = list.where((a) {
                return a.dueDate.isBefore(now) ||
                    a.status == AssignmentStatus.submitted ||
                    a.status == AssignmentStatus.approved;
              }).toList();

              final total = dueAssignments.length;

              if (total == 0) {
                return _buildIndicatorCard(
                  'الواجبات',
                  'لا توجد',
                  Colors.grey,
                  fontSize: 12.sp,
                );
              }

              final submitted = dueAssignments
                  .where(
                    (a) =>
                        a.status == AssignmentStatus.submitted ||
                        a.status == AssignmentStatus.approved,
                  )
                  .length;
              final pct = (submitted / total * 100).toInt();
              return _buildIndicatorCard('الواجبات', '$pct%', Colors.orange);
            },
            loading: () => _buildIndicatorCard('الواجبات', '...', Colors.grey),
            error: (_, __) => _buildIndicatorCard('الواجبات', '-', Colors.red),
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: performanceAsync.when(
            data: (p) => _buildProgressIndicator(p.score),
            loading: () => _buildIndicatorCard('التقدم', '...', Colors.grey),
            error: (_, __) => _buildIndicatorCard('التقدم', '-', Colors.red),
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorCard(
    String title,
    String value,
    Color color, {
    double? fontSize,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 4.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
          ),
          SizedBox(height: 4.h),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: TextStyle(
                fontSize: fontSize ?? 16.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressIndicator(num score) {
    String label = 'ممتاز';
    Color color = Colors.green;
    if (score < 90) {
      label = 'جيد جداً';
      color = Colors.blue;
    }
    if (score < 80) {
      label = 'جيد';
      color = Colors.orange;
    }
    if (score < 60) {
      label = 'مقبول';
      color = Colors.red;
    }

    return _buildIndicatorCard(
      'التقدم',
      '$score% ($label)',
      color,
      fontSize: 10.sp,
    );
  }

  Widget _buildQuickAccessGrid(
    BuildContext context,
    AsyncValue<School?> schoolAsync,
  ) {
    // Helper to check access
    bool isLocked(AppFeature feature) {
      if (schoolAsync.isLoading || schoolAsync.hasError) return false;
      final school = schoolAsync.value;
      if (school == null) return false;
      return !school.hasAccess(feature);
    }

    final classId =
        (student.assignedClassIds != null &&
            student.assignedClassIds!.isNotEmpty)
        ? student.assignedClassIds!.first
        : '';

    final items = [
      _GridItem(
        title: 'جدولي',
        icon: Icons.calendar_today,
        color: Colors.teal,
        route: '/student-schedule?classId=$classId',
        isLocked: isLocked(AppFeature.smartSchedule),
      ),
      _GridItem(
        title: 'سجل الالتزام المدرسي',
        icon: Icons.verified_user,
        color: Colors.indigo,
        route: '/student-violations',
        extra: student,
      ),
      _GridItem(
        title: 'الغياب',
        icon: Icons.access_time,
        color: Colors.orange,
        route: '/student-attendance',
        extra: student,
      ),
      _GridItem(
        title: 'الواجبات',
        icon: Icons.assignment,
        color: Colors.blue,
        route: '/assignments',
        showBadge: true,
        badgeType: 'assignments',
      ),
      _GridItem(
        title: 'الاختبارات',
        icon: Icons.quiz,
        color: Colors.indigo,
        route: '/tests',
        showBadge: true,
        badgeType: 'tests',
      ),
      _GridItem(
        title: 'الإعدادات',
        icon: Icons.settings,
        color: Colors.blueGrey,
        route: '/settings',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = 2;
        if (constraints.maxWidth > 900) {
          crossAxisCount = 4;
        } else if (constraints.maxWidth > 600) {
          crossAxisCount = 3;
        }

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 16.w,
            mainAxisSpacing: 16.h,
            childAspectRatio: 1.5,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            return _buildGridCard(context, item);
          },
        );
      },
    );
  }

  Widget _buildGridCard(BuildContext context, _GridItem item) {
    return Consumer(
      builder: (context, ref, child) {
        int badgeCount = 0;
        if (item.showBadge) {
          if (item.badgeType == 'assignments') {
            final assignmentsAsync = ref.watch(
              studentAssignmentsStreamProvider(student.id),
            );
            final list = assignmentsAsync.value ?? const [];
            badgeCount = list
                .where(
                  (a) =>
                      a.type == 'assignment' &&
                      a.status == AssignmentStatus.pending,
                )
                .length;
          } else if (item.badgeType == 'tests') {
            final assignmentsAsync = ref.watch(
              studentAssignmentsStreamProvider(student.id),
            );
            final list = assignmentsAsync.value ?? const [];
            badgeCount = list
                .where(
                  (a) =>
                      a.type == 'test' && a.status == AssignmentStatus.pending,
                )
                .length;
          }
        }

        return Card(
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
            side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16.r),
            onTap: item.isLocked
                ? () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('هذه الخاصية غير مفعلة لمدرستك'),
                      ),
                    );
                  }
                : () {
                    if (item.extra != null) {
                      context.push(item.route, extra: item.extra);
                    } else {
                      context.push(item.route);
                    }
                  },
            child: Stack(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12.w),
                      decoration: BoxDecoration(
                        color: item.color.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(item.icon, color: item.color, size: 32.sp),
                    ),
                    SizedBox(height: 12.h),
                    Center(
                      child: Text(
                        item.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.indigo.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                if (badgeCount > 0)
                  Positioned(
                    top: 8.h,
                    left: 8.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Text(
                        '$badgeCount',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                if (item.isLocked)
                  Positioned(
                    top: 8.h,
                    right: 8.w,
                    child: Icon(Icons.lock, color: Colors.grey, size: 20.sp),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecentActivitySection(WidgetRef ref) {
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));

    return behaviorAsync.when(
      data: (allRecords) {
        final approved = allRecords
            .where((r) => r.status == BehaviorStatus.approved)
            .toList();
        final pending = allRecords
            .where((r) => r.status == BehaviorStatus.pending)
            .toList();
        final records = <BehaviorRecord>[...pending, ...approved];

        if (records.isEmpty) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(24.w),
              child: const Text(
                'لا توجد أنشطة حديثة',
                style: TextStyle(color: Colors.grey),
              ),
            ),
          );
        }

        // Show last 5
        final recent = records.take(5).toList();

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: recent.length + (pending.isNotEmpty ? 1 : 0),
          separatorBuilder: (context, index) => SizedBox(height: 8.h),
          itemBuilder: (context, index) {
            if (pending.isNotEmpty && index == 0) {
              return Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(
                    color: Colors.blueGrey.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blueGrey.shade700),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'تم تسجيل ${pending.length} ملاحظة تربوية قيد الاعتماد.\nستظهر ضمن السجل بعد اعتمادها من المدرسة.',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade900,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            final i = pending.isNotEmpty ? index - 1 : index;
            final record = recent[i];
            final isPositive = record.points > 0;
            final isNeutral = record.points == 0;
            final isPending = record.status == BehaviorStatus.pending;
            return Card(
              elevation: 0,
              color: Colors.grey.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isPositive
                      ? Colors.green.shade100
                      : isNeutral
                          ? Colors.blueGrey.shade100
                          : Colors.red.shade100,
                  radius: 16.r,
                  child: Icon(
                    isPositive
                        ? Icons.thumb_up
                        : isNeutral
                            ? Icons.info_outline
                            : Icons.warning,
                    color: isPositive
                        ? Colors.green
                        : isNeutral
                            ? Colors.blueGrey
                            : Colors.red,
                    size: 16.sp,
                  ),
                ),
                title: Text(
                  _getFormalDescription(record.description),
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                subtitle: Text(
                  intl.DateFormat('yyyy/MM/dd', 'ar').format(record.timestamp),
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
                trailing: isPending
                    ? Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 10.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.22),
                          ),
                        ),
                        child: Text(
                          'قيد الاعتماد',
                          style: TextStyle(
                            color: Colors.orange.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11.sp,
                          ),
                        ),
                      )
                    : isNeutral
                        ? Text(
                            'ملاحظة',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade700,
                            ),
                          )
                        : Text(
                            '${isPositive ? '+' : ''}${record.points}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isPositive ? Colors.green : Colors.red,
                            ),
                          ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Text('خطأ: $e'),
    );
  }

  String _getFormalDescription(String original) {
    if (original.contains('تأخر') || original.contains('Late')) {
      return 'تأخر عن بداية الحصة';
    }
    if (original.contains('واجب') ||
        original.contains('homework') ||
        original.contains('Homework')) {
      return 'لم يُكمل واجبه المنزلي';
    }
    if (original.contains('هروب') ||
        original.contains('خروج') ||
        original.contains('Escape')) {
      return 'خروج أثناء الحصة دون إذن';
    }
    if (original.contains('مشاغبة') ||
        original.contains('إزعاج') ||
        original.contains('Disruption')) {
      return 'سلوك يحتاج لتحسين داخل الفصل';
    }
    if (original.contains('زي') || original.contains('Uniform')) {
      return 'عدم الالتزام بالزي المدرسي';
    }
    return original;
  }
}

class _GridItem {
  final String title;
  final IconData icon;
  final Color color;
  final String route;
  final bool isLocked;
  final Object? extra;
  final bool showBadge;
  final String? badgeType;

  _GridItem({
    required this.title,
    required this.icon,
    required this.color,
    required this.route,
    this.isLocked = false,
    this.extra,
    this.showBadge = false,
    this.badgeType,
  });
}
