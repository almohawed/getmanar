import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/services/school_config_service.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';
import '../../academic/presentation/students_provider.dart';
import '../data/mock_teacher_repository.dart';
import '../data/mock_class_repository.dart';

class _QuickDecision {
  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String route;
  final bool isAlert;
  const _QuickDecision({
    required this.title, required this.value, required this.subtitle,
    required this.icon, required this.color, required this.route,
    this.isAlert = false,
  });
}

final _smartDashboardStatsProvider =
    FutureProvider.autoDispose.family<Map<String, dynamic>, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return {};
  final db = FirebaseFirestore.instance;
  final school = db.collection('Schools').doc(schoolId);
  final now = DateTime.now();
  final todayTs = Timestamp.fromDate(DateTime(now.year, now.month, now.day));
  final weekAgo = Timestamp.fromDate(now.subtract(const Duration(days: 7)));
  try {
    final results = await Future.wait([
      school.collection('StudentAttendance')
          .where('date', isGreaterThanOrEqualTo: todayTs)
          .where('status', isEqualTo: 'absent').count().get(),
      db.collection('behavioral_violations')
          .where('schoolId', isEqualTo: schoolId)
          .where('timestamp', isGreaterThanOrEqualTo: todayTs).count().get(),
      db.collection('behavioral_violations')
          .where('schoolId', isEqualTo: schoolId)
          .where('timestamp', isGreaterThanOrEqualTo: weekAgo).count().get(),
      school.collection('Permissions')
          .where('status', isEqualTo: 'pending').count().get(),
      school.collection('HealthCases')
          .where('status', isEqualTo: 'active').count().get(),
      school.collection('MaintenanceTickets')
          .where('status', whereIn: ['open', 'pending']).count().get(),
    ]);
    return {
      'absencesToday':      results[0].count ?? 0,
      'violationsToday':    results[1].count ?? 0,
      'violationsWeek':     results[2].count ?? 0,
      'pendingPermissions': results[3].count ?? 0,
      'activeHealthCases':  results[4].count ?? 0,
      'openMaintenance':    results[5].count ?? 0,
    };
  } catch (_) { return {}; }
});

class SmartAdminDashboard extends ConsumerWidget {
  const SmartAdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user        = ref.watch(authStateProvider).value;
    final schoolId    = (user?.schoolId ?? '').trim();
    final schoolName  = ref.watch(schoolProvider(schoolId).select((v) => v.value?.name ?? ''));
    final countryCode = ref.watch(schoolProvider(schoolId).select((v) => v.value?.countryCode ?? 'SA'));
    final students    = ref.watch(studentsProvider.select((v) => v.value?.length ?? 0));
    final teachers    = ref.watch(teachersProvider.select((v) => v.value?.length ?? 0));
    final classes     = ref.watch(classesProvider.select((v) => v.value?.length ?? 0));
    final stats       = ref.watch(_smartDashboardStatsProvider(schoolId)).value ?? {};
    final configAsync = ref.watch(schoolConfigProvider(schoolId));

    // حساب عرض المحتوى
    final screenW = MediaQuery.of(context).size.width;
    final isWide  = screenW > 700;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_smartDashboardStatsProvider(schoolId));
          ref.invalidate(schoolConfigProvider(schoolId));
        },
        color: const Color(0xFF42A5F5),
        backgroundColor: const Color(0xFF1B2A4A),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 110,
              pinned: true,
              backgroundColor: const Color(0xFF0D1B2A),
              flexibleSpace: FlexibleSpaceBar(
                background: _buildHeader(schoolName, countryCode, user?.name ?? ''),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.notifications_outlined, color: Colors.white70),
                  onPressed: () => context.push('/notifications'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined, color: Colors.white70),
                  onPressed: () => context.push('/settings'),
                ),
              ],
            ),
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _sectionTitle('⚡ قرارات سريعة', 'الحالة الآن'),
                  const SizedBox(height: 8),
                  _buildQuickDecisions(context, stats, isWide),
                  const SizedBox(height: 16),
                  _sectionTitle('📊 نبض المدرسة', 'اليوم'),
                  const SizedBox(height: 8),
                  _buildPulseRow(students, teachers, classes, stats),
                  const SizedBox(height: 16),
                  configAsync.when(
                    data: (config) => _buildBehaviorCard(context, config, stats),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                  const SizedBox(height: 16),
                  _sectionTitle('🎯 الأكثر استخداماً', ''),
                  const SizedBox(height: 8),
                  _buildQuickActionsGrid(context, isWide),
                  const SizedBox(height: 16),
                  _buildFullDashboardButton(context),
                  const SizedBox(height: 60),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(String schoolName, String countryCode, String userName) {
    final flags = {'SA':'🇸🇦','AE':'🇦🇪','QA':'🇶🇦','KW':'🇰🇼','BH':'🇧🇭','OM':'🇴🇲','US':'🇺🇸','GB':'🇬🇧','FR':'🇫🇷','ES':'🇪🇸'};
    final flag = flags[countryCode] ?? '🌍';
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'صباح الخير' : hour < 17 ? 'مساء الخير' : 'مساء النور';
    final days = ['الأحد','الاثنين','الثلاثاء','الأربعاء','الخميس','الجمعة','السبت'];
    final dayName = days[DateTime.now().weekday % 7];

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0D1B4B), Color(0xFF1A237E), Color(0xFF283593)],
          begin: Alignment.topRight, end: Alignment.bottomLeft,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 48, 20, 14),
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('$greeting، $userName',
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                Text(schoolName.isNotEmpty ? schoolName : 'لوحة المدير',
                    style: const TextStyle(color: Colors.white, fontSize: 17,
                        fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(dayName,
                style: const TextStyle(color: Colors.white, fontSize: 12,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickDecisions(BuildContext context, Map<String, dynamic> stats, bool isWide) {
    final absences    = stats['absencesToday']      as int? ?? 0;
    final violations  = stats['violationsToday']    as int? ?? 0;
    final permissions = stats['pendingPermissions'] as int? ?? 0;
    final health      = stats['activeHealthCases']  as int? ?? 0;

    final decisions = [
      _QuickDecision(title: 'غياب اليوم',    value: '$absences',
          subtitle: absences > 10 ? 'يحتاج متابعة' : 'طبيعي',
          icon: Icons.person_off, color: absences > 10 ? Colors.red : Colors.green,
          route: '/school-attendance-dashboard', isAlert: absences > 10),
      _QuickDecision(title: 'مخالفات اليوم', value: '$violations',
          subtitle: violations > 5 ? 'ارتفاع ملحوظ' : 'مقبول',
          icon: Icons.gavel, color: violations > 5 ? Colors.orange : Colors.teal,
          route: '/behavior', isAlert: violations > 5),
      _QuickDecision(title: 'استئذان معلق',  value: '$permissions',
          subtitle: permissions > 0 ? 'يحتاج موافقة' : 'لا يوجد',
          icon: Icons.approval, color: permissions > 0 ? Colors.amber : Colors.green,
          route: '/permissions-dashboard', isAlert: permissions > 0),
      _QuickDecision(title: 'حالات صحية',    value: '$health',
          subtitle: health > 0 ? 'نشطة' : 'لا يوجد',
          icon: Icons.health_and_safety, color: health > 0 ? Colors.red.shade300 : Colors.green,
          route: '/health-dashboard', isAlert: health > 0),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 4 : 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isWide ? 3.2 : 1.5,
      ),
      itemCount: decisions.length,
      itemBuilder: (_, i) => _buildDecisionCard(context, decisions[i], isWide),
    );
  }

  Widget _buildDecisionCard(BuildContext context, _QuickDecision d, [bool isWide = false]) {
    return GestureDetector(
      onTap: () => context.push(d.route),
      child: Container(
        decoration: BoxDecoration(
          color: d.isAlert
              ? d.color.withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: d.isAlert ? d.color.withValues(alpha: 0.5) : Colors.white12,
            width: d.isAlert ? 1.5 : 1,
          ),
          boxShadow: d.isAlert
              ? [BoxShadow(color: d.color.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
              : [],
        ),
        padding: EdgeInsets.all(isWide ? 10 : 12),
        child: isWide
            // على الويب: أفقي مضغوط
            ? Row(children: [
                Icon(d.icon, color: d.color, size: 18),
                const SizedBox(width: 10),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(d.value, style: TextStyle(color: Colors.white,
                        fontSize: 22, fontWeight: FontWeight.bold)),
                    Text(d.title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                    Text(d.subtitle, style: TextStyle(color: d.color, fontSize: 10,
                        fontWeight: FontWeight.w600)),
                  ],
                )),
                if (d.isAlert)
                  Container(width: 7, height: 7,
                      decoration: BoxDecoration(color: d.color, shape: BoxShape.circle)),
              ])
            // على الموبايل: عمودي
            : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Icon(d.icon, color: d.color, size: 16),
                  const Spacer(),
                  if (d.isAlert)
                    Container(width: 7, height: 7,
                        decoration: BoxDecoration(color: d.color, shape: BoxShape.circle)),
                ]),
                const Spacer(),
                Text(d.value, style: const TextStyle(color: Colors.white,
                    fontSize: 26, fontWeight: FontWeight.bold)),
                Text(d.title, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                Text(d.subtitle, style: TextStyle(color: d.color, fontSize: 10,
                    fontWeight: FontWeight.w600)),
              ]),
      ),
    );
  }

  Widget _buildPulseRow(int students, int teachers, int classes, Map<String, dynamic> stats) {
    final violationsWeek = stats['violationsWeek'] as int? ?? 0;
    final items = [
      {'label': 'طالب',         'value': '$students',       'icon': Icons.people,        'color': const Color(0xFF42A5F5)},
      {'label': 'معلم',         'value': '$teachers',       'icon': Icons.person_pin,    'color': const Color(0xFF26A69A)},
      {'label': 'فصل',          'value': '$classes',        'icon': Icons.class_,        'color': Colors.orange},
      {'label': 'مخالفة/أسبوع', 'value': '$violationsWeek', 'icon': Icons.warning_amber, 'color': violationsWeek > 20 ? Colors.red : Colors.amber},
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: items.map((item) => Expanded(
          child: Column(children: [
            Icon(item['icon'] as IconData, color: item['color'] as Color, size: 18),
            const SizedBox(height: 5),
            Text(item['value'] as String,
                style: const TextStyle(color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.bold)),
            Text(item['label'] as String,
                style: const TextStyle(color: Colors.white38, fontSize: 9),
                textAlign: TextAlign.center),
          ]),
        )).toList(),
      ),
    );
  }

  Widget _buildBehaviorCard(BuildContext context, SchoolConfig config, Map<String, dynamic> stats) {
    final behaviorLabels = {
      'levels':   ('نظام الدرجات', Icons.layers,    const Color(0xFF1565C0)),
      'points':   ('نظام النقاط',  Icons.stars,     const Color(0xFF26A69A)),
      'guidance': ('نظام الإرشاد', Icons.psychology, const Color(0xFF6A1B9A)),
      'gpa':      ('نظام GPA',     Icons.grade,     Colors.orange),
      'warnings': ('نظام الإنذارات', Icons.warning, Colors.red),
      'custom':   ('نظام مرن',     Icons.tune,      Colors.teal),
    };
    final (label, icon, color) = behaviorLabels[config.behaviorSystem]
        ?? ('السلوك', Icons.gavel, Colors.orange);
    final violations = stats['violationsToday'] as int? ?? 0;
    final calLabel = config.calendarSystem == 'twoSemesters' ? 'فصلان'
        : config.calendarSystem == 'threeTerms' ? '3 فصول' : '4 أرباع';

    return GestureDetector(
      onTap: () => context.push('/behavior'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.05)]),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 14,
                  fontWeight: FontWeight.bold)),
              Text('${config.countryCode} • $calLabel',
                  style: const TextStyle(color: Colors.white38, fontSize: 10)),
            ],
          )),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('$violations', style: TextStyle(color: color, fontSize: 22,
                fontWeight: FontWeight.bold)),
            const Text('اليوم', style: TextStyle(color: Colors.white38, fontSize: 10)),
          ]),
          const SizedBox(width: 6),
          const Icon(Icons.arrow_forward_ios, color: Colors.white24, size: 13),
        ]),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context, bool isWide) {
    final actions = [
      {'icon': Icons.fact_check,   'label': 'الحضور',   'color': Colors.teal,       'route': '/school-attendance-dashboard'},
      {'icon': Icons.people_alt,   'label': 'الطلاب',   'color': Colors.blue,       'route': '/students-list'},
      {'icon': Icons.gavel,        'label': 'السلوك',   'color': Colors.orange,     'route': '/behavior'},
      {'icon': Icons.auto_awesome, 'label': 'الجدول',   'color': Colors.indigo,     'route': '/smart-schedule'},
      {'icon': Icons.psychology,   'label': 'الإرشاد',  'color': Colors.purple,     'route': '/counselor-dashboard'},
      {'icon': Icons.campaign,     'label': 'التعاميم', 'color': Colors.amber,      'route': '/circulars'},
      {'icon': Icons.inbox,        'label': 'الوارد',   'color': Colors.green,      'route': '/incoming-mail'},
      {'icon': Icons.bar_chart,    'label': 'التقارير', 'color': Colors.deepPurple, 'route': '/smart-placeholder'},
    ];
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isWide ? 8 : 4,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
        childAspectRatio: isWide ? 1.8 : 0.85,
      ),
      itemCount: actions.length,
      itemBuilder: (_, i) {
        final a = actions[i];
        final color = a['color'] as Color;
        return GestureDetector(
          onTap: () => context.push(a['route'] as String),
          child: Container(
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(a['icon'] as IconData, color: color, size: isWide ? 22 : 22),
              SizedBox(height: isWide ? 4 : 5),
              Text(a['label'] as String,
                  style: TextStyle(color: Colors.white70, fontSize: isWide ? 11 : 10),
                  textAlign: TextAlign.center),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildFullDashboardButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1565C0), Color(0xFF1A237E)],
          begin: Alignment.centerRight,
          end: Alignment.centerLeft,
        ),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: () => context.push('/admin-full-dashboard'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        icon: const Icon(Icons.grid_view, size: 20),
        label: const Text(
          'عرض لوحة التحكم الكاملة',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, String subtitle) {
    return Row(children: [
      Text(title, style: const TextStyle(color: Colors.white, fontSize: 14,
          fontWeight: FontWeight.bold)),
      if (subtitle.isNotEmpty) ...[
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(subtitle,
              style: const TextStyle(color: Colors.white38, fontSize: 10)),
        ),
      ],
    ]);
  }
}
