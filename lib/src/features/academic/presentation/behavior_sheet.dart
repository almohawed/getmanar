import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../behavior/domain/bathroom_pass.dart';

class BehaviorSheet extends ConsumerStatefulWidget {
  final User student;
  final BathroomPass? activeTrip;

  const BehaviorSheet({super.key, required this.student, this.activeTrip});

  @override
  ConsumerState<BehaviorSheet> createState() => _BehaviorSheetState();
}

class _BehaviorSheetState extends ConsumerState<BehaviorSheet> {
  bool _showOtherInput = false;
  final TextEditingController _otherController = TextEditingController();

  @override
  void dispose() {
    _otherController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isOut = widget.activeTrip != null;

    return Container(
      padding: EdgeInsets.all(24.w),
      height: 650.h, // Increased height for more content
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 50.w,
              height: 5.h,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          SizedBox(height: 24.h),

          // Header
          Row(
            children: [
              CircleAvatar(
                radius: 30.r,
                backgroundColor: Colors.blue.shade100,
                child: Text(
                  widget.student.name[0],
                  style: TextStyle(
                    fontSize: 24.sp,
                    color: Colors.blue.shade800,
                  ),
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.student.name,
                      style: Theme.of(context).textTheme.titleMedium,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      widget.student.email,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),

          SizedBox(height: 24.h),
          Divider(),
          SizedBox(height: 16.h),

          // Section 1: Academic & Status Actions
          Text(
            'الإجراءات السريعة',
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Bathroom / Return Button
              _ActionButton(
                icon: isOut ? Icons.login : Icons.timer,
                label: isOut ? 'عودة للفصل' : 'استئذان',
                color: isOut ? Colors.green : Colors.orange,
                onTap: () {
                  if (isOut) {
                    _returnStudent(context, ref);
                  } else {
                    _addRecord(
                      context,
                      ref,
                      BehaviorType.bathroom,
                      'خروج لدورة المياه',
                      0,
                      status: BehaviorStatus.approved,
                    );
                  }
                },
              ),
              // No Homework
              _ActionButton(
                icon: Icons.book_outlined,
                label: 'عدم حل الواجب',
                color: Colors.redAccent,
                onTap: () =>
                    _submitAcademicNote(context, ref, 'عدم حل الواجب', -1),
              ),
              // No Test
              _ActionButton(
                icon: Icons.assignment_late_outlined,
                label: 'عدم حل الاختبار',
                color: Colors.deepPurpleAccent,
                onTap: () =>
                    _submitAcademicNote(context, ref, 'عدم حل الاختبار', -2),
              ),
            ],
          ),

          SizedBox(height: 24.h),
          Divider(),
          SizedBox(height: 16.h),

          // Section 2: Behavioral Violations
          Text(
            'المخالفات السلوكية (تحتاج اعتماد الوكيل)',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          SizedBox(height: 12.h),

          Expanded(
            child: _showOtherInput
                ? Column(
                    children: [
                      TextField(
                        controller: _otherController,
                        decoration: InputDecoration(
                          hintText: 'اكتب وصف المخالفة...',
                          border: OutlineInputBorder(),
                          suffixIcon: IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () =>
                                setState(() => _showOtherInput = false),
                          ),
                        ),
                        maxLines: 3,
                      ),
                      SizedBox(height: 16.h),
                      ElevatedButton.icon(
                        onPressed: () async {
                          if (_otherController.text.isNotEmpty) {
                            final user = ref.read(authStateProvider).value;
                            if (user == null) return;

                            final controller = ref.read(
                              behaviorControllerProvider.notifier,
                            );
                            try {
                              final result = await controller
                                  .addViolationWithAutoEscalation(
                                    studentId: widget.student.id,
                                    studentName: widget.student.name,
                                    teacherId: user.id,
                                    description: _otherController.text,
                                    points: -2,
                                  );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(result.message),
                                    backgroundColor: result.escalated
                                        ? Colors.orange
                                        : (result.parentNotified
                                              ? Colors.purple
                                              : Colors.green),
                                    duration: const Duration(seconds: 4),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('حدث خطأ: $e'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.send),
                        label: const Text('تسجيل المخالفة'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  )
                : GridView.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 1.2,
                    children: [
                      _ViolationButton(
                        label: 'إزعاج',
                        onTap: () => _submitViolation(context, ref, 'إزعاج'),
                      ),
                      _ViolationButton(
                        label: 'كثرة الكلام',
                        onTap: () =>
                            _submitViolation(context, ref, 'كثرة الكلام'),
                      ),
                      _ViolationButton(
                        label: 'تلفظ',
                        onTap: () =>
                            _submitViolation(context, ref, 'تلفظ غير لائق'),
                      ),
                      _ViolationButton(
                        label: 'مشاغبة',
                        onTap: () => _submitViolation(context, ref, 'مشاغبة'),
                      ),
                      _ViolationButton(
                        label: 'عدم حضور الكتاب',
                        onTap: () =>
                            _submitViolation(context, ref, 'عدم إحضار الكتاب'),
                      ),
                      _ViolationButton(
                        label: 'أخرى',
                        isOther: true,
                        onTap: () => setState(() => _showOtherInput = true),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  // Helper method to show confirmation dialog
  Future<void> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required String confirmText,
    required String cancelText,
    required VoidCallback onConfirm,
    required VoidCallback onCancel,
    Widget? extraContent,
  }) async {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(content),
            if (extraContent != null) ...[SizedBox(height: 16.h), extraContent],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              onCancel();
            },
            child: Text(cancelText),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
            child: Text(confirmText),
          ),
        ],
      ),
    );
  }

  void _submitViolation(BuildContext context, WidgetRef ref, String reason) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل مخالفة: $reason'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('اختر الإجراء المناسب لهذه المخالفة:'),
            SizedBox(height: 16.h),
            // Option 1: Send (Normal)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processViolation(context, ref, reason, isWarning: false);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: const Text('تسجيل'),
            ),
            SizedBox(height: 8.h),
            // Option 2: Warning
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _processViolation(context, ref, reason, isWarning: true);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: const Text('إنذار'),
            ),
            SizedBox(height: 8.h),
            // Option 3: Draft
            OutlinedButton(
              onPressed: () {
                Navigator.pop(context);
                _addRecord(
                  context,
                  ref,
                  BehaviorType.negative,
                  reason,
                  -2,
                  status: BehaviorStatus.draft,
                );
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ المخالفة كمسودة')),
                );
                Navigator.pop(context); // Close sheet
              },
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 12.h),
              ),
              child: const Text('مسودة'),
            ),
            SizedBox(height: 8.h),
            // Option 4: Cancel
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _processViolation(
    BuildContext context,
    WidgetRef ref,
    String reason, {
    required bool isWarning,
  }) async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;

    final controller = ref.read(behaviorControllerProvider.notifier);
    try {
      final result = await controller.addViolationWithAutoEscalation(
        studentId: widget.student.id,
        studentName: widget.student.name,
        teacherId: user.id,
        description: reason,
        points: -2,
        isWarning: isWarning,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result.message),
            backgroundColor: result.escalated
                ? Colors.orange
                : (result.parentNotified ? Colors.purple : Colors.green),
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context); // Close sheet
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _submitAcademicNote(
    BuildContext context,
    WidgetRef ref,
    String title,
    int points,
  ) {
    final noteController = TextEditingController();
    _showConfirmationDialog(
      context: context,
      title: title,
      content: 'أدخل ملاحظاتك حول ($title):',
      confirmText: 'رصد في ملف الطالب',
      cancelText: 'حفظ كمسودة',
      extraContent: TextField(
        controller: noteController,
        decoration: InputDecoration(
          hintText: 'مثال: اسم الواجب أو الاختبار...',
          border: OutlineInputBorder(),
        ),
      ),
      onConfirm: () => _addRecord(
        context,
        ref,
        BehaviorType.negative,
        title,
        points,
        status: BehaviorStatus.approved,
        notes: noteController.text,
      ),
      onCancel: () => _addRecord(
        context,
        ref,
        BehaviorType.negative,
        title,
        points,
        status: BehaviorStatus.draft,
        notes: noteController.text,
      ),
    );
  }

  void _returnStudent(BuildContext context, WidgetRef ref) {
    final userAsync = ref.read(authStateProvider);
    final currentUser = userAsync.value;

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('خطأ: المستخدم غير مسجل الدخول')),
      );
      return;
    }

    if (widget.activeTrip != null) {
      ref
          .read(behaviorControllerProvider.notifier)
          .returnStudentFromBathroom(widget.activeTrip!, currentUser);
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تم تسجيل عودة الطالب')));
    }
  }




  void _addRecord(
    BuildContext context,
    WidgetRef ref,
    BehaviorType type,
    String desc,
    int points, {
    BehaviorStatus status = BehaviorStatus.approved,
    String? notes,
  }) {
    final userAsync = ref.read(authStateProvider);
    final teacherId = userAsync.value?.id ?? 'unknown_teacher';
    final schoolId = userAsync.value?.schoolId;

    final record = BehaviorRecord(
      id: const Uuid().v4(),
      studentId: widget.student.id,
      teacherId: teacherId,
      schoolId: schoolId,
      type: type,
      description: desc,
      notes: notes,
      points: points,
      timestamp: DateTime.now(),
      bathroomExitTime: type == BehaviorType.bathroom ? DateTime.now() : null,
      dueYellowAt: type == BehaviorType.bathroom
          ? DateTime.now().add(const Duration(minutes: 5))
          : null,
      status: status,
    );

    ref.read(behaviorControllerProvider.notifier).addRecord(record);

    // Notification Logic for Bathroom is now handled by Cloud Functions (onPassApproved)
    // to ensure reliability and parent lookup.

    Navigator.pop(context);

    String msg = 'تم تسجيل: $desc';
    if (status == BehaviorStatus.pending) {
      msg = 'تم إرسال المخالفة ($desc) للوكيل للاعتماد';
    } else if (status == BehaviorStatus.draft) {
      msg = 'تم حفظ ($desc) في المسودات';
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
              border: Border.all(color: color),
            ),
            child: Icon(icon, color: color, size: 28.sp),
          ),
          SizedBox(height: 8.h),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class _ViolationButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isOther;

  const _ViolationButton({
    required this.label,
    required this.onTap,
    this.isOther = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isOther ? Colors.grey.shade200 : Colors.red.shade50,
        foregroundColor: isOther ? Colors.black : Colors.red,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: isOther ? Colors.grey : Colors.red.shade200),
        ),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 12.sp),
      ),
    );
  }
}
