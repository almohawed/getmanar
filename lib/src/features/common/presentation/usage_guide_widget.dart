import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class UsageGuideButton extends StatelessWidget {
  final String title;
  final String usageText;

  const UsageGuideButton({
    super.key,
    required this.title,
    required this.usageText,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title, style: GoogleFonts.cairo()),
            content: SingleChildScrollView(
              child: Text(usageText, style: GoogleFonts.cairo()),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text('حسناً', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.blueAccent,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10.r),
        ),
      ),
      icon: const Icon(Icons.help_outline, size: 18),
      label: Text('دليل الاستخدام', style: GoogleFonts.cairo(fontSize: 12.sp)),
    );
  }
}
