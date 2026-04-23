import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../../core/domain/models/behavior_record.dart';
import '../../../notifications/domain/notification_record.dart';
import '../../../notifications/presentation/notifications_provider.dart';
import '../../../behavior/presentation/behavior_controller.dart';
import '../command_center_providers.dart';

class EscalationActionDialog extends ConsumerStatefulWidget {
  final CriticalCase criticalCase;

  const EscalationActionDialog({super.key, required this.criticalCase});

  @override
  ConsumerState<EscalationActionDialog> createState() =>
      _EscalationActionDialogState();
}

class _EscalationActionDialogState
    extends ConsumerState<EscalationActionDialog> {
  bool _isLoading = false;
  String? _selectedAction;
  final TextEditingController _notesController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pre-select logic based on actionLabel
    final label = widget.criticalCase.actionLabel;
    if (label != null) {
      if (label.contains('تنبيه')) {
        _selectedAction = 'alert';
      } else if (label.contains('إحالة')) {
        _selectedAction = 'referral';
      } else if (label.contains('استدعاء')) {
        _selectedAction = 'summons';
      } else {
        _selectedAction = 'alert';
      }
    } else {
      // Fallback
      if (widget.criticalCase.severity >= 3) {
        _selectedAction = 'referral';
      } else {
        _selectedAction = 'summons';
      }
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _executeAction() async {
    if (_selectedAction == null) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null || user.schoolId == null) {
        throw Exception('بيانات المستخدم غير متوفرة');
      }

      final schoolId = user.schoolId!;
      final studentId = widget.criticalCase.studentId;
      final studentName = widget.criticalCase.studentName;

      // 1. Get Parent ID for notification scenarios
      String? parentId;
      if (_selectedAction == 'alert' || _selectedAction == 'summons') {
        final behaviorRepo = ref.read(behaviorRepositoryProvider);
        parentId = await behaviorRepo.getParentIdForStudent(studentId);

        if (parentId == null) {
          throw Exception('لم يتم العثور على ولي أمر مرتبط بهذا الطالب');
        }
      }

      // 2. Execute Action
      switch (_selectedAction) {
        case 'alert':
          final notification = NotificationRecord(
            id: const Uuid().v4(),
            title: 'تنبيه سلوكي',
            body:
                'عزيزي ولي الأمر، نود إشعاركم بوجود ملاحظات سلوكية على الطالب $studentName: ${widget.criticalCase.reason}. نرجو المتابعة.',
            timestamp: DateTime.now(),
            userId: parentId, // Target Parent
            schoolId: schoolId,
            targetRole: 'parent',
          );
          await ref
              .read(notificationRepositoryProvider)
              .sendNotification(notification);
          break;

        case 'summons':
          final notification = NotificationRecord(
            id: const Uuid().v4(),
            title: 'استدعاء ولي أمر',
            body:
                'عزيزي ولي الأمر، نظراً لتكرار المخالفات للطالب $studentName، نرجو حضوركم للمدرسة لمناقشة وضع الطالب.',
            timestamp: DateTime.now(),
            userId: parentId, // Target Parent
            schoolId: schoolId,
            targetRole: 'parent',
          );
          await ref
              .read(notificationRepositoryProvider)
              .sendNotification(notification);
          break;

        case 'referral':
          // Create Admin Task for Counselor directly
          final taskId = const Uuid().v4();
          final taskData = {
            'id': taskId,
            'schoolId': schoolId,
            'title': 'إحالة سلوكية - $studentName',
            'description':
                'السبب: ${widget.criticalCase.reason}\nملاحظات الوكيل: ${_notesController.text}',
            'priority': 'high', // High priority for referrals
            'assignedTo': 'counselor', // Role-based assignment
            'assignedToRole': 'counselor',
            'status': 'open',
            'createdAt': FieldValue.serverTimestamp(),
            'dueDate': Timestamp.fromDate(
              DateTime.now().add(const Duration(days: 1)),
            ),
            'type': 'behavior_referral',
            'relatedStudentId': studentId,
            'createdBy': user.id,
          };

          await FirebaseFirestore.instance
              .collection('Schools')
              .doc(schoolId)
              .collection('AdminTasks')
              .doc(taskId)
              .set(taskData);
          break;
      }

      // 3. Log Escalation to Student Timeline
      final behaviorRepo = ref.read(behaviorRepositoryProvider);

      String logDescription = '';
      if (_selectedAction == 'alert') {
        logDescription = 'تم إشعار ولي الأمر (تنبيه سلوكي)';
      } else if (_selectedAction == 'summons') {
        logDescription = 'تم استدعاء ولي أمر';
      } else if (_selectedAction == 'referral') {
        logDescription = 'تم تحويل الحالة للمرشد الطلابي';
      }

      final escalationRecord = BehaviorRecord(
        id: const Uuid().v4(),
        studentId: studentId,
        teacherId: user.id,
        schoolId: schoolId,
        type: BehaviorType.escalation,
        description: logDescription,
        points: 0,
        timestamp: DateTime.now(),
        status: BehaviorStatus.approved,
        notes: _notesController.text,
      );
      await behaviorRepo.addBehaviorRecord(escalationRecord);

      if (mounted) {
        Navigator.pop(context, true); // Return success
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تنفيذ الإجراء بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ أثناء التنفيذ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 24.sp),
          SizedBox(width: 8.w),
          const Text('تنفيذ إجراء تصعيد'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'الطالب: ${widget.criticalCase.studentName}',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              'السبب: ${widget.criticalCase.reason}',
              style: TextStyle(color: Colors.grey[700], fontSize: 14.sp),
            ),
            SizedBox(height: 16.h),
            const Text(
              'الإجراء المطلوب:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              value: _selectedAction,
              items: const [
                DropdownMenuItem(
                  value: 'alert',
                  child: Text('إشعار ولي أمر (تنبيه)'),
                ),
                DropdownMenuItem(
                  value: 'summons',
                  child: Text('استدعاء ولي أمر'),
                ),
                DropdownMenuItem(
                  value: 'referral',
                  child: Text('تحويل للمرشد الطلابي'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedAction = value;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
              ),
            ),
            SizedBox(height: 16.h),
            const Text(
              'ملاحظات إضافية:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            TextField(
              controller: _notesController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'أضف أي ملاحظات هنا...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(false),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _executeAction,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
          ),
          child: _isLoading
              ? SizedBox(
                  width: 20.w,
                  height: 20.w,
                  child: const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
              : const Text('تنفيذ وإرسال'),
        ),
      ],
    );
  }
}
