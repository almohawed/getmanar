import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/transaction.dart';
import 'transaction_card.dart';

class TransactionFlowBoard extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction) onTransactionTap;
  final Function(Transaction, TransactionStatus) onStatusChange;

  const TransactionFlowBoard({
    super.key,
    required this.transactions,
    required this.onTransactionTap,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 2,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: TransactionStatus.values
            .map((status) => _buildStatusColumn(context, status))
            .toList(),
      ),
    );
  }

  Widget _buildStatusColumn(BuildContext context, TransactionStatus status) {
    final columnTransactions = transactions
        .where((t) => t.status == status)
        .toList();

    return Expanded(
      child: DragTarget<Transaction>(
        onWillAccept: (data) => data?.status != status,
        onAccept: (data) {
          onStatusChange(data, status);
        },
        builder: (context, candidateData, rejectedData) {
          return Container(
            margin: EdgeInsets.symmetric(horizontal: 6.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade100.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildColumnHeader(status, columnTransactions.length),
                Expanded(
                  child: ListView.builder(
                    itemCount: columnTransactions.length,
                    itemBuilder: (context, index) {
                      final transaction = columnTransactions[index];
                      return Draggable<Transaction>(
                        data: transaction,
                        feedback: Material(
                          elevation: 4.0,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 250.w),
                            child: TransactionCard(transaction: transaction),
                          ),
                        ),
                        childWhenDragging: Opacity(
                          opacity: 0.5,
                          child: TransactionCard(transaction: transaction),
                        ),
                        child: InkWell(
                          onTap: () => onTransactionTap(transaction),
                          child: TransactionCard(transaction: transaction),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildColumnHeader(TransactionStatus status, int count) {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 8.w),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1.5),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _getStatusName(status),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.2),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: _getStatusColor(status),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusName(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.awaitingDirectorRouting:
        return 'بانتظار توجيه المدير';
      case TransactionStatus.routed:
        return 'تم التوجيه – قيد التنفيذ';
      case TransactionStatus.needsFollowup:
        return 'تحتاج متابعة';
      case TransactionStatus.delayed:
        return 'متأخرة';
      case TransactionStatus.closed:
        return 'مغلقة';
    }
  }

  Color _getStatusColor(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.awaitingDirectorRouting:
        return Colors.blue.shade700;
      case TransactionStatus.routed:
        return Colors.green.shade700;
      case TransactionStatus.needsFollowup:
        return Colors.orange.shade800;
      case TransactionStatus.delayed:
        return Colors.red.shade700;
      case TransactionStatus.closed:
        return Colors.grey.shade600;
    }
  }
}
