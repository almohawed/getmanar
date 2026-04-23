import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/outgoing_transaction.dart' as domain;

class OutboxActionButtons extends StatelessWidget {
  final VoidCallback onCreate;
  final VoidCallback onSend;
  final VoidCallback onApprove;
  final VoidCallback onArchive;
  final VoidCallback onReport;
  final bool isMobile;

  const OutboxActionButtons({
    super.key,
    required this.onCreate,
    required this.onSend,
    required this.onApprove,
    required this.onArchive,
    required this.onReport,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          _buildMobileActionButton(
            label: 'إنشاء خطاب صادر',
            icon: Icons.add_circle,
            color: const Color(0xFF6A1B9A), // Deep Purple
            onTap: onCreate,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildMobileActionButton(
                  label: 'إرسال خطاب',
                  icon: Icons.send,
                  color: Colors.indigo.shade700,
                  onTap: onSend,
                  compact: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMobileActionButton(
                  label: 'اعتماد خطاب',
                  icon: Icons.check_circle,
                  color: Colors.teal.shade700,
                  onTap: onApprove,
                  compact: true,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildMobileActionButton(
                  label: 'أرشفة خطاب',
                  icon: Icons.archive,
                  color: Colors.blueGrey.shade700,
                  onTap: onArchive,
                  compact: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMobileActionButton(
                  label: 'تقرير الصادر',
                  icon: Icons.bar_chart,
                  color: Colors.deepPurple.shade700,
                  onTap: onReport,
                  compact: true,
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Row(
      children: [
        _buildDesktopActionButton(
          label: 'إنشاء خطاب صادر',
          icon: Icons.add_circle_outline,
          color: const Color(0xFF6A1B9A),
          onTap: onCreate,
        ),
        SizedBox(width: 12.w),
        _buildDesktopActionButton(
          label: 'إرسال خطاب',
          icon: Icons.send_outlined,
          color: Colors.indigo.shade700,
          onTap: onSend,
        ),
        SizedBox(width: 12.w),
        _buildDesktopActionButton(
          label: 'اعتماد خطاب',
          icon: Icons.check_circle_outline,
          color: Colors.teal.shade700,
          onTap: onApprove,
        ),
        SizedBox(width: 12.w),
        _buildDesktopActionButton(
          label: 'أرشفة خطاب',
          icon: Icons.archive_outlined,
          color: Colors.blueGrey.shade700,
          onTap: onArchive,
        ),
        SizedBox(width: 12.w),
        _buildDesktopActionButton(
          label: 'تقرير الصادر',
          icon: Icons.analytics_outlined,
          color: Colors.deepPurple.shade700,
          onTap: onReport,
        ),
      ],
    );
  }

  Widget _buildMobileActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool compact = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: compact ? 12.h : 16.h),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12.r),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20.sp),
            SizedBox(width: 8.w),
            Text(
              label,
              style: TextStyle(
                color: Colors.white,
                fontSize: compact ? 11.sp : 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(color: color.withOpacity(0.3)),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24.sp),
              SizedBox(height: 8.h),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutboxLifecycleBoard extends StatefulWidget {
  final List<domain.OutgoingTransaction> transactions;
  final Function(domain.OutgoingTransaction) onTap;
  final bool isMobile;

  const OutboxLifecycleBoard({
    super.key,
    required this.transactions,
    required this.onTap,
    this.isMobile = false,
  });

  @override
  State<OutboxLifecycleBoard> createState() => _OutboxLifecycleBoardState();
}

class _OutboxLifecycleBoardState extends State<OutboxLifecycleBoard> {
  int _selectedTabIndex = 0;
  final ScrollController _tabsScrollController = ScrollController();

  @override
  void dispose() {
    _tabsScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isMobile) {
      return Column(
        children: [
          ScrollConfiguration(
            behavior: ScrollConfiguration.of(context).copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
                PointerDeviceKind.trackpad,
              },
            ),
            child: SizedBox(
              height: 60.h, // Increased height for scrollbar
              child: Scrollbar(
                controller: _tabsScrollController,
                thumbVisibility: true,
                thickness: 4.w,
                radius: Radius.circular(10.r),
                child: ListView(
                  controller: _tabsScrollController,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 4.h,
                  ),
                  children: [
                    _buildMobileTab(0, 'مسودة', Colors.amber),
                    _buildMobileTab(1, 'مراجعة', Colors.orange),
                    _buildMobileTab(2, 'بانتظار الاعتماد', Colors.blue),
                    _buildMobileTab(3, 'تم الإرسال', Colors.green),
                    _buildMobileTab(4, 'مؤرشف', Colors.grey),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: 16.h),
          _buildActiveColumn(),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // If screen is wide enough, use Row (original layout)
        if (constraints.maxWidth > 1000) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildColumn(
                'مسودة',
                domain.OutgoingTransactionStatus.draft,
                Colors.amber,
              ),
              SizedBox(width: 12.w),
              _buildColumn(
                'قيد المراجعة',
                domain.OutgoingTransactionStatus.reviewing,
                Colors.orange,
              ),
              SizedBox(width: 12.w),
              _buildColumn(
                'بانتظار الاعتماد',
                domain.OutgoingTransactionStatus.awaitingApproval,
                Colors.blue,
              ),
              SizedBox(width: 12.w),
              _buildColumn(
                'تم الإرسال',
                domain.OutgoingTransactionStatus.sent,
                Colors.green,
              ),
              SizedBox(width: 12.w),
              _buildColumn(
                'مؤرشف',
                domain.OutgoingTransactionStatus.archived,
                Colors.grey,
              ),
            ],
          );
        }

        // If screen is medium (tablet/small desktop), use GridView to prevent overflow
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 0.8, // Adjust based on card height
          mainAxisSpacing: 20.h,
          crossAxisSpacing: 20.w,
          children: [
            _buildColumn(
              'مسودة',
              domain.OutgoingTransactionStatus.draft,
              Colors.amber,
              isExpanded: false,
            ),
            _buildColumn(
              'قيد المراجعة',
              domain.OutgoingTransactionStatus.reviewing,
              Colors.orange,
              isExpanded: false,
            ),
            _buildColumn(
              'بانتظار الاعتماد',
              domain.OutgoingTransactionStatus.awaitingApproval,
              Colors.blue,
              isExpanded: false,
            ),
            _buildColumn(
              'تم الإرسال',
              domain.OutgoingTransactionStatus.sent,
              Colors.green,
              isExpanded: false,
            ),
            _buildColumn(
              'مؤرشف',
              domain.OutgoingTransactionStatus.archived,
              Colors.grey,
              isExpanded: false,
            ),
          ],
        );
      },
    );
  }

  Widget _buildMobileTab(int index, String label, Color color) {
    final isSelected = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Container(
        margin: EdgeInsetsDirectional.only(end: 12.w, bottom: 4.h),
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(24.r),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 12.sp,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActiveColumn() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildColumn(
          '',
          domain.OutgoingTransactionStatus.draft,
          Colors.amber,
        );
      case 1:
        return _buildColumn(
          '',
          domain.OutgoingTransactionStatus.reviewing,
          Colors.orange,
        );
      case 2:
        return _buildColumn(
          '',
          domain.OutgoingTransactionStatus.awaitingApproval,
          Colors.blue,
        );
      case 3:
        return _buildColumn(
          '',
          domain.OutgoingTransactionStatus.sent,
          Colors.green,
        );
      case 4:
        return _buildColumn(
          '',
          domain.OutgoingTransactionStatus.archived,
          Colors.grey,
        );
      default:
        return const SizedBox();
    }
  }

  Widget _buildColumn(
    String title,
    domain.OutgoingTransactionStatus status,
    Color color, {
    bool isExpanded = true,
  }) {
    final columnTransactions = widget.transactions
        .where((t) => t.status == status)
        .toList();

    Widget columnContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8.r),
              border: Border(
                right: BorderSide(color: color, width: 4.w),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: color.withOpacity(0.8),
                  ),
                ),
                Text(
                  '${columnTransactions.length}',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        if (title.isNotEmpty) SizedBox(height: 12.h),
        if (columnTransactions.isEmpty)
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.h),
              child: Text(
                'لا توجد مراسلات',
                style: TextStyle(color: Colors.grey, fontSize: 11.sp),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: columnTransactions.length,
            itemBuilder: (context, index) {
              final t = columnTransactions[index];
              return _OutgoingTransactionCard(
                transaction: t,
                onTap: () => widget.onTap(t),
                color: color,
              );
            },
          ),
      ],
    );

    if (isExpanded) {
      return Expanded(flex: widget.isMobile ? 0 : 1, child: columnContent);
    }

    return columnContent;
  }
}

class _OutgoingTransactionCard extends StatelessWidget {
  final domain.OutgoingTransaction transaction;
  final VoidCallback onTap;
  final Color color;

  const _OutgoingTransactionCard({
    required this.transaction,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(12.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    transaction.number,
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey,
                    ),
                  ),
                  _buildTypeBadge(transaction.type),
                ],
              ),
              SizedBox(height: 8.h),
              Text(
                transaction.subject,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4.h),
              Text(
                'الجهة: ${transaction.recipientEntity}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.blueGrey.shade600,
                ),
              ),
              SizedBox(height: 12.h),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12.sp, color: Colors.grey),
                      SizedBox(width: 4.w),
                      Text(
                        '03/03', // Demo date
                        style: TextStyle(fontSize: 10.sp, color: Colors.grey),
                      ),
                    ],
                  ),
                  if (transaction.attachments.isNotEmpty)
                    Icon(
                      Icons.attach_file,
                      size: 14.sp,
                      color: Colors.blueGrey,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeBadge(domain.OutgoingTransactionType type) {
    String label = 'خطاب';
    Color bgColor = Colors.purple.shade50;
    Color textColor = Colors.purple.shade700;

    switch (type) {
      case domain.OutgoingTransactionType.report:
        label = 'تقرير';
        bgColor = Colors.blue.shade50;
        textColor = Colors.blue.shade700;
        break;
      case domain.OutgoingTransactionType.circular:
        label = 'تعميم';
        bgColor = Colors.orange.shade50;
        textColor = Colors.orange.shade700;
        break;
      case domain.OutgoingTransactionType.financial:
        label = 'مالي';
        bgColor = Colors.green.shade50;
        textColor = Colors.green.shade700;
        break;
      default:
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

class OutboxDepartmentLoadWidget extends StatelessWidget {
  final Map<String, int> data;

  const OutboxDepartmentLoadWidget({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
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
              Icon(Icons.bar_chart, color: Colors.indigo.shade600),
              SizedBox(width: 8.w),
              Text(
                'مؤشرات الأداء حسب الإدارة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          ...data.entries.map((e) => _buildLoadItem(e.key, e.value)).toList(),
        ],
      ),
    );
  }

  Widget _buildLoadItem(String label, int value) {
    // Assuming max value is 20 for scaling
    final double percentage = (value / 20).clamp(0.0, 1.0);

    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.blueGrey.shade700,
                ),
              ),
              Text(
                '$value معاملات',
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          ClipRRect(
            borderRadius: BorderRadius.circular(4.r),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 8.h,
              backgroundColor: Colors.grey.shade100,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.indigo.shade400),
            ),
          ),
        ],
      ),
    );
  }
}
