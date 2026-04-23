import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/domain/models/user.dart';
import '../../../academic/presentation/students_provider.dart';
import '../../../health/data/firestore_health_repository.dart';

class HealthDashboardScreen extends ConsumerWidget {
  const HealthDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final students = ref.watch(studentsProvider).value ?? const <User>[];
    final healthCases = ref.watch(healthCasesProvider).value ?? const [];
    final incidents = ref.watch(healthIncidentsProvider).value ?? const [];
    final careCount = students
        .where((s) => (s.healthStatus ?? '') == 'care')
        .length;
    final bathroomCount = students
        .where((s) => (s.healthStatus ?? '') == 'bathroom')
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.cyan.shade800, Colors.cyan.shade600, Colors.teal.shade500],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('لوحة الصحة المدرسية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('متابعة الحالات الصحية والحوادث', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Text(
                  'هذه الصفحة تعرض بيانات حقيقية من السجلات المضافة داخل النظام.',
                  style: GoogleFonts.cairo(fontSize: 13.sp),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ملخص سريع',
                      style: GoogleFonts.cairo(
                        fontSize: 15.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      'طلاب بحاجة لرعاية: $careCount',
                      style: GoogleFonts.cairo(),
                    ),
                    Text(
                      'طلاب بحاجة لدورة مياه: $bathroomCount',
                      style: GoogleFonts.cairo(),
                    ),
                    Text(
                      'سجلات حالات صحية (تفاصيل): ${healthCases.length}',
                      style: GoogleFonts.cairo(),
                    ),
                    Text(
                      'سجلات حوادث صحية: ${incidents.length}',
                      style: GoogleFonts.cairo(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: () => context.push('/health-cases'),
              icon: const Icon(Icons.folder_open),
              label: Text('سجل الحالات الصحية', style: GoogleFonts.cairo()),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-health-case'),
              icon: const Icon(Icons.add),
              label: Text('إضافة حالة صحية', style: GoogleFonts.cairo()),
            ),
            SizedBox(height: 12.h),
            ElevatedButton.icon(
              onPressed: () => context.push('/add-health-incident'),
              icon: const Icon(Icons.report),
              label: Text('تسجيل حادث صحي', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }
}
