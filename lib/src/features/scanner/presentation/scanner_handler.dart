import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/data/student_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../behavior/domain/bathroom_pass.dart';
import '../../behavior/data/firestore_bathroom_repository.dart';
import '../../academic/presentation/behavior_sheet.dart';
import '../../requests/data/permission_repository.dart';
import '../../requests/domain/permission_request.dart';
import '../../attendance/data/student_attendance_repository.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../academic/data/school_repository.dart';

class ScannerHandler {
  static Future<void> handleScanResult(
    BuildContext context,
    WidgetRef ref,
    String scanResult,
  ) async {
    // 1. Find Student by ID (Identity Number)
    // We need to query all students or find by specific field.
    // Assuming scanResult is the identityNumber.
    // Ideally, we should have a method findStudentByIdentity.
    // For now, we fetch all students in the school (cached/streamed) or query.
    // Let's assume we can use the repository to find.

    final user = ref.read(authStateProvider).value;
    if (user == null || user.schoolId == null) return;

    final studentRepo = ref.read(studentRepositoryProvider);
    // Find student by identity directly
    final student = await studentRepo.findStudentByIdentity(
      user.schoolId!,
      scanResult,
    );

    if (student == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('لم يتم العثور على طالب برقم الهوية: $scanResult'),
          ),
        );
      }
      return;
    }

    if (!context.mounted) return;

    // 2. Check for Active Bathroom Trip
    final bathroomRepo = ref.read(bathroomRepositoryProvider);
    final activeTrip = await bathroomRepo.getActivePass(student.id);

    if (!context.mounted) return;

    // 3. Show Action Sheet
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      builder: (context) => _ScanActionSheet(
        student: student,
        activeTrip: activeTrip,
        currentUser: user,
      ),
    );
  }
}

class _ScanActionSheet extends ConsumerWidget {
  final User student;
  final BathroomPass? activeTrip;
  final User currentUser;

  const _ScanActionSheet({
    required this.student,
    required this.activeTrip,
    required this.currentUser,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: EdgeInsets.all(24.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: Colors.indigo.shade100,
                child: Text(
                  student.name[0],
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'الهوية: ${student.identityNumber}',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 32.h),

          // Medical Alert
          if (student.healthStatus != null &&
              (student.healthStatus == 'bathroom' ||
                  student.healthStatus == 'care')) ...[
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.medical_services, color: Colors.blue),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Text(
                      'الطالب لديه حالة صحية خاصة — الاستئذان لا يدخل في التقييم السلوكي',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16.h),
          ],

          // Actions
          _buildAction(
            context,
            ref,
            icon: Icons.access_time_filled,
            color: Colors.indigo,
            label: 'تسجيل حضور صباحي',
            onTap: () async {
              Navigator.pop(context);
              await _markAttendance(context, ref);
            },
          ),
          SizedBox(height: 16.h),
          if (activeTrip != null) ...[
            _buildAction(
              context,
              ref,
              icon: Icons.check_circle_outline,
              color: Colors.green,
              label: 'تسجيل عودة من دورة المياه',
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref
                      .read(behaviorControllerProvider.notifier)
                      .returnStudentFromBathroom(activeTrip!, currentUser);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تسجيل العودة بنجاح'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('خطأ: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
            ),
          ] else ...[
            _buildAction(
              context,
              ref,
              icon: Icons.timer,
              color: Colors.orange,
              label: 'خروج لدورة المياه',
              onTap: () async {
                Navigator.pop(context);
                final record = BehaviorRecord(
                  id: const Uuid().v4(),
                  studentId: student.id,
                  teacherId: currentUser.id,
                  type: BehaviorType.bathroom,
                  description: 'خروج لدورة المياه',
                  points: 0,
                  timestamp: DateTime.now(),
                  bathroomExitTime: DateTime.now(),
                );
                await ref
                    .read(behaviorControllerProvider.notifier)
                    .addRecord(record);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الخروج')),
                  );
                }
              },
            ),
            SizedBox(height: 16.h),
            _buildAction(
              context,
              ref,
              icon: Icons.assignment_turned_in,
              color: Colors.blue,
              label: 'طلب استئذان (خروج من المدرسة)',
              onTap: () async {
                Navigator.pop(context);
                // Create Permission Request (Auto-approved if staff?)
                // Or just open dialog to confirm reason.
                _showPermissionDialog(context, ref);
              },
            ),
            SizedBox(height: 16.h),
            _buildAction(
              context,
              ref,
              icon: Icons.gavel,
              color: Colors.red,
              label: 'رصد مخالفة / سلوك',
              onTap: () {
                Navigator.pop(context);
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) => BehaviorSheet(student: student),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markAttendance(BuildContext context, WidgetRef ref) async {
    String? startTimeStr;
    if (currentUser.schoolId != null) {
      final school = await ref
          .read(schoolRepositoryProvider)
          .getSchool(currentUser.schoolId!);
      startTimeStr = school?.startTime;
    }

    final now = TimeOfDay.now();
    var status = StudentAttendanceStatus.present;

    if (startTimeStr != null) {
      final parts = startTimeStr.split(':');
      if (parts.length == 2) {
        final startH = int.parse(parts[0]);
        final startM = int.parse(parts[1]);
        final startMinutes = startH * 60 + startM;
        final nowMinutes = now.hour * 60 + now.minute;
        if (nowMinutes > startMinutes) {
          status = StudentAttendanceStatus.late;
        }
      }
    }

    final record = StudentAttendance(
      id: const Uuid().v4(),
      schoolId: currentUser.schoolId ?? '',
      studentId: student.id,
      studentName: student.name,
      classId: (student.assignedClassIds?.isNotEmpty ?? false)
          ? student.assignedClassIds!.first
          : 'unknown',
      date: DateTime.now(),
      status: status,
      arrivalTime: DateTime.now(),
      recordedBy: currentUser.id,
    );

    await ref.read(studentAttendanceRepositoryProvider).saveStudentAttendance([
      record,
    ]);

    if (context.mounted) {
      final msg = status == StudentAttendanceStatus.late
          ? 'تم تسجيل الحضور: متأخر'
          : 'تم تسجيل الحضور: حاضر';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: status == StudentAttendanceStatus.late
              ? Colors.orange
              : Colors.green,
        ),
      );
    }
  }

  Widget _buildAction(
    BuildContext context,
    WidgetRef ref, {
    required IconData icon,
    required Color color,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(width: 16.w),
            Text(
              label,
              style: TextStyle(
                fontSize: 16.sp,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPermissionDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل استئذان'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(
            labelText: 'سبب الاستئذان',
            hintText: 'مثال: موعد طبي',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (reasonController.text.isEmpty) return;

              // Try to find parent ID
              final behaviorRepo = ref.read(behaviorRepositoryProvider);
              final parentId = await behaviorRepo.getParentIdForStudent(
                student.id,
              );

              final request = PermissionRequest(
                id: const Uuid().v4(),
                studentId: student.id,
                studentName: student.name,
                parentId:
                    parentId ??
                    student.phoneNumber ??
                    '', // Fallback to phone or empty
                reason: reasonController.text,
                createdAt: DateTime.now(),
                status:
                    PermissionRequestStatus.approved, // Auto-approve by staff
                decidedAt: DateTime.now(),
              );

              await ref
                  .read(requestsProvider.notifier)
                  .addRequest(request, currentUser.schoolId ?? '');

              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تسجيل الاستئذان والموافقة عليه'),
                  ),
                );
              }
            },
            child: const Text('تسجيل وموافقة'),
          ),
        ],
      ),
    );
  }
}
