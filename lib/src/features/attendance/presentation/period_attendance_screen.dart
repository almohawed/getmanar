import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/teacher_attendance_service.dart';
import '../domain/school_schedule.dart';

class PeriodAttendanceScreen extends ConsumerStatefulWidget {
  const PeriodAttendanceScreen({super.key});

  @override
  ConsumerState<PeriodAttendanceScreen> createState() =>
      _PeriodAttendanceScreenState();
}

class _PeriodAttendanceScreenState
    extends ConsumerState<PeriodAttendanceScreen> {
  int _selectedPeriod = 1;
  late String _currentDay;

  @override
  void initState() {
    super.initState();
    _currentDay = _getCurrentDayName();
    _selectedPeriod = _calculateCurrentPeriod();
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    if (schoolId.isEmpty) {
      return const Scaffold(body: Center(child: Text('غير مصرح')));
    }

    final scheduleAsync = ref.watch(
      currentPeriodScheduleProvider((
        schoolId: schoolId,
        day: _currentDay,
        period: _selectedPeriod,
      )),
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'تحضير الحصص - الوكيل',
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
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: scheduleAsync.when(
                data: (schedules) {
                  if (schedules.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(32.r),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.event_busy_rounded,
                              size: 64.r,
                              color: Colors.grey.shade400,
                            ),
                          ),
                          SizedBox(height: 24.h),
                          Text(
                            'لا توجد حصص مسجلة',
                            style: GoogleFonts.cairo(
                              fontSize: 18.sp,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            'الحصة $_selectedPeriod في يوم $_currentDay',
                            style: GoogleFonts.cairo(
                              fontSize: 14.sp,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  // Sort by Class Name
                  schedules.sort((a, b) => a.className.compareTo(b.className));

                  return ListView.separated(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 20.h),
                    itemCount: schedules.length,
                    separatorBuilder: (_, __) => SizedBox(height: 12.h),
                    itemBuilder: (context, index) {
                      final schedule = schedules[index];
                      return _TeacherAttendanceCard(
                        schedule: schedule,
                        isDeputy: true,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                ),
                error: (e, s) => Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.r),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline_rounded,
                            color: Colors.red.shade400, size: 64.r),
                        SizedBox(height: 16.h),
                        Text(
                          'خطأ في تحميل البيانات',
                          style: GoogleFonts.cairo(
                              fontSize: 18.sp, color: Colors.grey.shade700),
                        ),
                        SizedBox(height: 8.h),
                        Text(
                          '$e',
                          style: GoogleFonts.cairo(
                              fontSize: 14.sp, color: Colors.grey.shade500),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: const Color(0xFF1565C0).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              'اليوم: $_currentDay',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16.sp,
                color: const Color(0xFF1565C0),
              ),
            ),
          ),
          SizedBox(width: 24.w),
          Text(
            'الحصة:',
            style: GoogleFonts.cairo(
              fontSize: 16.sp,
              color: Colors.grey.shade700,
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: DropdownButton<int>(
              value: _selectedPeriod,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  color: Color(0xFF1565C0)),
              underline: const SizedBox(),
              items: List.generate(7, (index) => index + 1)
                  .map((p) => DropdownMenuItem(
                        value: p,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12.w),
                          child: Text(
                            '$p',
                            style: GoogleFonts.cairo(
                              fontWeight: FontWeight.bold,
                              fontSize: 18.sp,
                            ),
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (val) {
                if (val != null) setState(() => _selectedPeriod = val);
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TeacherAttendanceCard extends ConsumerStatefulWidget {
  final SchoolSchedule schedule;
  final bool isDeputy;

  const _TeacherAttendanceCard({
    required this.schedule,
    required this.isDeputy,
  });

  @override
  ConsumerState<_TeacherAttendanceCard> createState() =>
      _TeacherAttendanceCardState();
}

class _TeacherAttendanceCardState
    extends ConsumerState<_TeacherAttendanceCard> {
  bool _isLoading = false;

  Future<void> _updateStatus(AttendanceStatus status, {String? reason}) async {
    setState(() => _isLoading = true);
    try {
      await ref.read(teacherAttendanceServiceProvider).recordAttendance(
            scheduleId: widget.schedule.id,
            status: status,
            source: widget.isDeputy ? 'period_screen' : 'attendance_screen',
            reason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20.r),
                SizedBox(width: 8.w),
                Text(
                  'تم تسجيل التحضير بنجاح',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 20.r),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    e.toString().replaceAll('Exception: ', ''),
                    style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFC62828),
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12.r),
            ),
            margin: EdgeInsets.symmetric(horizontal: 24.w, vertical: 24.h),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showModificationDialog() {
    final reasonController = TextEditingController();
    AttendanceStatus selectedStatus = widget.schedule.attendanceStatus;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit_rounded, color: Color(0xFF1565C0)),
                SizedBox(width: 12.w),
                Text(
                  'تعديل حالة التحضير',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: EdgeInsets.all(12.r),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(12.r),
                      border:
                          Border.all(color: Colors.amber.shade400, width: 1.5),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.amber.shade700,
                          size: 24.r,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Text(
                            'سيتم تسجيل هذا التعديل في سجل التدقيق',
                            style: GoogleFonts.cairo(
                              fontSize: 13.sp,
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'الحالة الجديدة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonFormField<AttendanceStatus>(
                      value: selectedStatus,
                      icon: const Icon(Icons.keyboard_arrow_down_rounded),
                      decoration:
                          const InputDecoration(border: InputBorder.none),
                      items: [
                        AttendanceStatus.present,
                        AttendanceStatus.late,
                        AttendanceStatus.absent,
                      ].map((s) {
                        String label;
                        IconData icon;
                        Color color;
                        switch (s) {
                          case AttendanceStatus.present:
                            label = 'حاضر';
                            icon = Icons.check_circle_rounded;
                            color = const Color(0xFF2E7D32);
                            break;
                          case AttendanceStatus.late:
                            label = 'متأخر';
                            icon = Icons.access_time_rounded;
                            color = const Color(0xFFE65100);
                            break;
                          case AttendanceStatus.absent:
                            label = 'غائب';
                            icon = Icons.block_rounded;
                            color = const Color(0xFFC62828);
                            break;
                          default:
                            label = '-';
                            icon = Icons.help;
                            color = Colors.grey;
                        }
                        return DropdownMenuItem(
                          value: s,
                          child: Row(
                            children: [
                              Icon(icon, color: color, size: 20.r),
                              SizedBox(width: 8.w),
                              Text(
                                label,
                                style: GoogleFonts.cairo(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 15.sp,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null)
                          setStateDialog(() => selectedStatus = val);
                      },
                    ),
                  ),
                  SizedBox(height: 20.h),
                  Text(
                    'سبب التعديل (إلزامي)',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 15.sp,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  TextField(
                    controller: reasonController,
                    maxLines: 3,
                    style: GoogleFonts.cairo(),
                    decoration: InputDecoration(
                      hintText: 'اكتب سبب التعديل هنا...',
                      hintStyle: GoogleFonts.cairo(color: Colors.grey.shade500),
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                        borderSide: const BorderSide(
                            color: Color(0xFF1565C0), width: 2),
                      ),
                      helperText: 'مطلوب لتوثيق التغيير',
                      helperStyle:
                          GoogleFonts.cairo(color: Colors.grey.shade500),
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                ],
              ),
            ),
            actionsPadding: EdgeInsets.all(16.r),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'إلغاء',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade600,
                  ),
                ),
              ),
              ElevatedButton(
                onPressed: reasonController.text.trim().isEmpty
                    ? null
                    : () {
                        Navigator.pop(ctx);
                        _updateStatus(
                          selectedStatus,
                          reason: reasonController.text.trim(),
                        );
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1565C0),
                  foregroundColor: Colors.white,
                  padding:
                      EdgeInsets.symmetric(horizontal: 28.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: Text(
                  'حفظ التعديل',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.schedule.attendanceStatus;
    final isPending = status == AttendanceStatus.pending;

    Color statusColor;
    String statusText;
    IconData statusIcon;
    switch (status) {
      case AttendanceStatus.present:
        statusColor = const Color(0xFF2E7D32);
        statusText = 'حاضر';
        statusIcon = Icons.check_circle_rounded;
        break;
      case AttendanceStatus.late:
        statusColor = const Color(0xFFE65100);
        statusText = 'تأخر';
        statusIcon = Icons.access_time_rounded;
        break;
      case AttendanceStatus.absent:
        statusColor = const Color(0xFFC62828);
        statusText = 'غائب';
        statusIcon = Icons.block_rounded;
        break;
      default:
        statusColor = Colors.grey.shade400;
        statusText = 'غير مسجل';
        statusIcon = Icons.help_outline_rounded;
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1565C0).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: Text(
                      widget.schedule.className
                          .substring(
                              0,
                              widget.schedule.className.length > 3
                                  ? 3
                                  : widget.schedule.className.length)
                          .toUpperCase(),
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 18.sp,
                        color: const Color(0xFF1565C0),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المعلم: ${widget.schedule.teacherId}',
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.sp,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        '${widget.schedule.subject} - ${widget.schedule.className}',
                        style: GoogleFonts.cairo(
                          color: Colors.grey.shade600,
                          fontSize: 13.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPending) ...[
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 14.w, vertical: 7.h),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(color: statusColor, width: 1.5),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          color: statusColor,
                          size: 18.r,
                        ),
                        SizedBox(width: 6.w),
                        Text(
                          statusText,
                          style: GoogleFonts.cairo(
                            color: statusColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.isDeputy) ...[
                    SizedBox(width: 10.w),
                    IconButton(
                      icon: Container(
                        padding: EdgeInsets.all(8.r),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                        child: const Icon(Icons.edit_rounded,
                            color: Color(0xFF1565C0)),
                      ),
                      tooltip: 'تعديل الحالة',
                      onPressed: _showModificationDialog,
                    ),
                  ],
                ],
              ],
            ),
            if (isPending && widget.isDeputy) ...[
              SizedBox(height: 16.h),
              Divider(color: Colors.grey.shade200, thickness: 1),
              SizedBox(height: 16.h),
              if (_isLoading)
                const LinearProgressIndicator(
                  color: Color(0xFF1565C0),
                  backgroundColor: Color(0xFFE3F2FD),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: _ActionButton(
                        label: 'حاضر',
                        color: const Color(0xFF2E7D32),
                        icon: Icons.check_circle_rounded,
                        onTap: () => _updateStatus(AttendanceStatus.present),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _ActionButton(
                        label: 'تأخر',
                        color: const Color(0xFFE65100),
                        icon: Icons.access_time_rounded,
                        onTap: () => _updateStatus(AttendanceStatus.late),
                      ),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: _ActionButton(
                        label: 'غائب',
                        color: const Color(0xFFC62828),
                        icon: Icons.block_rounded,
                        onTap: () => _updateStatus(AttendanceStatus.absent),
                      ),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20.r),
      label: Text(
        label,
        style: GoogleFonts.cairo(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 14.sp,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(vertical: 12.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        elevation: 0,
      ),
    );
  }
}
