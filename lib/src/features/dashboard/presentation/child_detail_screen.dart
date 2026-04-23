import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/data/firestore_assignments_repository.dart';

import '../../requests/presentation/parent_permission_sheet.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../subscription/domain/subscription_logic.dart';
import '../../academic/data/school_repository.dart';
import 'parent_sub_screens.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../attendance/data/student_attendance_repository.dart';
import '../../behavior/domain/bathroom_pass.dart';

class ChildDetailScreen extends ConsumerWidget {
  final User student;

  const ChildDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));
    final assignmentsAsync = ref.watch(studentAssignmentsProvider(student.id));
    final userAsync = ref.watch(authStateProvider);
    final schoolAsync = ref.watch(
      schoolProvider(userAsync.value?.schoolId ?? ''),
    );

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(student.name),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Last Activity Feed (Real-time Intelligence)
            behaviorAsync.when(
              data: (records) => _buildLastActivityFeed(context, records),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            SizedBox(height: 24.h),

            // 2. Student Excellence Index (SEI) Gauge
            _buildExcellenceGauge(student.excellenceScore),
            SizedBox(height: 24.h),

            // 3. Active Bathroom Timer (If any) - from Schools/{schoolId}/BathroomPasses
            Consumer(
              builder: (context, ref, _) {
                final activeMapAsync = ref.watch(
                  activeBathroomTripsProvider([student.id]),
                );
                return activeMapAsync.when(
                  data: (map) {
                    final pass = map[student.id];
                    if (pass == null) return const SizedBox.shrink();
                    return _buildActiveBathroomTimer(context, pass);
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
            ),

            // 4. Stats Grid (30d violations + attendance)
            behaviorAsync.when(
              data: (records) {
                final cutoff = DateTime.now().subtract(
                  const Duration(days: 30),
                );
                final violationsCount30d = records
                    .where(
                      (r) =>
                          r.type == BehaviorType.negative &&
                          r.status == BehaviorStatus.approved &&
                          r.timestamp.isAfter(cutoff),
                    )
                    .length;
                final attendanceAsync = ref.watch(
                  studentAttendanceHistoryProvider(student),
                );
                return attendanceAsync.when(
                  data: (attendance) {
                    final last30 = attendance
                        .where((a) => a.date.isAfter(cutoff))
                        .toList();
                    final excused = last30
                        .where(
                          (a) => a.status == StudentAttendanceStatus.excused,
                        )
                        .length;
                    final unexcused = last30
                        .where(
                          (a) => a.status == StudentAttendanceStatus.absent,
                        )
                        .length;
                    final late = last30
                        .where((a) => a.status == StudentAttendanceStatus.late)
                        .length;
                    return _buildStatsGrid(
                      violationsCount30d: violationsCount30d,
                      absentExcusedCount: excused,
                      absentUnexcusedCount: unexcused,
                      lateUnexcusedCount: late,
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            SizedBox(height: 24.h),

            // Request Permission Button (Existing Feature)
            if (userAsync.value != null &&
                schoolAsync.value != null &&
                schoolAsync.value!.hasAccess(AppFeature.digitalPermission))
              Container(
                margin: EdgeInsets.only(bottom: 16.h),
                child: ElevatedButton.icon(
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (context) => ParentPermissionSheet(
                        parent: userAsync.value!,
                        initialStudent: student,
                      ),
                    );
                  },
                  icon: const Icon(Icons.exit_to_app, color: Colors.white),
                  label: const Text(
                    'طلب استئذان (خروج مبكر)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade700,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // 5. Assignments Section
            assignmentsAsync.when(
              data: (assignments) =>
                  _buildAssignmentsSection(context, ref, assignments),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Text('Error: $e'),
            ),
            SizedBox(height: 24.h),

            // 6. Recent Activity List
            behaviorAsync.when(
              data: (records) => _buildRecentActivity(records),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('Error loading data: $e')),
            ),
          ],
        ),
      ),
    );
  }

  // --- 1. Last Activity Feed ---
  Widget _buildLastActivityFeed(
    BuildContext context,
    List<BehaviorRecord> records,
  ) {
    if (records.isEmpty) return const SizedBox.shrink();

    // Sort by timestamp descending
    final sorted = [...records]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final lastActivity = sorted.first;

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt, color: Colors.amber, size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'آخر نشاط',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            lastActivity.description,
            style: TextStyle(
              color: Colors.white,
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            intl.DateFormat('yyyy-MM-dd HH:mm').format(lastActivity.timestamp),
            style: TextStyle(color: Colors.white54, fontSize: 12.sp),
          ),
        ],
      ),
    );
  }

  // --- 2. Excellence Gauge ---
  Widget _buildExcellenceGauge(int score) {
    Color color;
    String label;
    if (score >= 90) {
      color = Colors.green;
      label = 'متميز';
    } else if (score >= 80) {
      color = Colors.lightGreen;
      label = 'طبيعي';
    } else if (score >= 60) {
      color = Colors.amber;
      label = 'يحتاج تعزيز';
    } else if (score >= 30) {
      color = Colors.orange;
      label = 'يحتاج تحفيز';
    } else {
      color = Colors.red;
      label = 'يحتاج متابعة';
    }

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'مؤشر التميز السلوكي',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(height: 16.h),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 120.w,
                height: 120.w,
                child: CircularProgressIndicator(
                  value: score / 100,
                  strokeWidth: 12.w,
                  backgroundColor: Colors.grey.shade100,
                  color: color,
                  strokeCap: StrokeCap.round,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$score',
                    style: TextStyle(
                      fontSize: 32.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: color,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- 3. Bathroom Timer ---
  Widget _buildActiveBathroomTimer(BuildContext context, BathroomPass pass) {
    final elapsed = DateTime.now().difference(pass.startTime).inMinutes;
    Color timerColor = Colors.green;
    if (elapsed > 15) {
      timerColor = Colors.red;
    } else if (elapsed > 5) {
      timerColor = Colors.amber;
    } else {
      timerColor = Colors.green;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 24.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: timerColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: timerColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(Icons.timer, color: timerColor, size: 32.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'إذن خروج نشط',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: timerColor,
                  ),
                ),
                Text(
                  'منذ $elapsed دقيقة',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: timerColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          if (pass.status == BathroomPassStatus.locked_red)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Text(
                'مقفل—مراجعة الوكيل',
                style: TextStyle(
                  color: Colors.red.shade800,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- 4. Stats Grid (30d) ---
  Widget _buildStatsGrid({
    required int violationsCount30d,
    required int absentExcusedCount,
    required int absentUnexcusedCount,
    required int lateUnexcusedCount,
  }) {
    return Wrap(
      spacing: 12.w,
      runSpacing: 12.h,
      children: [
        SizedBox(
          width: 0.46.sw,
          child: _buildStatCard(
            'مخالفات (30 يوم)',
            '$violationsCount30d',
            Icons.warning_amber,
            Colors.red,
          ),
        ),
        SizedBox(
          width: 0.46.sw,
          child: _buildStatCard(
            'غياب بعذر (30 يوم)',
            '$absentExcusedCount',
            Icons.event_available,
            Colors.orange,
          ),
        ),
        SizedBox(
          width: 0.46.sw,
          child: _buildStatCard(
            'غياب بلا عذر (30 يوم)',
            '$absentUnexcusedCount',
            Icons.cancel_presentation,
            Colors.red.shade900,
          ),
        ),
        SizedBox(
          width: 0.46.sw,
          child: _buildStatCard(
            'تأخر بلا عذر (30 يوم)',
            '$lateUnexcusedCount',
            Icons.access_time_filled,
            Colors.amber.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            title,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // --- 5. Assignments Section ---
  Widget _buildAssignmentsSection(
    BuildContext context,
    WidgetRef ref,
    List<Assignment> assignments,
  ) {
    final completed = assignments
        .where((a) => a.status == AssignmentStatus.approved)
        .toList();
    final upcoming = assignments
        .where((a) => a.status != AssignmentStatus.approved)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Upcoming Assignments
        Text(
          'الواجبات القادمة',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade800,
          ),
        ),
        SizedBox(height: 12.h),
        if (upcoming.isEmpty)
          const Center(child: Text('لا يوجد واجبات قادمة'))
        else
          ...upcoming.map(
            (assignment) => _buildAssignmentCard(context, ref, assignment),
          ),

        SizedBox(height: 24.h),

        // Completed Assignments
        Text(
          'الواجبات المنجزة',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.green.shade800,
          ),
        ),
        SizedBox(height: 12.h),
        if (completed.isEmpty)
          const Center(child: Text('لم يتم إنجاز أي واجبات بعد'))
        else
          ...completed.map(
            (assignment) => _buildAssignmentCard(context, ref, assignment),
          ),
      ],
    );
  }

  Widget _buildAssignmentCard(
    BuildContext context,
    WidgetRef ref,
    Assignment assignment,
  ) {
    final isApproved = assignment.status == AssignmentStatus.approved;
    final isSubmitted = assignment.status == AssignmentStatus.submitted;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isApproved
              ? Colors.green.shade100
              : Colors.orange.shade100,
          child: Icon(
            isApproved ? Icons.check : Icons.assignment,
            color: isApproved ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          assignment.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            decoration: isApproved ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${assignment.subject} • ${intl.DateFormat('yyyy-MM-dd').format(assignment.dueDate)}',
            ),
            if (isSubmitted)
              Text(
                'بانتظار اعتماد المعلم',
                style: TextStyle(color: Colors.orange, fontSize: 12.sp),
              ),
          ],
        ),
        trailing: isApproved
            ? const Icon(Icons.check_circle, color: Colors.green)
            : const Icon(Icons.access_time, color: Colors.orange),
      ),
    );
  }

  Widget _buildRecentActivity(List<BehaviorRecord> records) {
    // Sort by newest
    final sortedRecords = [...records]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل النشاط',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade800,
          ),
        ),
        SizedBox(height: 12.h),
        if (sortedRecords.isEmpty)
          const Center(child: Text('لا يوجد سجل نشاط حتى الآن'))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: sortedRecords.length > 5 ? 5 : sortedRecords.length,
            itemBuilder: (context, index) {
              final record = sortedRecords[index];
              return Card(
                margin: EdgeInsets.only(bottom: 8.h),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: record.points >= 0
                        ? Colors.green.shade100
                        : Colors.red.shade100,
                    child: Icon(
                      record.points >= 0 ? Icons.thumb_up : Icons.thumb_down,
                      color: record.points >= 0 ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(record.description),
                  subtitle: Text(
                    intl.DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(record.timestamp),
                  ),
                  trailing: Text(
                    '${record.points > 0 ? '+' : ''}${record.points}',
                    style: TextStyle(
                      color: record.points >= 0 ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
