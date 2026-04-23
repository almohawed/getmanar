import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../counselor/presentation/counselor_providers.dart';

class StudentFollowUpScreen extends ConsumerWidget {
  const StudentFollowUpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final risksAsync = ref.watch(riskTriageProvider);
    final students = ref.watch(studentsProvider).value ?? const <User>[];
    final byId = {for (final s in students) s.id: s};

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Text(
          'مركز متابعة الطلاب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.indigo.shade800,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: risksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('خطأ: $e')),
        data: (risks) {
          if (risks.isEmpty) {
            return Center(
              child: Text(
                'لا توجد حالات متابعة حالياً.',
                style: GoogleFonts.cairo(),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.all(16.w),
            itemCount: risks.length,
            separatorBuilder: (context, index) => SizedBox(height: 10.h),
            itemBuilder: (context, index) {
              final r = risks[index];
              final student = byId[r.studentId];
              final name = student?.name ?? r.studentName;
              final classLabel = (student?.assignedClassIds?.isNotEmpty ?? false)
                  ? student!.assignedClassIds!.first
                  : '—';

              Color border;
              switch (r.severity) {
                case 'critical':
                  border = Colors.red.shade200;
                  break;
                case 'high':
                  border = Colors.orange.shade200;
                  break;
                default:
                  border = Colors.blueGrey.shade200;
              }

              return InkWell(
                onTap: student == null
                    ? null
                    : () => context.push('/student-absence-details', extra: student),
                child: Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.shade200,
                        child: Text(
                          name.trim().isEmpty ? '؟' : name.trim()[0],
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.cairo(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              '$classLabel • ${r.reason}',
                              style: GoogleFonts.cairo(
                                fontSize: 12.sp,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

