import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../assignments/domain/assignment.dart';
import '../../assignments/data/mock_assignment_repository.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../attendance/data/student_attendance_repository.dart';

// Provider for attendance history moved to student_attendance_repository.dart

// --- Pledges Screen ---
class ParentPledgesScreen extends ConsumerWidget {
  final User student;
  const ParentPledgesScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('التعهدات'), centerTitle: true),
      body: behaviorAsync.when(
        data: (records) {
          // Filter for negative behaviors (assuming these are pledges/violations)
          final pledges = records
              .where((r) => r.type == BehaviorType.negative)
              .toList();

          if (pledges.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.thumb_up_alt_outlined,
                    size: 64.w,
                    color: Colors.green,
                  ),
                  SizedBox(height: 16.h),
                  const Text(
                    'لا يوجد تعهدات مسجلة',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: pledges.length,
            itemBuilder: (context, index) {
              final pledge = pledges[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
                child: ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.redAccent,
                    child: Icon(Icons.gavel, color: Colors.white),
                  ),
                  title: Text('تعهد / مخالفة'),
                  subtitle: Text(
                    'السبب: ${pledge.description}\nالتاريخ: ${intl.DateFormat('yyyy-MM-dd').format(pledge.timestamp)}',
                  ),
                  isThreeLine: true,
                  trailing: const Icon(Icons.info_outline),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('حدث خطأ: $err')),
      ),
    );
  }
}

// --- Attendance Screen ---
class ParentAttendanceScreen extends ConsumerWidget {
  final User student;
  const ParentAttendanceScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(
      studentAttendanceHistoryProvider(student),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('سجل الغياب'), centerTitle: true),
      body: attendanceAsync.when(
        data: (attendanceList) {
          final absenceCount = attendanceList
              .where((a) => a.status == StudentAttendanceStatus.absent)
              .length;
          final lateCount = attendanceList
              .where((a) => a.status == StudentAttendanceStatus.late)
              .length;

          // Filter to show only non-present records for the log
          final displayList = attendanceList
              .where((a) => a.status != StudentAttendanceStatus.present)
              .toList();

          if (attendanceList.isEmpty) {
            return const Center(child: Text('لا يوجد سجلات حضور مسجلة'));
          }

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildStatSummary(absenceCount, lateCount),
              SizedBox(height: 20.h),
              const Text(
                'تفاصيل الغياب',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              SizedBox(height: 10.h),
              if (displayList.isEmpty)
                Padding(
                  padding: EdgeInsets.all(16.h),
                  child: const Center(
                    child: Text('سجل الحضور ممتاز! لا يوجد غياب أو تأخير.'),
                  ),
                )
              else
                ...displayList.map((a) => _buildAbsenceItem(a)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildStatSummary(int absence, int lates) {
    return Row(
      children: [
        Expanded(child: _buildCard('أيام الغياب', '$absence', Colors.red)),
        SizedBox(width: 10.w),
        Expanded(child: _buildCard('التأخيرات', '$lates', Colors.orange)),
      ],
    );
  }

  Widget _buildCard(String title, String value, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: TextStyle(color: Colors.grey.shade700)),
        ],
      ),
    );
  }

  Widget _buildAbsenceItem(StudentAttendance record) {
    String title;
    Color color;
    switch (record.status) {
      case StudentAttendanceStatus.absent:
        title = 'غياب بدون عذر';
        color = Colors.red;
        break;
      case StudentAttendanceStatus.excused:
        title = 'غياب بعذر';
        color = Colors.orange;
        break;
      case StudentAttendanceStatus.late:
        title = 'تأخر صباحي';
        color = Colors.amber.shade800;
        break;
      default:
        title = 'حاضر';
        color = Colors.green;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      child: ListTile(
        leading: Icon(Icons.event_busy, color: color),
        title: Text(title),
        subtitle: Text(intl.DateFormat('yyyy-MM-dd').format(record.date)),
      ),
    );
  }
}

// --- Assignments Screen ---
class ParentAssignmentsScreen extends ConsumerWidget {
  final User student;
  const ParentAssignmentsScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final assignmentsAsync = ref.watch(studentAssignmentsProvider(student.id));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text('الواجبات المدرسية'), centerTitle: true),
      body: assignmentsAsync.when(
        data: (assignments) {
          final completed = assignments
              .where((a) => a.status == AssignmentStatus.approved)
              .toList();
          final upcoming = assignments
              .where((a) => a.status != AssignmentStatus.approved)
              .toList();

          return ListView(
            padding: EdgeInsets.all(16.w),
            children: [
              _buildSectionTitle('الواجبات القادمة', Colors.orange),
              if (upcoming.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لا يوجد واجبات قادمة'),
                  ),
                )
              else
                ...upcoming.map((a) => _buildAssignmentItem(a)),

              SizedBox(height: 24.h),

              _buildSectionTitle('الواجبات المنجزة', Colors.green),
              if (completed.isEmpty)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text('لم يتم إنجاز أي واجبات بعد'),
                  ),
                )
              else
                ...completed.map((a) => _buildAssignmentItem(a)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color color) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Container(width: 4.w, height: 24.h, color: color),
          SizedBox(width: 8.w),
          Text(
            title,
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignmentItem(Assignment assignment) {
    final isApproved = assignment.status == AssignmentStatus.approved;
    final isSubmitted = assignment.status == AssignmentStatus.submitted;

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 2,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: isApproved
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.orange.withValues(alpha: 0.1),
          child: Icon(
            isApproved
                ? Icons.check_circle
                : (isSubmitted ? Icons.access_time : Icons.assignment_outlined),
            color: isApproved ? Colors.green : Colors.orange,
          ),
        ),
        title: Text(
          assignment.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${assignment.subject} • موعد التسليم: ${intl.DateFormat('yyyy-MM-dd').format(assignment.dueDate)}',
        ),
        trailing: isApproved
            ? const Text(
                'مكتمل',
                style: TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.bold,
                ),
              )
            : (isSubmitted
                  ? const Text(
                      'قيد المراجعة',
                      style: TextStyle(
                        color: Colors.orange,
                        fontWeight: FontWeight.bold,
                      ),
                    )
                  : const Text(
                      'لم يسلم',
                      style: TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    )),
      ),
    );
  }
}
