import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../application/inbox_service.dart';
import '../../domain/transaction.dart';
import '../outbox_dashboard_screen.dart'; // Import Outbox Screen
import 'outbox_dialogs.dart'; // Import Outbox Dialogs
import '../../application/outbox_service.dart'; // Import Outbox Service

class TransactionDetailsPanel extends StatelessWidget {
  final Transaction transaction;
  final VoidCallback onClose;
  final InboxService inboxService;
  final String schoolId;
  final String userId;
  final String userName;

  const TransactionDetailsPanel({
    super.key,
    required this.transaction,
    required this.onClose,
    required this.inboxService,
    required this.schoolId,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 450.w,
      height: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: DefaultTabController(
              length: 3, // عدد التبويبات
              child: Column(
                children: [
                  const TabBar(
                    labelColor: Color(0xFF1565C0),
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF1565C0),
                    tabs: [
                      Tab(text: 'التفاصيل الكاملة', icon: Icon(Icons.article)),
                      Tab(text: 'سجل الحركة', icon: Icon(Icons.history)),
                      Tab(text: 'المرفقات', icon: Icon(Icons.attachment)),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildDetailsTab(),
                        _buildHistoryTab(),
                        _buildAttachmentsTab(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _buildActionBar(context),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 16.h, 8.w, 16.h),
      color: Colors.grey.shade50,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.subject,
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  'من: ${transaction.senderEntity} - #${transaction.number}',
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.black54),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsTab() {
    return ListView(
      padding: EdgeInsets.all(16.r),
      children: [
        _buildDetailItem('الحالة الحالية', _getStatusName(transaction.status)),
        _buildDetailItem('الأهمية', _getPriorityName(transaction.priority)),
        _buildDetailItem('نوع المعاملة', _getTypeName(transaction.type)),
        _buildDetailItem(
          'تاريخ الاستلام',
          timeago.format(transaction.receivedAt, locale: 'ar'),
        ),
        _buildDetailItem(
          'المدة في الحالة الحالية',
          '${transaction.durationInCurrentStatus.inDays} أيام',
        ),
        if (transaction.routedToUserName != null)
          _buildDetailItem('موجهة إلى', transaction.routedToUserName!),
        if (transaction.description != null &&
            transaction.description!.isNotEmpty)
          _buildDetailItem('الوصف', transaction.description!),
      ],
    );
  }

  Widget _buildHistoryTab() {
    return ListView.builder(
      itemCount: transaction.logs.length,
      itemBuilder: (context, index) {
        final log = transaction.logs.reversed.toList()[index];
        return ListTile(
          leading: const Icon(
            Icons.label_important_outline,
            color: Colors.blueGrey,
          ),
          title: Text(log.action),
          subtitle: Text(
            'بواسطة: ${log.userName} - ${timeago.format(log.timestamp, locale: 'ar')}',
          ),
        );
      },
    );
  }

  Widget _buildAttachmentsTab() {
    if (transaction.attachments.isEmpty) {
      return const Center(child: Text('لا توجد مرفقات'));
    }
    return ListView.builder(
      itemCount: transaction.attachments.length,
      itemBuilder: (context, index) {
        final attachment = transaction.attachments[index];
        return ListTile(
          leading: const Icon(Icons.attach_file, color: Colors.blueAccent),
          title: Text(attachment),
          trailing: IconButton(
            icon: const Icon(
              Icons.download_for_offline_outlined,
              color: Colors.green,
            ),
            onPressed: () {
              /* TODO: Implement download */
            },
          ),
        );
      },
    );
  }

  Widget _buildActionBar(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _showCreateReplyDialog(context),
              icon: const Icon(Icons.reply_rounded),
              label: const Text('إنشاء رد صادر'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6A1B9A), // Outbox Purple
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton.icon(
              onPressed: () => _showRoutingDialog(context),
              icon: const Icon(Icons.send_rounded),
              label: const Text('توجيه'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade700,
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton.icon(
              onPressed: () => _showRoutingDialog(context, isRerouting: true),
              icon: const Icon(Icons.replay_rounded),
              label: const Text('إعادة توجيه'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton.icon(
              onPressed: () => _escalateTransaction(context),
              icon: const Icon(Icons.arrow_upward_rounded),
              label: const Text('تصعيد'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton.icon(
              onPressed: () => _closeTransaction(context),
              icon: const Icon(Icons.check_circle_outline_rounded),
              label: const Text('إغلاق'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateReplyDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => CreateOutgoingTransactionDialog(
        schoolId: schoolId,
        userId: userId,
        userName: userName,
        // ignore: invalid_use_of_visible_for_testing_member
        onGenerateNumber: () =>
            OutboxService().generateNextTransactionNumber(schoolId),
        onSave: (transaction) {
          // Add reference to original transaction in content
          final replyTransaction = transaction.copyWith(
            content:
                'إشارة إلى المعاملة الواردة رقم ${this.transaction.number} بتاريخ ${timeago.format(this.transaction.receivedAt)}:\n\n${transaction.content}',
            recipientEntity:
                this.transaction.senderEntity, // Auto-fill recipient
            subject: 'رد على: ${this.transaction.subject}', // Auto-fill subject
          );

          OutboxService().createTransaction(replyTransaction);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('تم إنشاء الرد وحفظه في المسودات'),
              backgroundColor: Colors.green,
            ),
          );
          onClose(); // Close details panel
        },
      ),
    );
  }

  void _showRoutingDialog(BuildContext context, {bool isRerouting = false}) {
    // TODO: Implement user selection dialog
    // For now, we'll simulate routing to a predefined user
    inboxService.routeTransaction(
      schoolId: schoolId,
      transactionId: transaction.id,
      toUserId: 'dummy_user_id',
      toUserName: 'وكيل الشؤون التعليمية',
      byUserId: userId,
      byUserName: userName,
    );
    onClose();
  }

  void _escalateTransaction(BuildContext context) {
    inboxService.escalateTransaction(
      schoolId: schoolId,
      transactionId: transaction.id,
      byUserId: userId,
      byUserName: userName,
    );
    onClose();
  }

  void _closeTransaction(BuildContext context) {
    inboxService.closeTransaction(
      schoolId: schoolId,
      transactionId: transaction.id,
      byUserId: userId,
      byUserName: userName,
    );
    onClose();
  }

  Widget _buildDetailItem(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
                color: Colors.black54,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13.sp, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods to get names from enums (can be moved to a utility file)
  String _getStatusName(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.awaitingDirectorRouting:
        return 'بانتظار توجيه المدير';
      case TransactionStatus.routed:
        return 'تم التوجيه – قيد التنفيذ';
      case TransactionStatus.needsFollowup:
        return 'تحتاج متابعة';
      case TransactionStatus.delayed:
        return 'متأخرة';
      case TransactionStatus.closed:
        return 'مغلقة';
    }
  }

  String _getPriorityName(TransactionPriority priority) {
    switch (priority) {
      case TransactionPriority.critical:
        return 'عاجل جداً';
      case TransactionPriority.high:
        return 'مهم';
      case TransactionPriority.medium:
        return 'عادي';
      case TransactionPriority.low:
        return 'منخفض';
    }
  }

  String _getTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.financial:
        return 'مالي';
      case TransactionType.administrative:
        return 'إداري';
      case TransactionType.student:
        return 'طلابي';
      case TransactionType.circular:
        return 'تعميم';
      case TransactionType.complaint:
        return 'شكوى';
      case TransactionType.other:
        return 'أخرى';
    }
  }
}
