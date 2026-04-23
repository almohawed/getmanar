import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

/// زر عائم لماسح الهوية - يظهر في جميع لوحات التحكم
class QrScannerFab extends StatelessWidget {
  const QrScannerFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        try {
          context.push('/student-scan');
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تعذر فتح ماسح الهوية'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
      backgroundColor: Colors.indigo.shade700,
      elevation: 8,
      icon: Icon(
        Icons.qr_code_scanner,
        size: 28.sp,
        color: Colors.white,
      ),
      label: Text(
        'ماسح الهوية',
        style: TextStyle(
          fontSize: 16.sp,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }
}
