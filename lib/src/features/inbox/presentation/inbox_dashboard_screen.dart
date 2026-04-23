import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import '../../auth/presentation/auth_controller.dart';
import '../application/inbox_service.dart';
import '../domain/transaction.dart';
import 'outbox_dashboard_screen.dart';
import 'widgets/smart_inbox_widgets.dart';
import 'widgets/transaction_details_panel.dart';
import 'widgets/cycle_health_indicator.dart' as cycle;

class InboxDashboardScreen extends ConsumerStatefulWidget {
  final String? schoolId;
  final String? userId;
  final String? userName;

  const InboxDashboardScreen({
    super.key,
    this.schoolId,
    this.userId,
    this.userName,
  });

  @override
  ConsumerState<InboxDashboardScreen> createState() =>
      _InboxDashboardScreenState();
}

class _InboxDashboardScreenState extends ConsumerState<InboxDashboardScreen> {
  final InboxService _inboxService = InboxService();
  Transaction? _selectedTransaction;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    final user = authState.value;

    final effectiveSchoolId = widget.schoolId?.isNotEmpty == true
        ? widget.schoolId!
        : user?.schoolId ?? '';
    final effectiveUserId = widget.userId?.isNotEmpty == true
        ? widget.userId!
        : user?.id ?? '';
    final effectiveUserName = widget.userName?.isNotEmpty == true
        ? widget.userName!
        : user?.name ?? 'مستخدم';

    if (effectiveSchoolId.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('الوارد الإداري الذكي'),
          centerTitle: true,
          backgroundColor: const Color(0xFF1565C0),
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل بيانات المدرسة...'),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color(0xFFF8FAFC), Color(0xFFF8FAFC)],
            stops: [0.0, 0.2, 1.0],
          ),
        ),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Row(
              children: [
                FadeInLeft(
                  child: const Icon(Icons.auto_awesome, color: Colors.amber),
                ),
                SizedBox(width: 8.w),
                const Text('لوحة الوارد الإداري الذكي'),
              ],
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              IconButton(
                tooltip: 'إدارة الصادر',
                icon: const Icon(Icons.outbox, color: Colors.white),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => OutboxDashboardScreen(
                        schoolId: effectiveSchoolId,
                        userName: effectiveUserName,
                        userRole: 'مدير المدرسة',
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.refresh, color: Colors.white),
                onPressed: () => setState(() {}),
              ),
              SizedBox(width: 8.w),
            ],
          ),
          body: Stack(
            children: [
              StreamBuilder<List<Transaction>>(
                stream: _inboxService.getTransactions(effectiveSchoolId),
                builder: (context, snapshot) {
                  final transactions = snapshot.data ?? const <Transaction>[];

                  return FutureBuilder<Map<String, dynamic>>(
                    future: _fetchAllStats(effectiveSchoolId),
                    builder: (context, statsSnapshot) {
                      final stats =
                          statsSnapshot.data ??
                          {
                            'inboxStats': InboxStatistics(
                              totalToday: 0,
                              unrouted: 0,
                              delayed: 0,
                              averageProcessingTime: 0,
                              critical: 0,
                              flowStatus: 'غير متوفر',
                            ),
                            'analysis': AdministrativeAnalysis(
                              topSenderEntity: 'غير متوفر',
                              topSenderCount: 0,
                              mostDelayedType: TransactionType.other,
                              peakDays: const [],
                              delayReasons: const {},
                              summary: 'لا توجد بيانات كافية للتحليل بعد.',
                            ),
                            'workload': WorkloadMap(
                              departmentLoad: const {},
                              mostReceivedStaff: 'غير متوفر',
                              mostReceivedCount: 0,
                              mostDelayedStaff: 'غير متوفر',
                              mostDelayedCount: 0,
                            ),
                          };

                      final inboxStats = stats['inboxStats'] as InboxStatistics;
                      final analysis =
                          stats['analysis'] as AdministrativeAnalysis;
                      final workload = stats['workload'] as WorkloadMap;

                      final isMobile = MediaQuery.of(context).size.width < 600;

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
                                            'أهلاً بك، $effectiveUserName',
                                            style: TextStyle(
                                              color: Colors.blueGrey.shade900,
                                              fontSize: 20.sp,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          SizedBox(height: 8.h),
                                          _buildFlowStatusBadge(
                                            inboxStats.flowStatus,
                                          ),
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
                                                  'أهلاً بك، $effectiveUserName',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade900,
                                                    fontSize: 24.sp,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                Text(
                                                  'لديك ${inboxStats.unrouted} معاملات بانتظار التوجيه و ${inboxStats.delayed} معاملات متأخرة.',
                                                  style: TextStyle(
                                                    color: Colors
                                                        .blueGrey
                                                        .shade700,
                                                    fontSize: 14.sp,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          _buildFlowStatusBadge(
                                            inboxStats.flowStatus,
                                          ),
                                        ],
                                      ),
                              ),
                            ),

                            // 1. KPI Cards Section
                            FadeInDown(
                              child: isMobile
                                  ? GridView.count(
                                      crossAxisCount: 2,
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      mainAxisSpacing: 12.h,
                                      crossAxisSpacing: 12.w,
                                      childAspectRatio: 1.2,
                                      children: [
                                        _buildTopStatCard(
                                          'إجمالي الوارد',
                                          '${transactions.length}',
                                          Icons.inbox,
                                          const Color(0xFF1565C0),
                                          true,
                                        ),
                                        _buildTopStatCard(
                                          'غير موجهة',
                                          '${inboxStats.unrouted}',
                                          Icons.alt_route,
                                          const Color(0xFFEF6C00),
                                          true,
                                        ),
                                        _buildTopStatCard(
                                          'متأخرة',
                                          '${inboxStats.delayed}',
                                          Icons.timer_off,
                                          const Color(0xFFC62828),
                                          true,
                                        ),
                                        _buildTopStatCard(
                                          'زمن المعالجة',
                                          '${inboxStats.averageProcessingTime.toStringAsFixed(1)} س',
                                          Icons.speed,
                                          const Color(0xFF2E7D32),
                                          true,
                                        ),
                                        // Specific handling for the 5th card to span full width if needed
                                      ],
                                    )
                                  : SizedBox(
                                      height: 150.h,
                                      child: SingleChildScrollView(
                                        scrollDirection: Axis.horizontal,
                                        physics: const BouncingScrollPhysics(),
                                        padding: EdgeInsets.symmetric(
                                          vertical: 8.h,
                                        ),
                                        child: Row(
                                          children: [
                                            _buildTopStatCard(
                                              'إجمالي الوارد هذا الأسبوع',
                                              '${transactions.length}',
                                              Icons.inbox,
                                              const Color(0xFF1565C0),
                                              false,
                                            ),
                                            SizedBox(width: 12.w),
                                            _buildTopStatCard(
                                              'المعاملات غير الموجهة',
                                              '${inboxStats.unrouted}',
                                              Icons.alt_route,
                                              const Color(0xFFEF6C00),
                                              false,
                                            ),
                                            SizedBox(width: 12.w),
                                            _buildTopStatCard(
                                              'المعاملات المتأخرة',
                                              '${inboxStats.delayed}',
                                              Icons.timer_off,
                                              const Color(0xFFC62828),
                                              false,
                                            ),
                                            SizedBox(width: 12.w),
                                            _buildTopStatCard(
                                              'زمن المعالجة',
                                              '${inboxStats.averageProcessingTime.toStringAsFixed(1)} س',
                                              Icons.speed,
                                              const Color(0xFF2E7D32),
                                              false,
                                            ),
                                            SizedBox(width: 12.w),
                                            _buildTopStatCard(
                                              'نسبة الإنجاز',
                                              '${(100 - (inboxStats.delayed / (transactions.length > 0 ? transactions.length : 1) * 100)).toInt()}%',
                                              Icons.check_circle_outline,
                                              const Color(0xFF6A1B9A),
                                              false,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                            if (isMobile) SizedBox(height: 12.h),
                            if (isMobile)
                              _buildTopStatCard(
                                'نسبة الإنجاز الإجمالية',
                                '${(100 - (inboxStats.delayed / (transactions.length > 0 ? transactions.length : 1) * 100)).toInt()}%',
                                Icons.check_circle_outline,
                                const Color(0xFF6A1B9A),
                                true,
                                fullWidth: true,
                              ),
                            SizedBox(height: 24.h),

                            // 2. Action Buttons
                            FadeInDown(
                              child: ActionButtonsRow(
                                onAdd: () => _showAddTransactionDialog(context),
                                onExport: () => _handleExport(context),
                                onSettings: () => _showSettings(context),
                                isMobile: isMobile,
                              ),
                            ),
                            SizedBox(height: 24.h),

                            // 3. Main Dashboard Layout
                            if (isMobile)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionTitle('تدفق المعاملات'),
                                  SizedBox(height: 16.h),
                                  TransactionFlowBoard(
                                    transactions: transactions,
                                    onTransactionTap: _showTransactionDetails,
                                    onStatusChange: _handleStatusChange,
                                    isMobile: true,
                                  ),
                                  SizedBox(height: 24.h),
                                  _buildSectionTitle('التحليلات الذكية'),
                                  SizedBox(height: 16.h),
                                  PriorityPieChart(
                                    data: _getPriorityData(transactions),
                                  ),
                                  SizedBox(height: 16.h),
                                  DepartmentLoadBarChart(
                                    data: workload.departmentLoad,
                                  ),
                                  SizedBox(height: 16.h),
                                  AdministrativeAnalysisPanel(
                                    schoolId: effectiveSchoolId,
                                  ),
                                  SizedBox(height: 16.h),
                                  cycle.CycleHealthIndicatorWidget(
                                    schoolId: effectiveSchoolId,
                                    inboxService: _inboxService,
                                  ),
                                  SizedBox(height: 16.h),
                                  RecentTransactionsTable(
                                    transactions: transactions,
                                    onTap: _showTransactionDetails,
                                  ),
                                ],
                              )
                            else
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Left Side - Flow Board and Charts
                                  Expanded(
                                    flex: 7,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        _buildSectionTitle('تدفق المعاملات'),
                                        SizedBox(height: 16.h),
                                        TransactionFlowBoard(
                                          transactions: transactions,
                                          onTransactionTap:
                                              _showTransactionDetails,
                                          onStatusChange: _handleStatusChange,
                                        ),
                                        SizedBox(height: 32.h),

                                        // Charts Row
                                        Row(
                                          children: [
                                            Expanded(
                                              child: FadeInLeft(
                                                child: PriorityPieChart(
                                                  data: _getPriorityData(
                                                    transactions,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 20.w),
                                            Expanded(
                                              child: FadeInLeft(
                                                child: DepartmentLoadBarChart(
                                                  data: workload.departmentLoad,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 20.h),
                                        FadeInUp(
                                          child: WeeklyFlowTrendChart(
                                            received: _weeklyTrend(
                                              transactions,
                                            )['received']!,
                                            closed: _weeklyTrend(
                                              transactions,
                                            )['closed']!,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 20.w),

                                  // Right Side - Analysis and KPI Details
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      children: [
                                        AdministrativeAnalysisPanel(
                                          schoolId: effectiveSchoolId,
                                        ),
                                        SizedBox(height: 20.h),
                                        cycle.CycleHealthIndicatorWidget(
                                          schoolId: effectiveSchoolId,
                                          inboxService: _inboxService,
                                        ),
                                        SizedBox(height: 20.h),
                                        RecentTransactionsTable(
                                          transactions: transactions,
                                          onTap: _showTransactionDetails,
                                        ),
                                      ],
                                    ),
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
              if (_selectedTransaction != null)
                Positioned(
                  right: 0,
                  left: MediaQuery.of(context).size.width < 600 ? 0 : null,
                  top: 0,
                  bottom: 0,
                  child: TransactionDetailsPanel(
                    transaction: _selectedTransaction!,
                    onClose: _hideTransactionDetails,
                    inboxService: _inboxService,
                    schoolId: effectiveSchoolId,
                    userId: effectiveUserId,
                    userName: effectiveUserName,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFlowStatusBadge(String status) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50.withOpacity(0.8),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.trending_up, color: Colors.green.shade700, size: 18.sp),
          SizedBox(width: 8.w),
          Text(
            'حالة التدفق: $status',
            style: TextStyle(
              color: Colors.blueGrey.shade900,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
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

  Future<Map<String, dynamic>> _fetchAllStats(String schoolId) async {
    try {
      final results = await Future.wait([
        _inboxService.getStatistics(schoolId),
        _inboxService.getAnalysis(schoolId),
        _inboxService.getWorkloadMap(schoolId),
      ]).timeout(const Duration(seconds: 10));

      return {
        'inboxStats': results[0],
        'analysis': results[1],
        'workload': results[2],
      };
    } catch (e) {
      // Return empty stats in case of error/timeout to avoid hanging
      return {
        'inboxStats': InboxStatistics(
          totalToday: 0,
          unrouted: 0,
          delayed: 0,
          averageProcessingTime: 0,
          critical: 0,
          flowStatus: 'غير متوفر',
        ),
        'analysis': AdministrativeAnalysis(
          topSenderEntity: 'غير متوفر',
          topSenderCount: 0,
          mostDelayedType: TransactionType.other,
          peakDays: [],
          delayReasons: {},
          summary: 'فشل تحميل التحليل الذكي',
        ),
        'workload': WorkloadMap(
          departmentLoad: {},
          mostReceivedStaff: 'غير متوفر',
          mostReceivedCount: 0,
          mostDelayedStaff: 'غير متوفر',
          mostDelayedCount: 0,
        ),
      };
    }
  }

  Widget _buildTopStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    bool isMobile, {
    bool fullWidth = false,
  }) {
    return Container(
      width: fullWidth ? double.infinity : (isMobile ? 140.w : 180.w),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(isMobile ? 6.w : 8.w),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: isMobile ? 18.sp : 20.sp),
              ),
              if (fullWidth)
                Icon(Icons.trending_up, color: Colors.green, size: 20.sp),
            ],
          ),
          SizedBox(height: isMobile ? 8.h : 12.h),
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
              fontSize: isMobile ? 10.sp : 11.sp,
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

  Map<TransactionPriority, int> _getPriorityData(
    List<Transaction> transactions,
  ) {
    final data = <TransactionPriority, int>{};
    for (var t in transactions) {
      data[t.priority] = (data[t.priority] ?? 0) + 1;
    }
    return data;
  }

  Map<String, List<double>> _weeklyTrend(List<Transaction> transactions) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 6));
    final received = List<double>.filled(7, 0);
    final closed = List<double>.filled(7, 0);

    int dayIndex(DateTime dt) {
      final d = DateTime(dt.year, dt.month, dt.day);
      final diff = d.difference(start).inDays;
      return diff;
    }

    for (final t in transactions) {
      final i = dayIndex(t.receivedAt);
      if (i >= 0 && i < 7) received[i] += 1;
      final c = t.closedAt;
      if (c != null) {
        final j = dayIndex(c);
        if (j >= 0 && j < 7) closed[j] += 1;
      }
    }
    return {'received': received, 'closed': closed};
  }

  void _showTransactionDetails(Transaction transaction) {
    setState(() {
      _selectedTransaction = transaction;
    });
  }

  void _hideTransactionDetails() {
    setState(() {
      _selectedTransaction = null;
    });
  }

  void _showAddTransactionDialog(BuildContext context) {
    // Implement add transaction dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('سيتم فتح نافذة إضافة معاملة جديدة قريباً')),
    );
  }

  void _handleExport(BuildContext context) {
    // Implement export
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('جاري تجهيز التقرير الإداري...')),
    );
  }

  void _showSettings(BuildContext context) {
    // Implement settings
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('نافذة الإعدادات قيد التطوير')),
    );
  }

  Future<void> _handleStatusChange(
    Transaction transaction,
    TransactionStatus newStatus,
  ) async {
    final authState = ref.read(authStateProvider);
    final user = authState.value;

    final effectiveSchoolId = widget.schoolId?.isNotEmpty == true
        ? widget.schoolId!
        : user?.schoolId ?? '';
    final effectiveUserId = widget.userId?.isNotEmpty == true
        ? widget.userId!
        : user?.id ?? '';
    final effectiveUserName = widget.userName?.isNotEmpty == true
        ? widget.userName!
        : user?.name ?? 'مستخدم';

    try {
      await _inboxService.updateTransactionStatus(
        schoolId: effectiveSchoolId,
        transactionId: transaction.id,
        newStatus: newStatus,
        byUserId: effectiveUserId,
        byUserName: effectiveUserName,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم تحديث حالة المعاملة إلى: ${newStatus.name}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الحالة: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
