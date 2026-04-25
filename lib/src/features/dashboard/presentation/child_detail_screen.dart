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
import '../../attendance/domain/student_attendance.dart';
import '../../attendance/data/student_attendance_repository.dart';
import '../../behavior/domain/bathroom_pass.dart';

class ChildDetailScreen extends ConsumerWidget {
  final User student;
  const ChildDetailScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behaviorAsync   = ref.watch(studentBehaviorProvider(student.id));
    final assignmentsAsync = ref.watch(studentAssignmentsProvider(student.id));
    final userAsync       = ref.watch(authStateProvider);
    final schoolAsync     = ref.watch(schoolProvider(userAsync.value?.schoolId ?? ''));

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: CustomScrollView(
        slivers: [
          // ─── Hero Header ──────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: const Color(0xFF0D1B2A),
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHeroHeader(context, student),
            ),
          ),

          SliverPadding(
            padding: EdgeInsets.all(16.w),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // ─── مؤشر التميز السلوكي ──────────────────────────────
                behaviorAsync.when(
                  data: (records) => _buildExcellenceCard(student.excellenceScore, records),
                  loading: () => _buildExcellenceCard(student.excellenceScore, []),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),

                // ─── إحصائيات 30 يوم ──────────────────────────────────
                behaviorAsync.when(
                  data: (records) {
                    final cutoff = DateTime.now().subtract(const Duration(days: 30));
                    final violations = records.where((r) =>
                        r.type == BehaviorType.negative &&
                        r.status == BehaviorStatus.approved &&
                        r.timestamp.isAfter(cutoff)).length;
                    final attendanceAsync = ref.watch(studentAttendanceHistoryProvider(student));
                    return attendanceAsync.when(
                      data: (att) {
                        final last30 = att.where((a) => a.date.isAfter(cutoff)).toList();
                        return _buildStatsRow(
                          violations: violations,
                          excused: last30.where((a) => a.status == StudentAttendanceStatus.excused).length,
                          unexcused: last30.where((a) => a.status == StudentAttendanceStatus.absent).length,
                          late: last30.where((a) => a.status == StudentAttendanceStatus.late).length,
                        );
                      },
                      loading: () => _buildStatsRow(violations: violations, excused: 0, unexcused: 0, late: 0),
                      error: (_, __) => const SizedBox.shrink(),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),

                // ─── طلب استئذان ──────────────────────────────────────
                if (userAsync.value != null &&
                    schoolAsync.value != null &&
                    schoolAsync.value!.hasAccess(AppFeature.digitalPermission))
                  _buildPermissionButton(context, userAsync.value!),
                SizedBox(height: 16.h),

                // ─── آخر نشاط ─────────────────────────────────────────
                behaviorAsync.when(
                  data: (records) => records.isNotEmpty
                      ? _buildLastActivity(records) : const SizedBox.shrink(),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),

                // ─── الواجبات ─────────────────────────────────────────
                assignmentsAsync.when(
                  data: (assignments) => _buildAssignmentsSection(context, ref, assignments),
                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.white38)),
                  error: (e, _) => const SizedBox.shrink(),
                ),
                SizedBox(height: 16.h),

                // ─── سجل النشاط ───────────────────────────────────────
                behaviorAsync.when(
                  data: (records) => _buildActivityLog(records),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                SizedBox(height: 60.h),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Hero Header ──────────────────────────────────────────────────────────
  Widget _buildHeroHeader(BuildContext context, User student) {
    final initials = student.name.isNotEmpty ? student.name[0] : '?';
    final colors = [
      [const Color(0xFF1A237E), const Color(0xFF283593)],
      [const Color(0xFF00695C), const Color(0xFF00897B)],
      [const Color(0xFF4A148C), const Color(0xFF6A1B9A)],
      [const Color(0xFF1565C0), const Color(0xFF1976D2)],
    ];
    final colorPair = colors[student.name.codeUnitAt(0) % colors.length];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colorPair,
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 20.h),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  width: 64.w, height: 64.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 2),
                  ),
                  child: Center(child: Text(initials,
                      style: TextStyle(color: Colors.white, fontSize: 28.sp,
                          fontWeight: FontWeight.bold))),
                ),
                SizedBox(width: 16.w),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(student.name,
                        style: TextStyle(color: Colors.white, fontSize: 20.sp,
                            fontWeight: FontWeight.bold)),
                    SizedBox(height: 4.h),
                    Row(children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20)),
                        child: Text(student.stage ?? 'طالب',
                            style: TextStyle(color: Colors.white70, fontSize: 11.sp))),
                      if (student.assignedClassIds != null && student.assignedClassIds!.isNotEmpty) ...[
                        SizedBox(width: 6.w),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20)),
                          child: Text(student.assignedClassIds!.first,
                              style: TextStyle(color: Colors.white70, fontSize: 11.sp))),
                      ],
                    ]),
                  ],
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Excellence Card ──────────────────────────────────────────────────────
  Widget _buildExcellenceCard(int score, List<BehaviorRecord> records) {
    Color color;
    String label;
    String emoji;
    if (score >= 90) { color = const Color(0xFF4CAF50); label = 'متميز'; emoji = '🌟'; }
    else if (score >= 80) { color = const Color(0xFF8BC34A); label = 'جيد جداً'; emoji = '✅'; }
    else if (score >= 60) { color = const Color(0xFFFFC107); label = 'يحتاج تعزيز'; emoji = '💪'; }
    else if (score >= 30) { color = const Color(0xFFFF9800); label = 'يحتاج تحفيز'; emoji = '⚡'; }
    else { color = const Color(0xFFF44336); label = 'يحتاج متابعة'; emoji = '🔔'; }

    final positives = records.where((r) => r.type == BehaviorType.positive).length;
    final negatives = records.where((r) => r.type == BehaviorType.negative).length;

    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.05)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        // Gauge
        SizedBox(
          width: 90.w, height: 90.w,
          child: Stack(alignment: Alignment.center, children: [
            CircularProgressIndicator(
              value: score / 100,
              strokeWidth: 8.w,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: color,
              strokeCap: StrokeCap.round,
            ),
            Column(mainAxisSize: MainAxisSize.min, children: [
              Text('$score', style: TextStyle(color: color, fontSize: 24.sp,
                  fontWeight: FontWeight.bold)),
              Text(emoji, style: TextStyle(fontSize: 14.sp)),
            ]),
          ]),
        ),
        SizedBox(width: 20.w),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مؤشر التميز السلوكي',
                style: TextStyle(color: Colors.white70, fontSize: 12.sp)),
            SizedBox(height: 4.h),
            Text(label, style: TextStyle(color: color, fontSize: 18.sp,
                fontWeight: FontWeight.bold)),
            SizedBox(height: 12.h),
            Row(children: [
              _miniStat('إيجابي', '$positives', const Color(0xFF4CAF50)),
              SizedBox(width: 16.w),
              _miniStat('سلبي', '$negatives', const Color(0xFFF44336)),
            ]),
          ],
        )),
      ]),
    );
  }

  Widget _miniStat(String label, String value, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(value, style: TextStyle(color: color, fontSize: 18.sp,
          fontWeight: FontWeight.bold)),
      Text(label, style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
    ],
  );

  // ─── Stats Row ────────────────────────────────────────────────────────────
  Widget _buildStatsRow({required int violations, required int excused,
      required int unexcused, required int late}) {
    final stats = [
      {'label': 'مخالفات', 'value': violations, 'icon': Icons.warning_amber,
        'color': const Color(0xFFF44336)},
      {'label': 'غياب بعذر', 'value': excused, 'icon': Icons.event_available,
        'color': const Color(0xFFFF9800)},
      {'label': 'غياب بلا عذر', 'value': unexcused, 'icon': Icons.cancel_presentation,
        'color': const Color(0xFFE53935)},
      {'label': 'تأخر', 'value': late, 'icon': Icons.access_time_filled,
        'color': const Color(0xFFFFC107)},
    ];

    return Row(
      children: stats.map((s) => Expanded(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 4.w),
          padding: EdgeInsets.symmetric(vertical: 14.h),
          decoration: BoxDecoration(
            color: (s['color'] as Color).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: (s['color'] as Color).withValues(alpha: 0.25)),
          ),
          child: Column(children: [
            Icon(s['icon'] as IconData, color: s['color'] as Color, size: 20.sp),
            SizedBox(height: 6.h),
            Text('${s['value']}', style: TextStyle(
                color: s['color'] as Color, fontSize: 20.sp,
                fontWeight: FontWeight.bold)),
            Text(s['label'] as String, style: TextStyle(
                color: Colors.white38, fontSize: 9.sp),
                textAlign: TextAlign.center),
          ]),
        ),
      )).toList(),
    );
  }

  // ─── Permission Button ────────────────────────────────────────────────────
  Widget _buildPermissionButton(BuildContext context, User parent) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => ParentPermissionSheet(parent: parent, initialStudent: student)),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFB71C1C), Color(0xFFD32F2F)]),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(
            color: Colors.red.withValues(alpha: 0.3),
            blurRadius: 12, offset: const Offset(0, 4))],
        ),
        child: Row(children: [
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.exit_to_app, color: Colors.white, size: 22.sp)),
          SizedBox(width: 14.w),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('طلب استئذان', style: TextStyle(color: Colors.white,
                  fontSize: 16.sp, fontWeight: FontWeight.bold)),
              Text('خروج مبكر من المدرسة',
                  style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
            ],
          )),
          Icon(Icons.arrow_back_ios, color: Colors.white54, size: 14.sp),
        ]),
      ),
    );
  }

  // ─── Last Activity ────────────────────────────────────────────────────────
  Widget _buildLastActivity(List<BehaviorRecord> records) {
    final sorted = [...records]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final last = sorted.first;
    final isPositive = last.type == BehaviorType.positive;
    final color = isPositive ? const Color(0xFF4CAF50) : const Color(0xFFF44336);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(10.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.bolt, color: color, size: 20.sp)),
        SizedBox(width: 12.w),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('آخر نشاط', style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
            Text(last.description, style: TextStyle(color: Colors.white,
                fontSize: 14.sp, fontWeight: FontWeight.w600)),
            Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(last.timestamp),
                style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
          ],
        )),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8)),
          child: Text('${last.points > 0 ? '+' : ''}${last.points}',
              style: TextStyle(color: color, fontSize: 13.sp,
                  fontWeight: FontWeight.bold))),
      ]),
    );
  }

  // ─── Assignments ──────────────────────────────────────────────────────────
  Widget _buildAssignmentsSection(BuildContext context, WidgetRef ref,
      List<Assignment> assignments) {
    final upcoming  = assignments.where((a) => a.status != AssignmentStatus.approved).toList();
    final completed = assignments.where((a) => a.status == AssignmentStatus.approved).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('الواجبات القادمة', Icons.assignment, const Color(0xFF42A5F5)),
      SizedBox(height: 10.h),
      if (upcoming.isEmpty)
        _emptyState('لا يوجد واجبات قادمة')
      else
        ...upcoming.map((a) => _assignmentCard(a)),
      SizedBox(height: 16.h),
      _sectionHeader('الواجبات المنجزة', Icons.check_circle, const Color(0xFF4CAF50)),
      SizedBox(height: 10.h),
      if (completed.isEmpty)
        _emptyState('لم يتم إنجاز أي واجبات بعد')
      else
        ...completed.map((a) => _assignmentCard(a)),
    ]);
  }

  Widget _assignmentCard(Assignment a) {
    final isApproved = a.status == AssignmentStatus.approved;
    final color = isApproved ? const Color(0xFF4CAF50) : const Color(0xFFFF9800);
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8)),
          child: Icon(isApproved ? Icons.check : Icons.assignment,
              color: color, size: 18.sp)),
        SizedBox(width: 12.w),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(a.title, style: TextStyle(color: Colors.white, fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                decoration: isApproved ? TextDecoration.lineThrough : null,
                decorationColor: Colors.white38)),
            Text('${a.subject} • ${intl.DateFormat('yyyy/MM/dd').format(a.dueDate)}',
                style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
          ],
        )),
        Icon(isApproved ? Icons.check_circle : Icons.access_time,
            color: color, size: 18.sp),
      ]),
    );
  }

  // ─── Activity Log ─────────────────────────────────────────────────────────
  Widget _buildActivityLog(List<BehaviorRecord> records) {
    final sorted = [...records]..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final recent = sorted.take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionHeader('سجل النشاط', Icons.history, const Color(0xFF9C27B0)),
      SizedBox(height: 10.h),
      if (recent.isEmpty)
        _emptyState('لا يوجد سجل نشاط حتى الآن')
      else
        ...recent.map((r) {
          final isPos = r.type == BehaviorType.positive;
          final color = isPos ? const Color(0xFF4CAF50) : const Color(0xFFF44336);
          return Container(
            margin: EdgeInsets.only(bottom: 8.h),
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06))),
            child: Row(children: [
              Container(
                width: 36.w, height: 36.w,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle),
                child: Center(child: Icon(
                    isPos ? Icons.thumb_up : Icons.thumb_down,
                    color: color, size: 16.sp))),
              SizedBox(width: 12.w),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.description, style: TextStyle(color: Colors.white,
                      fontSize: 12.sp, fontWeight: FontWeight.w500)),
                  Text(intl.DateFormat('yyyy/MM/dd HH:mm').format(r.timestamp),
                      style: TextStyle(color: Colors.white38, fontSize: 10.sp)),
                ],
              )),
              Text('${r.points > 0 ? '+' : ''}${r.points}',
                  style: TextStyle(color: color, fontSize: 14.sp,
                      fontWeight: FontWeight.bold)),
            ]),
          );
        }),
    ]);
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  Widget _sectionHeader(String title, IconData icon, Color color) => Row(children: [
    Container(
      padding: EdgeInsets.all(6.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: color, size: 16.sp)),
    SizedBox(width: 10.w),
    Text(title, style: TextStyle(color: Colors.white, fontSize: 15.sp,
        fontWeight: FontWeight.bold)),
  ]);

  Widget _emptyState(String msg) => Container(
    padding: EdgeInsets.all(16.w),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.03),
      borderRadius: BorderRadius.circular(12)),
    child: Center(child: Text(msg,
        style: TextStyle(color: Colors.white38, fontSize: 13.sp))),
  );
}
