import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/teacher_attendance_service.dart';
import '../domain/school_schedule.dart';

class TeacherAttendanceScreen extends ConsumerStatefulWidget {
  const TeacherAttendanceScreen({super.key});

  @override
  ConsumerState<TeacherAttendanceScreen> createState() =>
      _TeacherAttendanceScreenState();
}

class _TeacherAttendanceScreenState
    extends ConsumerState<TeacherAttendanceScreen> {
  late String _currentDay;
  late int _currentPeriod;

  @override
  void initState() {
    super.initState();
    _currentDay = _getCurrentDayName();
    _currentPeriod = _calculateCurrentPeriod();
  }

  String _getCurrentDayName() {
    final now = DateTime.now();
    switch (now.weekday) {
      case DateTime.sunday:
        return 'الأحد';
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      default:
        return 'الأحد';
    }
  }

  int _calculateCurrentPeriod() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day, 7, 0);
    final diff = now.difference(start).inMinutes;
    if (diff < 0) return 1;
    final period = (diff / 50).ceil();
    if (period > 7) return 7;
    if (period < 1) return 1;
    return period;
  }

  Future<void> _recordStatus(
    String? scheduleId,
    AttendanceStatus status,
  ) async {
    try {
      await ref
          .read(teacherAttendanceServiceProvider)
          .recordAttendance(
            scheduleId:
                scheduleId ??
                'adhoc_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
            status: status,
            source: 'attendance_screen',
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null)
      return const Scaffold(body: Center(child: Text('يجب تسجيل الدخول')));

    final slotAsync = ref.watch(
      teacherCurrentSlotProvider((
        schoolId: user.schoolId ?? '',
        teacherId: user.id,
        day: _currentDay,
        period: _currentPeriod,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('تحضيري الآن'), centerTitle: true),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20.r),
          child: slotAsync.when(
            data: (slot) {
              // Always show buttons, even if slot is null (User Requirement 3)
              final isPending =
                  slot?.attendanceStatus == AttendanceStatus.pending ||
                  slot == null;
              final subjectName = slot?.subject ?? 'تسجيل حضور إضافي';
              final className = slot?.className ?? 'خارج الجدول';

              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'الحصة الحالية',
                    style: TextStyle(fontSize: 16.sp, color: Colors.grey),
                  ),
                  SizedBox(height: 10.h),
                  Text(
                    '$subjectName - $className',
                    style: TextStyle(
                      fontSize: 24.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 40.h),

                  if (!isPending && slot != null)
                    _buildBigStatusBadge(slot.attendanceStatus)
                  else
                    _buildAdHocButtons(slot?.id),
                ],
              );
            },
            loading: () => const CircularProgressIndicator(),
            error: (e, s) => Text('خطأ: $e'),
          ),
        ),
      ),
    );
  }

  Widget _buildAdHocButtons(String? scheduleId) {
    return Column(
      children: [
        _buildBigActionButton(
          'حاضر في الفصل',
          Colors.green,
          Icons.check_circle,
          () => _recordStatus(scheduleId, AttendanceStatus.present),
        ),
        SizedBox(height: 16.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBigActionButton(
              'تأخرت قليلاً',
              Colors.orange,
              Icons.access_time,
              () => _recordStatus(scheduleId, AttendanceStatus.late),
              isSmall: true,
            ),
            SizedBox(width: 16.w),
            _buildBigActionButton(
              'اعتذار عن الحصة',
              Colors.red,
              Icons.block,
              () => _recordStatus(scheduleId, AttendanceStatus.absent),
              isSmall: true,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBigStatusBadge(AttendanceStatus status) {
    Color color;
    String text;
    IconData icon;
    switch (status) {
      case AttendanceStatus.present:
        color = Colors.green;
        text = 'تم التحضير: حاضر';
        icon = Icons.check_circle;
        break;
      case AttendanceStatus.late:
        color = Colors.orange;
        text = 'تم التحضير: متأخر';
        icon = Icons.warning;
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        text = 'تم التحضير: غائب';
        icon = Icons.error;
        break;
      default:
        color = Colors.grey;
        text = 'غير معروف';
        icon = Icons.help;
    }

    return Container(
      padding: EdgeInsets.all(20.r),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Icon(icon, size: 40.sp, color: color),
          SizedBox(height: 8.h),
          Text(
            text,
            style: TextStyle(color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildBigActionButton(
    String label,
    Color color,
    IconData icon,
    VoidCallback onTap, {
    bool isSmall = false,
  }) {
    return SizedBox(
      width: isSmall ? 120.w : 200.w,
      height: isSmall ? 50.h : 60.h,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white),
        label: Text(
          label,
          style: TextStyle(
            fontSize: isSmall ? 14.sp : 18.sp,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
      ),
    );
  }
}
