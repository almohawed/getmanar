import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class UnderConstructionScreen extends StatelessWidget {
  final String? title;

  const UnderConstructionScreen({super.key, this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title ?? 'قريباً'),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.engineering,
              size: 80.sp,
              color: Colors.orange,
            ),
            SizedBox(height: 24.h),
            Text(
              'هذه الصفحة قيد التطوير',
              style: TextStyle(
                fontSize: 20.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12.h),
            Text(
              'نعمل حالياً على تفعيل هذه الميزة',
              style: TextStyle(
                fontSize: 16.sp,
                color: Colors.grey,
              ),
            ),
            SizedBox(height: 32.h),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('عودة'),
            ),
          ],
        ),
      ),
    );
  }
}
