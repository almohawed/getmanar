import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/domain/models/behavior_record.dart';
import '../../../../core/domain/models/user.dart';
import '../../../behavior/presentation/behavior_controller.dart';
import '../../../attendance/data/student_attendance_repository.dart';
import '../../../assignments/data/firestore_assignments_repository.dart';
import '../logic/silent_guidance_engine.dart';
import '../../../auth/presentation/auth_controller.dart';

class StudentViolationsScreen extends ConsumerWidget {
  final User student;

  const StudentViolationsScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));
    final currentUser = ref.watch(authStateProvider).value;
    final isStaffView = currentUser != null && isStaffRole(currentUser.role);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'سجل الالتزام المدرسي',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.indigo.shade900,
      ),
      body: behaviorAsync.when(
        data: (allRecords) {
          final records = isStaffView
              ? allRecords
                    .where((r) => r.status != BehaviorStatus.rejected)
                    .toList()
              : allRecords
                    .where((r) => r.status == BehaviorStatus.approved)
                    .toList();

          return Column(
            children: [
              _buildCommitmentLevel(context),
              _buildSilentGuidanceEngine(context, ref),
              Expanded(
                child: records.isEmpty
                    ? _buildEmptyState()
                    : ListView.separated(
                        padding: EdgeInsets.all(16.w),
                        itemCount: records.length + 1, // +1 for footer
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          if (index == records.length) {
                            return _buildEducationalFooter();
                          }
                          final record = records[index];
                          return _buildBehaviorCard(record);
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
    );
  }

  Widget _buildSilentGuidanceEngine(BuildContext context, WidgetRef ref) {
    // 1. Silent Correlation Engine (Internal Logic)
    final attendanceAsync = ref.watch(
      studentAttendanceHistoryProvider(student),
    );
    final assignmentsAsync = ref.watch(studentAssignmentsProvider(student.id));
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));

    return attendanceAsync.when(
      data: (attendanceList) {
        return assignmentsAsync.when(
          data: (assignmentsList) {
            return behaviorAsync.when(
              data: (behaviorList) {
                final message = SilentGuidanceEngine.analyzeAndGenerateMessage(
                  attendanceHistory: attendanceList,
                  assignments: assignmentsList,
                  behaviorRecords: behaviorList,
                  excellenceScore: student.excellenceScore.toDouble(),
                );

                if (message == null) return const SizedBox.shrink();

                return Container(
                  margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.indigo.shade100),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline,
                        color: Colors.indigo.shade700,
                        size: 24.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          message,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.indigo.shade900,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, s) => const SizedBox.shrink(),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (e, s) => const SizedBox.shrink(),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }

  Widget _buildCommitmentLevel(BuildContext context) {
    String level = 'التزام ممتاز';
    Color color = Colors.green;
    IconData icon = Icons.verified;
    String message = 'استمر على هذا المستوى من الالتزام.';

    if (student.excellenceScore < 90) {
      level = 'التزام جيد';
      color = Colors.orange;
      icon = Icons.info_outline;
      message = 'يمكنك تحسين مستوى التزامك أكثر.';
    }
    if (student.excellenceScore < 80) {
      level = 'يحتاج إلى عناية';
      color = Colors.red;
      icon = Icons.warning_amber_rounded;
      message = 'نرجو منك الانتباه أكثر لسلوكك.';
    }

    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: 0.2),
            child: Icon(icon, color: color),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مستوى الالتزام',
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                ),
                Text(
                  level,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  message,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: color.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${student.excellenceScore}%',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64.sp, color: Colors.green),
          SizedBox(height: 16.h),
          Text(
            'سجلك نظيف! أحسنت',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.green.shade800,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'لا توجد ملاحظات مسجلة عليك حالياً',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  Widget _buildBehaviorCard(BehaviorRecord record) {
    final isPositive = record.points > 0;
    final isNeutral = record.points == 0;
    final formalData = _getFormalData(record.description, isPositive);
    final status = record.status;
    final statusLabel = status == BehaviorStatus.pending
        ? 'قيد الاعتماد'
        : status == BehaviorStatus.warning
        ? 'إنذار'
        : status == BehaviorStatus.approved
        ? 'معتمد'
        : status.name;
    final statusColor = status == BehaviorStatus.pending
        ? Colors.orange
        : status == BehaviorStatus.warning
        ? Colors.blueGrey
        : status == BehaviorStatus.approved
        ? Colors.green
        : Colors.grey;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: isPositive
                        ? Colors.green.withValues(alpha: 0.1)
                        : isNeutral
                            ? Colors.blueGrey.withValues(alpha: 0.1)
                            : Colors.red.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    isPositive
                        ? Icons.thumb_up
                        : isNeutral
                            ? Icons.info_outline
                            : Icons.warning_amber_rounded,
                    color: isPositive
                        ? Colors.green
                        : isNeutral
                            ? Colors.blueGrey
                            : Colors.red,
                    size: 20.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formalData.title,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        intl.DateFormat(
                          'yyyy/MM/dd - hh:mm a',
                          'ar',
                        ).format(record.timestamp),
                        style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  isNeutral ? 'ملاحظة' : '${isPositive ? '+' : ''}${record.points}',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: isPositive
                        ? Colors.green
                        : isNeutral
                            ? Colors.blueGrey
                            : Colors.red,
                  ),
                ),
              ],
            ),
            if (status != BehaviorStatus.approved) ...[
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: statusColor.withValues(alpha: 0.22),
                  ),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                  ),
                ),
              ),
            ],
            if (record.notes != null && record.notes!.isNotEmpty) ...[
              SizedBox(height: 8.h),
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Text(
                  record.notes!,
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey[800]),
                ),
              ),
            ],
            SizedBox(height: 8.h),
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  size: 14.sp,
                  color: Colors.amber.shade700,
                ),
                SizedBox(width: 4.w),
                Expanded(
                  child: Text(
                    formalData.tip,
                    style: TextStyle(
                      fontSize: 11.sp,
                      color: Colors.amber.shade900,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEducationalFooter() {
    return Container(
      margin: EdgeInsets.only(top: 16.h, bottom: 32.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        children: [
          Icon(Icons.school, color: Colors.indigo, size: 32.sp),
          SizedBox(height: 8.h),
          Text(
            'أثر الالتزام على تحصيلك الدراسي',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            'الطلاب الأكثر التزامًا يحققون نتائج أكاديمية أعلى.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.indigo.shade700),
          ),
        ],
      ),
    );
  }

  ({String title, String tip}) _getFormalData(
    String original,
    bool isPositive,
  ) {
    if (isPositive) {
      return (
        title: original,
        tip: 'استمر في هذا السلوك الإيجابي، فهو طريقك للتميز.',
      );
    }

    // Mapping for negative behaviors
    if (original.contains('تأخر') || original.contains('Late')) {
      return (
        title: 'تأخر عن بداية الحصة',
        tip: 'الالتزام بالحضور في الوقت يعكس احترامك لزملائك ومعلمك.',
      );
    }
    if (original.contains('واجب') ||
        original.contains('homework') ||
        original.contains('Homework')) {
      return (
        title: 'لم يُكمل واجبه المنزلي',
        tip: 'إنجاز المهام في وقتها سمة الناجحين.',
      );
    }
    if (original.contains('هروب') ||
        original.contains('خروج') ||
        original.contains('Escape')) {
      return (
        title: 'خروج أثناء الحصة دون إذن',
        tip: 'احترام القوانين دليل على نضج شخصيتك.',
      );
    }
    if (original.contains('مشاغبة') ||
        original.contains('إزعاج') ||
        original.contains('Disruption')) {
      return (
        title: 'سلوك يحتاج لتحسين داخل الفصل',
        tip: 'الهدوء يساعدك وزملاءك على التركيز والتعلم.',
      );
    }
    if (original.contains('زي') || original.contains('Uniform')) {
      return (
        title: 'عدم الالتزام بالزي المدرسي',
        tip: 'الزي المدرسي يعكس انضباطك وانتماءك للمدرسة.',
      );
    }

    // Default fallback
    return (title: original, tip: 'سلوكك الإيجابي يمهد طريق نجاحك.');
  }
}
