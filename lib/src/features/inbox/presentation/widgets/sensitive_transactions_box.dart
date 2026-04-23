
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/transaction.dart';
import 'transaction_card.dart';

class SensitiveTransactionsBox extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction) onTransactionTap;

  const SensitiveTransactionsBox({
    super.key,
    required this.transactions,
    required this.onTransactionTap,
  });

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.priority_high_rounded, color: Colors.red.shade700),
              SizedBox(width: 8.w),
              Text(
                'معاملات حساسة (${transactions.length})',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          SizedBox(
            height: 180.h, // Adjust height as needed
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                return SizedBox(
                  width: 250.w, // Adjust width as needed
                  child: InkWell(
                    onTap: () => onTransactionTap(transactions[index]),
                    child: TransactionCard(transaction: transactions[index]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
