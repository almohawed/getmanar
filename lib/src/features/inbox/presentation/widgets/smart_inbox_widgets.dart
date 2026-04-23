import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';
import 'package:intl/intl.dart' as intl;
import '../../domain/transaction.dart' as domain;

class StatCardWithSparkline extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final List<double> spots;

  const StatCardWithSparkline({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    required this.spots,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInRight(
      child: Container(
        padding: EdgeInsets.all(16.w),
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
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  SizedBox(
                    height: 30.h,
                    child: LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: false),
                        titlesData: const FlTitlesData(show: false),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots
                                .asMap()
                                .entries
                                .map((e) => FlSpot(e.key.toDouble(), e.value))
                                .toList(),
                            isCurved: true,
                            color: Colors.white,
                            barWidth: 2,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(
                              show: true,
                              color: Colors.white.withOpacity(0.2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'اتجاه 7 أيام',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.7),
                      fontSize: 10.sp,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 24.sp),
            ),
          ],
        ),
      ),
    );
  }
}

class TransactionFlowBoard extends StatefulWidget {
  final List<domain.Transaction> transactions;
  final Function(domain.Transaction) onTransactionTap;
  final Function(domain.Transaction, domain.TransactionStatus) onStatusChange;
  final bool isMobile;

  const TransactionFlowBoard({
    super.key,
    required this.transactions,
    required this.onTransactionTap,
    required this.onStatusChange,
    this.isMobile = false,
  });

  @override
  State<TransactionFlowBoard> createState() => _TransactionFlowBoardState();
}

class _TransactionFlowBoardState extends State<TransactionFlowBoard> {
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
                    _buildMobileTab(0, 'الوارد', Colors.orange),
                    _buildMobileTab(1, 'الموجه', Colors.blue),
                    _buildMobileTab(2, 'المتابعة', Colors.purple),
                    _buildMobileTab(3, 'المتأخر', Colors.red),
                    _buildMobileTab(4, 'المغلق', Colors.green),
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

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildColumn(
          'بانتظار التوجيه',
          domain.TransactionStatus.awaitingDirectorRouting,
          Colors.orange,
        ),
        SizedBox(width: 12.w),
        _buildColumn(
          'قيد التنفيذ',
          domain.TransactionStatus.routed,
          Colors.blue,
        ),
        SizedBox(width: 12.w),
        _buildColumn(
          'تحتاج متابعة',
          domain.TransactionStatus.needsFollowup,
          Colors.purple,
        ),
        SizedBox(width: 12.w),
        _buildColumn('متأخرة', domain.TransactionStatus.delayed, Colors.red),
        SizedBox(width: 12.w),
        _buildColumn('مغلقة', domain.TransactionStatus.closed, Colors.green),
      ],
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
              fontSize: 13.sp,
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
          domain.TransactionStatus.awaitingDirectorRouting,
          Colors.orange,
        );
      case 1:
        return _buildColumn('', domain.TransactionStatus.routed, Colors.blue);
      case 2:
        return _buildColumn(
          '',
          domain.TransactionStatus.needsFollowup,
          Colors.purple,
        );
      case 3:
        return _buildColumn('', domain.TransactionStatus.delayed, Colors.red);
      case 4:
        return _buildColumn('', domain.TransactionStatus.closed, Colors.green);
      default:
        return const SizedBox();
    }
  }

  Widget _buildColumn(
    String title,
    domain.TransactionStatus status,
    Color color,
  ) {
    final columnTransactions = widget.transactions
        .where((t) => t.status == status)
        .toList();

    return Expanded(
      flex: widget.isMobile ? 0 : 1,
      child: Column(
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
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                      color: color.withOpacity(0.8),
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.all(4.w),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${columnTransactions.length}',
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
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
                  'لا توجد معاملات',
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
                return _TransactionCard(
                  transaction: t,
                  onTap: () => widget.onTransactionTap(t),
                  color: color,
                );
              },
            ),
        ],
      ),
    );
  }
}

class _TransactionCard extends StatelessWidget {
  final domain.Transaction transaction;
  final VoidCallback onTap;
  final Color color;

  const _TransactionCard({
    required this.transaction,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return FadeInUp(
      child: Card(
        margin: EdgeInsets.only(bottom: 12.h),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
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
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 8.w,
                        vertical: 4.h,
                      ),
                      decoration: BoxDecoration(
                        color: _getTypeColor(transaction.type).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        _getTypeName(transaction.type),
                        style: TextStyle(
                          fontSize: 10.sp,
                          color: _getTypeColor(transaction.type),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (transaction.priority ==
                        domain.TransactionPriority.critical)
                      Icon(Icons.warning, color: Colors.red, size: 16.sp),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  transaction.subject,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade900,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 4.h),
                Text(
                  transaction.senderEntity,
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 12.h),
                const Divider(height: 1),
                SizedBox(height: 8.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 12.sp,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          intl.DateFormat(
                            'MM/dd',
                          ).format(transaction.receivedAt),
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                    if (transaction.attachments.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.attach_file,
                            size: 12.sp,
                            color: Colors.grey,
                          ),
                          Text(
                            '${transaction.attachments.length}',
                            style: TextStyle(
                              fontSize: 10.sp,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
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

  Color _getTypeColor(domain.TransactionType type) {
    switch (type) {
      case domain.TransactionType.circular:
        return Colors.indigo;
      case domain.TransactionType.administrative:
        return Colors.blue;
      case domain.TransactionType.student:
        return Colors.teal;
      case domain.TransactionType.financial:
        return Colors.amber.shade800;
      case domain.TransactionType.complaint:
        return Colors.red;
      case domain.TransactionType.other:
        return Colors.grey;
    }
  }

  String _getTypeName(domain.TransactionType type) {
    switch (type) {
      case domain.TransactionType.circular:
        return 'تعميم';
      case domain.TransactionType.administrative:
        return 'إدارية';
      case domain.TransactionType.student:
        return 'طلابية';
      case domain.TransactionType.financial:
        return 'مالية';
      case domain.TransactionType.complaint:
        return 'شكوى';
      case domain.TransactionType.other:
        return 'أخرى';
    }
  }
}

class AdministrativeAnalysisPanel extends StatelessWidget {
  final String? schoolId;

  const AdministrativeAnalysisPanel({super.key, this.schoolId});

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
              const Icon(Icons.analytics_outlined, color: Colors.blue),
              SizedBox(width: 8.w),
              Text(
                'التحليل الإداري',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildAnalysisItem(
            'أكثر جهة مراسلة',
            'مكتب التعليم',
            Icons.business,
            Colors.blue,
          ),
          SizedBox(height: 12.h),
          _buildAnalysisItem(
            'نوع المعاملات الأكثر تأخيراً',
            'الشكاوى',
            Icons.warning_amber,
            Colors.red,
          ),
          SizedBox(height: 12.h),
          _buildAnalysisItem(
            'أيام الذروة',
            'الاثنين، الثلاثاء',
            Icons.trending_up,
            Colors.indigo,
          ),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.assignment_turned_in_outlined,
                      color: Colors.blue.shade800,
                      size: 18.sp,
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      'توصية النظام',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  'لوحظ ارتفاع في معاملات مكتب التعليم بنسبة 25% هذا الأسبوع. يُنصح بتفويض وكيل الشؤون التعليمية للمساعدة في توجيه هذه المعاملات لتسريع الدورة الإدارية.',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: Colors.blue.shade900,
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
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18.sp),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 13.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class CycleHealthIndicatorWidget extends StatelessWidget {
  final double overallScore;

  const CycleHealthIndicatorWidget({super.key, required this.overallScore});

  @override
  Widget build(BuildContext context) {
    final isGood = overallScore > 80;
    final isFair = overallScore > 60;
    final color = isGood ? Colors.green : (isFair ? Colors.orange : Colors.red);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          Text(
            'كفاءة الدورة الإدارية',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 140.h,
            width: 140.h,
            child: Stack(
              children: [
                Center(
                  child: SizedBox(
                    height: 120.h,
                    width: 120.h,
                    child: CircularProgressIndicator(
                      value: overallScore / 100,
                      strokeWidth: 12.r,
                      backgroundColor: Colors.grey.shade100,
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${overallScore.toInt()}%',
                        style: TextStyle(
                          fontSize: 22.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey.shade900,
                          height: 1,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        isGood ? 'ممتاز' : (isFair ? 'جيد' : 'ضعيف'),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: color,
                          height: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PriorityPieChart extends StatelessWidget {
  final Map<domain.TransactionPriority, int> data;

  const PriorityPieChart({super.key, required this.data});

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
          Text(
            'توزيع المعاملات حسب الأولوية',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 200.h,
            child: PieChart(
              PieChartData(
                sectionsSpace: 4,
                centerSpaceRadius: 40,
                sections: [
                  PieChartSectionData(
                    color: Colors.red.shade600,
                    value: (data[domain.TransactionPriority.critical] ?? 0)
                        .toDouble(),
                    title: '${data[domain.TransactionPriority.critical] ?? 0}',
                    radius: 60,
                    titleStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.orange.shade600,
                    value: (data[domain.TransactionPriority.high] ?? 0)
                        .toDouble(),
                    title: '${data[domain.TransactionPriority.high] ?? 0}',
                    radius: 55,
                    titleStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.blue.shade600,
                    value: (data[domain.TransactionPriority.medium] ?? 0)
                        .toDouble(),
                    title: '${data[domain.TransactionPriority.medium] ?? 0}',
                    radius: 50,
                    titleStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                  PieChartSectionData(
                    color: Colors.teal.shade600,
                    value: (data[domain.TransactionPriority.low] ?? 0)
                        .toDouble(),
                    title: '${data[domain.TransactionPriority.low] ?? 0}',
                    radius: 45,
                    titleStyle: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14.sp,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 16.h),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildLegend() {
    return Column(
      children: [
        _buildLegendItem('حرجة للغاية', Colors.red.shade600),
        _buildLegendItem('عالية الأولوية', Colors.orange.shade600),
        _buildLegendItem('متوسطة الأولوية', Colors.blue.shade600),
        _buildLegendItem('منخفضة الأولوية', Colors.teal.shade600),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(
            width: 12.w,
            height: 12.w,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          SizedBox(width: 8.w),
          Text(
            label,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

class DepartmentLoadBarChart extends StatelessWidget {
  final Map<String, int> data;

  const DepartmentLoadBarChart({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final sortedEntries = data.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final displayEntries = sortedEntries.take(5).toList();

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
          Text(
            'ضغط العمل حسب الإدارة',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 200.h,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    (displayEntries.isEmpty
                            ? 10
                            : displayEntries
                                      .map((e) => e.value)
                                      .reduce((a, b) => a > b ? a : b) *
                                  1.2)
                        .toDouble(),
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        if (value.toInt() < displayEntries.length) {
                          return Padding(
                            padding: EdgeInsets.only(top: 8.h),
                            child: Text(
                              displayEntries[value.toInt()].key
                                  .split(' ')
                                  .first,
                              style: TextStyle(fontSize: 10.sp),
                            ),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: displayEntries.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value.value.toDouble(),
                        color: Colors.indigo.shade400,
                        width: 20.w,
                        borderRadius: BorderRadius.circular(4.r),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY: 100,
                          color: Colors.grey.shade100,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class WeeklyFlowTrendChart extends StatelessWidget {
  final List<double> received;
  final List<double> closed;

  const WeeklyFlowTrendChart({
    super.key,
    required this.received,
    required this.closed,
  });

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
          Text(
            'معدل التدفق الأسبوعي',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade800,
            ),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 200.h,
            child: LineChart(
              LineChartData(
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (value) =>
                      FlLine(color: Colors.grey.shade200, strokeWidth: 1),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['ح', 'ن', 'ث', 'ر', 'خ', 'ج', 'س'];
                        if (value.toInt() < days.length) {
                          return Text(
                            days[value.toInt()],
                            style: TextStyle(fontSize: 10.sp),
                          );
                        }
                        return const SizedBox();
                      },
                    ),
                  ),
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: received
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: Colors.blue.shade600,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                  LineChartBarData(
                    spots: closed
                        .asMap()
                        .entries
                        .map((e) => FlSpot(e.key.toDouble(), e.value))
                        .toList(),
                    isCurved: true,
                    color: Colors.green.shade600,
                    barWidth: 3,
                    dotData: const FlDotData(show: true),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSmallLegend('وارد', Colors.blue.shade600),
              SizedBox(width: 16.w),
              _buildSmallLegend('مغلق', Colors.green.shade600),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSmallLegend(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          label,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey),
        ),
      ],
    );
  }
}

class ActionButtonsRow extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onExport;
  final VoidCallback onSettings;
  final bool isMobile;

  const ActionButtonsRow({
    super.key,
    required this.onAdd,
    required this.onExport,
    required this.onSettings,
    this.isMobile = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isMobile) {
      return Column(
        children: [
          _buildMobileActionButton(
            label: 'إضافة معاملة واردة',
            icon: Icons.add_circle,
            color: const Color(0xFF1565C0),
            onTap: onAdd,
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              Expanded(
                child: _buildMobileActionButton(
                  label: 'تصدير تقرير',
                  icon: Icons.ios_share,
                  color: Colors.teal.shade700,
                  onTap: onExport,
                  compact: true,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: _buildMobileActionButton(
                  label: 'الإعدادات',
                  icon: Icons.settings,
                  color: Colors.blueGrey.shade700,
                  onTap: onSettings,
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
        Expanded(
          child: _buildActionButton(
            label: 'إضافة معاملة',
            icon: Icons.add_circle_outline,
            color: const Color(0xFF1565C0),
            onTap: onAdd,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildActionButton(
            label: 'تصدير تقرير',
            icon: Icons.ios_share,
            color: Colors.teal.shade700,
            onTap: onExport,
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: _buildActionButton(
            label: 'إعدادات الوارد',
            icon: Icons.settings_outlined,
            color: Colors.blueGrey.shade700,
            onTap: onSettings,
          ),
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
                fontSize: compact ? 12.sp : 14.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 4.h),
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
    );
  }
}

class RecentTransactionsTable extends StatelessWidget {
  final List<domain.Transaction> transactions;
  final Function(domain.Transaction) onTap;

  const RecentTransactionsTable({
    super.key,
    required this.transactions,
    required this.onTap,
  });

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'آخر المعاملات الحرجة',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade800,
                ),
              ),
              TextButton(onPressed: () {}, child: const Text('عرض الكل')),
            ],
          ),
          SizedBox(height: 12.h),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columnSpacing: 20.w,
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              columns: const [
                DataColumn(label: Text('الرقم')),
                DataColumn(label: Text('الموضوع')),
                DataColumn(label: Text('الجهة')),
                DataColumn(label: Text('التاريخ')),
                DataColumn(label: Text('الحالة')),
              ],
              rows: transactions.take(5).map((t) {
                return DataRow(
                  onSelectChanged: (_) => onTap(t),
                  cells: [
                    DataCell(Text(t.number, style: TextStyle(fontSize: 11.sp))),
                    DataCell(
                      SizedBox(
                        width: 150.w,
                        child: Text(
                          t.subject,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11.sp),
                        ),
                      ),
                    ),
                    DataCell(
                      Text(t.senderEntity, style: TextStyle(fontSize: 11.sp)),
                    ),
                    DataCell(
                      Text(
                        intl.DateFormat('yyyy/MM/dd').format(t.receivedAt),
                        style: TextStyle(fontSize: 11.sp),
                      ),
                    ),
                    DataCell(_buildStatusBadge(t.status)),
                  ],
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(domain.TransactionStatus status) {
    Color color;
    String label;
    switch (status) {
      case domain.TransactionStatus.awaitingDirectorRouting:
        color = Colors.orange;
        label = 'بانتظار التوجيه';
        break;
      case domain.TransactionStatus.routed:
        color = Colors.blue;
        label = 'موجهة';
        break;
      case domain.TransactionStatus.needsFollowup:
        color = Colors.purple;
        label = 'متابعة';
        break;
      case domain.TransactionStatus.delayed:
        color = Colors.red;
        label = 'متأخرة';
        break;
      case domain.TransactionStatus.closed:
        color = Colors.green;
        label = 'مغلقة';
        break;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 10.sp,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
