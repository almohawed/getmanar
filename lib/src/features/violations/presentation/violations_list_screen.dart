import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/student_repository.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../academic/data/school_repository.dart';
import '../../admin/data/firestore_class_repository.dart';
import '../domain/behavioral_violation.dart';
import '../data/firestore_violations_repository.dart';
import '../application/violation_pdf_service.dart';
import 'add_violation_sheet.dart';

class ViolationsListScreen extends ConsumerStatefulWidget {
  const ViolationsListScreen({super.key});

  @override
  ConsumerState<ViolationsListScreen> createState() =>
      _ViolationsListScreenState();
}

class _ViolationsListScreenState extends ConsumerState<ViolationsListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      return const Scaffold(body: Center(child: Text('Error: No User')));
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: Text(
          'سجل المخالفات السلوكية',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18.sp,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: const Color(0xFF8B0000),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 15.sp,
          ),
          unselectedLabelStyle: GoogleFonts.cairo(
            fontWeight: FontWeight.w600,
            fontSize: 14.sp,
          ),
          tabs: const [
            Tab(text: 'بانتظار الاعتماد'),
            Tab(text: 'السجل الكامل'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _PendingViolationsList(schoolId: user.schoolId!),
          _AllViolationsList(schoolId: user.schoolId!),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFF8B0000),
        foregroundColor: Colors.white,
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => const AddViolationSheet(),
          );
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(
          'إضافة مخالفة',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}

class _PendingViolationsList extends ConsumerWidget {
  final String schoolId;
  const _PendingViolationsList({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final violationsStream = ref.watch(
      pendingViolationsStreamProvider(schoolId),
    );

    return violationsStream.when(
      data: (violations) {
        if (violations.isEmpty) {
          return const Center(child: Text('لا توجد مخالفات بانتظار الاعتماد'));
        }
        return ListView.builder(
          padding: EdgeInsets.all(16.r),
          itemCount: violations.length,
          itemBuilder: (context, index) {
            return _ViolationCard(
              violation: violations[index],
              isPending: true,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('Error: $e')),
    );
  }
}

class _AllViolationsList extends ConsumerWidget {
  final String schoolId;
  const _AllViolationsList({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Ideally use a stream or future provider for all violations
    // For now, using future provider pattern (simulated)
    final repo = ref.watch(violationsRepositoryProvider);
    return FutureBuilder<List<BehavioralViolation>>(
      future: repo.getViolationsBySchool(schoolId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }
        final violations = snapshot.data ?? [];
        if (violations.isEmpty) {
          return const Center(child: Text('لا توجد مخالفات مسجلة'));
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.r),
          itemCount: violations.length,
          itemBuilder: (context, index) {
            return _ViolationCard(
              violation: violations[index],
              isPending: false,
            );
          },
        );
      },
    );
  }
}

class _ViolationCard extends ConsumerWidget {
  final BehavioralViolation violation;
  final bool isPending;

  const _ViolationCard({required this.violation, required this.isPending});

  Future<void> _approve(BuildContext context, WidgetRef ref) async {
    try {
      // 1. Update Status
      final updated = violation.copyWith(status: ViolationStatus.approved);
      await ref.read(violationsRepositoryProvider).updateViolation(updated);

      // 2. Notify Parent
      final studentRepo = ref.read(studentRepositoryProvider);
      final student = await studentRepo.getStudentById(
        violation.schoolId,
        violation.studentId,
      );

      if (student != null && student.parentId != null) {
        // Fix: Use notificationRepositoryProvider to send notification
        final notificationRepo = ref.read(notificationRepositoryProvider);
        await notificationRepo.sendNotification(
          NotificationRecord(
            id: const Uuid().v4(),
            userId: student.parentId!,
            title: 'تنبيه سلوكي',
            body:
                'تم تسجيل مخالفة سلوكية على الابن ${student.name}: ${violation.violationTitle}. نرجو المتابعة.',
            timestamp: DateTime.now(),
            schoolId: violation.schoolId,
            data: {'violationId': violation.id},
          ),
        );
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم اعتماد المخالفة وإشعار ولي الأمر')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
      }
    }
  }

  Future<void> _printPdf(BuildContext context, WidgetRef ref) async {
    try {
      // Fetch necessary data
      // Fix: authStateProvider needs to be watched/read properly if defined, assuming it is imported
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('المستخدم غير مسجل الدخول');

      final studentRepo = ref.read(studentRepositoryProvider);
      final schoolRepo = ref.read(schoolRepositoryProvider);
      final classRepo = ref.read(classRepositoryProvider);

      final student = await studentRepo.getStudentById(
        violation.schoolId,
        violation.studentId,
      );
      final school = await schoolRepo.getSchool(violation.schoolId);

      if (student == null) throw Exception('Student not found');
      if (school == null) throw Exception('School not found');

      String? className;
      if (student.assignedClassIds != null &&
          student.assignedClassIds!.isNotEmpty) {
        final cls = await classRepo.getClassById(
          violation.schoolId,
          student.assignedClassIds!.first,
        );
        className = cls?.name;
      }

      final pdfBytes = await ViolationPdfService().generateViolationLetter(
        violation: violation,
        student: student,
        school: school,
        recorder: user, // Assuming current user is printing (Deputy/Admin)
        className: className,
      );

      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'violation_${violation.studentName}.pdf',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في الطباعة: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final levelColor = _getLevelColor(violation.level);
    final levelLabel = _getLevelLabel(violation.level);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.r),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56.w,
                  height: 56.w,
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Center(
                    child: Text(
                      '${violation.level.index + 1}',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 20.sp,
                        color: levelColor,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        violation.violationTitle,
                        style: GoogleFonts.cairo(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                          color: Colors.grey.shade900,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        'الطالب: ${violation.studentName}',
                        style: GoogleFonts.cairo(
                          color: Colors.grey.shade600,
                          fontSize: 14.sp,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: levelColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    levelLabel,
                    style: GoogleFonts.cairo(
                      color: levelColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 16.r,
                  color: Colors.grey.shade500,
                ),
                SizedBox(width: 8.w),
                Text(
                  violation.date.toString().substring(0, 10),
                  style: GoogleFonts.cairo(
                    color: Colors.grey.shade600,
                    fontSize: 13.sp,
                  ),
                ),
                const Spacer(),
                if (violation.status == ViolationStatus.approved)
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2E7D32).withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded,
                            color: const Color(0xFF2E7D32), size: 16.r),
                        SizedBox(width: 6.w),
                        Text(
                          'معتمد',
                          style: GoogleFonts.cairo(
                            color: const Color(0xFF2E7D32),
                            fontWeight: FontWeight.bold,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            if (isPending) ...[
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _approve(context, ref),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFF2E7D32), width: 1.5),
                        foregroundColor: const Color(0xFF2E7D32),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      icon: const Icon(Icons.check_circle_rounded),
                      label: Text(
                        'اعتماد',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {},
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(
                            color: Color(0xFFC62828), width: 1.5),
                        foregroundColor: const Color(0xFFC62828),
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                      ),
                      icon: const Icon(Icons.close_rounded),
                      label: Text(
                        'رفض',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (!isPending) ...[
              SizedBox(height: 16.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _printPdf(context, ref),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.print_rounded),
                  label: Text(
                    'طباعة الخطاب',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getLevelLabel(ViolationLevel level) {
    switch (level) {
      case ViolationLevel.firstDegree:
        return 'درجة أولى';
      case ViolationLevel.secondDegree:
        return 'درجة ثانية';
      case ViolationLevel.thirdDegree:
        return 'درجة ثالثة';
      case ViolationLevel.fourthDegree:
        return 'درجة رابعة';
      case ViolationLevel.fifthDegree:
        return 'درجة خامسة';
    }
  }

  Color _getLevelColor(ViolationLevel level) {
    switch (level) {
      case ViolationLevel.firstDegree:
        return Colors.orange;
      case ViolationLevel.secondDegree:
        return Colors.deepOrange;
      case ViolationLevel.thirdDegree:
        return Colors.red;
      case ViolationLevel.fourthDegree:
        return Colors.red.shade900;
      case ViolationLevel.fifthDegree:
        return Colors.black;
    }
  }
}

// Provider for streaming pending violations
final pendingViolationsStreamProvider =
    StreamProvider.family<List<BehavioralViolation>, String>((ref, schoolId) {
  final repo = ref.watch(violationsRepositoryProvider);
  return repo.streamPendingViolations(schoolId);
});
