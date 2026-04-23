import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/student_repository.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../academic/data/school_repository.dart'; // Import school repository
import '../../admin/data/firestore_class_repository.dart'; // Import for class repository provider
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
      appBar: AppBar(
        title: const Text('سجل المخالفات السلوكية'),
        bottom: TabBar(
          controller: _tabController,
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
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (_) => const AddViolationSheet(),
          );
        },
        child: const Icon(Icons.add),
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
    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getLevelColor(violation.level),
          child: Text(
            '${violation.level.index + 1}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          violation.violationTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('الطالب: ${violation.studentName}'),
            Text(
              violation.date.toString().substring(0, 10),
              style: TextStyle(fontSize: 12.sp, color: Colors.grey),
            ),
            if (violation.status == ViolationStatus.approved)
              Text(
                'معتمد',
                style: TextStyle(color: Colors.green, fontSize: 12.sp),
              ),
          ],
        ),
        trailing: isPending
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.check, color: Colors.green),
                    onPressed: () => _approve(context, ref),
                    tooltip: 'اعتماد',
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed: () {
                      // Implement reject logic
                    },
                  ),
                ],
              )
            : IconButton(
                icon: const Icon(Icons.print, color: Colors.blue),
                onPressed: () => _printPdf(context, ref),
                tooltip: 'طباعة الخطاب',
              ),
      ),
    );
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
