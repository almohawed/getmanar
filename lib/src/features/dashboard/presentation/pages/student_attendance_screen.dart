import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;
import '../../../../core/domain/models/user.dart';
import '../../../attendance/domain/student_attendance.dart';
import '../../../attendance/data/student_attendance_repository.dart';

class StudentAttendanceScreen extends ConsumerWidget {
  final User student;

  const StudentAttendanceScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attendanceAsync = ref.watch(
      studentAttendanceHistoryProvider(student),
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          'سجل الغياب',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: attendanceAsync.when(
        data: (attendanceList) {
          // Calculate stats
          final unexcusedAbsenceCount = attendanceList
              .where((a) => a.status == StudentAttendanceStatus.absent)
              .length;
          final excusedAbsenceCount = attendanceList
              .where((a) => a.status == StudentAttendanceStatus.excused)
              .length;
          final lateCount = attendanceList
              .where((a) => a.status == StudentAttendanceStatus.late)
              .length;

          // Filter out 'present' for the list
          final displayList = attendanceList
              .where((a) => a.status != StudentAttendanceStatus.present)
              .toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      // Summary Cards Row
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryCard(
                              'غياب بعذر',
                              excusedAbsenceCount.toString(),
                              Colors.teal,
                              Icons.verified_user_outlined,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildSummaryCard(
                              'غياب بدون عذر',
                              unexcusedAbsenceCount.toString(),
                              Colors.red,
                              Icons.cancel_outlined,
                            ),
                          ),
                          SizedBox(width: 12.w),
                          Expanded(
                            child: _buildSummaryCard(
                              'تأخر',
                              lateCount.toString(),
                              Colors.orange,
                              Icons.access_time,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 24.h),

                      // List Header
                      if (displayList.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.history,
                              color: Colors.indigo,
                              size: 24.sp,
                            ),
                            SizedBox(width: 8.w),
                            Text(
                              'سجل الحضور والغياب',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo[900],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              // Attendance List
              if (displayList.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 64.sp,
                          color: Colors.green,
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          'سجلك ممتاز! لا يوجد غياب أو تأخير',
                          style: TextStyle(
                            fontSize: 16.sp,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final record = displayList[index];
                    return _buildAttendanceItem(record);
                  }, childCount: displayList.length),
                ),

              SliverPadding(padding: EdgeInsets.only(bottom: 24.h)),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Text(
              'حدث خطأ في تحميل البيانات: $e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String count,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 8.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 8.h),
          Text(
            count,
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.sp,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceItem(StudentAttendance record) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (record.status) {
      case StudentAttendanceStatus.absent:
        statusColor = Colors.red;
        statusText = 'غياب بدون عذر';
        statusIcon = Icons.close;
        break;
      case StudentAttendanceStatus.excused:
        statusColor = Colors.teal;
        statusText = 'غياب بعذر';
        statusIcon = Icons.assignment_turned_in_outlined;
        break;
      case StudentAttendanceStatus.late:
        statusColor = Colors.orange;
        statusText = 'تأخر';
        statusIcon = Icons.access_time;
        break;
      default:
        statusColor = Colors.grey;
        statusText = 'غير محدد';
        statusIcon = Icons.help_outline;
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6.w, color: statusColor),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          statusIcon,
                          color: statusColor,
                          size: 20.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              statusText,
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              intl.DateFormat(
                                'EEEE d MMMM yyyy',
                                'ar',
                              ).format(record.date),
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
