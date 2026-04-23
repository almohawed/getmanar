import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';
import '../domain/models/teacher_behavior_profile.dart';
import 'teacher_intelligence_controller.dart';

class TeacherIntelligenceDashboard extends ConsumerStatefulWidget {
  const TeacherIntelligenceDashboard({super.key});

  @override
  ConsumerState<TeacherIntelligenceDashboard> createState() =>
      _TeacherIntelligenceDashboardState();
}

class _TeacherIntelligenceDashboardState
    extends ConsumerState<TeacherIntelligenceDashboard> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolAsync = ref.watch(
      schoolProvider(user?.schoolId ?? ''),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.indigo.shade900, Colors.indigo.shade700, Colors.blue.shade700],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
            ),
          ),
          title: schoolAsync.when(
            data: (school) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  school != null ? 'منصة منار | ${school.name}' : 'ذكاء المعلم',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16.sp),
                ),
                Text('تحليل أداء المعلمين', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
              ],
            ),
            loading: () => const Text('منصة منار', style: TextStyle(color: Colors.white)),
            error: (_, __) => const Text('منصة منار', style: TextStyle(color: Colors.white)),
          ),
          centerTitle: false,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        body: Column(
          children: [
            Padding(
              padding: EdgeInsets.all(12.w),
              child: Row(
                children: [
                  _buildSectionCard(
                    context,
                    index: 0,
                    label: 'نظرة عامة',
                    icon: Icons.dashboard,
                  ),
                  SizedBox(width: 8.w),
                  _buildSectionCard(
                    context,
                    index: 1,
                    label: 'المعلمون',
                    icon: Icons.people,
                  ),
                  SizedBox(width: 8.w),
                  _buildSectionCard(
                    context,
                    index: 2,
                    label: 'الأنماط',
                    icon: Icons.psychology,
                  ),
                  SizedBox(width: 8.w),
                  _buildSectionCard(
                    context,
                    index: 3,
                    label: 'توصيات الجدول',
                    icon: Icons.lightbulb,
                  ),
                ],
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: _selectedIndex,
                children: const [
                  _OverviewTab(),
                  _TeachersListTab(),
                  _PatternsTab(),
                  _ScheduleHintsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
  }) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
        },
        child: Card(
          color: isSelected ? Colors.indigo.shade50 : Colors.white,
          elevation: isSelected ? 3 : 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(
              color: isSelected ? Colors.indigo : Colors.grey.shade200,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 10.h),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 20.sp,
                  color: isSelected ? Colors.indigo : Colors.grey.shade700,
                ),
                SizedBox(height: 4.h),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    color:
                        isSelected ? Colors.indigo.shade900 : Colors.grey.shade800,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(teacherIntelligenceStatsProvider);
    final profilesAsync = ref.watch(teacherProfilesProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        children: [
          // KPIs
          Row(
            children: [
              Expanded(
                child: _buildKPICard(
                  'المعلمين',
                  '${stats.totalTeachers}',
                  Colors.blue,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildKPICard(
                  'الالتزام',
                  '${stats.averageScore.toStringAsFixed(1)}%',
                  _getScoreColor(stats.averageScore),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: _buildKPICard(
                  'حالات حرجة',
                  '${stats.criticalCount}',
                  Colors.red,
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),

          // Donut Chart & Distribution
          _buildDistributionSection(stats),

          SizedBox(height: 24.h),

          // Top Issues List (Patterns placeholder)
          _buildTopPatternsPreview(profilesAsync),
        ],
      ),
    );
  }

  Color _getScoreColor(double score) {
    if (score >= 90) return Colors.green;
    if (score >= 80) return Colors.lightGreen;
    if (score >= 60) return Colors.orange;
    return Colors.red;
  }

  Widget _buildKPICard(String title, String value, Color color) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, val, child) {
        return Transform.scale(
          scale: val,
          child: Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border(
                right: BorderSide(color: color, width: 4.w),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 14.sp, color: Colors.grey),
                ),
                SizedBox(height: 8.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDistributionSection(TeacherStats stats) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'توزيع مستويات الالتزام',
            style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 24.h),
          SizedBox(
            height: 200.h,
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: [
                        _buildPieSection(
                          stats.excellentCount,
                          Colors.green,
                          'متميز',
                        ),
                        _buildPieSection(
                          stats.goodCount,
                          Colors.lightGreen,
                          'جيد',
                        ),
                        _buildPieSection(
                          stats.supportCount,
                          Colors.orange,
                          'يحتاج دعم',
                        ),
                        _buildPieSection(
                          stats.followUpCount,
                          Colors.deepOrange,
                          'متابعة',
                        ),
                        _buildPieSection(
                          stats.criticalCount,
                          Colors.red,
                          'حرج',
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(
                        'متميز',
                        Colors.green,
                        stats.excellentCount,
                      ),
                      _buildLegendItem(
                        'جيد',
                        Colors.lightGreen,
                        stats.goodCount,
                      ),
                      _buildLegendItem(
                        'يحتاج دعم',
                        Colors.orange,
                        stats.supportCount,
                      ),
                      _buildLegendItem(
                        'متابعة',
                        Colors.deepOrange,
                        stats.followUpCount,
                      ),
                      _buildLegendItem('حرج', Colors.red, stats.criticalCount),
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

  PieChartSectionData _buildPieSection(int value, Color color, String title) {
    return PieChartSectionData(
      color: color,
      value: value.toDouble(),
      title: value > 0 ? '$value' : '',
      radius: 50,
      titleStyle: TextStyle(
        fontSize: 14.sp,
        fontWeight: FontWeight.bold,
        color: Colors.white,
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color, int count) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(width: 12.w, height: 12.w, color: color),
          SizedBox(width: 8.w),
          Text('$title ($count)', style: TextStyle(fontSize: 12.sp)),
        ],
      ),
    );
  }

  Widget _buildTopPatternsPreview(
    AsyncValue<List<TeacherBehaviorProfile>> profilesAsync,
  ) {
    return profilesAsync.when(
      data: (profiles) {
        // Simple aggregation of patterns
        final patternCounts = <String, int>{};
        for (var p in profiles) {
          for (var pat in p.patterns) {
            patternCounts[pat] = (patternCounts[pat] ?? 0) + 1;
          }
        }
        final sortedPatterns = patternCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'أبرز الأنماط المكتشفة',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            ...sortedPatterns
                .take(3)
                .map(
                  (e) => Card(
                    child: ListTile(
                      leading: Icon(Icons.analytics, color: Colors.purple),
                      title: Text(e.key),
                      trailing: CircleAvatar(
                        radius: 14,
                        backgroundColor: Colors.purple.shade100,
                        child: Text(
                          '${e.value}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.purple,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

class _TeachersListTab extends ConsumerStatefulWidget {
  const _TeachersListTab();

  @override
  ConsumerState<_TeachersListTab> createState() => _TeachersListTabState();
}

class _TeachersListTabState extends ConsumerState<_TeachersListTab> {
  String _searchQuery = '';
  String _filterBadge = 'All';

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(teacherProfilesProvider);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.all(16.w),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'بحث باسم المعلم...',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
              ),
              SizedBox(width: 16.w),
              DropdownButton<String>(
                value: _filterBadge,
                items:
                    [
                          'All',
                          'التزام متميز',
                          'التزام جيد',
                          'يحتاج دعم تنظيمي',
                          'يحتاج متابعة إدارية',
                          'حالة حرجة وظيفيًا',
                        ]
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e == 'All' ? 'الكل' : e),
                          ),
                        )
                        .toList(),
                onChanged: (val) => setState(() => _filterBadge = val!),
              ),
            ],
          ),
        ),
        Expanded(
          child: profilesAsync.when(
            data: (profiles) {
              final filtered = profiles.where((p) {
                final matchesSearch = p.teacherId.contains(
                  _searchQuery,
                ); // Assume ID has name for now or fetch user.
                // Note: Profile has ID. We normally join with User collection.
                // For this demo, assuming we can search or pass User map.
                // Let's assume teacherId is sufficient or we need to fetch names.
                // In a real app, we'd use a provider that combines User + Profile.

                final matchesBadge =
                    _filterBadge == 'All' || p.badge == _filterBadge;
                return matchesSearch && matchesBadge; // Simplified search
              }).toList();

              return ListView.builder(
                itemCount: filtered.length,
                itemBuilder: (context, index) {
                  final profile = filtered[index];
                  return Card(
                    margin: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 8.h,
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _getColor(profile.badgeColor),
                        child: Text(
                          '${profile.score}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      title: Text(
                        'المعلم: ${profile.teacherId}',
                      ), // Ideally Name
                      subtitle: Text(profile.badge),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showTeacherDetails(context, profile),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('Error: $e')),
          ),
        ),
      ],
    );
  }

  Color _getColor(String colorName) {
    switch (colorName) {
      case 'Green':
        return Colors.green;
      case 'Yellow':
        return Colors.amber;
      case 'Orange':
        return Colors.orange;
      case 'Red':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showTeacherDetails(
    BuildContext context,
    TeacherBehaviorProfile profile,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => _TeacherDetailSheet(profile: profile),
    );
  }
}

class _TeacherDetailSheet extends StatelessWidget {
  final TeacherBehaviorProfile profile;

  const _TeacherDetailSheet({required this.profile});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
        ),
        child: ListView(
          controller: controller,
          padding: EdgeInsets.all(24.w),
          children: [
            Center(
              child: Container(
                width: 60.w,
                height: 6.h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            SizedBox(height: 24.h),
            Text(
              'تحليل أداء المعلم',
              style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8.h),
            Text(
              'ID: ${profile.teacherId}',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 24.h),

            _buildScoreBadge(),
            SizedBox(height: 24.h),

            _buildSectionHeader('أبرز الأنماط المكتشفة'),
            ...profile.patterns.map(
              (p) => ListTile(
                leading: Icon(Icons.warning_amber, color: Colors.orange),
                title: Text(p),
              ),
            ),
            if (profile.patterns.isEmpty)
              const Text('لا توجد أنماط سلبية واضحة.'),

            Divider(height: 32.h),

            _buildSectionHeader('التوصيات المقترحة'),
            ...profile.recommendations.map(
              (r) => ListTile(
                leading: Icon(Icons.lightbulb_outline, color: Colors.blue),
                title: Text(r),
              ),
            ),

            Divider(height: 32.h),

            _buildSectionHeader('قيود الجدول الذكي (Elite Hints)'),
            SwitchListTile(
              value: profile.scheduleHints.avoidPeriods.contains(1),
              onChanged: (val) {}, // Todo: Implement update
              title: const Text('تجنب الحصة الأولى'),
              subtitle: const Text('بناءً على تكرار التأخر الصباحي'),
            ),
            SwitchListTile(
              value: profile.scheduleHints.avoidPeriods.contains(7),
              onChanged: (val) {}, // Todo: Implement update
              title: const Text('تجنب الحصة السابعة'),
              subtitle: const Text('بناءً على ملاحظات عدم الانتظام'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBadge() {
    Color c;
    switch (profile.badgeColor) {
      case 'Green':
        c = Colors.green;
        break;
      case 'Yellow':
        c = Colors.amber;
        break;
      case 'Orange':
        c = Colors.orange;
        break;
      case 'Red':
        c = Colors.red;
        break;
      default:
        c = Colors.grey;
    }
    return Container(
      padding: EdgeInsets.symmetric(vertical: 16.h, horizontal: 32.w),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: c),
      ),
      child: Column(
        children: [
          Text(
            '${profile.score}',
            style: TextStyle(
              fontSize: 48.sp,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
          Text(
            profile.badge,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: c,
            ),
          ),
          Text(
            'الاتجاه: ${profile.trend}',
            style: TextStyle(fontSize: 14.sp, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Text(
        title,
        style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _PatternsTab extends StatelessWidget {
  const _PatternsTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('تحليل الأنماط الجماعية (قريباً)'));
  }
}

class _ScheduleHintsTab extends StatelessWidget {
  const _ScheduleHintsTab();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('إدارة قيود الجدول المركزية (قريباً)'));
  }
}
