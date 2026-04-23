import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'sent_violations_provider.dart';

class ViolationsLogScreen extends ConsumerWidget {
  const ViolationsLogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violations = ref.watch(sentViolationsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('سجل المخالفات')),
      body: violations.isEmpty
          ? const Center(child: Text('لا توجد مخالفات مسجلة'))
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: violations.length,
              itemBuilder: (context, index) {
                final violation = violations[index];
                return Card(
                  margin: EdgeInsets.only(bottom: 12.h),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.red.shade100,
                      child: const Icon(Icons.warning, color: Colors.red),
                    ),
                    title: Text(violation.description),
                    subtitle: Text(
                      'الطالب: ${violation.studentId} | التاريخ: ${DateFormat('yyyy-MM-dd').format(violation.timestamp)}',
                    ),
                    trailing: Container(
                      padding:
                          EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '-${violation.pointsDeducted}',
                        style: const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
