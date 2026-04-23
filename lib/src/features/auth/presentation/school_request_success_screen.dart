import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

class SchoolRequestSuccessScreen extends StatelessWidget {
  const SchoolRequestSuccessScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(24.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(
                Icons.check_circle_outline,
                color: Colors.green,
                size: 80.sp,
              ),
              SizedBox(height: 24.h),
              Text(
                'تم استلام طلب التفعيل',
                style: TextStyle(
                  fontSize: 24.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Text(
                'تم استلام طلب تفعيل حساب المدرسة بنجاح.',
                style: TextStyle(
                  fontSize: 16.sp,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade100),
                ),
                child: Column(
                  children: [
                    Text(
                      'حالة الطلب: قيد المراجعة الإدارية',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                    SizedBox(height: 12.h),
                    Text(
                      'يخضع الطلب حالياً لإجراءات المراجعة والاعتماد.\nسيتم إرسال رمز تحقق (OTP) إلى رقم الجوال المسجل فور اعتماد الطلب لاستكمال إجراءات التفعيل.',
                      style: TextStyle(
                        fontSize: 14.sp,
                        color: Colors.blue.shade800,
                        height: 1.6,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              Text(
                'في حال وجود استفسار، يمكن التواصل عبر القنوات الرسمية الموضحة في صفحة الدعم.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 40.h),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'العودة إلى صفحة تسجيل الدخول',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
