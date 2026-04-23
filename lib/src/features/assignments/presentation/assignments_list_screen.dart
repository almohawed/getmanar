import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/presentation/students_provider.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../academic/data/student_repository.dart';
import '../data/firestore_assignments_repository.dart';
import '../domain/assignment.dart';

class AssignmentsListScreen extends ConsumerWidget {
  const AssignmentsListScreen({super.key});

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
              colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (!isStudent && !isParent) ? 'واجبات طلابي' : 'الواجبات والأنشطة',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
            Text(
              (!isStudent && !isParent) ? 'إدارة وإرسال الواجبات' : 'متابعة الواجبات المطلوبة',
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
                  colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                  begin: Alignment.topRight,
                  end: Alignment.bottomLeft,
                ),
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1A237E).withOpacity(0.4),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton.extended(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => _AddAssignmentDialog(teacher: user),
                  );
                },
                backgroundColor: Colors.transparent,
                elevation: 0,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
                label: Text('إضافة واجب', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13.sp)),
              ),
            )
          : null,
      body: assignmentsAsync.when(
        data: (allAssignments) {
          if (!isStudent && !isParent) {
            final teacherAssignments = allAssignments
                .where((a) => a.type == 'assignment')
                .toList();

            if (teacherAssignments.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: EdgeInsets.all(24.w),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1A237E).withOpacity(0.08), const Color(0xFF3949AB).withOpacity(0.04)],
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.assignment_outlined, size: 64.sp, color: const Color(0xFF3949AB)),
                    ),
                    SizedBox(height: 20.h),
                    Text('لا توجد واجبات مضافة بعد',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                    SizedBox(height: 8.h),
                    Text('اضغط على "إضافة واجب" لإنشاء واجب جديد',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
                  ],
                ),
              );
            }

            final grouped = <String, List<Assignment>>{};
            for (final a in teacherAssignments) {
              final key = a.batchId ?? a.id;
              grouped.putIfAbsent(key, () => []).add(a);
            }
            final groups = grouped.values.toList()
              ..sort((a, b) => b.first.dueDate.compareTo(a.first.dueDate));

            return ListView.builder(
              padding: EdgeInsets.all(16.r),
              itemCount: groups.length,
              itemBuilder: (context, index) {
                final group = groups[index];
                return _TeacherAssignmentCard(assignments: group);
              },
            );
          }

          final assignments = allAssignments
              .where((a) => a.type == 'assignment' || a.type == 'activity')
              .toList();

          if (assignments.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.green.withOpacity(0.08), Colors.teal.withOpacity(0.04)],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.assignment_outlined, size: 64.sp, color: Colors.teal.shade600),
                  ),
                  SizedBox(height: 20.h),
                  Text('لا توجد واجبات حالياً',
                      style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                  SizedBox(height: 8.h),
                  Text('ستظهر الواجبات هنا عند إضافتها من المعلم',
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: EdgeInsets.all(16.r),
            itemCount: assignments.length,
            itemBuilder: (context, index) {
              final assignment = assignments[index];
              return _AssignmentCard(assignment: assignment);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final Assignment assignment;

  const _AssignmentCard({required this.assignment});

  @override
  Widget build(BuildContext context) {
    final isSubmitted =
        assignment.status == AssignmentStatus.submitted ||
        assignment.status == AssignmentStatus.approved;
    final isLate = !isSubmitted && assignment.dueDate.isBefore(DateTime.now());

    final statusColor = isSubmitted ? const Color(0xFF2E7D32) : isLate ? const Color(0xFFC62828) : const Color(0xFFE65100);
    final statusLabel = isSubmitted ? 'تم التسليم' : isLate ? 'متأخر' : 'قيد الانتظار';
    final statusIcon = isSubmitted ? Icons.check_circle_rounded : isLate ? Icons.warning_rounded : Icons.hourglass_top_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.08), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // شريط الحالة العلوي
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
                    color: isLate ? Colors.red.shade50 : Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: isLate ? Colors.red.shade200 : Colors.blue.shade200),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.calendar_today, size: 11.sp, color: isLate ? Colors.red.shade700 : Colors.blue.shade700),
                      SizedBox(width: 4.w),
                      Text(
                        DateFormat('d MMM', 'ar').format(assignment.dueDate),
                        style: TextStyle(fontSize: 11.sp, color: isLate ? Colors.red.shade700 : Colors.blue.shade700, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // المحتوى
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
                        gradient: LinearGradient(
                          colors: [const Color(0xFF1A237E).withOpacity(0.12), const Color(0xFF3949AB).withOpacity(0.06)],
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Icon(Icons.assignment_rounded, color: const Color(0xFF1A237E), size: 22.sp),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(assignment.title,
                              style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                          SizedBox(height: 4.h),
                          Row(
                            children: [
                              Icon(Icons.book_outlined, size: 12.sp, color: Colors.grey.shade500),
                              SizedBox(width: 4.w),
                              Text(assignment.subject, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (assignment.description != null && assignment.description!.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(10.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(assignment.description!,
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700, height: 1.5)),
                  ),
                ],
                if (!isSubmitted) ...[
                  SizedBox(height: 12.h),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
                            title: Text(assignment.title),
                            content: SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('المادة: ${assignment.subject}', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 8),
                                  if (assignment.description != null) Text(assignment.description!),
                                  const SizedBox(height: 8),
                                  Text('تاريخ التسليم: ${DateFormat('yyyy-MM-dd').format(assignment.dueDate)}'),
                                ],
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(context), child: const Text('إغلاق')),
                            ],
                          ),
                        );
                      },
                      icon: Icon(Icons.info_outline, size: 14.sp),
                      label: const Text('التفاصيل'),
                      style: TextButton.styleFrom(foregroundColor: const Color(0xFF1A237E)),
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

  Widget _buildStatusBadge(bool isSubmitted, bool isLate) {
    return const SizedBox.shrink(); // مدمج في التصميم الجديد
  }
}

class _TeacherAssignmentCard extends ConsumerWidget {
  final List<Assignment> assignments;

  const _TeacherAssignmentCard({required this.assignments});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final representative = assignments.first;
    final isPublished = assignments.every(
      (a) => a.published == true || a.published == null,
    );
    final studentsCount = assignments.length;
    final isLate = representative.dueDate.isBefore(DateTime.now()) && !isPublished;

    final statusColor = isPublished ? const Color(0xFF2E7D32) : isLate ? const Color(0xFFC62828) : const Color(0xFFE65100);
    final statusLabel = isPublished ? 'تم الإرسال' : isLate ? 'متأخرة (غير مرسلة)' : 'مسودة';
    final statusIcon = isPublished ? Icons.check_circle_rounded : isLate ? Icons.warning_rounded : Icons.edit_note_rounded;

    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: statusColor.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: statusColor.withOpacity(0.1), blurRadius: 16, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        children: [
          // رأس البطاقة بتدرج
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [const Color(0xFF1A237E).withOpacity(0.06), const Color(0xFF3949AB).withOpacity(0.02)],
                begin: Alignment.centerRight,
                end: Alignment.centerLeft,
              ),
              borderRadius: BorderRadius.only(topLeft: Radius.circular(20.r), topRight: Radius.circular(20.r)),
              border: Border(bottom: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [BoxShadow(color: const Color(0xFF1A237E).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Icon(Icons.assignment_rounded, color: Colors.white, size: 20.sp),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(representative.title,
                          style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade900)),
                      SizedBox(height: 3.h),
                      Row(
                        children: [
                          Icon(Icons.book_outlined, size: 12.sp, color: Colors.grey.shade500),
                          SizedBox(width: 4.w),
                          Text(representative.subject, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                        ],
                      ),
                    ],
                  ),
                ),
                // شارة الحالة
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
          // تفاصيل
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              children: [
                Row(
                  children: [
                    _infoChip(Icons.people_outline, '$studentsCount طالب', Colors.indigo),
                    SizedBox(width: 8.w),
                    _infoChip(Icons.calendar_today, DateFormat('d MMM yyyy', 'ar').format(representative.dueDate),
                        isLate ? Colors.red : Colors.teal),
                    if (representative.deliveryType != null) ...[
                      SizedBox(width: 8.w),
                      _infoChip(Icons.category_outlined, _deliveryLabel(representative.deliveryType!), Colors.purple),
                    ],
                  ],
                ),
                SizedBox(height: 14.h),
                // أزرار الإجراءات
                Row(
                  children: [
                    if (!isPublished)
                      Expanded(
                        child: _actionButton(
                          label: 'إرسال',
                          icon: Icons.send_rounded,
                          color: const Color(0xFF2E7D32),
                          onTap: () async => await _sendAssignments(context, ref),
                        ),
                      ),
                    if (!isPublished) SizedBox(width: 8.w),
                    Expanded(
                      child: _actionButton(
                        label: 'تعديل',
                        icon: Icons.edit_rounded,
                        color: const Color(0xFF1565C0),
                        onTap: () async => await showDialog(
                          context: context,
                          builder: (context) => _EditAssignmentDialog(assignments: assignments),
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _actionButton(
                      label: 'حذف',
                      icon: Icons.delete_outline_rounded,
                      color: Colors.red.shade700,
                      onTap: () async => await _deleteAssignments(context, ref),
                      isOutlined: true,
                    ),
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
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11.sp, color: color),
          SizedBox(width: 4.w),
          Text(label, style: TextStyle(fontSize: 11.sp, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isOutlined = false,
  }) {
    return Material(
      color: isOutlined ? Colors.transparent : color,
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 9.h, horizontal: 12.w),
          decoration: isOutlined
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(10.r),
                  border: Border.all(color: color),
                )
              : null,
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

  String _deliveryLabel(String type) {
    switch (type) {
      case 'book': return 'من الكتاب';
      case 'worksheet': return 'ورقة عمل';
      case 'research': return 'بحث';
      default: return type;
    }
  }

  Widget _buildTeacherStatusBadge(bool isPublished, bool isLate) {
    return const SizedBox.shrink(); // مدمج في التصميم الجديد
  }

  Future<void> _sendAssignments(BuildContext context, WidgetRef ref) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null || currentUser.schoolId == null) return;

    final notifRepo = ref.read(notificationRepositoryProvider);
    final studentRepo = ref.read(studentRepositoryProvider);

    for (final assignment in assignments) {
      if (assignment.published == true) continue;

      await notifRepo.sendNotification(
        NotificationRecord(
          id: const Uuid().v4(),
          userId: assignment.studentId,
          title: 'واجب جديد',
          body: assignment.title,
          timestamp: DateTime.now(),
          schoolId: currentUser.schoolId,
          route: '/assignments',
          data: {'assignmentId': assignment.id, 'type': 'assignment'},
        ),
      );

      try {
        final student = await studentRepo.getStudentById(
          currentUser.schoolId!,
          assignment.studentId,
        );
        if (student != null && student.parentId != null) {
          await notifRepo.sendNotification(
            NotificationRecord(
              id: const Uuid().v4(),
              userId: student.parentId,
              title: 'واجب جديد للطالب ${student.name}',
              body: assignment.title,
              timestamp: DateTime.now(),
              schoolId: currentUser.schoolId,
              route: '/assignments',
              data: {'assignmentId': assignment.id, 'type': 'assignment'},
            ),
          );
        }
      } catch (_) {}

      final repo = ref.read(firestoreAssignmentRepositoryProvider);
      await repo.updateAssignment(assignment.copyWith(published: true));
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم إرسال الواجب للطلاب وأولياء الأمور')),
      );
    }
  }

  Future<void> _deleteAssignments(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(firestoreAssignmentRepositoryProvider);
    for (final assignment in assignments) {
      await repo.deleteAssignment(assignment.id);
    }

    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم حذف الواجب')));
    }
  }
}

class _AddAssignmentDialog extends ConsumerStatefulWidget {
  final User teacher;

  const _AddAssignmentDialog({required this.teacher});

  @override
  ConsumerState<_AddAssignmentDialog> createState() =>
      _AddAssignmentDialogState();
}

class _AddAssignmentDialogState extends ConsumerState<_AddAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _pageFromController = TextEditingController();
  final _pageToController = TextEditingController();

  DateTime? _dueDate;
  String _deliveryType = 'book';
  String _targetType = 'all';
  final List<String> _selectedClassIds = [];
  final List<User> _selectedStudents = [];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pageFromController.dispose();
    _pageToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return AlertDialog(
      title: const Text('إضافة واجب جديد'),
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
                  decoration: const InputDecoration(labelText: 'عنوان الواجب'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال عنوان الواجب';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: _deliveryType,
                  items: const [
                    DropdownMenuItem(
                      value: 'book',
                      child: Text('واجب من الكتاب'),
                    ),
                    DropdownMenuItem(
                      value: 'worksheet',
                      child: Text('ورقة عمل'),
                    ),
                    DropdownMenuItem(value: 'research', child: Text('بحث')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _deliveryType = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'نوع الواجب'),
                ),
                if (_deliveryType == 'book') ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pageFromController,
                          decoration: const InputDecoration(
                            labelText: 'من صفحة',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextFormField(
                          controller: _pageToController,
                          decoration: const InputDecoration(
                            labelText: 'إلى صفحة',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية (اختياري)',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 8.h),
                ListTile(
                  title: Text(
                    _dueDate == null
                        ? 'اختر تاريخ الاستحقاق'
                        : 'تاريخ الاستحقاق: ${DateFormat('yyyy-MM-dd').format(_dueDate!)}',
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
                        _dueDate = picked;
                      });
                    }
                  },
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
                                    s.name ?? '',
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
            if (_dueDate == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('الرجاء اختيار تاريخ الاستحقاق')),
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

            final createdAssignments = <Assignment>[];

            for (final student in targetStudents) {
              final classId = (student.assignedClassIds?.isNotEmpty ?? false)
                  ? student.assignedClassIds!.first
                  : null;

              final assignment = Assignment(
                id: const Uuid().v4(),
                title: _titleController.text.trim(),
                subject: subject,
                dueDate: _dueDate!,
                status: AssignmentStatus.pending,
                studentId: student.id,
                description: _descriptionController.text.trim(),
                type: 'assignment',
                pageFrom: _deliveryType == 'book'
                    ? _pageFromController.text.trim()
                    : null,
                pageTo: _deliveryType == 'book'
                    ? _pageToController.text.trim()
                    : null,
                teacherId: widget.teacher.id,
                classId: classId,
                schoolId: widget.teacher.schoolId,
                deliveryType: _deliveryType,
                batchId: batchId,
                published: true,
              );

              await repo.addAssignment(assignment);
              createdAssignments.add(assignment);
            }

            if (schoolId != null) {
              for (final assignment in createdAssignments) {
                await notifRepo.sendNotification(
                  NotificationRecord(
                    id: const Uuid().v4(),
                    userId: assignment.studentId,
                    title: 'واجب جديد',
                    body: assignment.title,
                    timestamp: DateTime.now(),
                    schoolId: schoolId,
                    route: '/assignments',
                    data: {'assignmentId': assignment.id, 'type': 'assignment'},
                  ),
                );

                try {
                  final student = await studentRepo.getStudentById(
                    schoolId,
                    assignment.studentId,
                  );
                  if (student != null && student.parentId != null) {
                    await notifRepo.sendNotification(
                      NotificationRecord(
                        id: const Uuid().v4(),
                        userId: student.parentId,
                        title: 'واجب جديد للطالب ${student.name}',
                        body: assignment.title,
                        timestamp: DateTime.now(),
                        schoolId: schoolId,
                        route: '/assignments',
                        data: {
                          'assignmentId': assignment.id,
                          'type': 'assignment',
                        },
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
                    'تم إنشاء الواجب لعدد ${targetStudents.length} طالب',
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

class _EditAssignmentDialog extends ConsumerStatefulWidget {
  final List<Assignment> assignments;

  const _EditAssignmentDialog({required this.assignments});

  @override
  ConsumerState<_EditAssignmentDialog> createState() =>
      _EditAssignmentDialogState();
}

class _EditAssignmentDialogState extends ConsumerState<_EditAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _pageFromController;
  late final TextEditingController _pageToController;
  late DateTime _dueDate;
  late String _deliveryType;

  @override
  void initState() {
    super.initState();
    final representative = widget.assignments.first;
    _titleController = TextEditingController(text: representative.title);
    _descriptionController = TextEditingController(
      text: representative.description ?? '',
    );
    _pageFromController = TextEditingController(
      text: representative.pageFrom ?? '',
    );
    _pageToController = TextEditingController(
      text: representative.pageTo ?? '',
    );
    _dueDate = representative.dueDate;
    _deliveryType = representative.deliveryType ?? 'book';
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _pageFromController.dispose();
    _pageToController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل الواجب'),
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
                  decoration: const InputDecoration(labelText: 'عنوان الواجب'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'الرجاء إدخال عنوان الواجب';
                    }
                    return null;
                  },
                ),
                SizedBox(height: 8.h),
                DropdownButtonFormField<String>(
                  value: _deliveryType,
                  items: const [
                    DropdownMenuItem(
                      value: 'book',
                      child: Text('واجب من الكتاب'),
                    ),
                    DropdownMenuItem(
                      value: 'worksheet',
                      child: Text('ورقة عمل'),
                    ),
                    DropdownMenuItem(value: 'research', child: Text('بحث')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _deliveryType = value;
                      });
                    }
                  },
                  decoration: const InputDecoration(labelText: 'نوع الواجب'),
                ),
                if (_deliveryType == 'book') ...[
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _pageFromController,
                          decoration: const InputDecoration(
                            labelText: 'من صفحة',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: TextFormField(
                          controller: _pageToController,
                          decoration: const InputDecoration(
                            labelText: 'إلى صفحة',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                ],
                SizedBox(height: 8.h),
                TextFormField(
                  controller: _descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'تفاصيل إضافية (اختياري)',
                  ),
                  maxLines: 3,
                ),
                SizedBox(height: 8.h),
                ListTile(
                  title: Text(
                    'تاريخ الاستحقاق: ${DateFormat('yyyy-MM-dd').format(_dueDate)}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final now = DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dueDate,
                      firstDate: now.subtract(const Duration(days: 365)),
                      lastDate: now.add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() {
                        _dueDate = picked;
                      });
                    }
                  },
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

            for (final assignment in widget.assignments) {
              final updated = assignment.copyWith(
                title: _titleController.text.trim(),
                description: _descriptionController.text.trim(),
                dueDate: _dueDate,
                deliveryType: _deliveryType,
                pageFrom: _deliveryType == 'book'
                    ? _pageFromController.text.trim()
                    : null,
                pageTo: _deliveryType == 'book'
                    ? _pageToController.text.trim()
                    : null,
              );
              await repo.updateAssignment(updated);
            }

            if (context.mounted) {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم تحديث الواجب')));
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
              title: Text(student.name ?? ''),
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
