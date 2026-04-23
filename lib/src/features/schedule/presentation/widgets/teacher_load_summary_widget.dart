import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// Widget يعرض ملخص حمل المعلم (الحصص المطلوبة، المجدولة، والفترات الحرة)
class TeacherLoadSummaryWidget extends StatelessWidget {
  final String teacherName;
  final int requiredLessons;
  final int actualLessons;
  final int freePeriods;
  final int totalPeriods;

  const TeacherLoadSummaryWidget({
    super.key,
    required this.teacherName,
    required this.requiredLessons,
    required this.actualLessons,
    required this.freePeriods,
    required this.totalPeriods,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = requiredLessons == actualLessons;
    final completionPercentage = totalPeriods > 0 
        ? (actualLessons / totalPeriods * 100).toStringAsFixed(1)
        : '0';

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: isComplete ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(
          color: isComplete ? Colors.green.shade300 : Colors.orange.shade300,
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(
                isComplete ? Icons.check_circle : Icons.info,
                color: isComplete ? Colors.green : Colors.orange,
                size: 24.sp,
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص حمل المعلم',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: isComplete ? Colors.green.shade900 : Colors.orange.shade900,
                      ),
                    ),
                    Text(
                      teacherName,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: isComplete ? Colors.green : Colors.orange,
                  borderRadius: BorderRadius.circular(20.r),
                ),
                child: Text(
                  '$completionPercentage%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),

          // Stats Grid
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                label: 'الحصص المطلوبة',
                value: requiredLessons.toString(),
                color: Colors.blue,
                icon: Icons.assignment,
              ),
              _buildStatCard(
                label: 'الحصص المجدولة',
                value: actualLessons.toString(),
                color: isComplete ? Colors.green : Colors.orange,
                icon: Icons.check_box,
              ),
              _buildStatCard(
                label: 'الفترات الحرة',
                value: freePeriods.toString(),
                color: Colors.grey,
                icon: Icons.free_cancellation,
              ),
            ],
          ),

          // Status Message
          SizedBox(height: 12.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Row(
              children: [
                Icon(
                  isComplete ? Icons.done_all : Icons.schedule,
                  color: isComplete ? Colors.green : Colors.orange,
                  size: 20.sp,
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    isComplete
                        ? 'تم تجديول جميع الحصص المطلوبة بنجاح'
                        : 'جاري تجديول الحصص المتبقية',
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: isComplete ? Colors.green.shade700 : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 20.sp),
          SizedBox(height: 6.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
