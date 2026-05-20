import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'تحضيري الآن',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF1565C0),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 500),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 32.h),
            child: slotAsync.when(
              data: (slot) {
                final isPending =
                    slot?.attendanceStatus == AttendanceStatus.pending ||
                    slot == null;
                final subjectName = slot?.subject ?? 'تسجيل حضور إضافي';
                final className = slot?.className ?? 'خارج الجدول';

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header Card
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(24.r),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF0D47A1)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20.r),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1565C0).withOpacity(0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'الحصة الحالية',
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                color: Colors.white.withOpacity(0.9),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          SizedBox(height: 16.h),
                          Text(
                            subjectName,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.cairo(
                              fontSize: 22.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          SizedBox(height: 8.h),
                          Container(
                            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            child: Text(
                              className,
                              style: GoogleFonts.cairo(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 40.h),

                    // Status or Buttons
                    if (!isPending && slot != null)
                      _buildModernStatusBadge(slot.attendanceStatus)
                    else
                      _buildModernButtons(slot?.id),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0))),
              error: (e, s) => Text(
                'خطأ: $e',
                style: GoogleFonts.cairo(fontSize: 16.sp),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildModernStatusBadge(AttendanceStatus status) {
    Color color;
    String text;
    IconData icon;
    switch (status) {
      case AttendanceStatus.present:
        color = const Color(0xFF2E7D32);
        text = 'تم التحضير: حاضر';
        icon = Icons.check_circle_rounded;
        break;
      case AttendanceStatus.late:
        color = const Color(0xFFE65100);
        text = 'تم التحضير: متأخر';
        icon = Icons.access_time_rounded;
        break;
      case AttendanceStatus.absent:
        color = const Color(0xFFC62828);
        text = 'تم التحضير: غائب';
        icon = Icons.block_rounded;
        break;
      default:
        color = Colors.grey;
        text = 'غير معروف';
        icon = Icons.help_rounded;
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 32.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color, width: 2),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.r),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 64.r,
              color: color,
            ),
          ),
          SizedBox(height: 20.h),
          Text(
            text,
            textAlign: TextAlign.center,
            style: GoogleFonts.cairo(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernButtons(String? scheduleId) {
    return Column(
      children: [
        // Main Button - Present
        _buildModernActionButton(
          label: 'حاضر في الفصل',
          color: const Color(0xFF2E7D32),
          icon: Icons.check_circle_rounded,
          onTap: () => _recordStatus(scheduleId, AttendanceStatus.present),
          isPrimary: true,
        ),
        SizedBox(height: 16.h),

        // Secondary Buttons
        Row(
          children: [
            Expanded(
              child: _buildModernActionButton(
                label: 'تأخرت قليلاً',
                color: const Color(0xFFE65100),
                icon: Icons.access_time_rounded,
                onTap: () => _recordStatus(scheduleId, AttendanceStatus.late),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: _buildModernActionButton(
                label: 'اعتذار عن الحصة',
                color: const Color(0xFFC62828),
                icon: Icons.block_rounded,
                onTap: () => _recordStatus(scheduleId, AttendanceStatus.absent),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildModernActionButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
    bool isPrimary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: isPrimary ? 16 : 12,
            offset: Offset(0, isPrimary ? 6 : 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: isPrimary ? 24.r : 20.r),
        label: Text(
          label,
          style: GoogleFonts.cairo(
            fontSize: isPrimary ? 16.sp : 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(
            vertical: isPrimary ? 18.h : 14.h,
            horizontal: isPrimary ? 24.w : 16.w,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.r),
          ),
          elevation: 0,
        ),
      ),
    );
  }
}
