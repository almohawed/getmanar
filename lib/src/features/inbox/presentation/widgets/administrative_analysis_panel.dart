
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../application/inbox_service.dart';
import '../../domain/transaction.dart';

class AdministrativeAnalysisPanel extends StatelessWidget {
  final String schoolId;
  final InboxService inboxService;

  const AdministrativeAnalysisPanel({
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
            'التحليل الإداري الذكي',
            style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          FutureBuilder<AdministrativeAnalysis>(
            future: inboxService.getAnalysis(schoolId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final analysis = snapshot.data!;
              return Column(
                children: [
                  _buildAnalysisItem(
                    icon: Icons.maps_home_work_outlined,
                    label: 'أكثر جهة مرسلة',
                    value: analysis.topSenderEntity,
                    color: Colors.blue.shade700,
                  ),
                  SizedBox(height: 10.h),
                  _buildAnalysisItem(
                    icon: Icons.warning_amber_rounded,
                    label: 'أكثر نوع يتأخر',
                    value: _getTypeName(analysis.mostDelayedType),
                    color: Colors.orange.shade800,
                  ),
                  SizedBox(height: 10.h),
                  _buildAnalysisItem(
                    icon: Icons.calendar_today,
                    label: 'أيام الذروة في الأسبوع',
                    value: analysis.peakDays.join(', '),
                    color: Colors.purple.shade700,
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'ملخص: ${analysis.summary}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20.sp),
        SizedBox(width: 10.w),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
            Text(value, style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  String _getTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.financial:
        return 'مالي';
      case TransactionType.administrative:
        return 'إداري';
      case TransactionType.student:
        return 'طلابي';
      case TransactionType.circular:
        return 'تعميم';
      case TransactionType.complaint:
        return 'شكوى';
      case TransactionType.other:
        return 'أخرى';
    }
  }
}
