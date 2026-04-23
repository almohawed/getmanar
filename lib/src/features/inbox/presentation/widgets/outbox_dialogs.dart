import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../domain/outgoing_transaction.dart';

class CreateOutgoingTransactionDialog extends StatefulWidget {
  final Function(OutgoingTransaction) onSave;
  final Future<String> Function() onGenerateNumber; // New callback
  final String schoolId;
  final String userId;
  final String userName;
  final String? initialRecipient;
  final String? initialSubject;
  final String? initialContent;

  const CreateOutgoingTransactionDialog({
    super.key,
    required this.onSave,
    required this.onGenerateNumber,
    required this.schoolId,
    required this.userId,
    required this.userName,
    this.initialRecipient,
    this.initialSubject,
    this.initialContent,
  });

  @override
  State<CreateOutgoingTransactionDialog> createState() =>
      _CreateOutgoingTransactionDialogState();
}

class _CreateOutgoingTransactionDialogState
    extends State<CreateOutgoingTransactionDialog> {
  final _formKey = GlobalKey<FormState>();
  String _recipient = '';
  String _subject = '';
  OutgoingTransactionType _type = OutgoingTransactionType.letter;
  OutgoingTransactionPriority _priority = OutgoingTransactionPriority.normal;
  String _content = '';

  @override
  void initState() {
    super.initState();
    _recipient = widget.initialRecipient ?? '';
    _subject = widget.initialSubject ?? '';
    _content = widget.initialContent ?? '';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 600.w,
        padding: EdgeInsets.all(24.w),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إنشاء خطاب صادر جديد',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                SizedBox(height: 24.h),
                _buildTextField(
                  label: 'عنوان الخطاب',
                  hint: 'مثال: طلب اعتماد نشاط',
                  initialValue: _subject,
                  onSaved: (v) => _subject = v ?? '',
                  validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                ),
                SizedBox(height: 16.h),
                Row(
                  children: [
                    Expanded(
                      child: _buildTextField(
                        label: 'الجهة المستقبلة',
                        hint: 'مثال: إدارة التعليم',
                        initialValue: _recipient,
                        onSaved: (v) => _recipient = v ?? '',
                        validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
                      ),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: _buildDropdown<OutgoingTransactionType>(
                        label: 'نوع الخطاب',
                        value: _type,
                        items: OutgoingTransactionType.values,
                        onChanged: (v) => setState(() => _type = v!),
                        itemLabel: (v) => _getTypeLabel(v),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16.h),
                _buildDropdown<OutgoingTransactionPriority>(
                  label: 'الأولوية',
                  value: _priority,
                  items: OutgoingTransactionPriority.values,
                  onChanged: (v) => setState(() => _priority = v!),
                  itemLabel: (v) => _getPriorityLabel(v),
                ),
                SizedBox(height: 16.h),
                _buildTextField(
                  label: 'محتوى الخطاب',
                  hint: 'اكتب نص الخطاب هنا...',
                  maxLines: 5,
                  initialValue: _content,
                  onSaved: (v) => _content = v ?? '',
                ),
                SizedBox(height: 24.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('إلغاء'),
                    ),
                    SizedBox(width: 12.w),
                    ElevatedButton.icon(
                      onPressed: () async {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();

                          // Generate number
                          final number = await widget.onGenerateNumber();

                          final newTransaction = OutgoingTransaction(
                            id: const Uuid().v4(),
                            schoolId: widget.schoolId,
                            number: number,
                            recipientEntity: _recipient,
                            subject: _subject,
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now(),
                            status: OutgoingTransactionStatus.draft,
                            type: _type,
                            priority: _priority,
                            content: _content,
                            attachments: [],
                            creatorId: widget.userId,
                            creatorName: widget.userName,
                            logs: [
                              OutgoingLog(
                                action: 'إنشاء المسودة',
                                userId: widget.userId,
                                userName: widget.userName,
                                timestamp: DateTime.now(),
                              ),
                            ],
                          );

                          widget.onSave(newTransaction);
                          Navigator.pop(context);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6A1B9A),
                        padding: EdgeInsets.symmetric(
                          horizontal: 24.w,
                          vertical: 12.h,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                      icon: const Icon(Icons.save_as, color: Colors.white),
                      label: const Text(
                        'حفظ المسودة',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required FormFieldSetter<String> onSaved,
    FormFieldValidator<String>? validator,
    int maxLines = 1,
    String? initialValue,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: 8.h),
        TextFormField(
          initialValue: initialValue,
          decoration: InputDecoration(
            hintText: hint,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
          ),
          maxLines: maxLines,
          onSaved: onSaved,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required String label,
    required T value,
    required List<T> items,
    required ValueChanged<T?> onChanged,
    required String Function(T) itemLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: 8.h),
        DropdownButtonFormField<T>(
          value: value,
          items: items
              .map((e) => DropdownMenuItem(value: e, child: Text(itemLabel(e))))
              .toList(),
          onChanged: onChanged,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 16.w,
              vertical: 12.h,
            ),
          ),
        ),
      ],
    );
  }

  String _getTypeLabel(OutgoingTransactionType type) {
    switch (type) {
      case OutgoingTransactionType.report:
        return 'تقرير';
      case OutgoingTransactionType.letter:
        return 'خطاب';
      case OutgoingTransactionType.circular:
        return 'تعميم';
      case OutgoingTransactionType.financial:
        return 'مالي';
      default:
        return 'أخرى';
    }
  }

  String _getPriorityLabel(OutgoingTransactionPriority priority) {
    switch (priority) {
      case OutgoingTransactionPriority.urgent:
        return 'عاجل';
      case OutgoingTransactionPriority.high:
        return 'هام';
      default:
        return 'عادي';
    }
  }
}

class OutboxTransactionDetailsDialog extends StatelessWidget {
  final OutgoingTransaction transaction;
  final Function(OutgoingTransactionStatus) onStatusChange;

  const OutboxTransactionDetailsDialog({
    super.key,
    required this.transaction,
    required this.onStatusChange,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 500.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(Icons.description, color: Colors.deepPurple),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        transaction.subject,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        transaction.number,
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 24.h),
            _buildDetailRow(
              Icons.business,
              'الجهة المستقبلة',
              transaction.recipientEntity,
            ),
            _buildDetailRow(
              Icons.calendar_today,
              'تاريخ الإنشاء',
              '${transaction.createdAt.day}/${transaction.createdAt.month}/${transaction.createdAt.year}',
            ),
            _buildDetailRow(Icons.person, 'المُنشئ', transaction.creatorName),
            _buildDetailRow(
              Icons.info_outline,
              'الحالة',
              _getStatusLabel(transaction.status),
            ),
            SizedBox(height: 24.h),
            Text(
              'المحتوى:',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                transaction.content.isEmpty
                    ? 'لا يوجد محتوى نصي'
                    : transaction.content,
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildActionButtons(context),
                SizedBox(width: 8.w),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('إغلاق'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    switch (transaction.status) {
      case OutgoingTransactionStatus.draft:
        return Row(
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                onStatusChange(OutgoingTransactionStatus.reviewing);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              child: const Text(
                'إرسال للمراجعة',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      case OutgoingTransactionStatus.reviewing:
        return ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onStatusChange(OutgoingTransactionStatus.awaitingApproval);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
          child: const Text(
            'رفع للاعتماد',
            style: TextStyle(color: Colors.white),
          ),
        );
      case OutgoingTransactionStatus.awaitingApproval:
        return ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onStatusChange(OutgoingTransactionStatus.sent);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text(
            'اعتماد وإرسال',
            style: TextStyle(color: Colors.white),
          ),
        );
      case OutgoingTransactionStatus.sent:
        return ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            onStatusChange(OutgoingTransactionStatus.archived);
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
          child: const Text('أرشفة', style: TextStyle(color: Colors.white)),
        );
      case OutgoingTransactionStatus.archived:
        return const SizedBox();
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(icon, size: 18.sp, color: Colors.grey.shade600),
          SizedBox(width: 8.w),
          Text(
            '$label: ',
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blueGrey.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(OutgoingTransactionStatus status) {
    switch (status) {
      case OutgoingTransactionStatus.draft:
        return 'مسودة';
      case OutgoingTransactionStatus.reviewing:
        return 'قيد المراجعة';
      case OutgoingTransactionStatus.awaitingApproval:
        return 'بانتظار الاعتماد';
      case OutgoingTransactionStatus.sent:
        return 'تم الإرسال';
      case OutgoingTransactionStatus.archived:
        return 'مؤرشف';
    }
  }
}
