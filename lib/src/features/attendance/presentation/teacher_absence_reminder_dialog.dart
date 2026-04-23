import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

// This dialog is triggered if a teacher hasn't recorded attendance by the deadline.
class TeacherAbsenceReminderDialog extends ConsumerWidget {
  final String teacherId;
  final String periodName;

  const TeacherAbsenceReminderDialog({
    super.key,
    required this.teacherId,
    required this.periodName,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20.r)),
      title: Row(
        children: [
          Icon(Icons.notifications_active, color: Colors.amber, size: 28.sp),
          SizedBox(width: 8.w),
          Text(
            'تذكير تسجيل الغياب',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade800,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'معلمنا الفاضل 🌱',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'طلبًا لا أمر، نأمل التأكد من تسجيل الغياب لحصتك ($periodName).',
            style: TextStyle(fontSize: 14.sp, color: Colors.black54),
          ),
          SizedBox(height: 4.h),
          Text(
            'حرصك ينعكس أثرًا تربويًا عظيمًا 🤍',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade600,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            // Action: Navigate to Attendance Recording Screen
            Navigator.pop(context);
            // Assuming route name, replace with actual route
             context.push('/teacher-dashboard/attendance');
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('لا، لم أسجل بعد'),
        ),
        ElevatedButton.icon(
          onPressed: () {
            Navigator.pop(context);
            _showThankYouDialog(context);
          },
          icon: const Icon(Icons.check_circle, color: Colors.white, size: 18),
          label: const Text('نعم، تم التسجيل'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ],
    );
  }

  void _showThankYouDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20.r),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, color: Colors.amber, size: 60.sp),
                SizedBox(height: 16.h),
                Text(
                  'شكرًا لك 🌟',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'التزامك محل تقدير، وبجهودك نرتقي بطلابنا.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
    );
  }
}
