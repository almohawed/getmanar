import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../domain/announcement.dart';

class AnnouncementsReportDialog extends StatelessWidget {
  final List<Announcement> announcements;

  const AnnouncementsReportDialog({super.key, required this.announcements});

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: isMobile ? 350.w : 700.w,
        height: isMobile ? 600.h : 600.h,
        padding: EdgeInsets.all(isMobile ? 16.w : 24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    'تقرير الإعلانات المدرسية',
                    style: TextStyle(
                      fontSize: isMobile ? 18.sp : 20.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    if (isMobile) ...[
                      SizedBox(height: 300.h, child: _buildPieChartSection()),
                      SizedBox(height: 24.h),
                      SizedBox(height: 300.h, child: _buildBarChartSection()),
                    ] else
                      SizedBox(
                        height: 400.h,
                        child: Row(
                          children: [
                            Expanded(flex: 1, child: _buildPieChartSection()),
                            SizedBox(width: 24.w),
                            Expanded(flex: 1, child: _buildBarChartSection()),
                          ],
                        ),
                      ),
                    SizedBox(height: 24.h),
                    _buildSummarySection(isMobile),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChartSection() {
    final typeCounts = _getTypeCounts();
    return Column(
      children: [
        Text(
          'توزيع الإعلانات حسب النوع',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: typeCounts.entries.map((e) {
                return PieChartSectionData(
                  color: _getTypeColor(e.key),
                  value: e.value.toDouble(),
                  title: '${e.value}',
                  radius: 50,
                  titleStyle: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        SizedBox(height: 16.h),
        Wrap(
          spacing: 8.w,
          runSpacing: 8.h,
          children: typeCounts.keys.map((key) {
            return _buildLegendItem(
              Announcement.getTypeLabel(key),
              _getTypeColor(key),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBarChartSection() {
    // Demo data for monthly announcements
    return Column(
      children: [
        Text(
          'الإعلانات خلال الأشهر الأخيرة',
          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
        ),
        SizedBox(height: 16.h),
        Expanded(
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: 15,
              barTouchData: BarTouchData(enabled: false),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (value, meta) {
                      const titles = ['يناير', 'فبراير', 'مارس'];
                      if (value.toInt() < titles.length) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            titles[value.toInt()],
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
              barGroups: [
                BarChartGroupData(
                  x: 0,
                  barRods: [BarChartRodData(toY: 6, color: Colors.orange)],
                ),
                BarChartGroupData(
                  x: 1,
                  barRods: [BarChartRodData(toY: 9, color: Colors.orange)],
                ),
                BarChartGroupData(
                  x: 2,
                  barRods: [BarChartRodData(toY: 12, color: Colors.orange)],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSummarySection(bool isMobile) {
    final total = announcements.length;
    final active = announcements
        .where((a) => a.status == AnnouncementStatus.active)
        .length;
    final totalViews = announcements.fold(0, (sum, a) => sum + a.viewCount);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: isMobile
          ? Column(
              children: [
                _buildSummaryItem('إجمالي الإعلانات', '$total'),
                SizedBox(height: 12.h),
                _buildSummaryItem('الإعلانات النشطة', '$active'),
                SizedBox(height: 12.h),
                _buildSummaryItem('إجمالي المشاهدات', '$totalViews'),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem('إجمالي الإعلانات', '$total'),
                _buildSummaryItem('الإعلانات النشطة', '$active'),
                _buildSummaryItem('إجمالي المشاهدات', '$totalViews'),
              ],
            ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.orange.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 12.w, height: 12.w, color: color),
        SizedBox(width: 4.w),
        Text(label, style: TextStyle(fontSize: 11.sp)),
      ],
    );
  }

  Map<AnnouncementType, int> _getTypeCounts() {
    final counts = <AnnouncementType, int>{};
    for (var a in announcements) {
      counts[a.type] = (counts[a.type] ?? 0) + 1;
    }
    return counts;
  }

  Color _getTypeColor(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.activity:
        return Colors.purple;
      case AnnouncementType.event:
        return Colors.orange;
      case AnnouncementType.alert:
        return Colors.red;
      case AnnouncementType.occasion:
        return Colors.pink;
      case AnnouncementType.general:
        return Colors.blue;
    }
  }
}
