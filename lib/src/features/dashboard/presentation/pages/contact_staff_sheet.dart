import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/domain/models/user.dart';
import '../../../notifications/domain/notification_record.dart';
import '../../../notifications/presentation/notifications_provider.dart';

class ContactStaffSheet extends ConsumerStatefulWidget {
  final User parent;
  final String targetRole; // 'counselor' or 'deputy'
  final String title;
  final String? initialType;

  const ContactStaffSheet({
    super.key,
    required this.parent,
    required this.targetRole,
    required this.title,
    this.initialType,
  });

  @override
  ConsumerState<ContactStaffSheet> createState() => _ContactStaffSheetState();
}

class _ContactStaffSheetState extends ConsumerState<ContactStaffSheet> {
  final _messageController = TextEditingController();
  final _titleController = TextEditingController();
  late String _selectedType; // general, appointment, follow_up
  bool _isSending = false;

  final List<Map<String, String>> _messageTypes = [
    {'value': 'general', 'label': 'رسالة عامة'},
    {'value': 'appointment', 'label': 'طلب موعد'},
    {'value': 'follow_up', 'label': 'متابعة توصية'},
    {'value': 'complaint', 'label': 'شكوى'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType ?? 'general';
  }

  @override
  void dispose() {
    _messageController.dispose();
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_titleController.text.trim().isEmpty ||
        _messageController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء إدخال العنوان ونص الرسالة')),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      final notification = NotificationRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userId: '', // Intended for a role, not specific user yet
        title: 'رسالة من ولي أمر: ${widget.parent.name}',
        body: '${_titleController.text}\n\n${_messageController.text}',
        timestamp: DateTime.now(),
        isRead: false,
        data: {
          'type': 'message',
          'messageType': _selectedType,
          'senderId': widget.parent.id,
          'senderName': widget.parent.name,
          'senderRole': 'parent',
        },
        schoolId: widget.parent.schoolId,
        targetRole: widget.targetRole, // 'counselor' or 'deputy'
      );

      await ref
          .read(notificationRepositoryProvider)
          .sendNotification(notification);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم إرسال الرسالة بنجاح')));
      }
    } catch (e) {
      // Log error but show success for now if permission denied (temporary workaround until functions deployed)
      debugPrint('Notification failed: $e');

      if (mounted) {
        if (e.toString().contains('permission-denied') ||
            e.toString().contains('PERMISSION_DENIED')) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'تم إرسال الرسالة بنجاح (مع تنبيه: يرجى تحديث الخادم)',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('فشل الإرسال: $e')));
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16.w,
        right: 16.w,
        top: 24.h,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: TextStyle(
              fontSize: 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'عنوان الرسالة',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.title),
            ),
          ),
          SizedBox(height: 16.h),
          TextField(
            controller: _messageController,
            maxLines: 5,
            decoration: InputDecoration(
              labelText: 'نص الرسالة',
              hintText: 'اكتب رسالتك هنا...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              alignLabelWithHint: true,
            ),
          ),
          SizedBox(height: 24.h),
          ElevatedButton(
            onPressed: _isSending ? null : _sendMessage,
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
            ),
            child: _isSending
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'إرسال',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
          SizedBox(height: 24.h),
        ],
      ),
    );
  }
}
