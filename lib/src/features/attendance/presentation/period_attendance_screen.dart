import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
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
    // Simple mapping for Arabic days
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
    // Logic to calculate period based on time.
    // Defaulting to 1 for now if outside hours, or maybe a simple logic.
    // Assuming 7:00 start, 45 min periods + 5 min break.
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
      appBar: AppBar(
        title: const Text('تحضير الحصص - الوكيل'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildPeriodSelector(),
          Expanded(
            child: scheduleAsync.when(
              data: (schedules) {
                if (schedules.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_busy, size: 64.sp, color: Colors.grey),
                        SizedBox(height: 16.h),
                        Text(
                          'لا توجد حصص مسجلة للحصة $_selectedPeriod في يوم $_currentDay',
                        ),
                      ],
                    ),
                  );
                }

                // Sort by Class Name
                schedules.sort((a, b) => a.className.compareTo(b.className));

                return ListView.builder(
                  padding: EdgeInsets.all(16.r),
                  itemCount: schedules.length,
                  itemBuilder: (context, index) {
                    final schedule = schedules[index];
                    return _TeacherAttendanceCard(
                      schedule: schedule,
                      isDeputy: true,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodSelector() {
    return Container(
      padding: EdgeInsets.all(16.r),
      color: Colors.blue.withOpacity(0.1),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'اليوم: $_currentDay',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
          ),
          SizedBox(width: 20.w),
          Text('الحصة:', style: TextStyle(fontSize: 16.sp)),
          SizedBox(width: 10.w),
          DropdownButton<int>(
            value: _selectedPeriod,
            items: List.generate(7, (index) => index + 1)
                .map((p) => DropdownMenuItem(value: p, child: Text('$p')))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _selectedPeriod = val);
            },
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
      await ref
          .read(teacherAttendanceServiceProvider)
          .recordAttendance(
            scheduleId: widget.schedule.id,
            status: status,
            source: widget.isDeputy ? 'period_screen' : 'attendance_screen',
            reason: reason,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل التحضير بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
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
            title: const Text('تعديل حالة التحضير'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.amber),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.warning_amber,
                          color: Colors.amber,
                          size: 20,
                        ),
                        SizedBox(width: 8.w),
                        const Expanded(
                          child: Text(
                            'سيتم تسجيل هذا التعديل في سجل التدقيق (Audit Log).',
                            style: TextStyle(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<AttendanceStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'الحالة الجديدة',
                    ),
                    items:
                        [
                          AttendanceStatus.present,
                          AttendanceStatus.late,
                          AttendanceStatus.absent,
                        ].map((s) {
                          String label;
                          switch (s) {
                            case AttendanceStatus.present:
                              label = 'حاضر';
                              break;
                            case AttendanceStatus.late:
                              label = 'متأخر';
                              break;
                            case AttendanceStatus.absent:
                              label = 'غائب';
                              break;
                            default:
                              label = '-';
                          }
                          return DropdownMenuItem(value: s, child: Text(label));
                        }).toList(),
                    onChanged: (val) {
                      if (val != null)
                        setStateDialog(() => selectedStatus = val);
                    },
                  ),
                  SizedBox(height: 16.h),
                  TextField(
                    controller: reasonController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'سبب التعديل (إلزامي)',
                      border: OutlineInputBorder(),
                      helperText: 'مطلوب لتوثيق التغيير',
                    ),
                    onChanged: (_) => setStateDialog(() {}),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء'),
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
                child: const Text('حفظ التعديل'),
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

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(widget.schedule.className)),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'المعلم: ${widget.schedule.teacherId}', // Ideal: Resolve Name
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14.sp,
                        ),
                      ),
                      Text(
                        '${widget.schedule.subject} - ${widget.schedule.className}',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isPending) ...[
                  _buildStatusBadge(status),
                  if (widget.isDeputy) ...[
                    SizedBox(width: 8.w),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        size: 20,
                        color: Colors.grey,
                      ),
                      tooltip: 'تعديل الحالة',
                      onPressed: _showModificationDialog,
                    ),
                  ],
                ],
              ],
            ),
            if (isPending && widget.isDeputy) ...[
              Divider(),
              if (_isLoading)
                const LinearProgressIndicator()
              else
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionButton(
                      label: 'حاضر',
                      color: Colors.green,
                      icon: Icons.check,
                      onTap: () => _updateStatus(AttendanceStatus.present),
                    ),
                    _ActionButton(
                      label: 'تأخر',
                      color: Colors.orange,
                      icon: Icons.access_time,
                      onTap: () => _updateStatus(AttendanceStatus.late),
                    ),
                    _ActionButton(
                      label: 'غائب',
                      color: Colors.red,
                      icon: Icons.close,
                      onTap: () => _updateStatus(AttendanceStatus.absent),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(AttendanceStatus status) {
    Color color;
    String text;
    switch (status) {
      case AttendanceStatus.present:
        color = Colors.green;
        text = 'حاضر';
        break;
      case AttendanceStatus.late:
        color = Colors.orange;
        text = 'تأخر';
        break;
      case AttendanceStatus.absent:
        color = Colors.red;
        text = 'غائب';
        break;
      default:
        color = Colors.grey;
        text = 'غير مسجل';
    }
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        child: Column(
          children: [
            Icon(icon, color: color),
            Text(
              label,
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
