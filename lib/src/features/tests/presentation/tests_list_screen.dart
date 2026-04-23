import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/presentation/students_provider.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../academic/data/student_repository.dart';
import '../../assignments/data/firestore_assignments_repository.dart';
import '../../assignments/domain/assignment.dart';

class TestsListScreen extends ConsumerWidget {
  const TestsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('الرجاء تسجيل الدخول')));
    }

    final AsyncValue<List<Assignment>> assignmentsAsync;

    final isStudent = user.role == UserRole.student;
    final isParent = user.role == UserRole.parent;

    if (isStudent) {
      assignmentsAsync = ref.watch(studentAssignmentsStreamProvider(user.id));
    } else if (!isStudent && !isParent) {
      assignmentsAsync = ref.watch(teacherAssignmentsProvider(user.id));
      ref.watch(studentsProvider);
    } else {
      assignmentsAsync = const AsyncValue.data([]);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF880E4F), Color(0xFFAD1457), Color(0xFFC2185B)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (!isStudent && !isParent) ? 'اختبارات طلابي' : 'الاختبارات',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
            Text(
              (!isStudent && !isParent) ? 'إدارة وجدولة الاختبارات' : 'مواعيد الاختبارات القادمة',
              style: TextStyle(color: Colors.white70, fontSize: 11.sp),
            ),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      floatingActionButton: (!isStudent && !isParent)
          ? Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF880E4F), Color(0xFFC2185B)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [BoxShadow(color: const Color(0xFF880E4F).withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
              ),
              child: FloatingActionButton.extended(
                onPressed: () => showDialog(context: context, builder: (context) => _AddTestDialog(teacher: user)),
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text('إضافة اختبار', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
              ),
            )
          : null,
      body: assignmentsAsync.when(
        data: (allAssignments) {
          if (!isStudent && !isParent) {
            final teacherTests = allAssignments
                .where((a) => a.type == 'test')
                .toList();

            if (teacherTests.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [const Color(0xFF880E4F).withOpacity(0.08), const Color(0xFFC2185B).withOpacity(0.04)]),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.quiz_outlined, size: 64.sp, color: const Color(0xFFC2185B)),
                    ),
                    SizedBox(height: 20.h),
                    Text('لا توجد اختبارات مضافة بعد', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    SizedBox(height: 8.h),
                    Text('اضغط على "إضافة اختبار" لإنشاء اختبار جديد', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
                  ],
                ),
              );
            }

            final grouped = <String, List<Assignment>>{};
            for (final t in teacherTests) {
              final key = t.batchId ?? t.id;
              grouped.putIfAbsent(key, () => []).add(t);
            }
            final groups = grouped.values.toList()
              ..sort((a, b) => b.first.dueDate.compareTo(a.first.dueDate));

            return ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _TeacherTestCard(tests: group);
              },
            );
          }

          final tests = allAssignments.where((a) => a.type == 'test').toList();

          if (tests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [const Color(0xFF880E4F).withOpacity(0.08), const Color(0xFFC2185B).withOpacity(0.04)]),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.quiz_outlined, size: 64.sp, color: const Color(0xFFC2185B)),
                  ),
                  SizedBox(height: 20.h),
                  Text('لا توجد اختبارات حالياً', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  SizedBox(height: 8.h),
                  Text('ستظهر الاختبارات هنا عند إضافتها من المعلم', style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.r),
            itemCount: tests.length,
            itemBuilder: (context, index) {
              final test = tests[index];
              return _TestCard(test: test);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
    );
  }
}

class _TestCard extends StatelessWidget {
  final Assignment test;

  const _TestCard({required this.test});

  @override
  Widget build(BuildContext context) {
    final isPassed = test.dueDate.isBefore(DateTime.now());
    final daysLeft = test.dueDate.difference(DateTime.now()).inDays;
    final statusColor = isPassed ? Colors.grey.shade600 : daysLeft <= 3 ? Colors.red.shade700 : const Color(0xFF1565C0);
    final statusLabel = isPassed ? 'منتهي' : daysLeft == 0 ? 'اليوم!' : 'قادم';
    final statusIcon = isPassed ? Icons.check_circle_outline : daysLeft <= 3 ? Icons.warning_amber_rounded : Icons.upcoming_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          // شريط علوي
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.07),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(18.r), topRight: Radius.circular(18.r)),
            ),
            child: Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 16.sp),
                SizedBox(width: 6.w),
                Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 12.sp, fontWeight: FontWeight.bold)),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.event, size: 11.sp, color: statusColor),
                      SizedBox(width: 4.w),
                      Text(DateFormat('d MMM yyyy', 'ar').format(test.dueDate),
                          style: TextStyle(fontSize: 11.sp, color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [const Color(0xFF880E4F).withOpacity(0.12), const Color(0xFFC2185B).withOpacity(0.06)]),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.quiz_rounded, color: const Color(0xFF880E4F), size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(test.title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                          SizedBox(height: 4.h),
                          Row(children: [
                            Icon(Icons.book_outlined, size: 12.sp, color: Colors.grey.shade500),
                            SizedBox(width: 4.w),
                            Text(test.subject, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                          ]),
                        ],
                      ),
                    ),
                  ],
                ),
                if (test.description != null && test.description!.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10.r), border: Border.all(color: Colors.grey.shade200)),
                    child: Text(test.description!, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700, height: 1.5)),
                  ),
                ],
                if (test.testLink != null && test.testLink!.isNotEmpty) ...[
                  SizedBox(height: 10.h),
                  InkWell(
                    onTap: () => _launchTestLink(context, test.testLink!),
                    borderRadius: BorderRadius.circular(10.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(10.r),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 14.sp, color: Colors.blue.shade700),
                          SizedBox(width: 6.w),
                          Text('رابط الاختبار', style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(bool isPassed) {
    return const SizedBox.shrink();
  }

  Future<void> _launchTestLink(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('لا يمكن فتح الرابط')));
      }
    }
  }
}

class _TeacherTestCard extends ConsumerWidget {
  final List<Assignment> tests;

  const _TeacherTestCard({required this.tests});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final representative = tests.first;
    final isPublished = tests.every((t) => t.published == true || t.published == null);
    final studentsCount = tests.length;
    final isPassed = representative.dueDate.isBefore(DateTime.now());

    final statusColor = isPublished ? const Color(0xFF2E7D32) : isPassed ? Colors.red.shade700 : const Color(0xFFE65100);
    final statusLabel = isPublished ? 'تم الإرسال' : isPassed ? 'منتهي (غير مرسل)' : 'مسودة';
    final statusIcon = isPublished ? Icons.check_circle_rounded : isPassed ? Icons.warning_rounded : Icons.edit_note_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          // رأس البطاقة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF880E4F).withOpacity(0.06), const Color(0xFFC2185B).withOpacity(0.02)],
                begin: Alignment.centerRight, end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF880E4F), Color(0xFFC2185B)], begin: Alignment.topRight, end: Alignment.bottomLeft),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [BoxShadow(color: const Color(0xFF880E4F).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(Icons.quiz_rounded, color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(representative.title, style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                      SizedBox(height: 3.h),
                      Row(children: [
                        Icon(Icons.book_outlined, size: 12.sp, color: Colors.grey.shade500),
                        SizedBox(width: 4.w),
                        Text(representative.subject, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                      ]),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 5.h),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: statusColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 12.sp, color: statusColor),
                      SizedBox(width: 4.w),
                      Text(statusLabel, style: TextStyle(fontSize: 10.sp, color: statusColor, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoChip(Icons.people_outline, '$studentsCount طالب', Colors.indigo),
                    SizedBox(width: 8.w),
                    _infoChip(Icons.event, DateFormat('d MMM yyyy', 'ar').format(representative.dueDate), isPassed ? Colors.red : Colors.teal),
                  ],
                ),
                SizedBox(height: 14.h),
                Row(
                  children: [
                    if (!isPublished)
                      Expanded(
                        child: _actionButton(label: 'إرسال', icon: Icons.send_rounded, color: const Color(0xFF2E7D32),
                            onTap: () async => await _sendTests(context, ref)),
                      ),
                    if (!isPublished) SizedBox(width: 8.w),
                    Expanded(
                      child: _actionButton(label: 'تعديل', icon: Icons.edit_rounded, color: const Color(0xFF880E4F),
                          onTap: () async => await showDialog(context: context, builder: (context) => _EditTestDialog(tests: tests))),
                    ),
                    SizedBox(width: 8.w),
                    _actionButton(label: 'حذف', icon: Icons.delete_outline_rounded, color: Colors.red.shade700,
                        onTap: () async => await _deleteTests(context, ref), isOutlined: true),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoChip(IconData icon, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 5.h),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(20.r), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11.sp, color: color),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 11.sp, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _actionButton({required String label, required IconData icon, required Color color, required VoidCallback onTap, bool isOutlined = false}) {
    return Material(
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 12.w),
          decoration: isOutlined ? BoxDecoration(borderRadius: BorderRadius.circular(10.r), border: Border.all(color: color)) : null,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14.sp, color: isOutlined ? color : Colors.white),
              SizedBox(width: 5.w),
              Text(label, style: TextStyle(fontSize: 12.sp, color: isOutlined ? color : Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _sendTests(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null || currentUser.schoolId == null) return;

    final notifRepo = ref.read(notificationRepositoryProvider);
    final studentRepo = ref.read(studentRepositoryProvider);

    for (final test in tests) {
      if (test.published == true) continue;

      await notifRepo.sendNotification(
        NotificationRecord(
          id: const Uuid().v4(),
          userId: test.studentId,
          title: 'اختبار جديد',
          body: test.title,
          timestamp: DateTime.now(),
          schoolId: currentUser.schoolId,
          route: '/tests',
          data: {'assignmentId': test.id, 'type': 'test'},
        ),
      );

      try {
        final student = await studentRepo.getStudentById(
          currentUser.schoolId!,
          test.studentId,
        );
        if (student != null && student.parentId != null) {
          await notifRepo.sendNotification(
            NotificationRecord(
              id: const Uuid().v4(),
              userId: student.parentId,
              title: 'اختبار جديد للطالب ${student.name}',
              body: test.title,
              timestamp: DateTime.now(),
              schoolId: currentUser.schoolId,
              route: '/tests',
              data: {'assignmentId': test.id, 'type': 'test'},
            ),
          );
        }
      } catch (_) {}

      final repo = ref.read(firestoreAssignmentRepositoryProvider);
      await repo.updateAssignment(test.copyWith(published: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال الاختبار للطلاب وأولياء الأمور'),
        ),
      );
    }
  }

  Future<void> _deleteTests(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(firestoreAssignmentRepositoryProvider);
    for (final test in tests) {
      await repo.deleteAssignment(test.id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الاختبار')));
    }
  }
}

class _AddTestDialog extends ConsumerStatefulWidget {
  final User teacher;

  const _AddTestDialog({required this.teacher});

  @override
  ConsumerState<_AddTestDialog> createState() => _AddTestDialogState();
}

class _AddTestDialogState extends ConsumerState<_AddTestDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _testLinkController = TextEditingController();

  DateTime? _date;
  DateTime? _endDate;
  bool _isRemote = false;
  String _targetType = 'all';
  final List<String> _selectedClassIds = [];
  final List<User> _selectedStudents = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _testLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return AlertDialog(
      title: const Text('إضافة اختبار جديد'),
      content: SizedBox(
        width: 400.w,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الاختبار',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال عنوان الاختبار';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية (اختياري)',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 8.h),
                SwitchListTile(
                  value: _isRemote,
                  onChanged: (value) {
                    setState(() {
                      _isRemote = value;
                    });
                  },
                  title: const Text('اختبار عن بُعد'),
                ),
                ListTile(
                  title: Text(
                    _date == null
                        ? 'اختر تاريخ الاختبار'
                        : 'تاريخ الاختبار: ${DateFormat('yyyy-MM-dd').format(_date!)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: now,
                      firstDate: now.subtract(const Duration(days: 1)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked;
                      });
                    }
                  },
                ),
                if (_isRemote)
                  ListTile(
                    title: Text(
                      _endDate == null
                          ? 'اختر نهاية الاختبار'
                          : 'نهاية الاختبار: ${DateFormat('yyyy-MM-dd').format(_endDate!)}',
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final base = _date ?? DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: base,
                        firstDate: base,
                        lastDate: base.add(const Duration(days: 7)),
                      );
                      if (picked != null) {
                        setState(() {
                          _endDate = picked;
                        });
                      }
                    },
                  ),
                if (_isRemote)
                  TextFormField(
                    controller: _testLinkController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الاختبار',
                    ),
                  ),
                SizedBox(height: 8.h),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'إرسال إلى',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ),
                RadioListTile<String>(
                  value: 'all',
                  groupValue: _targetType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _targetType = value;
                      });
                    }
                  },
                  title: const Text('جميع فصولي'),
                ),
                RadioListTile<String>(
                  value: 'classes',
                  groupValue: _targetType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _targetType = value;
                      });
                    }
                  },
                  title: const Text('فصول محددة'),
                ),
                if (_targetType == 'classes')
                  classesAsync.when(
                    data: (classes) {
                      final filtered = classes
                          .where(
                            (c) =>
                                widget.teacher.assignedClassIds?.contains(
                                  c.id,
                                ) ??
                                false,
                          )
                          .toList();
                      if (filtered.isEmpty) {
                        return const Text('لا يوجد لديك فصول مرتبطة.');
                      }
                      return Wrap(
                        spacing: 8.w,
                        children: filtered.map((c) {
                          final selected = _selectedClassIds.contains(c.id);
                          return FilterChip(
                            label: Text(c.name),
                            selected: selected,
                            onSelected: (value) {
                              setState(() {
                                if (value) {
                                  _selectedClassIds.add(c.id);
                                } else {
                                  _selectedClassIds.remove(c.id);
                                }
                              });
                            },
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const CircularProgressIndicator(),
                    error: (e, s) => Text('خطأ في تحميل الفصول: $e'),
                  ),
                RadioListTile<String>(
                  value: 'students',
                  groupValue: _targetType,
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _targetType = value;
                      });
                    }
                  },
                  title: const Text('طلاب محددين'),
                ),
                if (_targetType == 'students')
                  Align(
                    alignment: Alignment.centerRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final allStudents = studentsAsync.value ?? [];
                            final teacherClassIds =
                                widget.teacher.assignedClassIds ?? [];
                            final candidates = allStudents.where((s) {
                              final assigned = s.assignedClassIds ?? [];
                              return assigned.any(teacherClassIds.contains);
                            }).toList();

                            final result = await showDialog<List<User>>(
                              context: context,
                              builder: (context) {
                                return _StudentsSelectionDialog(
                                  initialSelected: _selectedStudents,
                                  candidates: candidates,
                                );
                              },
                            );
                            if (result != null) {
                              setState(() {
                                _selectedStudents
                                  ..clear()
                                  ..addAll(result);
                              });
                            }
                          },
                          icon: const Icon(Icons.group_add),
                          label: const Text('اختيار الطلاب'),
                        ),
                        Wrap(
                          spacing: 4.w,
                          children: _selectedStudents
                              .map(
                                (s) => Chip(
                                  label: Text(
                                    s.name,
                                    style: TextStyle(fontSize: 12.sp),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            if (_date == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء اختيار تاريخ الاختبار')),
              );
              return;
            }
            if (_isRemote && _endDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء اختيار نهاية الاختبار')),
              );
              return;
            }

            final targetStudents = _resolveTargetStudents(
              studentsAsync.value ?? [],
            );
            if (targetStudents.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('لا يوجد طلاب مطابقين للاختيار')),
              );
              return;
            }

            final repo = ref.read(firestoreAssignmentRepositoryProvider);
            final notifRepo = ref.read(notificationRepositoryProvider);
            final studentRepo = ref.read(studentRepositoryProvider);
            final schoolId = widget.teacher.schoolId;
            final batchId = const Uuid().v4();
            final subject = widget.teacher.specialization ?? 'غير محدد';

            final DateTime dueDate = _isRemote ? _endDate ?? _date! : _date!;

            final createdTests = <Assignment>[];

            for (final student in targetStudents) {
              final classId = (student.assignedClassIds?.isNotEmpty ?? false)
                  ? student.assignedClassIds!.first
                  : null;

              final test = Assignment(
                id: const Uuid().v4(),
                title: _titleController.text.trim(),
                subject: subject,
                dueDate: dueDate,
                status: AssignmentStatus.pending,
                studentId: student.id,
                description: _descriptionController.text.trim(),
                type: 'test',
                isRemote: _isRemote,
                testLink: _isRemote ? _testLinkController.text.trim() : null,
                teacherId: widget.teacher.id,
                classId: classId,
                schoolId: widget.teacher.schoolId,
                batchId: batchId,
                published: true,
              );

              await repo.addAssignment(test);
              createdTests.add(test);
            }

            if (schoolId != null) {
              for (final test in createdTests) {
                await notifRepo.sendNotification(
                  NotificationRecord(
                    id: const Uuid().v4(),
                    userId: test.studentId,
                    title: 'اختبار جديد',
                    body: test.title,
                    timestamp: DateTime.now(),
                    schoolId: schoolId,
                    route: '/tests',
                    data: {'assignmentId': test.id, 'type': 'test'},
                  ),
                );

                try {
                  final student = await studentRepo.getStudentById(
                    schoolId,
                    test.studentId,
                  );
                  if (student != null && student.parentId != null) {
                    await notifRepo.sendNotification(
                      NotificationRecord(
                        id: const Uuid().v4(),
                        userId: student.parentId,
                        title: 'اختبار جديد للطالب ${student.name}',
                        body: test.title,
                        timestamp: DateTime.now(),
                        schoolId: schoolId,
                        route: '/tests',
                        data: {'assignmentId': test.id, 'type': 'test'},
                      ),
                    );
                  }
                } catch (_) {}
              }
            }

            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إنشاء الاختبار لعدد ${targetStudents.length} طالب',
                  ),
                ),
              );
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }

  List<User> _resolveTargetStudents(List<User> allStudents) {
    final teacherClassIds = widget.teacher.assignedClassIds ?? [];

    if (_targetType == 'all') {
      return allStudents.where((s) {
        final assigned = s.assignedClassIds ?? [];
        return assigned.any(teacherClassIds.contains);
      }).toList();
    }

    if (_targetType == 'classes') {
      if (_selectedClassIds.isEmpty) return [];
      return allStudents.where((s) {
        final assigned = s.assignedClassIds ?? [];
        return assigned.any(_selectedClassIds.contains);
      }).toList();
    }

    if (_targetType == 'students') {
      return List<User>.from(_selectedStudents);
    }

    return [];
  }
}

class _EditTestDialog extends ConsumerStatefulWidget {
  final List<Assignment> tests;

  const _EditTestDialog({required this.tests});

  @override
  ConsumerState<_EditTestDialog> createState() => _EditTestDialogState();
}

class _EditTestDialogState extends ConsumerState<_EditTestDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _testLinkController;
  late DateTime _date;
  late bool _isRemote;

  @override
  void initState() {
    super.initState();
    final representative = widget.tests.first;
    _titleController = TextEditingController(text: representative.title);
    _descriptionController = TextEditingController(
      text: representative.description ?? '',
    );
    _testLinkController = TextEditingController(
      text: representative.testLink ?? '',
    );
    _date = representative.dueDate;
    _isRemote = representative.isRemote ?? false;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _testLinkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الاختبار'),
      content: SizedBox(
        width: 400.w,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'عنوان الاختبار',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال عنوان الاختبار';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية (اختياري)',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 8.h),
                SwitchListTile(
                  value: _isRemote,
                  onChanged: (value) {
                    setState(() {
                      _isRemote = value;
                    });
                  },
                  title: const Text('اختبار عن بُعد'),
                ),
                ListTile(
                  title: Text(
                    'تاريخ الاختبار: ${DateFormat('yyyy-MM-dd').format(_date)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _date,
                      firstDate: now.subtract(const Duration(days: 365)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _date = picked;
                      });
                    }
                  },
                ),
                if (_isRemote)
                  TextFormField(
                    controller: _testLinkController,
                    decoration: const InputDecoration(
                      labelText: 'رابط الاختبار',
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            if (!_formKey.currentState!.validate()) return;
            final repo = ref.read(firestoreAssignmentRepositoryProvider);

            for (final test in widget.tests) {
              final updated = test.copyWith(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                dueDate: _date,
                isRemote: _isRemote,
                testLink: _isRemote ? _testLinkController.text.trim() : null,
              );
              await repo.updateAssignment(updated);
            }

            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تحديث الاختبار')),
              );
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

class _StudentsSelectionDialog extends StatefulWidget {
  final List<User> initialSelected;
  final List<User> candidates;

  const _StudentsSelectionDialog({
    required this.initialSelected,
    required this.candidates,
  });

  @override
  State<_StudentsSelectionDialog> createState() =>
      _StudentsSelectionDialogState();
}

class _StudentsSelectionDialogState extends State<_StudentsSelectionDialog> {
  late final List<User> _selected;

  @override
  void initState() {
    super.initState();
    _selected = List<User>.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('اختيار الطلاب'),
      content: SizedBox(
        width: 400.w,
        height: 400.h,
        child: ListView.builder(
          itemCount: widget.candidates.length,
          itemBuilder: (context, index) {
            final student = widget.candidates[index];
            final selected = _selected.any((s) => s.id == student.id);
            return CheckboxListTile(
              value: selected,
              title: Text(student.name),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selected.add(student);
                  } else {
                    _selected.removeWhere((s) => s.id == student.id);
                  }
                });
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop(_selected);
          },
          child: const Text('تم'),
        ),
      ],
    );
  }
}
