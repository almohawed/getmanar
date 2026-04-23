import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';

class ExecutiveDashboardScreen extends StatelessWidget {
  final String title;
  final Color color;
  final IconData icon;

  const ExecutiveDashboardScreen({
    super.key,
    required this.title,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          title,
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: color,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'هذه الصفحة لا تعرض بيانات تجريبية. ستظهر المؤشرات والإحصائيات تلقائياً بعد إدخال السجلات من الشاشات المخصصة لكل قسم وربطها بقاعدة البيانات.',
                  style: GoogleFonts.cairo(),
                ),
              ),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
              label: Text('العودة', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}

