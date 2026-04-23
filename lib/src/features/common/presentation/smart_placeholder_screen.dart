import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:google_fonts/google_fonts.dart';

class SmartPlaceholderScreen extends StatelessWidget {
  final String title;
  final Color themeColor;
  final IconData icon;

  const SmartPlaceholderScreen({
    super.key,
    required this.title,
    this.themeColor = Colors.indigo,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, fontSize: 18.sp),
        ),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FadeInDown(
                child: Container(
                  padding: EdgeInsets.all(24.w),
                  decoration: BoxDecoration(
                    color: themeColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 80.sp, color: themeColor),
                ),
              ),
              SizedBox(height: 24.h),
              FadeInUp(
                delay: const Duration(milliseconds: 200),
                child: Text(
                  'جاري تطوير قسم "$title"',
                  style: GoogleFonts.cairo(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              FadeInUp(
                delay: const Duration(milliseconds: 400),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32.w),
                  child: Text(
                    'نعمل حالياً على بناء واجهة تخصصية تليق بهذا القسم وتلبي احتياجاتكم بدقة.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cairo(
                      fontSize: 14.sp,
                      color: Colors.grey.shade600,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
              SizedBox(height: 40.h),
              FadeInUp(
                delay: const Duration(milliseconds: 600),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back),
                  label: Text('العودة للرئيسية', style: GoogleFonts.cairo()),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 32.w, vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
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
