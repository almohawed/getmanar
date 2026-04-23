import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/domain/models/user.dart';
import '../../../../features/attendance/presentation/widgets/student_discipline_widgets.dart';
import '../../../../features/attendance/presentation/providers/attendance_stats_providers.dart';

class FrequentAbsenceScreen extends ConsumerWidget {
  const FrequentAbsenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final analysisAsync = ref.watch(frequentAbsenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'الطلاب كثيري الغياب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: analysisAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('خطأ: $e')),
          data: (analysis) {
            return Column(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.orange.shade800,
                        size: 32.sp,
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(
                          'هذه القائمة تعرض الطلاب الذين تجاوزوا حد الغياب (3 أيام فأكثر) خلال آخر 30 يوم.',
                          style: GoogleFonts.cairo(
                            fontSize: 12.sp,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 16.h),
                Expanded(
                  child: analysis.students.isEmpty
                      ? Center(
                          child: Text('لا توجد بيانات', style: GoogleFonts.cairo()),
                        )
                      : ListView.builder(
                          itemCount: analysis.students.length,
                          itemBuilder: (context, index) {
                            return FrequentAbsenceCard(
                              item: analysis.students[index],
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
