import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class CaseDetailsScreen extends StatelessWidget {
  final String? caseId;
  const CaseDetailsScreen({super.key, this.caseId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('تفاصيل القضية')),
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open, size: 64, color: Colors.teal),
              SizedBox(height: 16.h),
              Text(
                caseId != null ? 'رقم القضية: $caseId' : 'لم يتم تمرير معرف القضية',
                style: TextStyle(fontSize: 16.sp),
              ),
              SizedBox(height: 8.h),
              const Text('شاشة تفاصيل القضية (قيد التطوير)'),
            ],
          ),
        ),
      ),
    );
  }
}
