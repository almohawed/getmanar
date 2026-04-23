import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../application/outbox_service.dart';
import '../domain/outgoing_transaction.dart' as domain;
import 'widgets/outbox_widgets.dart';
import 'widgets/outbox_dialogs.dart';
import 'widgets/smart_inbox_widgets.dart'; // Reusing PriorityPieChart and DepartmentLoadBarChart

import '../domain/transaction.dart' as inbox_domain;

class OutboxDashboardScreen extends StatefulWidget {
  final String schoolId;
  final String userName;
  final String userRole;

  const OutboxDashboardScreen({
    super.key,
    required this.schoolId,
    required this.userName,
    required this.userRole,
  });

  @override
  State<OutboxDashboardScreen> createState() => _OutboxDashboardScreenState();
}

class _OutboxDashboardScreenState extends State<OutboxDashboardScreen> {
  final OutboxService _outboxService = OutboxService();
  domain.OutgoingTransaction? _selectedTransaction;

  // Used for top buttons to show feedback
  void _showSelectionHint(String action) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('الرجاء اختيار معاملة من القائمة أدناه لـ $action'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.blueGrey.shade700,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveSchoolId = widget.schoolId.trim();
    final isMobile = MediaQuery.of(context).size.width < 600;

    if (effectiveSchoolId.isEmpty) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8F9FE),
        appBar: AppBar(
          title: const Text('الصادر الإداري'),
          backgroundColor: const Color(0xFF6A1B9A),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Text(
            'لا توجد بيانات مدرسة مرتبطة بالحساب.',
            style: TextStyle(fontSize: 14.sp, color: Colors.blueGrey.shade700),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE),
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.outbox, color: Colors.white),
            SizedBox(width: 8.w),
            Text(
              'الصادر الإداري',
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF6A1B9A), // Official Outbox Purple
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () => setState(() {}),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: Stack(
        children: [
          StreamBuilder<List<domain.OutgoingTransaction>>(
            stream: _outboxService.getOutgoingTransactions(effectiveSchoolId),
            builder: (context, snapshot) {
              final transactions =
                  snapshot.data ?? const <domain.OutgoingTransaction>[];

              return FutureBuilder<domain.OutboxStatistics>(
                future: _outboxService.getOutboxStatistics(effectiveSchoolId),
                builder: (context, statsSnapshot) {
                  final stats =
                      statsSnapshot.data ??
                      domain.OutboxStatistics(
                        totalToday: 0,
                        inPreparation: 0,
                        awaitingApproval: 0,
                        sent: 0,
                        averageProcessingTime: 0,
                      );

                  return SingleChildScrollView(
                    padding: EdgeInsets.all(isMobile ? 12.w : 20.w),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 0. Hero Section
                        FadeInDown(
                          child: Padding(
                            padding: EdgeInsets.only(bottom: 24.h),
                            child: isMobile
                                ? Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'أهلاً بك، ${widget.userName}',
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade900,
                                          fontSize: 20.sp,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      SizedBox(height: 8.h),
                                      _buildOfficialBadge(),
                                    ],
                                  )
                                : Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'أهلاً بك، ${widget.userName}',
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade900,
                                                fontSize: 24.sp,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            Text(
                                              'لديك ${stats.awaitingApproval} مراسلات بانتظار الاعتماد و ${stats.inPreparation} قيد الإعداد.',
                                              style: TextStyle(
                                                color: Colors.blueGrey.shade700,
                                                fontSize: 14.sp,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      _buildOfficialBadge(),
                                    ],
                                  ),
                          ),
                        ),

                        // 1. KPI Cards Row (Grid on Mobile)
                        FadeInDown(
                          child: isMobile
                              ? GridView.count(
                                  crossAxisCount: 2,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  mainAxisSpacing: 12.h,
                                  crossAxisSpacing: 12.w,
                                  childAspectRatio: 1.2,
                                  children: [
                                    _buildOutboxStatCard(
                                      'صادر اليوم',
                                      '${stats.totalToday}',
                                      Icons.today,
                                      const Color(0xFF6A1B9A),
                                      true,
                                    ),
                                    _buildOutboxStatCard(
                                      'قيد الإعداد',
                                      '${stats.inPreparation}',
                                      Icons.edit_note,
                                      Colors.amber.shade800,
                                      true,
                                    ),
                                    _buildOutboxStatCard(
                                      'بانتظار الاعتماد',
                                      '${stats.awaitingApproval}',
                                      Icons.fact_check,
                                      Colors.blue.shade700,
                                      true,
                                    ),
                                    _buildOutboxStatCard(
                                      'تم الإرسال',
                                      '${stats.sent}',
                                      Icons.send_rounded,
                                      Colors.green.shade700,
                                      true,
                                    ),
                                  ],
                                )
                              : LayoutBuilder(
                                  builder: (context, constraints) {
                                    return Wrap(
                                      spacing: 12.w,
                                      runSpacing: 12.h,
                                      children: [
                                        _buildOutboxStatCard(
                                          'صادر اليوم',
                                          '${stats.totalToday}',
                                          Icons.today,
                                          const Color(0xFF6A1B9A),
                                          false,
                                        ),
                                        _buildOutboxStatCard(
                                          'قيد الإعداد',
                                          '${stats.inPreparation}',
                                          Icons.edit_note,
                                          Colors.amber.shade800,
                                          false,
                                        ),
                                        _buildOutboxStatCard(
                                          'بانتظار الاعتماد',
                                          '${stats.awaitingApproval}',
                                          Icons.fact_check,
                                          Colors.blue.shade700,
                                          false,
                                        ),
                                        _buildOutboxStatCard(
                                          'تم الإرسال',
                                          '${stats.sent}',
                                          Icons.send_rounded,
                                          Colors.green.shade700,
                                          false,
                                        ),
                                        _buildOutboxStatCard(
                                          'زمن الإصدار',
                                          '${stats.averageProcessingTime} يوم',
                                          Icons.timer,
                                          Colors.teal,
                                          false,
                                        ),
                                      ],
                                    );
                                  },
                                ),
                        ),
                        if (isMobile) SizedBox(height: 12.h),
                        if (isMobile)
                          _buildOutboxStatCard(
                            'متوسط زمن الإصدار',
                            '${stats.averageProcessingTime} يوم',
                            Icons.timer,
                            Colors.teal,
                            true,
                            fullWidth: true,
                          ),
                        SizedBox(height: 24.h),

                        // 2. Action Buttons
                        FadeInDown(
                          child: OutboxActionButtons(
                            onCreate: () {
                              showDialog(
                                context: context,
                                builder: (_) => CreateOutgoingTransactionDialog(
                                  schoolId: effectiveSchoolId,
                                  userId:
                                      'current_user_id', // Replace with actual user ID
                                  userName: widget.userName,
                                  onGenerateNumber: () => _outboxService
                                      .generateNextTransactionNumber(
                                        effectiveSchoolId,
                                      ),
                                  onSave: (transaction) {
                                    _outboxService.createTransaction(
                                      transaction,
                                    );
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'تم إنشاء المعاملة بنجاح',
                                        ),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  },
                                ),
                              );
                            },
                            onSend: () => _showSelectionHint('إرسال الخطاب'),
                            onApprove: () =>
                                _showSelectionHint('اعتماد الخطاب'),
                            onArchive: () => _showSelectionHint('أرشفة الخطاب'),
                            onReport: () => _showActionDialog(
                              context,
                              'تقرير الصادر',
                              'جاري إنشاء التقرير...',
                            ),
                            isMobile: isMobile,
                          ),
                        ),
                        SizedBox(height: 24.h),

                        // 3. Lifecycle Board
                        _buildSectionTitle('دورة حياة المراسلة'),
                        SizedBox(height: 16.h),
                        OutboxLifecycleBoard(
                          transactions: transactions,
                          onTap: (t) {
                            showDialog(
                              context: context,
                              builder: (_) => OutboxTransactionDetailsDialog(
                                transaction: t,
                                onStatusChange: (newStatus) {
                                  _outboxService.updateTransactionStatus(
                                    effectiveSchoolId,
                                    t.id,
                                    newStatus,
                                    'current_user_id', // Replace with actual user ID
                                    widget.userName,
                                  );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('تم تحديث حالة المعاملة'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                          isMobile: isMobile,
                        ),
                        SizedBox(height: 32.h),

                        // 4. Analytics Section
                        _buildSectionTitle('تحليل الصادر المؤسسي'),
                        SizedBox(height: 16.h),
                        if (isMobile)
                          Column(
                            children: [
                              PriorityPieChart(
                                data: _getPriorityData(transactions),
                              ),
                              SizedBox(height: 16.h),
                              _buildOutboxAnalysisPanel(transactions, stats),
                              SizedBox(height: 16.h),
                              OutboxDepartmentLoadWidget(
                                data: _buildRecipientLoadMap(transactions),
                              ),
                            ],
                          )
                        else
                          Column(
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    flex: 5,
                                    child: PriorityPieChart(
                                      data: _getPriorityData(transactions),
                                    ),
                                  ),
                                  SizedBox(width: 20.w),
                                  Expanded(
                                    flex: 5,
                                    child: _buildOutboxAnalysisPanel(
                                      transactions,
                                      stats,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 20.h),
                              OutboxDepartmentLoadWidget(
                                data: _buildRecipientLoadMap(transactions),
                              ),
                            ],
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOfficialBadge() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade50,
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.deepPurple.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.gavel, color: Colors.deepPurple.shade700, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            'نظام الصادر الإداري',
            style: TextStyle(
              color: Colors.deepPurple.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
    );
  }

  void _showActionDialog(BuildContext context, String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
        ),
        content: Text(message, style: TextStyle(fontSize: 14.sp)),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 18.sp,
        fontWeight: FontWeight.bold,
        color: Colors.blueGrey.shade900,
      ),
    );
  }

  Widget _buildOutboxStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile, {
    bool fullWidth = false,
  }) {
    // For desktop layout, we want cards to take available width but not be too wide
    final double width = fullWidth
        ? double.infinity
        : (isMobile
              ? 140.w
              : 200.w); // Increased desktop width slightly for better fit

    return Container(
      width: width,
      padding: EdgeInsets.all(isMobile ? 12.w : 16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isMobile ? 6.w : 8.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: isMobile ? 18.sp : 20.sp),
          ),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: isMobile ? 18.sp : 20.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(
              fontSize: 10.sp,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Map<String, int> _buildRecipientLoadMap(
    List<domain.OutgoingTransaction> transactions,
  ) {
    final byRecipient = <String, int>{};
    for (final t in transactions) {
      final r = t.recipientEntity.trim();
      if (r.isEmpty) continue;
      byRecipient[r] = (byRecipient[r] ?? 0) + 1;
    }
    final entries = byRecipient.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(entries.take(6));
  }

  String _typeLabel(domain.OutgoingTransactionType t) {
    switch (t) {
      case domain.OutgoingTransactionType.report:
        return 'تقرير';
      case domain.OutgoingTransactionType.letter:
        return 'خطاب';
      case domain.OutgoingTransactionType.circular:
        return 'تعميم';
      case domain.OutgoingTransactionType.financial:
        return 'مالي';
      case domain.OutgoingTransactionType.other:
        return 'أخرى';
    }
  }

  String _weekdayLabel(int weekday) {
    switch (weekday) {
      case DateTime.monday:
        return 'الاثنين';
      case DateTime.tuesday:
        return 'الثلاثاء';
      case DateTime.wednesday:
        return 'الأربعاء';
      case DateTime.thursday:
        return 'الخميس';
      case DateTime.friday:
        return 'الجمعة';
      case DateTime.saturday:
        return 'السبت';
      case DateTime.sunday:
        return 'الأحد';
      default:
        return 'غير متوفر';
    }
  }

  Widget _buildOutboxAnalysisPanel(
    List<domain.OutgoingTransaction> transactions,
    domain.OutboxStatistics stats,
  ) {
    final byRecipient = <String, int>{};
    final byType = <domain.OutgoingTransactionType, int>{};
    final byWeekday = <int, int>{};

    for (final t in transactions) {
      final r = t.recipientEntity.trim();
      if (r.isNotEmpty) byRecipient[r] = (byRecipient[r] ?? 0) + 1;
      byType[t.type] = (byType[t.type] ?? 0) + 1;
      final dt = t.sentAt ?? t.createdAt;
      byWeekday[dt.weekday] = (byWeekday[dt.weekday] ?? 0) + 1;
    }

    String topRecipient() {
      if (byRecipient.isEmpty) return 'غير متوفر';
      final e = byRecipient.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return e.first.key;
    }

    String topType() {
      if (byType.isEmpty) return 'غير متوفر';
      final e = byType.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return _typeLabel(e.first.key);
    }

    String peakDay() {
      if (byWeekday.isEmpty) return 'غير متوفر';
      final e = byWeekday.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      return _weekdayLabel(e.first.key);
    }

    final summary = transactions.isEmpty
        ? 'لا توجد مراسلات صادرة مسجلة بعد.'
        : 'اليوم: ${stats.totalToday} صادر، وبانتظار الاعتماد: ${stats.awaitingApproval}، ومتوسط زمن المعالجة: ${stats.averageProcessingTime.toStringAsFixed(1)} يوم.';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Colors.deepPurple),
              SizedBox(width: 8.w),
              Expanded(
                child: Text(
                  'التحليل الإداري للصادر',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade800,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildAnalysisItem(
            'أكثر جهة مستقبلة',
            topRecipient(),
            Icons.business,
            Colors.deepPurple,
          ),
          _buildAnalysisItem(
            'أكثر نوع خطابات',
            topType(),
            Icons.description,
            Colors.blue,
          ),
          _buildAnalysisItem(
            'يوم الذروة للإرسال',
            peakDay(),
            Icons.trending_up,
            Colors.green,
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.deepPurple.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.deepPurple.shade800,
                      size: 16.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'ملخص الأداء الرسمي',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.deepPurple.shade900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  summary,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.deepPurple.shade900,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(6.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8.r),
          ),
          child: Icon(icon, color: color, size: 16.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Map<inbox_domain.TransactionPriority, int> _getPriorityData(
    List<domain.OutgoingTransaction> transactions,
  ) {
    Map<inbox_domain.TransactionPriority, int> data = {};
    for (var t in transactions) {
      inbox_domain.TransactionPriority priority;
      switch (t.priority) {
        case domain.OutgoingTransactionPriority.urgent:
          priority = inbox_domain.TransactionPriority.critical;
          break;
        case domain.OutgoingTransactionPriority.high:
          priority = inbox_domain.TransactionPriority.high;
          break;
        case domain.OutgoingTransactionPriority.normal:
        default:
          priority = inbox_domain.TransactionPriority.medium;
          break;
      }
      data[priority] = (data[priority] ?? 0) + 1;
    }
    return data;
  }
}
