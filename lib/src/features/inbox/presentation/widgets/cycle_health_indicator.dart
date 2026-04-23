
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../../application/inbox_service.dart';
import '../../domain/transaction.dart';

class CycleHealthIndicatorWidget extends StatelessWidget {
  final String schoolId;
  final InboxService inboxService;

  const CycleHealthIndicatorWidget({
    super.key,
    required this.schoolId,
    required this.inboxService,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 3,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مؤشر سلامة الدورة الإدارية',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          FutureBuilder<CycleHealthIndicator>(
            future: inboxService.getCycleHealth(schoolId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final health = snapshot.data!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  CircularPercentIndicator(
                    radius: 50.r,
                    lineWidth: 10.0,
                    percent: health.overallScore / 100,
                    center: Text(
                      '${health.overallScore.toStringAsFixed(0)}%',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
                    ),
                    footer: Padding(
                      padding: EdgeInsets.only(top: 8.h),
                      child: Text(health.ratingArabic, style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    progressColor: _getHealthColor(health.overallScore),
                    backgroundColor: Colors.grey.shade200,
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHealthMetric('سرعة التوجيه', health.routingSpeed),
                      _buildHealthMetric('سرعة الإغلاق', health.closingSpeed),
                      _buildHealthMetric('نسبة التأخير', health.delayRate, invert: true),
                    ],
                  )
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildHealthMetric(String label, double value, {bool invert = false}) {
    final color = invert ? _getHealthColor(100 - value) : _getHealthColor(value);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Icon(Icons.circle, color: color, size: 12.sp),
          SizedBox(width: 8.w),
          Text('$label: ${value.toStringAsFixed(0)}%', style: TextStyle(fontSize: 13.sp)),
        ],
      ),
    );
  }

  Color _getHealthColor(double score) {
    if (score >= 85) return Colors.green.shade600;
    if (score >= 70) return Colors.orange.shade600;
    return Colors.red.shade600;
  }
}
