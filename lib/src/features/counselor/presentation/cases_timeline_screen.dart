import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../../auth/presentation/auth_controller.dart';

// ─── Filter Enum ─────────────────────────────────────────────────────────────

enum _TimelineFilter { all, active, closed, thisWeek, thisMonth }

extension _FilterLabel on _TimelineFilter {
  String get label {
    switch (this) {
      case _TimelineFilter.all: return 'الكل';
      case _TimelineFilter.active: return 'نشط';
      case _TimelineFilter.closed: return 'مغلق';
      case _TimelineFilter.thisWeek: return 'هذا الأسبوع';
      case _TimelineFilter.thisMonth: return 'هذا الشهر';
    }
  }
}

// ─── Provider ────────────────────────────────────────────────────────────────

final casesTimelineProvider = StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId ?? '';
  if (schoolId.isEmpty) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('behavioral_cases')
      .snapshots()
      .map((snap) {
        final docs = snap.docs.map((d) => {'id': d.id, ...d.data()}).toList();
        docs.sort((a, b) {
          final at = (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          final bt = (b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
          return bt.compareTo(at);
        });
        return docs;
      });
});

// ─── Screen ──────────────────────────────────────────────────────────────────

class CasesTimelineScreen extends ConsumerStatefulWidget {
  const CasesTimelineScreen({super.key});

  @override
  ConsumerState<CasesTimelineScreen> createState() => _CasesTimelineScreenState();
}

class _CasesTimelineScreenState extends ConsumerState<CasesTimelineScreen> {
  _TimelineFilter _filter = _TimelineFilter.all;

  @override
  Widget build(BuildContext context) {
    final streamAsync = ref.watch(casesTimelineProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFFFF8F0),
      body: streamAsync.when(
        data: (cases) {
          final filtered = _applyFilter(cases, _filter);
          return _TimelineBody(
            cases: cases,
            filtered: filtered,
            filter: _filter,
            onFilterChanged: (f) => setState(() => _filter = f),
          );
        },
        loading: () => const _OrangeLoader(),
        error: (e, _) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> cases, _TimelineFilter filter) {
    final now = DateTime.now();
    switch (filter) {
      case _TimelineFilter.all:
        return cases;
      case _TimelineFilter.active:
        return cases.where((c) {
          final s = (c['status'] ?? '').toString().toLowerCase();
          return s != 'closed' && s != 'resolved' && s != 'مغلقة';
        }).toList();
      case _TimelineFilter.closed:
        return cases.where((c) {
          final s = (c['status'] ?? '').toString().toLowerCase();
          return s == 'closed' || s == 'resolved' || s == 'مغلقة';
        }).toList();
      case _TimelineFilter.thisWeek:
        final weekStart = now.subtract(Duration(days: now.weekday % 7));
        return cases.where((c) {
          final ts = (c['createdAt'] as Timestamp?)?.toDate();
          return ts != null && ts.isAfter(weekStart);
        }).toList();
      case _TimelineFilter.thisMonth:
        final monthStart = DateTime(now.year, now.month, 1);
        return cases.where((c) {
          final ts = (c['createdAt'] as Timestamp?)?.toDate();
          return ts != null && ts.isAfter(monthStart);
        }).toList();
    }
  }
}

class _TimelineBody extends StatelessWidget {
  final List<Map<String, dynamic>> cases;
  final List<Map<String, dynamic>> filtered;
  final _TimelineFilter filter;
  final ValueChanged<_TimelineFilter> onFilterChanged;
  const _TimelineBody({required this.cases, required this.filtered, required this.filter, required this.onFilterChanged});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final weekStart = now.subtract(Duration(days: now.weekday % 7));

    final openedThisWeek = cases.where((c) {
      final ts = (c['createdAt'] as Timestamp?)?.toDate();
      return ts != null && ts.isAfter(weekStart);
    }).length;

    final closedThisWeek = cases.where((c) {
      final s = (c['status'] ?? '').toString().toLowerCase();
      final ts = (c['closedAt'] as Timestamp?)?.toDate();
      return (s == 'closed' || s == 'resolved' || s == 'مغلقة') &&
          ts != null && ts.isAfter(weekStart);
    }).length;

    final pending = cases.where((c) {
      final s = (c['status'] ?? '').toString().toLowerCase();
      return s != 'closed' && s != 'resolved' && s != 'مغلقة';
    }).length;

    return CustomScrollView(
      slivers: [
        _buildHeader(context),
        SliverToBoxAdapter(
          child: Column(
            children: [
              _StatsBar(openedThisWeek: openedThisWeek, closedThisWeek: closedThisWeek, pending: pending),
              _FilterChips(current: filter, onChanged: onFilterChanged),
            ],
          ),
        ),
        if (filtered.isEmpty)
          SliverFillRemaining(child: _EmptyTimeline())
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16.w, 8.h, 16.w, 24.h),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) => _TimelineItem(
                  caseData: filtered[index],
                  isLast: index == filtered.length - 1,
                ),
                childCount: filtered.length,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 150.h,
      pinned: true,
      backgroundColor: const Color(0xFFE65100),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
        onPressed: () => Navigator.of(context).pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFBF360C), Color(0xFFE65100), Color(0xFFFFB300)],
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
                        child: Icon(Icons.timeline_rounded, color: Colors.white, size: 28.sp),
                      ),
                      SizedBox(width: 12.w),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('الجدول الزمني للحالات',
                              style: TextStyle(color: Colors.white, fontSize: 20.sp, fontWeight: FontWeight.bold)),
                          Text('عرض تسلسلي لجميع الحالات',
                              style: TextStyle(color: Colors.white70, fontSize: 13.sp)),
                        ],
                      ),
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

class _StatsBar extends StatelessWidget {
  final int openedThisWeek, closedThisWeek, pending;
  const _StatsBar({required this.openedThisWeek, required this.closedThisWeek, required this.pending});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE65100), Color(0xFFFF8F00)],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        borderRadius: BorderRadius.circular(18.r),
        boxShadow: [
          BoxShadow(color: const Color(0xFFE65100).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          _StatItem(label: 'مفتوحة هذا الأسبوع', value: openedThisWeek, icon: Icons.add_circle_outline_rounded, color: Colors.white),
          _Divider(),
          _StatItem(label: 'مغلقة هذا الأسبوع', value: closedThisWeek, icon: Icons.check_circle_outline_rounded, color: Colors.white),
          _Divider(),
          _StatItem(label: 'قيد الانتظار', value: pending, icon: Icons.pending_outlined, color: Colors.white),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color color;
  const _StatItem({required this.label, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color.withOpacity(0.8), size: 20.sp),
          SizedBox(height: 4.h),
          Text('$value', style: TextStyle(color: color, fontSize: 22.sp, fontWeight: FontWeight.bold)),
          Text(label, textAlign: TextAlign.center, style: TextStyle(color: color.withOpacity(0.8), fontSize: 10.sp)),
        ],
      ),
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40.h, color: Colors.white.withOpacity(0.3));
  }
}

class _FilterChips extends StatelessWidget {
  final _TimelineFilter current;
  final ValueChanged<_TimelineFilter> onChanged;
  const _FilterChips({required this.current, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44.h,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        children: _TimelineFilter.values.map((f) {
          final isSelected = f == current;
          return GestureDetector(
            onTap: () => onChanged(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(left: 8.w),
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE65100) : Colors.white,
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(
                  color: isSelected ? const Color(0xFFE65100) : Colors.grey.shade300,
                ),
                boxShadow: isSelected
                    ? [BoxShadow(color: const Color(0xFFE65100).withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Text(
                f.label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 13.sp,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map<String, dynamic> caseData;
  final bool isLast;
  const _TimelineItem({required this.caseData, required this.isLast});

  Color get _statusColor {
    final s = (caseData['status'] ?? '').toString().toLowerCase();
    if (s == 'closed' || s == 'resolved' || s == 'مغلقة') return const Color(0xFF43A047);
    if (s == 'active' || s == 'نشطة' || s == 'open') return const Color(0xFF1E88E5);
    return const Color(0xFFF9A825);
  }

  Color get _priorityColor {
    final p = (caseData['priority'] ?? '').toString().toLowerCase();
    if (p.contains('عالي') || p.contains('high')) return const Color(0xFFE53935);
    if (p.contains('متوسط') || p.contains('medium')) return const Color(0xFFF9A825);
    return const Color(0xFF43A047);
  }

  String get _statusLabel {
    final s = (caseData['status'] ?? '').toString().toLowerCase();
    if (s == 'closed' || s == 'resolved' || s == 'مغلقة') return 'مغلقة';
    if (s == 'active' || s == 'نشطة' || s == 'open') return 'نشطة';
    return 'قيد المعالجة';
  }

  String get _priorityLabel {
    final p = (caseData['priority'] ?? '').toString().toLowerCase();
    if (p.contains('عالي') || p.contains('high')) return 'عالي';
    if (p.contains('متوسط') || p.contains('medium')) return 'متوسط';
    return 'منخفض';
  }

  @override
  Widget build(BuildContext context) {
    final createdAt = (caseData['createdAt'] as Timestamp?)?.toDate();
    final dateStr = createdAt != null
        ? DateFormat('dd MMM yyyy', 'ar').format(createdAt)
        : '—';
    final studentName = (caseData['studentName'] ?? 'طالب').toString();
    final caseType = (caseData['caseType'] ?? caseData['type'] ?? 'حالة').toString();

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline line + dot
          SizedBox(
            width: 40.w,
            child: Column(
              children: [
                Container(
                  width: 16.w,
                  height: 16.h,
                  decoration: BoxDecoration(
                    color: _statusColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [BoxShadow(color: _statusColor.withOpacity(0.4), blurRadius: 6)],
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2.w,
                      color: Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(width: 8.w),
          // Card
          Expanded(
            child: Container(
              margin: EdgeInsets.only(bottom: 12.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(dateStr,
                          style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
                      const Spacer(),
                      _Badge(label: _statusLabel, color: _statusColor),
                      SizedBox(width: 6.w),
                      _Badge(label: _priorityLabel, color: _priorityColor),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Icon(Icons.person_rounded, size: 16.sp, color: Colors.grey.shade500),
                      SizedBox(width: 6.w),
                      Text(studentName,
                          style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
                    ],
                  ),
                  SizedBox(height: 4.h),
                  Row(
                    children: [
                      Icon(Icons.label_rounded, size: 14.sp, color: Colors.grey.shade400),
                      SizedBox(width: 6.w),
                      Text(caseType,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(label, style: TextStyle(fontSize: 10.sp, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class _EmptyTimeline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.timeline_rounded, size: 70.sp, color: Colors.grey.shade300),
          SizedBox(height: 12.h),
          Text('لا توجد حالات', style: TextStyle(fontSize: 16.sp, color: Colors.grey.shade500)),
        ],
      ),
    );
  }
}

class _OrangeLoader extends StatelessWidget {
  const _OrangeLoader();
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFBF360C), Color(0xFFE65100)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}
