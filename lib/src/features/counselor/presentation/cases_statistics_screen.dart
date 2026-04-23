import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../auth/presentation/auth_controller.dart';

// ─── Provider ────────────────────────────────────────────────────────────────

final casesStatisticsProvider =
    FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return {};

  final snap = await FirebaseFirestore.instance
      .collection('behavioral_cases')
      .get();

  final docs = snap.docs;
  final now = DateTime.now();
  final startThisMonth = DateTime(now.year, now.month, 1);
  final startLastMonth = DateTime(now.year, now.month - 1, 1);

  int high = 0, medium = 0, low = 0;
  int thisMonth = 0, lastMonth = 0;
  final typeCounts = <String, int>{};
  final studentRisk = <String, int>{};
  double totalResolutionDays = 0;
  int resolvedCount = 0;

  for (final doc in docs) {
    final data = doc.data();
    final priority = (data['priority'] ?? '').toString().toLowerCase();
    if (priority.contains('عالي') || priority.contains('high')) {
      high++;
    } else if (priority.contains('متوسط') || priority.contains('medium')) {
      medium++;
    } else {
      low++;
    }

    final type = (data['caseType'] ?? data['type'] ?? 'أخرى').toString();
    typeCounts[type] = (typeCounts[type] ?? 0) + 1;

    final created = (data['createdAt'] as Timestamp?)?.toDate();
    if (created != null) {
      if (created.isAfter(startThisMonth)) thisMonth++;
      if (created.isAfter(startLastMonth) && created.isBefore(startThisMonth)) lastMonth++;
    }

    final status = (data['status'] ?? '').toString().toLowerCase();
    if (status == 'closed' || status == 'resolved' || status == 'مغلقة') {
      final closed = (data['closedAt'] as Timestamp?)?.toDate();
      if (created != null && closed != null) {
        totalResolutionDays += closed.difference(created).inDays;
        resolvedCount++;
      }
    }

    final sid = (data['studentId'] ?? '').toString();
    if (sid.isNotEmpty) {
      studentRisk[sid] = (studentRisk[sid] ?? 0) + 1;
    }
  }

  int highRisk = 0, medRisk = 0, lowRisk = 0;
  for (final count in studentRisk.values) {
    if (count >= 3) highRisk++;
    else if (count == 2) medRisk++;
    else lowRisk++;
  }

  final monthChange = lastMonth > 0
      ? ((thisMonth - lastMonth) / lastMonth * 100).round()
      : (thisMonth > 0 ? 100 : 0);

  return {
    'total': docs.length,
    'high': high,
    'medium': medium,
    'low': low,
    'typeCounts': typeCounts,
    'thisMonth': thisMonth,
    'lastMonth': lastMonth,
    'monthChange': monthChange,
    'avgResolutionDays': resolvedCount > 0 ? (totalResolutionDays / resolvedCount) : 0.0,
    'highRisk': highRisk,
    'medRisk': medRisk,
    'lowRisk': lowRisk,
  };
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class CasesStatisticsScreen extends ConsumerWidget {
  const CasesStatisticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(casesStatisticsProvider);

    return Scaffold(
        backgroundColor: const Color(0xFFF0F7F7),
        body: dataAsync.when(
          data: (data) => _StatBody(data: data),
          loading: () => const _TealLoader(),
          error: (e, _) => Center(child: Text('خطأ: $e')),
        ),
      );
  }
}

class _StatBody extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatBody({required this.data});

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        _buildHeader(context),
        SliverPadding(
          padding: EdgeInsets.all(16.w),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              _PriorityCard(data: data),
              SizedBox(height: 20.h),
              _MonthComparisonCard(data: data),
              SizedBox(height: 20.h),
              _TypePieCard(typeCounts: data['typeCounts'] as Map<String, int>),
              SizedBox(height: 20.h),
              _ResolutionTimeCard(avgDays: data['avgResolutionDays'] as double),
              SizedBox(height: 20.h),
              _RiskMatrixCard(data: data),
              SizedBox(height: 24.h),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 150.h,
      pinned: true,
      backgroundColor: const Color(0xFF00695C),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF004D40), Color(0xFF00897B), Color(0xFF26C6DA)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(10.w),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        child: Icon(Icons.insert_chart_rounded, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('إحصائيات الحالات',
                              style: TextStyle(color: Colors.white, fontSize: 22.sp, fontWeight: FontWeight.bold)),
                          Text('تحليل شامل لبيانات الحالات',
                              style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                        ],
                      ),
                      const Spacer(),
                      _TotalBadge(total: data['total'] as int),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TotalBadge extends StatelessWidget {
  final int total;
  const _TotalBadge({required this.total});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withOpacity(0.4)),
      ),
      child: Column(
        children: [
          Text('$total', style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
          Text('حالة', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _PriorityCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final total = data['total'] as int;
    if (total == 0) return const SizedBox.shrink();

    final priorities = [
      _PriorityItem('عالي', data['high'] as int, const Color(0xFFE53935), Icons.priority_high_rounded),
      _PriorityItem('متوسط', data['medium'] as int, const Color(0xFFF9A825), Icons.remove_rounded),
      _PriorityItem('منخفض', data['low'] as int, const Color(0xFF43A047), Icons.arrow_downward_rounded),
    ];

    return _StatCard(
      title: 'توزيع الأولويات',
      icon: Icons.flag_rounded,
      iconColor: const Color(0xFF00897B),
      child: Column(
        children: priorities.map((p) {
          final pct = total > 0 ? p.count / total : 0.0;
          return Padding(
            padding: EdgeInsets.only(bottom: 14.h),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6.w),
                      decoration: BoxDecoration(
                        color: p.color.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(p.icon, color: p.color, size: 16.sp),
                    ),
                    SizedBox(width: 10.w),
                    Text(p.label,
                        style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w600, color: Colors.grey.shade700)),
                    const Spacer(),
                    Text('${p.count}',
                        style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: p.color)),
                    SizedBox(width: 6.w),
                    Text('(${(pct * 100).round()}%)',
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade500)),
                  ],
                ),
                SizedBox(height: 8.h),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6.r),
                  child: LinearProgressIndicator(
                    value: pct,
                    backgroundColor: p.color.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(p.color),
                    minHeight: 10.h,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PriorityItem {
  final String label;
  final int count;
  final Color color;
  final IconData icon;
  const _PriorityItem(this.label, this.count, this.color, this.icon);
}

class _MonthComparisonCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MonthComparisonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final thisMonth = data['thisMonth'] as int;
    final lastMonth = data['lastMonth'] as int;
    final change = data['monthChange'] as int;
    final isUp = change >= 0;

    return _StatCard(
      title: 'مقارنة شهرية',
      icon: Icons.compare_arrows_rounded,
      iconColor: const Color(0xFF1565C0),
      child: Row(
        children: [
          Expanded(
            child: _MonthBox(
              label: 'هذا الشهر',
              value: thisMonth,
              color: const Color(0xFF1565C0),
            ),
          ),
          SizedBox(width: 12.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: (isUp ? Colors.red : Colors.green).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Column(
              children: [
                Icon(
                  isUp ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                  color: isUp ? Colors.red : Colors.green,
                  size: 24.sp,
                ),
                Text(
                  '${isUp ? '+' : ''}$change%',
                  style: TextStyle(
                    color: isUp ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.sp,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: _MonthBox(
              label: 'الشهر الماضي',
              value: lastMonth,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthBox extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MonthBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text('$value',
              style: TextStyle(fontSize: 28.sp, fontWeight: FontWeight.bold, color: color)),
          Text(label,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
        ],
      ),
    );
  }
}

class _TypePieCard extends StatelessWidget {
  final Map<String, int> typeCounts;
  const _TypePieCard({required this.typeCounts});

  @override
  Widget build(BuildContext context) {
    final total = typeCounts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const SizedBox.shrink();

    final palette = [
      const Color(0xFF00897B),
      const Color(0xFF1E88E5),
      const Color(0xFFE53935),
      const Color(0xFF8E24AA),
      const Color(0xFFF9A825),
      const Color(0xFF546E7A),
    ];

    final entries = typeCounts.entries.where((e) => e.value > 0).toList();
    final sections = entries.asMap().entries.map((e) {
      final c = palette[e.key % palette.length];
      return PieChartSectionData(
        color: c,
        value: e.value.value.toDouble(),
        title: '${(e.value.value / total * 100).round()}%',
        radius: 60.r,
        titleStyle: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: Colors.white),
      );
    }).toList();

    return _StatCard(
      title: 'توزيع أنواع الحالات',
      icon: Icons.pie_chart_rounded,
      iconColor: const Color(0xFF00897B),
      child: Row(
        children: [
          SizedBox(
            height: 150.h,
            width: 150.w,
            child: PieChart(PieChartData(sections: sections, sectionsSpace: 2, centerSpaceRadius: 35.r)),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: entries.asMap().entries.map((e) {
                final c = palette[e.key % palette.length];
                return Padding(
                  padding: EdgeInsets.only(bottom: 8.h),
                  child: Row(
                    children: [
                      Container(width: 10.w, height: 10.h, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                      SizedBox(width: 6.w),
                      Expanded(
                        child: Text('${e.value.key} (${e.value.value})',
                            style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700)),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResolutionTimeCard extends StatelessWidget {
  final double avgDays;
  const _ResolutionTimeCard({required this.avgDays});

  @override
  Widget build(BuildContext context) {
    final color = avgDays <= 7
        ? const Color(0xFF43A047)
        : avgDays <= 14
            ? const Color(0xFFF9A825)
            : const Color(0xFFE53935);

    return _StatCard(
      title: 'تحليل وقت الحل',
      icon: Icons.hourglass_bottom_rounded,
      iconColor: color,
      child: Row(
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)]),
              border: Border.all(color: color, width: 3),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(avgDays.toStringAsFixed(1),
                      style: TextStyle(fontSize: 20.sp, fontWeight: FontWeight.bold, color: color)),
                  Text('يوم', style: TextStyle(fontSize: 10.sp, color: color)),
                ],
              ),
            ),
          ),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('متوسط وقت الحل',
                    style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                SizedBox(height: 8.h),
                _TimeIndicator(label: 'ممتاز', range: '≤ 7 أيام', color: const Color(0xFF43A047), active: avgDays <= 7),
                _TimeIndicator(label: 'جيد', range: '8-14 يوم', color: const Color(0xFFF9A825), active: avgDays > 7 && avgDays <= 14),
                _TimeIndicator(label: 'يحتاج تحسين', range: '> 14 يوم', color: const Color(0xFFE53935), active: avgDays > 14),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TimeIndicator extends StatelessWidget {
  final String label, range;
  final Color color;
  final bool active;
  const _TimeIndicator({required this.label, required this.range, required this.color, required this.active});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        children: [
          Container(
            width: 8.w,
            height: 8.h,
            decoration: BoxDecoration(
              color: active ? color : Colors.grey.shade300,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6.w),
          Text('$label: $range',
              style: TextStyle(
                  fontSize: 12.sp,
                  color: active ? color : Colors.grey.shade400,
                  fontWeight: active ? FontWeight.bold : FontWeight.normal)),
        ],
      ),
    );
  }
}

class _RiskMatrixCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RiskMatrixCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final items = [
      _RiskItem('خطر عالٍ', data['highRisk'] as int, const Color(0xFFE53935), '3+ حالات'),
      _RiskItem('خطر متوسط', data['medRisk'] as int, const Color(0xFFF9A825), 'حالتان'),
      _RiskItem('خطر منخفض', data['lowRisk'] as int, const Color(0xFF43A047), 'حالة واحدة'),
    ];

    return _StatCard(
      title: 'مصفوفة مخاطر الطلاب',
      icon: Icons.grid_view_rounded,
      iconColor: const Color(0xFFE53935),
      child: Row(
        children: items.map((item) {
          return Expanded(
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 4.w),
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14.r),
                border: Border.all(color: item.color.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text('${item.count}',
                      style: TextStyle(fontSize: 26.sp, fontWeight: FontWeight.bold, color: item.color)),
                  SizedBox(height: 4.h),
                  Text(item.label,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: item.color)),
                  SizedBox(height: 2.h),
                  Text(item.subtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RiskItem {
  final String label, subtitle;
  final int count;
  final Color color;
  const _RiskItem(this.label, this.count, this.color, this.subtitle);
}

class _StatCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color iconColor;
  final Widget child;
  const _StatCard({required this.title, required this.icon, required this.iconColor, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(18.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 16, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Icon(icon, color: iconColor, size: 20.sp),
              ),
              SizedBox(width: 10.w),
              Text(title,
                  style: TextStyle(fontSize: 15.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            ],
          ),
          SizedBox(height: 16.h),
          child,
        ],
      ),
    );
  }
}

class _TealLoader extends StatelessWidget {
  const _TealLoader();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF004D40), Color(0xFF00897B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
