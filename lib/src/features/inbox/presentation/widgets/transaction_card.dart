
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../domain/transaction.dart';

class TransactionCard extends StatelessWidget {
  final Transaction transaction;

  const TransactionCard({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('ar', timeago.ArMessages());
    final daysInStatus = transaction.durationInCurrentStatus.inDays;

    return Card(
      margin: EdgeInsets.symmetric(vertical: 6.h, horizontal: 4.w),
      elevation: 2.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10.r),
        side: BorderSide(
          color: _getPriorityColor(transaction.priority).withOpacity(0.7),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildCardHeader(),
            SizedBox(height: 8.h),
            Text(
              transaction.subject,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: 10.h),
            _buildInfoRow(
              Icons.business_rounded,
              transaction.senderEntity,
            ),
            SizedBox(height: 6.h),
            _buildInfoRow(
              Icons.calendar_today_outlined,
              'مستلمة منذ: ${timeago.format(transaction.receivedAt, locale: 'ar')}',
            ),
            SizedBox(height: 10.h),
            _buildFooter(daysInStatus),
          ],
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '#${transaction.number}',
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade700,
          ),
        ),
        _buildPriorityChip(),
      ],
    );
  }

  Widget _buildPriorityChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: _getPriorityColor(transaction.priority).withOpacity(0.15),
        borderRadius: BorderRadius.circular(15.r),
      ),
      child: Text(
        _getPriorityName(transaction.priority),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
          color: _getPriorityColor(transaction.priority),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14.sp, color: Colors.grey.shade600),
        SizedBox(width: 6.w),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade800),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(int daysInStatus) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildTypeChip(),
        Row(
          children: [
            Icon(Icons.hourglass_bottom_rounded, size: 14.sp, color: Colors.teal.shade700),
            SizedBox(width: 4.w),
            Text(
              '$daysInStatus أيام',
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: Colors.teal.shade800,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeChip() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Text(
        _getTypeName(transaction.type),
        style: TextStyle(
          fontSize: 10.sp,
          fontWeight: FontWeight.w500,
          color: Colors.grey.shade800,
        ),
      ),
    );
  }

  String _getPriorityName(TransactionPriority priority) {
    switch (priority) {
      case TransactionPriority.critical:
        return 'عاجل جداً';
      case TransactionPriority.high:
        return 'مهم';
      case TransactionPriority.medium:
        return 'عادي';
      case TransactionPriority.low:
        return 'منخفض';
    }
  }

  Color _getPriorityColor(TransactionPriority priority) {
    switch (priority) {
      case TransactionPriority.critical:
        return Colors.red.shade800;
      case TransactionPriority.high:
        return Colors.amber.shade800;
      case TransactionPriority.medium:
        return Colors.blue.shade700;
      case TransactionPriority.low:
        return Colors.green.shade700;
    }
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
