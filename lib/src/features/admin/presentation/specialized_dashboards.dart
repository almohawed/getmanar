import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';
import '../../inbox/presentation/inbox_dashboard_screen.dart';
import '../../permissions/presentation/permissions_dashboard_screen.dart';
import '../../assignments/application/staff_assignment_service.dart';
import '../../assignments/domain/staff_assignment.dart';
import '../data/mock_staff_repository.dart';
import '../../safety/data/firestore_safety_repository.dart';

// --- Shared Components for Specialized Dashboards ---

class SpecializedDashboardScaffold extends StatelessWidget {
  final String title;
  final Color themeColor;
  final Widget body;
  final List<Widget>? actions;

  const SpecializedDashboardScaffold({
    super.key,
    required this.title,
    required this.themeColor,
    required this.body,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 120.h,
            floating: false,
            pinned: true,
            backgroundColor: themeColor,
            elevation: 0,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                title,
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                  color: Colors.white,
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [themeColor, themeColor.withBlue(200)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -20,
                      top: -20,
                      child: Icon(
                        Icons.auto_awesome_mosaic,
                        size: 150.sp,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: actions,
          ),
          SliverToBoxAdapter(child: body),
        ],
      ),
    );
  }
}

// --- 1. Communication Dashboard (Inbox/Outbox/Circulars) ---

class CommunicationDashboard extends ConsumerWidget {
  const CommunicationDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SpecializedDashboardScaffold(
      title: 'مركز الاتصالات الإدارية',
      themeColor: Colors.blue.shade800,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildMailTabs(context, ref),
            SizedBox(height: 20.h),
            _buildLiveMailFlow(),
            SizedBox(height: 24.h),
            _buildCircularsSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildMailTabs(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        _buildTabCard(
          context,
          ref,
          'الوارد',
          '14',
          Icons.download_rounded,
          Colors.green,
          onTap: () {
            final user = ref.read(authStateProvider).value;
            if (user != null && user.schoolId != null) {
              context.push(
                '/incoming-mail',
                extra: {
                  'schoolId': user.schoolId,
                  'userId': user.id,
                  'userName': user.name,
                },
              );
            } else {
              context.push('/incoming-mail');
            }
          },
        ),
        SizedBox(width: 12.w),
        _buildTabCard(
          context,
          ref,
          'الصادر',
          '8',
          Icons.upload_rounded,
          Colors.blue,
        ),
        SizedBox(width: 12.w),
        _buildTabCard(
          context,
          ref,
          'المسودات',
          '3',
          Icons.edit_document,
          Colors.orange,
        ),
      ],
    );
  }

  Widget _buildTabCard(
    BuildContext context,
    WidgetRef ref,
    String label,
    String count,
    IconData icon,
    Color color, {
    VoidCallback? onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20.r),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20.r),
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28.sp),
              SizedBox(height: 8.h),
              Text(
                count,
                style: GoogleFonts.cairo(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveMailFlow() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'تدفق المعاملات الأخير',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
              Icon(Icons.filter_list, color: Colors.grey),
            ],
          ),
          SizedBox(height: 16.h),
          _buildMailFlowItem(
            'طلب صيانة طارئ',
            'وارد من: قسم المرافق',
            'منذ 5 دقائق',
            Colors.orange,
          ),
          _buildMailFlowItem(
            'تقرير الأداء الشهري',
            'صادر إلى: مكتب التعليم',
            'منذ ساعة',
            Colors.green,
          ),
          _buildMailFlowItem(
            'توجيه وزاري: الاختبارات',
            'وارد من: الوزارة',
            'اليوم، 10:00 ص',
            Colors.blue,
          ),
        ],
      ),
    );
  }

  Widget _buildMailFlowItem(
    String title,
    String subtitle,
    String time,
    Color statusColor,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            width: 45.w,
            height: 45.w,
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.description, color: statusColor, size: 20.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                ),
              ],
            ),
          ),
          Text(
            time,
            style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularsSection() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.orange.shade700, Colors.orange.shade400],
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.campaign, color: Colors.white, size: 24.sp),
              SizedBox(width: 8.w),
              Text(
                'أحدث التعاميم الوزارية',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'تعميم رقم (1447/أ) بشأن ضوابط الزي المدرسي الجديد وتوقيتات الدوام الشتوي.',
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 13.sp),
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.orange.shade800,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
            ),
            child: Text(
              'عرض التفاصيل والتوقيع',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// --- 2. Logistics Dashboard (Transport/Assets) ---

class LogisticsDashboard extends ConsumerStatefulWidget {
  const LogisticsDashboard({super.key});

  @override
  ConsumerState<LogisticsDashboard> createState() => _LogisticsDashboardState();
}

class _LogisticsDashboardState extends ConsumerState<LogisticsDashboard> {
  int _activeBuses = 0;
  int _studentsOnBoard = 0;
  int _tripsCompleted = 0;
  double _safetyScore = 0;
  int _laptopsCurrent = 0;
  int _laptopsTotal = 0;
  int _arabicBooksCurrent = 0;
  int _arabicBooksTotal = 0;
  int _labToolsCurrent = 0;
  int _labToolsTotal = 0;
  List<String> _driverNames = const [];
  List<String> _busLabels = const [];
  List<Map<String, String>> _tripHistory = const [];
  List<Map<String, dynamic>> _liveTrips = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;

    int activeBuses = 0;
    int studentsOnBoard = 0;
    int tripsCompleted = 0;
    double safetyScore = 0;
    int laptopsCurrent = 0;
    int laptopsTotal = 0;
    int arabicBooksCurrent = 0;
    int arabicBooksTotal = 0;
    int labToolsCurrent = 0;
    int labToolsTotal = 0;
    List<String> driverNames = [];
    List<String> busLabels = [];
    List<Map<String, String>> tripHistory = [];
    List<Map<String, dynamic>> liveTrips = [];

    try {
      final busesSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('TransportBuses')
          .get();
      activeBuses = busesSnap.docs.length;
      for (final d in busesSnap.docs) {
        final data = d.data();
        final label = (data['label'] ?? data['name'] ?? d.id).toString();
        if (label.trim().isNotEmpty) busLabels.add(label);
      }
    } catch (_) {}

    try {
      final tripsSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('TransportTrips')
          .get();
      for (final d in tripsSnap.docs) {
        final data = d.data();
        final s = (data['studentsOnBoard'] as num?)?.toInt();
        if (s != null) studentsOnBoard += s;
      }
    } catch (_) {}

    try {
      final today = DateTime.now();
      final start = DateTime(today.year, today.month, today.day);
      final snap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('TransportTrips')
          .where('status', isEqualTo: 'completed')
          .where(
            'completedAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(start),
          )
          .get();
      tripsCompleted = snap.docs.length;
    } catch (_) {}

    try {
      final kpi = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Kpis')
          .doc('Logistics')
          .get();
      final v = kpi.data()?['safetyScore'];
      safetyScore = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    } catch (_) {}

    try {
      final inv = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('InventoryItems')
          .get();
      for (final d in inv.docs) {
        final data = d.data();
        final type = (data['type'] ?? '').toString();
        final current = (data['current'] as num?)?.toInt() ?? 0;
        final total = (data['total'] as num?)?.toInt() ?? 0;
        if (type == 'laptops') {
          laptopsCurrent = current;
          laptopsTotal = total;
        } else if (type == 'arabic_books') {
          arabicBooksCurrent = current;
          arabicBooksTotal = total;
        } else if (type == 'lab_tools') {
          labToolsCurrent = current;
          labToolsTotal = total;
        }
      }
    } catch (_) {}

    try {
      final staffSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Staff')
          .get();
      for (final d in staffSnap.docs) {
        final name = (d.data()['name'] ?? '').toString();
        if (name.trim().isNotEmpty) driverNames.add(name);
      }
    } catch (_) {}

    try {
      final snap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('TransportTrips')
          .orderBy('startedAt', descending: true)
          .limit(5)
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final bus = (data['busLabel'] ?? data['busId'] ?? '').toString();
        final driver = (data['driverName'] ?? '').toString();
        String timeLabel = (data['timeLabel'] ?? '').toString();
        final startedAt = data['startedAt'];
        if (timeLabel.trim().isEmpty && startedAt is Timestamp) {
          final dt = startedAt.toDate();
          final hh = dt.hour.toString().padLeft(2, '0');
          final mm = dt.minute.toString().padLeft(2, '0');
          timeLabel = '$hh:$mm';
        }
        tripHistory.add({
          'title': bus.trim().isEmpty ? 'رحلة' : 'رحلة - $bus',
          'subtitle': [
            if (driver.trim().isNotEmpty) 'السائق: $driver',
            if (timeLabel.trim().isNotEmpty) timeLabel,
          ].join(' - '),
        });
      }
    } catch (_) {}

    try {
      final snap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('TransportTrips')
          .orderBy('startedAt', descending: true)
          .limit(3)
          .get();
      for (final d in snap.docs) {
        final m = d.data();
        final bus = (m['busLabel'] ?? m['busId'] ?? '').toString().trim();
        final route = (m['routeLabel'] ?? m['route'] ?? '').toString().trim();
        final status = (m['status'] ?? '').toString().trim();
        final progress =
            (m['progress'] as num?)?.toDouble().clamp(0.0, 1.0) ??
            (status == 'completed' ? 1.0 : 0.6);
        String statusLabel = 'غير محدد';
        Color color = Colors.grey;
        if (status == 'completed') {
          statusLabel = 'مكتملة';
          color = Colors.blue;
        } else if (status == 'arrived') {
          statusLabel = 'وصل';
          color = Colors.blue;
        } else if (status == 'stopped') {
          statusLabel = 'متوقف';
          color = Colors.orange;
        } else if (status.isNotEmpty) {
          statusLabel = 'جاري النقل';
          color = Colors.green;
        }
        liveTrips.add({
          'bus': bus.isEmpty ? 'حافلة' : bus,
          'route': route.isEmpty ? '—' : route,
          'statusLabel': statusLabel,
          'progress': progress,
          'color': color,
        });
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeBuses = activeBuses;
      _studentsOnBoard = studentsOnBoard;
      _tripsCompleted = tripsCompleted;
      _safetyScore = safetyScore;
      _laptopsCurrent = laptopsCurrent;
      _laptopsTotal = laptopsTotal;
      _arabicBooksCurrent = arabicBooksCurrent;
      _arabicBooksTotal = arabicBooksTotal;
      _labToolsCurrent = labToolsCurrent;
      _labToolsTotal = labToolsTotal;
      _driverNames = driverNames;
      _busLabels = busLabels;
      _tripHistory = tripHistory;
      _liveTrips = liveTrips;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpecializedDashboardScaffold(
      title: 'إدارة الموارد واللوجستيات',
      themeColor: Colors.blueGrey.shade800,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildTransportOperationsCenter(),
              SizedBox(height: 24.h),
              _buildQuickActionsGrid(context),
              SizedBox(height: 24.h),
              _buildLiveTripTracking(),
              SizedBox(height: 24.h),
              _buildInventoryLevels(),
              SizedBox(height: 24.h),
              _buildMaintenanceSchedule(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTransportOperationsCenter() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مركز عمليات النقل المدرسي',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    'مراقبة حية للأسطول وحركة الطلاب',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.green.withOpacity(0.5)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 8.w,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'نظام نشط',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              _buildStatCard(
                'حافلة نشطة',
                '$_activeBuses',
                Icons.directions_bus,
                Colors.blue,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'طالب منقول',
                '$_studentsOnBoard',
                Icons.groups,
                Colors.orange,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'رحلة مكتملة',
                '$_tripsCompleted',
                Icons.check_circle,
                Colors.green,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'معدل الأمان',
                '$_safetyScore%',
                Icons.shield,
                Colors.teal,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخدمات والإجراءات السريعة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: 16.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 4 : 8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.9,
              children: [
                _buildActionCard(
                  'تسجيل طالب',
                  Icons.person_add,
                  Colors.blue,
                  () => _showStudentRegistrationDialog(context),
                ),
                _buildActionCard(
                  'إضافة حافلة',
                  Icons.directions_bus_filled,
                  Colors.orange,
                  () => _showAddBusDialog(context),
                ),
                _buildActionCard(
                  'تعيين سائق',
                  Icons.badge,
                  Colors.purple,
                  () => _showAssignDriverDialog(context),
                ),
                _buildActionCard(
                  'سجل الرحلات',
                  Icons.history,
                  Colors.teal,
                  () => _showTripHistoryDialog(context),
                ),
                _buildActionCard(
                  'الفحص اليومي',
                  Icons.fact_check,
                  Colors.red,
                  () => _showDailyInspectionDialog(context),
                ),
                _buildActionCard(
                  'بلاغ صيانة',
                  Icons.build,
                  Colors.brown,
                  () => _showMaintenanceReportDialog(context),
                ),
                _buildActionCard(
                  'التقارير',
                  Icons.bar_chart,
                  Colors.indigo,
                  () => _showReportsDialog(context),
                ),
                _buildActionCard(
                  'الإعدادات',
                  Icons.settings,
                  Colors.grey,
                  () => _showSettingsDialog(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showTripHistoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سجل الرحلات اليومي', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 500.w,
          height: 400.h,
          child: _tripHistory.isEmpty
              ? Center(
                  child: Text(
                    'لا توجد رحلات مسجلة.',
                    style: GoogleFonts.cairo(),
                  ),
                )
              : ListView.separated(
                  itemCount: _tripHistory.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final t = _tripHistory[index];
                    return ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Colors.teal,
                        child: Icon(Icons.history, color: Colors.white),
                      ),
                      title: Text(
                        (t['title'] ?? 'رحلة').toString(),
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        (t['subtitle'] ?? '').toString(),
                        style: GoogleFonts.cairo(),
                      ),
                      trailing: const Icon(
                        Icons.check_circle,
                        color: Colors.green,
                      ),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showDailyInspectionDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    String selectedBus = _busLabels.isNotEmpty ? _busLabels.first : '';
    bool tires = true;
    bool oils = true;
    bool ac = false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('نموذج الفحص اليومي للحافلات', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              StatefulBuilder(
                builder: (context, setLocal) => Column(
                  children: [
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(
                        labelText: 'رقم/اسم الحافلة',
                      ),
                      value: selectedBus.isEmpty ? null : selectedBus,
                      items: _busLabels
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setLocal(() => selectedBus = (v ?? '').toString()),
                    ),
                    CheckboxListTile(
                      value: tires,
                      title: Text('فحص الإطارات', style: GoogleFonts.cairo()),
                      onChanged: (v) => setLocal(() => tires = v ?? false),
                    ),
                    CheckboxListTile(
                      value: oils,
                      title: Text('فحص الزيوت', style: GoogleFonts.cairo()),
                      onChanged: (v) => setLocal(() => oils = v ?? false),
                    ),
                    CheckboxListTile(
                      value: ac,
                      title: Text('فحص التكييف', style: GoogleFonts.cairo()),
                      onChanged: (v) => setLocal(() => ac = v ?? false),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('TransportInspections')
                  .add({
                    'busLabel': selectedBus,
                    'checks': {'tires': tires, 'oils': oils, 'ac': ac},
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('تم إرسال التقرير')),
                );
              }
            },
            child: Text('إرسال التقرير', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceReportDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    String? faultType;
    final descriptionController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقديم بلاغ صيانة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع العطل'),
                items: ['ميكانيكي', 'كهربائي', 'تكييف', 'هيكل']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => faultType = v,
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: descriptionController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف المشكلة',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () async {
              await FirebaseFirestore.instance
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('MaintenanceTickets')
                  .add({
                    'title': 'بلاغ صيانة للنقل',
                    'description': descriptionController.text.trim(),
                    'category': (faultType ?? '').toString(),
                    'status': 'open',
                    'createdAt': FieldValue.serverTimestamp(),
                    'source': 'transport',
                  });
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('تم رفع البلاغ بنجاح')),
                );
              }
            },
            child: Text('رفع البلاغ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showReportsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقارير النقل والتشغيل', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('تقرير استهلاك الوقود', style: GoogleFonts.cairo()),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('تقرير حضور الطلاب', style: GoogleFonts.cairo()),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('سجل الصيانة الشهري', style: GoogleFonts.cairo()),
                onTap: () {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعدادات نظام النقل', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  'تنبيهات السرعة الزائدة',
                  style: GoogleFonts.cairo(),
                ),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: Text('تتبع الموقع المباشر', style: GoogleFonts.cairo()),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: Text('إشعارات وصول الطلاب', style: GoogleFonts.cairo()),
                value: false,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveTripTracking() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'التتبع المباشر للرحلات',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.map),
                label: Text('عرض الخريطة', style: GoogleFonts.cairo()),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_liveTrips.isEmpty)
            Text(
              'لا توجد رحلات مسجلة.',
              style: GoogleFonts.cairo(color: Colors.grey.shade600),
            )
          else
            ..._liveTrips.map((t) {
              final color = (t['color'] as Color?) ?? Colors.grey;
              final progress = (t['progress'] as num?)?.toDouble() ?? 0.0;
              return _buildTripItem(
                (t['bus'] ?? '').toString(),
                (t['route'] ?? '').toString(),
                (t['statusLabel'] ?? '').toString(),
                progress.clamp(0.0, 1.0),
                color,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTripItem(
    String busId,
    String route,
    String status,
    double progress,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(Icons.directions_bus, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '$busId - $route',
                      style: GoogleFonts.cairo(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.sp,
                      ),
                    ),
                    Text(
                      status,
                      style: GoogleFonts.cairo(
                        color: color,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6.h),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey.shade100,
                  valueColor: AlwaysStoppedAnimation(color),
                  minHeight: 6.h,
                  borderRadius: BorderRadius.circular(4.r),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showStudentRegistrationDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final nameController = TextEditingController();
    final nationalIdController = TextEditingController();
    String selectedBus = _busLabels.isNotEmpty ? _busLabels.first : '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تسجيل طالب في خدمة النقل', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'اسم الطالب',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: nationalIdController,
                decoration: InputDecoration(
                  labelText: 'رقم الهوية',
                  prefixIcon: const Icon(Icons.badge),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'تحديد المسار/الحافلة',
                  prefixIcon: const Icon(Icons.route),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                value: selectedBus.isEmpty ? null : selectedBus,
                items: _busLabels
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (v) => selectedBus = (v ?? '').toString(),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              if (name.isEmpty) return;
              await FirebaseFirestore.instance
                  .collection('Schools')
                  .doc(schoolId)
                  .collection('TransportStudents')
                  .add({
                    'name': name,
                    'nationalId': nationalIdController.text.trim(),
                    'busLabel': selectedBus,
                    'createdAt': FieldValue.serverTimestamp(),
                  });
              if (context.mounted) Navigator.pop(context);
              if (mounted) {
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(content: Text('تم تسجيل الطالب بنجاح')),
                );
              }
            },
            child: Text('تسجيل', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAddBusDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إضافة حافلة جديدة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'رقم اللوحة',
                  prefixIcon: const Icon(Icons.directions_bus),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                decoration: InputDecoration(
                  labelText: 'سعة الركاب',
                  prefixIcon: const Icon(Icons.people),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                decoration: InputDecoration(
                  labelText: 'الموديل وسنة الصنع',
                  prefixIcon: const Icon(Icons.calendar_today),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إضافة الحافلة بنجاح')),
              );
            },
            child: Text('إضافة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAssignDriverDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعيين سائق لحافلة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'اختر السائق',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                items: _driverNames
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'اختر الحافلة',
                  prefixIcon: const Icon(Icons.directions_bus),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                items: _busLabels
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تعيين السائق بنجاح')),
              );
            },
            child: Text('تعيين', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryLevels() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مستويات المخزون والعهد',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 16.h),
          _buildInventoryItem(
            'أجهزة اللابتوب',
            _laptopsCurrent,
            _laptopsTotal,
            Colors.blue,
          ),
          _buildInventoryItem(
            'كتب اللغة العربية',
            _arabicBooksCurrent,
            _arabicBooksTotal,
            Colors.green,
          ),
          _buildInventoryItem(
            'أدوات المعامل',
            _labToolsCurrent,
            _labToolsTotal,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildInventoryItem(
    String label,
    int current,
    int total,
    Color color,
  ) {
    final progress = total == 0 ? 0.0 : (current / total);
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.cairo(fontSize: 13.sp)),
              Text(
                '$current / $total',
                style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: color.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 8.h,
            borderRadius: BorderRadius.circular(10.r),
          ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceSchedule() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.indigo.shade900,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        children: [
          Icon(Icons.build_circle, color: Colors.white, size: 40.sp),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الصيانة الوقائية القادمة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'تكييف المبنى الرئيسي - غداً، 9:00 ص',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_left, color: Colors.white),
        ],
      ),
    );
  }
}

// --- 3. Academic Dashboard (Exams/Results) ---

class AcademicDashboard extends ConsumerWidget {
  const AcademicDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    return SpecializedDashboardScaffold(
      title: 'التميز الأكاديمي والتحصيل',
      themeColor: Colors.blue.shade900,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: FutureBuilder<_AcademicComputed>(
          future: _AcademicComputed.load(schoolId),
          builder: (context, snap) {
            final data = snap.data ?? _AcademicComputed.empty();
            return Column(
              children: [
                _buildAcademicPulse(data),
                SizedBox(height: 24.h),
                _buildHeatmapSection(data),
                SizedBox(height: 24.h),
                _buildTopPerformers(data),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAcademicPulse(_AcademicComputed data) {
    return Row(
      children: [
        _buildPulseCard(
          'متوسط التحصيل',
          data.avgAchievementLabel,
          Icons.trending_up,
          Colors.green,
        ),
        SizedBox(width: 12.w),
        _buildPulseCard(
          'نسبة النجاح',
          data.successRateLabel,
          Icons.check_circle,
          Colors.blue,
        ),
      ],
    );
  }

  Widget _buildPulseCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(height: 12.h),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeatmapSection(_AcademicComputed data) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'مصفوفة التحصيل حسب المواد',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 16.h),
          _buildSubjectRow(
            'الرياضيات',
            data.heatmap['الرياضيات'] ?? const [null, null, null, null],
          ),
          _buildSubjectRow(
            'العلوم',
            data.heatmap['العلوم'] ?? const [null, null, null, null],
          ),
          _buildSubjectRow(
            'اللغة العربية',
            data.heatmap['اللغة العربية'] ?? const [null, null, null, null],
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildLegend('ممتاز', Colors.green),
              SizedBox(width: 8.w),
              _buildLegend('جيد', Colors.blue),
              SizedBox(width: 8.w),
              _buildLegend('متعثر', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(String label, List<double?> vals) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        children: [
          SizedBox(
            width: 80.w,
            child: Text(label, style: GoogleFonts.cairo(fontSize: 12.sp)),
          ),
          ...vals.map(
            (v) => Expanded(
              child: Container(
                height: 35.h,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                decoration: BoxDecoration(
                  color:
                      (v == null
                              ? Colors.grey
                              : (v > 0.8
                                    ? Colors.green
                                    : (v > 0.5 ? Colors.blue : Colors.red)))
                          .withOpacity(0.6),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    v == null ? '—' : '%${(v * 100).round()}',
                    style: GoogleFonts.cairo(
                      fontSize: 10.sp,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 10.w, height: 10.h, color: color.withOpacity(0.6)),
        SizedBox(width: 4.w),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildTopPerformers(_AcademicComputed data) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        children: [
          Text(
            'لوحة الشرف الأكاديمية',
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 16.h),
          if (data.topStudents.isEmpty)
            Text(
              'لا توجد بيانات درجات لعرض لوحة الشرف.',
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 12.sp),
              textAlign: TextAlign.center,
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                for (final s in data.topStudents)
                  _buildTopStudent(s.name, s.scoreLabel),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildTopStudent(String name, String score) {
    return Column(
      children: [
        CircleAvatar(
          radius: 25.r,
          backgroundColor: Colors.white24,
          child: Icon(Icons.person, color: Colors.white),
        ),
        SizedBox(height: 8.h),
        Text(
          name,
          style: GoogleFonts.cairo(color: Colors.white, fontSize: 11.sp),
        ),
        Text(
          score,
          style: GoogleFonts.cairo(
            color: Colors.amber,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _AcademicTopStudent {
  final String name;
  final String scoreLabel;
  const _AcademicTopStudent({required this.name, required this.scoreLabel});
}

class _AcademicComputed {
  final String avgAchievementLabel;
  final String successRateLabel;
  final Map<String, List<double?>> heatmap;
  final List<_AcademicTopStudent> topStudents;

  const _AcademicComputed({
    required this.avgAchievementLabel,
    required this.successRateLabel,
    required this.heatmap,
    required this.topStudents,
  });

  factory _AcademicComputed.empty() => const _AcademicComputed(
    avgAchievementLabel: '—',
    successRateLabel: '—',
    heatmap: {
      'الرياضيات': [null, null, null, null],
      'العلوم': [null, null, null, null],
      'اللغة العربية': [null, null, null, null],
    },
    topStudents: [],
  );

  static String _normalizeSubject(String raw) {
    final s = raw.trim().toLowerCase();
    if (s.contains('رياض') || s.contains('math')) return 'الرياضيات';
    if (s.contains('علوم') || s.contains('science')) return 'العلوم';
    if (s.contains('عرب') || s.contains('arab')) return 'اللغة العربية';
    return raw.trim();
  }

  static List<double?> _heatBuckets(List<double> scores) {
    if (scores.isEmpty) return const [null, null, null, null];
    final sorted = List<double>.from(scores)..sort();
    final n = sorted.length;
    int start(int i) => (i * n / 4).floor();
    int end(int i) => (((i + 1) * n / 4).floor()).clamp(0, n);
    double avg(List<double> a) =>
        a.isEmpty ? 0 : a.reduce((x, y) => x + y) / a.length;
    final buckets = <double?>[];
    for (int i = 0; i < 4; i++) {
      final a = sorted.sublist(start(i), end(i));
      buckets.add((avg(a) / 100.0).clamp(0.0, 1.0));
    }
    return buckets;
  }

  static Future<_AcademicComputed> load(String schoolId) async {
    final sid = schoolId.trim();
    if (sid.isEmpty) return _AcademicComputed.empty();
    final fs = FirebaseFirestore.instance;

    final tracksSnap = await fs
        .collection('Schools')
        .doc(sid)
        .collection('ExamGradesTracking')
        .orderBy('lastUpdateAt', descending: true)
        .limit(30)
        .get();

    final allScores = <double>[];
    final bySubject = <String, List<double>>{};
    final byStudent = <String, List<double>>{};

    for (final t in tracksSnap.docs) {
      final subjectId = (t.data()['subjectId'] ?? '').toString();
      final subject = _normalizeSubject(
        subjectId.isEmpty ? 'غير محدد' : subjectId,
      );
      final entriesSnap = await t.reference.collection('Entries').get();
      for (final e in entriesSnap.docs) {
        final m = e.data();
        final rawScore = m['score'];
        double? score;
        if (rawScore is num) score = rawScore.toDouble();
        if (rawScore is String) score = double.tryParse(rawScore);
        if (score == null) continue;
        score = score.clamp(0.0, 100.0);
        allScores.add(score);
        bySubject.putIfAbsent(subject, () => <double>[]).add(score);
        final studentId = (m['studentId'] ?? e.id).toString();
        byStudent.putIfAbsent(studentId, () => <double>[]).add(score);
      }
    }

    if (allScores.isEmpty) return _AcademicComputed.empty();

    final avg = allScores.reduce((a, b) => a + b) / allScores.length;
    final passed = allScores.where((s) => s >= 50).length;
    final success = passed / allScores.length;

    final heatmap = <String, List<double?>>{
      'الرياضيات': _heatBuckets(bySubject['الرياضيات'] ?? const []),
      'العلوم': _heatBuckets(bySubject['العلوم'] ?? const []),
      'اللغة العربية': _heatBuckets(bySubject['اللغة العربية'] ?? const []),
    };

    final studentAvg = byStudent.entries.map((e) {
      final scores = e.value;
      final a = scores.reduce((x, y) => x + y) / scores.length;
      return MapEntry(e.key, a);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    final topIds = studentAvg.take(3).toList();
    final topStudents = <_AcademicTopStudent>[];

    for (final e in topIds) {
      String name = e.key;
      try {
        final s = await fs
            .collection('Schools')
            .doc(sid)
            .collection('Students')
            .doc(e.key)
            .get();
        final m = s.data();
        final n = (m?['name'] ?? m?['studentName'] ?? '').toString().trim();
        if (n.isNotEmpty) name = n;
      } catch (_) {}
      topStudents.add(
        _AcademicTopStudent(
          name: name,
          scoreLabel: '${e.value.toStringAsFixed(1)}%',
        ),
      );
    }

    return _AcademicComputed(
      avgAchievementLabel: '${avg.toStringAsFixed(0)}%',
      successRateLabel: '${(success * 100).toStringAsFixed(0)}%',
      heatmap: heatmap,
      topStudents: topStudents,
    );
  }
}

// --- 4. Student Life Dashboard (Attendance/Behavior/Activity) ---

class StudentLifeDashboard extends StatelessWidget {
  const StudentLifeDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return SpecializedDashboardScaffold(
      title: 'الحياة المدرسية والنشاط',
      themeColor: Colors.teal.shade800,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildSentimentAnalysis(),
            SizedBox(height: 24.h),
            _buildAttendanceTrends(),
            SizedBox(height: 24.h),
            _buildActivitySpotlight(),
          ],
        ),
      ),
    );
  }

  Widget _buildSentimentAnalysis() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تحليل المشاعر السلوكي (AI)',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 16.h),
          _buildSentimentBar('إيجابي (تفاعل، مبادرة)', 0.85, Colors.green),
          SizedBox(height: 12.h),
          _buildSentimentBar('محايد (التزام روتيني)', 0.10, Colors.blue),
          SizedBox(height: 12.h),
          _buildSentimentBar('سلبي (تنمر، تأخر)', 0.05, Colors.red),
        ],
      ),
    );
  }

  Widget _buildSentimentBar(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: GoogleFonts.cairo(fontSize: 12.sp)),
            Text(
              '%${(val * 100).toInt()}',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        SizedBox(height: 6.h),
        LinearProgressIndicator(
          value: val,
          backgroundColor: color.withOpacity(0.1),
          valueColor: AlwaysStoppedAnimation(color),
          minHeight: 10.h,
          borderRadius: BorderRadius.circular(10.r),
        ),
      ],
    );
  }

  Widget _buildAttendanceTrends() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اتجاهات الانضباط الأسبوعية',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 16.sp,
            ),
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _buildAttendanceBar(0.4, 'أسبوع 1'),
              _buildAttendanceBar(0.6, 'أسبوع 2'),
              _buildAttendanceBar(0.5, 'أسبوع 3'),
              _buildAttendanceBar(0.95, 'أسبوع 4'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceBar(double h, String label) {
    return Column(
      children: [
        Container(
          width: 40.w,
          height: 100.h * h,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal, Colors.teal.shade200],
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
            ),
            borderRadius: BorderRadius.circular(12.r),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          label,
          style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey),
        ),
      ],
    );
  }

  Widget _buildActivitySpotlight() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.deepOrange.shade700, Colors.deepOrange.shade400],
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'النشاط القادم',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
                Text(
                  'يوم المبتكر الصغير - الخميس القادم',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 13.sp,
                  ),
                ),
                SizedBox(height: 12.h),
                Text(
                  'تم تسجيل 45 طالباً للمشاركة في المعرض العلمي.',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontSize: 11.sp,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.rocket_launch, color: Colors.white, size: 50.sp),
        ],
      ),
    );
  }
}

// --- 5. Strategic Dashboard (The Real Command Center) ---

class StrategicDashboard extends ConsumerWidget {
  const StrategicDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Navy
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 250.h,
            pinned: true,
            backgroundColor: const Color(0xFF1E293B),
            flexibleSpace: FlexibleSpaceBar(
              background: _StrategicPulseHeader(schoolId: schoolId),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: FutureBuilder<_StrategicComputed>(
                future: _StrategicComputed.load(schoolId),
                builder: (context, snap) {
                  final data = snap.data ?? _StrategicComputed.empty();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildStrategicSectionTitle('رادار المخاطر والفرص'),
                      SizedBox(height: 16.h),
                      _buildRiskRadarGrid(data),
                      SizedBox(height: 32.h),
                      _buildStrategicSectionTitle('مؤشرات الاستقرار الكلية'),
                      SizedBox(height: 16.h),
                      _buildStrategicMetricsGrid(data),
                      SizedBox(height: 32.h),
                      _buildStrategicSectionTitle('التوصيات القيادية العاجلة'),
                      SizedBox(height: 16.h),
                      _buildUrgentRecommendations(data),
                      SizedBox(height: 40.h),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategicSectionTitle(String title) {
    return Row(
      children: [
        Container(width: 4.w, height: 20.h, color: Colors.indigoAccent),
        SizedBox(width: 12.w),
        Text(
          title,
          style: GoogleFonts.cairo(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildRiskRadarGrid(_StrategicComputed data) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 8.w,
      mainAxisSpacing: 8.h,
      childAspectRatio: 3.1,
      children: [
        _buildRiskCard(
          'فجوة التحصيل',
          data.achievementGapLabel,
          data.achievementGapColor,
        ),
        _buildRiskCard('التسرب الطلابي', data.dropoutLabel, data.dropoutColor),
        _buildRiskCard(
          'العجز في الكادر',
          data.staffingLabel,
          data.staffingColor,
        ),
        _buildRiskCard('المناخ العام', data.climateLabel, data.climateColor),
      ],
    );
  }

  Widget _buildRiskCard(String label, String value, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10.sp),
          ),
          Text(
            value,
            style: GoogleFonts.cairo(
              color: color,
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStrategicMetricsGrid(_StrategicComputed data) {
    return Column(
      children: [
        _buildMetricRow(
          'انتظام الحضور (30ي)',
          data.attendanceRate,
          Colors.blueAccent,
        ),
        SizedBox(height: 12.h),
        _buildMetricRow(
          'جاهزية السلامة',
          data.safetyReadiness,
          Colors.purpleAccent,
        ),
        SizedBox(height: 12.h),
        _buildMetricRow('تنفيذ الخطط', data.plansProgress, Colors.amberAccent),
      ],
    );
  }

  Widget _buildMetricRow(String label, double val, Color color) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.cairo(color: Colors.white, fontSize: 13.sp),
              ),
              Text(
                '%${(val * 100).toInt()}',
                style: GoogleFonts.cairo(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          LinearProgressIndicator(
            value: val,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation(color),
            minHeight: 6.h,
            borderRadius: BorderRadius.circular(10.r),
          ),
        ],
      ),
    );
  }

  Widget _buildUrgentRecommendations(_StrategicComputed data) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [data.recommendationA, data.recommendationB],
        ),
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, color: Colors.white),
              SizedBox(width: 8.w),
              Text(
                'توصية القائد الآلي (AI)',
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            data.recommendationText,
            style: GoogleFonts.cairo(color: Colors.white, fontSize: 13.sp),
          ),
        ],
      ),
    );
  }
}

class _StrategicPulseHeader extends StatelessWidget {
  final String schoolId;
  const _StrategicPulseHeader({required this.schoolId});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StrategicComputed>(
      future: _StrategicComputed.load(schoolId),
      builder: (context, snap) {
        final data = snap.data ?? _StrategicComputed.empty();
        final score = data.schoolHealthScore;
        final statusText = data.schoolHealthLabel;
        final statusColor = data.schoolHealthColor;
        return Container(
          decoration: BoxDecoration(
            gradient: RadialGradient(
              colors: [Colors.indigo.shade900, const Color(0xFF0F172A)],
              radius: 1.2,
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const _PulseAnimation(),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'مؤشر المناعة المدرسية الذكي',
                    style: GoogleFonts.cairo(
                      color: Colors.indigo.shade200,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    score == null ? '—' : '%$score',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontSize: 72.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -2,
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 16.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20.r),
                      border: Border.all(color: statusColor.withOpacity(0.55)),
                    ),
                    child: Text(
                      statusText,
                      style: GoogleFonts.cairo(
                        color: statusColor,
                        fontSize: 12.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StrategicComputed {
  final int? schoolHealthScore;
  final String schoolHealthLabel;
  final Color schoolHealthColor;

  final String achievementGapLabel;
  final Color achievementGapColor;
  final String dropoutLabel;
  final Color dropoutColor;
  final String staffingLabel;
  final Color staffingColor;
  final String climateLabel;
  final Color climateColor;

  final double attendanceRate;
  final double safetyReadiness;
  final double plansProgress;

  final String recommendationText;
  final Color recommendationA;
  final Color recommendationB;

  const _StrategicComputed({
    required this.schoolHealthScore,
    required this.schoolHealthLabel,
    required this.schoolHealthColor,
    required this.achievementGapLabel,
    required this.achievementGapColor,
    required this.dropoutLabel,
    required this.dropoutColor,
    required this.staffingLabel,
    required this.staffingColor,
    required this.climateLabel,
    required this.climateColor,
    required this.attendanceRate,
    required this.safetyReadiness,
    required this.plansProgress,
    required this.recommendationText,
    required this.recommendationA,
    required this.recommendationB,
  });

  factory _StrategicComputed.empty() => const _StrategicComputed(
    schoolHealthScore: null,
    schoolHealthLabel: 'حالة الاستقرار: غير متوفر',
    schoolHealthColor: Colors.white70,
    achievementGapLabel: 'غير متوفر',
    achievementGapColor: Colors.white54,
    dropoutLabel: 'غير متوفر',
    dropoutColor: Colors.white54,
    staffingLabel: 'غير متوفر',
    staffingColor: Colors.white54,
    climateLabel: 'غير متوفر',
    climateColor: Colors.white54,
    attendanceRate: 0,
    safetyReadiness: 0,
    plansProgress: 0,
    recommendationText: 'لا توجد بيانات كافية لإصدار توصية حالياً.',
    recommendationA: Color(0xFF334155),
    recommendationB: Color(0xFF1E293B),
  );

  static Future<_StrategicComputed> load(String schoolId) async {
    final sid = schoolId.trim();
    if (sid.isEmpty) return _StrategicComputed.empty();
    final fs = FirebaseFirestore.instance;

    double attendanceRate = 0;
    int lowAttendanceStudents = 0;
    try {
      final start = DateTime.now().subtract(const Duration(days: 30));
      final snap = await fs
          .collection('Schools')
          .doc(sid)
          .collection('StudentAttendance')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .get();
      final byStudent = <String, Map<String, int>>{};
      for (final d in snap.docs) {
        final m = d.data();
        final studentId = (m['studentId'] ?? '').toString();
        if (studentId.trim().isEmpty) continue;
        final status = (m['status'] ?? 'present').toString();
        final bucket = byStudent.putIfAbsent(
          studentId,
          () => {'present': 0, 'absent': 0, 'late': 0, 'excused': 0},
        );
        bucket[status] = (bucket[status] ?? 0) + 1;
      }
      if (byStudent.isNotEmpty) {
        final rates = <double>[];
        for (final v in byStudent.values) {
          final total =
              (v['present'] ?? 0) +
              (v['absent'] ?? 0) +
              (v['late'] ?? 0) +
              (v['excused'] ?? 0);
          final r = total == 0
              ? 1.0
              : ((v['present'] ?? 0) + 0.5 * (v['late'] ?? 0)) / total;
          rates.add(r.clamp(0.0, 1.0));
          if (r < 0.85) lowAttendanceStudents += 1;
        }
        attendanceRate = rates.reduce((a, b) => a + b) / rates.length;
      }
    } catch (_) {}

    double safetyReadiness = 0;
    try {
      final s = await fs
          .collection('Schools')
          .doc(sid)
          .collection('Safety')
          .doc('settings')
          .get();
      final m = s.data() ?? const <String, dynamic>{};
      final camA = (m['camerasActive'] as num?)?.toDouble();
      final camT = (m['camerasTotal'] as num?)?.toDouble();
      final alarmsReady = m['alarmsReady'] as bool?;
      final meetingPoint = (m['meetingPoint'] ?? '').toString().trim();
      final officer = (m['evacuationOfficer'] ?? '').toString().trim();
      final cameraScore = (camA != null && camT != null && camT > 0)
          ? (camA / camT).clamp(0.0, 1.0)
          : 0.0;
      final alarmsScore = alarmsReady == null ? 0.0 : (alarmsReady ? 1.0 : 0.3);
      final planScore = (meetingPoint.isNotEmpty || officer.isNotEmpty)
          ? 1.0
          : 0.0;
      safetyReadiness =
          (cameraScore * 0.5) + (alarmsScore * 0.3) + (planScore * 0.2);
    } catch (_) {}

    double plansProgress = 0;
    int plansActive = 0;
    int plansOverdue = 0;
    try {
      final plansSnap = await fs
          .collection('Schools')
          .doc(sid)
          .collection('DevelopmentPlans')
          .get();
      if (plansSnap.docs.isNotEmpty) {
        double sum = 0;
        for (final d in plansSnap.docs) {
          final m = d.data();
          final status = (m['status'] ?? 'active').toString();
          final p = (m['progress'] as num?)?.toDouble() ?? 0.0;
          sum += p.clamp(0.0, 1.0);
          if (status != 'completed') {
            plansActive += 1;
            final endTs = m['endDate'];
            final endDate = endTs is Timestamp ? endTs.toDate() : null;
            if (endDate != null && endDate.isBefore(DateTime.now()))
              plansOverdue += 1;
          }
        }
        plansProgress = (sum / plansSnap.docs.length).clamp(0.0, 1.0);
      }
    } catch (_) {}

    int? healthScore;
    int redPredictions = 0;
    int yellowPredictions = 0;
    int activeRemedial = 0;
    try {
      final q = await fs
          .collection('Schools')
          .doc(sid)
          .collection('SchoolIntelligence')
          .orderBy('generatedAt', descending: true)
          .limit(1)
          .get();
      if (q.docs.isNotEmpty) {
        final v = q.docs.first.data()['schoolHealthScore'];
        final d = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0.0;
        healthScore = d.round().clamp(0, 100);
      }
    } catch (_) {}

    try {
      final preds = await fs
          .collection('Schools')
          .doc(sid)
          .collection('RiskPredictions')
          .where('riskLevel', whereIn: ['RED', 'YELLOW'])
          .limit(200)
          .get();
      for (final d in preds.docs) {
        final lvl = (d.data()['riskLevel'] ?? 'GREEN').toString();
        if (lvl == 'RED') redPredictions += 1;
        if (lvl == 'YELLOW') yellowPredictions += 1;
      }
    } catch (_) {}

    try {
      final rem = await fs
          .collection('Schools')
          .doc(sid)
          .collection('RemedialPlans')
          .where('status', isEqualTo: 'active')
          .limit(200)
          .get();
      activeRemedial = rem.docs.length;
    } catch (_) {}

    int staffCount = 0;
    int activeAssignments = 0;
    try {
      final staffSnap = await fs
          .collection('Schools')
          .doc(sid)
          .collection('Staff')
          .get();
      staffCount = staffSnap.docs.length;
    } catch (_) {}
    try {
      final a = await fs
          .collection('Schools')
          .doc(sid)
          .collection('StaffAssignments')
          .where('status', isNotEqualTo: 'completed')
          .limit(200)
          .get();
      activeAssignments = a.docs.length;
    } catch (_) {}

    String stabilityLabel;
    Color stabilityColor;
    if (healthScore == null) {
      stabilityLabel = 'حالة الاستقرار: غير متوفر';
      stabilityColor = Colors.white70;
    } else if (healthScore >= 85) {
      stabilityLabel = 'حالة الاستقرار: ممتاز';
      stabilityColor = Colors.greenAccent;
    } else if (healthScore >= 70) {
      stabilityLabel = 'حالة الاستقرار: جيد';
      stabilityColor = Colors.amberAccent;
    } else {
      stabilityLabel = 'حالة الاستقرار: يحتاج تدخل';
      stabilityColor = Colors.redAccent;
    }

    String achievementGapLabel;
    Color achievementGapColor;
    if (redPredictions == 0 && activeRemedial == 0) {
      achievementGapLabel = 'منخفضة';
      achievementGapColor = Colors.greenAccent;
    } else if (redPredictions <= 3) {
      achievementGapLabel = 'متوسطة';
      achievementGapColor = Colors.orangeAccent;
    } else {
      achievementGapLabel = 'مرتفعة';
      achievementGapColor = Colors.redAccent;
    }

    final dropoutLabel = lowAttendanceStudents == 0
        ? 'صفر'
        : '$lowAttendanceStudents حالات';
    final dropoutColor = lowAttendanceStudents == 0
        ? Colors.greenAccent
        : Colors.orangeAccent;

    String staffingLabel;
    Color staffingColor;
    if (staffCount == 0) {
      staffingLabel = 'غير مسجل';
      staffingColor = Colors.white54;
    } else {
      final ratio = activeAssignments / staffCount;
      if (ratio <= 0.8) {
        staffingLabel = 'مستقر';
        staffingColor = Colors.greenAccent;
      } else if (ratio <= 1.5) {
        staffingLabel = 'متوسط';
        staffingColor = Colors.orangeAccent;
      } else {
        staffingLabel = 'مرتفع';
        staffingColor = Colors.redAccent;
      }
    }

    String climateLabel;
    Color climateColor;
    if (redPredictions == 0 && lowAttendanceStudents == 0) {
      climateLabel = 'إيجابي';
      climateColor = Colors.lightBlueAccent;
    } else if (redPredictions <= 3 && lowAttendanceStudents <= 3) {
      climateLabel = 'مقبول';
      climateColor = Colors.amberAccent;
    } else {
      climateLabel = 'يحتاج متابعة';
      climateColor = Colors.orangeAccent;
    }

    final String recommendationText;
    final Color recommendationA;
    final Color recommendationB;
    if (plansOverdue > 0) {
      recommendationText =
          'يوجد $plansOverdue خطط متأخرة. حدّد إجراءين أسبوعيًا لكل خطة وربطهما بمؤشرات قياس واضحة.';
      recommendationA = Colors.red.shade900;
      recommendationB = Colors.red.shade700;
    } else if (redPredictions > 0) {
      recommendationText =
          'توجد حالات أكاديمية عالية الخطورة ($redPredictions). فعّل خطط علاجية مركزة وربطها بمتابعة أسبوعية.';
      recommendationA = Colors.orange.shade900;
      recommendationB = Colors.orange.shade700;
    } else if (lowAttendanceStudents > 0) {
      recommendationText =
          'يوجد $lowAttendanceStudents طلاب بانخفاض في انتظام الحضور. فعّل متابعة صباحية وإشعارات ولي الأمر.';
      recommendationA = Colors.blue.shade900;
      recommendationB = Colors.blue.shade700;
    } else if (plansActive == 0) {
      recommendationText =
          'لا توجد خطط نشطة. ابدأ بخطة واحدة قصيرة المدى مرتبطة بالتحصيل والانضباط.';
      recommendationA = const Color(0xFF0B6E4F);
      recommendationB = Colors.teal.shade700;
    } else {
      recommendationText =
          'المؤشرات مستقرة. استمر في رفع تنفيذ الخطط وتحسين جودة التوثيق والشواهد.';
      recommendationA = Colors.indigo.shade900;
      recommendationB = Colors.indigo.shade700;
    }

    return _StrategicComputed(
      schoolHealthScore: healthScore,
      schoolHealthLabel: stabilityLabel,
      schoolHealthColor: stabilityColor,
      achievementGapLabel: achievementGapLabel,
      achievementGapColor: achievementGapColor,
      dropoutLabel: dropoutLabel,
      dropoutColor: dropoutColor,
      staffingLabel: staffingLabel,
      staffingColor: staffingColor,
      climateLabel: climateLabel,
      climateColor: climateColor,
      attendanceRate: attendanceRate.clamp(0.0, 1.0),
      safetyReadiness: safetyReadiness.clamp(0.0, 1.0),
      plansProgress: plansProgress.clamp(0.0, 1.0),
      recommendationText: recommendationText,
      recommendationA: recommendationA,
      recommendationB: recommendationB,
    );
  }
}

// --- 6. Assets & Inventory Dashboard ---

class AssetsDashboard extends ConsumerStatefulWidget {
  const AssetsDashboard({super.key});

  @override
  ConsumerState<AssetsDashboard> createState() => _AssetsDashboardState();
}

class _AssetsDashboardState extends ConsumerState<AssetsDashboard> {
  int _totalAssets = 0;
  double _assetsValue = 0; // In Millions
  double _utilizationRate = 0;
  bool _autoBarcodeAfterRegister = true;
  bool _requireTransferApproval = true;
  bool _enableAuditTrail = true;

  List<Map<String, dynamic>> _assetCategories = [];
  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _maintenanceTickets = [];
  List<Map<String, dynamic>> _activityLog = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;

    int totalAssets = 0;
    double assetsValue = 0;
    int inUse = 0;
    final categories = <String, int>{};
    final pendingRequests = <Map<String, dynamic>>[];
    final maintenanceTickets = <Map<String, dynamic>>[];
    final activityLog = <Map<String, dynamic>>[];

    try {
      final assetsSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Assets')
          .get();
      totalAssets = assetsSnap.docs.length;
      for (final d in assetsSnap.docs) {
        final data = d.data();
        final value = (data['value'] as num?)?.toDouble() ?? 0;
        assetsValue += value;
        final status = (data['status'] ?? '').toString();
        if (status == 'in_use') inUse++;
        final cat = (data['category'] ?? 'غير مصنف').toString();
        categories[cat] = (categories[cat] ?? 0) + 1;
      }
    } catch (_) {}

    try {
      final reqSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('AssetRequests')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get();
      for (final d in reqSnap.docs) {
        final data = d.data();
        pendingRequests.add({
          'title': (data['title'] ?? data['subject'] ?? '').toString(),
          'from': (data['from'] ?? data['requesterName'] ?? '').toString(),
          'time': (data['timeLabel'] ?? '').toString(),
          'priority': (data['priority'] ?? '').toString(),
          'status': (data['status'] ?? '').toString(),
        });
      }
    } catch (_) {}

    try {
      final tSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('MaintenanceTickets')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .get();
      for (final d in tSnap.docs) {
        final data = d.data();
        final assetId = (data['assetId'] ?? data['assetCode'] ?? '').toString();
        if (assetId.isEmpty) continue;
        maintenanceTickets.add({
          'assetId': assetId,
          'type': (data['type'] ?? '').toString(),
          'priority': (data['priority'] ?? '').toString(),
          'time': (data['timeLabel'] ?? '').toString(),
          'status': (data['status'] ?? '').toString(),
        });
      }
    } catch (_) {}

    try {
      final aSnap = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('AssetActivity')
          .orderBy('createdAt', descending: true)
          .limit(8)
          .get();
      for (final d in aSnap.docs) {
        final data = d.data();
        activityLog.add({
          'title': (data['title'] ?? '').toString(),
          'time': (data['timeLabel'] ?? '').toString(),
          'icon': Icons.info_outline,
          'color': Colors.blueGrey,
        });
      }
    } catch (_) {}

    final utilRate = totalAssets == 0 ? 0.0 : ((inUse / totalAssets) * 100.0);

    final categoriesList = categories.entries.map((e) {
      return {
        'name': e.key,
        'qty': e.value,
        'unit': 'وحدة',
        'status': '',
        'color': Colors.blueGrey,
        'type': e.key,
      };
    }).toList();

    try {
      final settings = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc('Assets')
          .get();
      final data = settings.data();
      if (data != null) {
        _autoBarcodeAfterRegister =
            (data['autoBarcodeAfterRegister'] as bool?) ??
            _autoBarcodeAfterRegister;
        _requireTransferApproval =
            (data['requireTransferApproval'] as bool?) ??
            _requireTransferApproval;
        _enableAuditTrail =
            (data['enableAuditTrail'] as bool?) ?? _enableAuditTrail;
      }
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _totalAssets = totalAssets;
      _assetsValue = assetsValue / 1000000.0;
      _utilizationRate = utilRate;
      _assetCategories = categoriesList;
      _pendingRequests = pendingRequests;
      _maintenanceTickets = maintenanceTickets;
      _activityLog = activityLog;
    });
  }

  int get _maintenanceRequests => _maintenanceTickets.length;

  @override
  Widget build(BuildContext context) {
    return SpecializedDashboardScaffold(
      title: 'إدارة العهد والممتلكات',
      themeColor: Colors.blueGrey.shade700,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildAssetsOperationsCenter(),
              SizedBox(height: 24.h),
              _buildQuickActionsGrid(context),
              SizedBox(height: 24.h),
              _buildAssetRequests(),
              SizedBox(height: 24.h),
              _buildInventoryGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetsOperationsCenter() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade600],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blueGrey.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مركز مراقبة الأصول والممتلكات',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    'نظام إدارة الموارد المؤسسية (ERP)',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.sync, color: Colors.greenAccent, size: 14.sp),
                    SizedBox(width: 6.w),
                    Text(
                      'مزامنة فورية',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              _buildStatCard(
                'إجمالي الأصول',
                '$_totalAssets',
                Icons.inventory_2,
                Colors.blue,
                () => _showAssetsOverviewDialog(context),
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'قيمة الأصول (مليون)',
                '$_assetsValue M',
                Icons.attach_money,
                Colors.green,
                () => _showValueBreakdownDialog(context),
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'طلبات الصيانة',
                '$_maintenanceRequests',
                Icons.build_circle,
                Colors.orange,
                () => _showMaintenanceTicketsDialog(context),
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'معدل الاستخدام',
                '$_utilizationRate%',
                Icons.pie_chart,
                Colors.purple,
                () => _showUtilizationDialog(context),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24.sp),
              SizedBox(height: 8.h),
              Text(
                value,
                style: GoogleFonts.cairo(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18.sp,
                ),
              ),
              Text(
                label,
                style: GoogleFonts.cairo(
                  color: Colors.white70,
                  fontSize: 10.sp,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخدمات والإجراءات السريعة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            color: Colors.blueGrey.shade800,
          ),
        ),
        SizedBox(height: 16.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 4 : 8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.9,
              children: [
                _buildActionCard(
                  'إضافة عهدة',
                  Icons.add_box,
                  Colors.blue,
                  () => _showAddAssetDialog(context),
                ),
                _buildActionCard(
                  'نقل عهدة',
                  Icons.move_up,
                  Colors.orange,
                  () => _showTransferAssetDialog(context),
                ),
                _buildActionCard(
                  'بدء جرد',
                  Icons.qr_code_scanner,
                  Colors.purple,
                  () => _showInventoryCheckDialog(context),
                ),
                _buildActionCard(
                  'إتلاف/فقدان',
                  Icons.delete_forever,
                  Colors.red,
                  () => _showDamageReportDialog(context),
                ),
                _buildActionCard(
                  'طلب صيانة',
                  Icons.build,
                  Colors.brown,
                  () => _showMaintenanceRequestDialog(context),
                ),
                _buildActionCard(
                  'طباعة باركود',
                  Icons.print,
                  Colors.teal,
                  () => _showBarcodePrintDialog(context),
                ),
                _buildActionCard(
                  'التقارير',
                  Icons.bar_chart,
                  Colors.indigo,
                  () => _showAssetReportsDialog(context),
                ),
                _buildActionCard(
                  'الإعدادات',
                  Icons.settings,
                  Colors.grey,
                  () => _showAssetSettingsDialog(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  void _showAddAssetDialog(BuildContext context) {
    final nameController = TextEditingController();
    final valueController = TextEditingController();
    final qtyController = TextEditingController(text: '1');
    String? category;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('تسجيل أصل جديد', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'اسم الأصل',
                      prefixIcon: const Icon(Icons.inventory_2),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: category,
                    decoration: const InputDecoration(labelText: 'التصنيف'),
                    items: _assetCategories
                        .map(
                          (c) => DropdownMenuItem(
                            value: c['type'] as String,
                            child: Text(c['name'] as String),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setStateDialog(() => category = v),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: qtyController,
                    decoration: InputDecoration(
                      labelText: 'الكمية',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: valueController,
                    decoration: InputDecoration(
                      labelText: 'القيمة التقديرية (ريال)',
                      prefixIcon: const Icon(Icons.attach_money),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  final qty = int.tryParse(qtyController.text.trim()) ?? 1;
                  final valueSar =
                      double.tryParse(valueController.text.trim()) ?? 0;
                  final name = nameController.text.trim();
                  final type =
                      category ?? (_assetCategories.first['type'] as String);

                  setState(() {
                    _totalAssets += qty;
                    _assetsValue += (valueSar * qty) / 1000000;
                    final idx = _assetCategories.indexWhere(
                      (c) => c['type'] == type,
                    );
                    if (idx != -1) {
                      _assetCategories[idx]['qty'] =
                          (_assetCategories[idx]['qty'] as int) + qty;
                      _assetCategories[idx]['status'] = 'محدث';
                    }
                    if (_enableAuditTrail) {
                      _activityLog.insert(0, {
                        'title':
                            'تم تسجيل أصل جديد: ${name.isEmpty ? 'أصل' : name} ($qty)',
                        'time': 'الآن',
                        'icon': Icons.add_box,
                        'color': Colors.blue,
                      });
                    }
                  });

                  Navigator.pop(context);

                  if (_autoBarcodeAfterRegister) {
                    _showBarcodePrintDialog(
                      context,
                      prefillAssetId:
                          'AST-${DateTime.now().millisecondsSinceEpoch % 10000}',
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تسجيل الأصل بنجاح')),
                    );
                  }
                },
                child: Text('حفظ', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showTransferAssetDialog(BuildContext context) {
    final assetIdController = TextEditingController();
    String? toEntity;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('نقل عهدة', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: assetIdController,
                    decoration: InputDecoration(
                      labelText: 'رقم الأصل / الباركود',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: toEntity,
                    decoration: const InputDecoration(
                      labelText: 'المنقول إليه',
                    ),
                    items:
                        [
                              'قسم الحاسب',
                              'المكتبة',
                              'الإدارة',
                              'معلم: محمد علي',
                              'معلم: عبدالله السالم',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setStateDialog(() => toEntity = v),
                  ),
                  if (_requireTransferApproval) ...[
                    SizedBox(height: 12.h),
                    Container(
                      padding: EdgeInsets.all(10.w),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12.r),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.2),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.verified_user, color: Colors.orange),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Text(
                              'يتطلب هذا الإجراء موافقة واعتماد قبل الإغلاق النهائي.',
                              style: GoogleFonts.cairo(fontSize: 12.sp),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  final assetId = assetIdController.text.trim().isEmpty
                      ? 'AST-${DateTime.now().millisecondsSinceEpoch % 10000}'
                      : assetIdController.text.trim();
                  final to = toEntity ?? 'الإدارة';

                  setState(() {
                    if (_requireTransferApproval) {
                      _pendingRequests.insert(0, {
                        'title': 'اعتماد نقل عهدة ($assetId)',
                        'from': to,
                        'time': 'الآن',
                        'priority': 'متوسط',
                        'status': 'معلق',
                      });
                    }
                    if (_enableAuditTrail) {
                      _activityLog.insert(0, {
                        'title': 'تم إنشاء طلب نقل عهدة: $assetId → $to',
                        'time': 'الآن',
                        'icon': Icons.move_up,
                        'color': Colors.orange,
                      });
                    }
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _requireTransferApproval
                            ? 'تم إنشاء طلب نقل بانتظار الاعتماد'
                            : 'تم نقل العهدة بنجاح',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                },
                child: Text('تأكيد', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showInventoryCheckDialog(BuildContext context) {
    String? location;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('بدء عملية جرد', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: location,
                    decoration: const InputDecoration(
                      labelText: 'الموقع المستهدف',
                    ),
                    items: ['المعمل 1', 'المكتبة', 'المستودع الرئيسي', 'الفصول']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => location = v),
                  ),
                  SizedBox(height: 12.h),
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.purple.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(12.r),
                      border: Border.all(
                        color: Colors.purple.withOpacity(0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.qr_code_scanner, color: Colors.purple),
                        SizedBox(width: 10.w),
                        Expanded(
                          child: Text(
                            'يتم ربط الجرد بالباركود/QR لإثبات الاستلام وتوثيق العهد.',
                            style: GoogleFonts.cairo(fontSize: 12.sp),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    for (final c in _assetCategories) {
                      c['status'] = 'تم الجرد';
                    }
                    if (_enableAuditTrail) {
                      _activityLog.insert(0, {
                        'title':
                            'تم بدء جرد: ${location ?? 'المستودع الرئيسي'}',
                        'time': 'الآن',
                        'icon': Icons.qr_code_scanner,
                        'color': Colors.purple,
                      });
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم بدء عملية الجرد',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                },
                child: Text('بدء', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showDamageReportDialog(BuildContext context) {
    final assetIdController = TextEditingController();
    final detailsController = TextEditingController();
    String? reason;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('محضر إتلاف / فقدان', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: assetIdController,
                    decoration: InputDecoration(
                      labelText: 'رقم الأصل',
                      prefixIcon: const Icon(Icons.numbers),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: reason,
                    decoration: const InputDecoration(labelText: 'السبب'),
                    items:
                        [
                              'تلف طبيعي',
                              'سوء استخدام',
                              'سرقة/فقدان',
                              'انتهاء عمر افتراضي',
                            ]
                            .map(
                              (e) => DropdownMenuItem(value: e, child: Text(e)),
                            )
                            .toList(),
                    onChanged: (v) => setStateDialog(() => reason = v),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: detailsController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'التفاصيل',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () {
                  final assetId = assetIdController.text.trim().isEmpty
                      ? 'AST-${DateTime.now().millisecondsSinceEpoch % 10000}'
                      : assetIdController.text.trim();
                  final r = reason ?? 'تلف طبيعي';

                  setState(() {
                    _totalAssets = (_totalAssets - 1).clamp(0, 1000000000);
                    if (_enableAuditTrail) {
                      _activityLog.insert(0, {
                        'title': 'تم رفع محضر ($r) للأصل: $assetId',
                        'time': 'الآن',
                        'icon': Icons.delete_forever,
                        'color': Colors.red,
                      });
                    }
                    _pendingRequests.insert(0, {
                      'title': 'اعتماد محضر إتلاف/فقدان ($assetId)',
                      'from': 'النظام',
                      'time': 'الآن',
                      'priority': 'عاجل',
                      'status': 'معلق',
                    });
                  });

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم رفع المحضر وإرساله للاعتماد',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                },
                child: Text('رفع المحضر', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryBox(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: GoogleFonts.cairo(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final isMobile = width < 600;
        final crossAxisCount = isMobile
            ? 2
            : width >= 1400
            ? 6
            : width >= 1000
            ? 4
            : 3;

        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: isMobile ? 0.9 : 1.25,
          children: [
            for (final c in _assetCategories)
              _buildAssetItem(
                c['name'] as String,
                '${c['qty']} ${c['unit']}',
                c['status'] as String,
                c['color'] as Color,
                isDense: !isMobile,
                onTap: () => _showAssetCategoryDialog(context, c),
              ),
          ],
        );
      },
    );
  }

  Widget _buildAssetItem(
    String name,
    String qty,
    String status,
    Color color, {
    bool isDense = false,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(isDense ? 12.w : 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(isDense ? 8.w : 10.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.category,
                color: color,
                size: isDense ? 20.sp : 24.sp,
              ),
            ),
            SizedBox(height: isDense ? 8.h : 12.h),
            Text(
              name,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: isDense ? 11.sp : 13.sp,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              qty,
              style: GoogleFonts.cairo(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isDense ? 11.sp : 13.sp,
              ),
            ),
            Text(
              status,
              style: GoogleFonts.cairo(
                fontSize: isDense ? 9.sp : 10.sp,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssetRequests() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.blueGrey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'طلبات العهد المعلقة',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp,
                ),
              ),
              TextButton(
                onPressed: () => _showRequestsDialog(context),
                child: Text(
                  'عرض الكل (${_pendingRequests.length})',
                  style: GoogleFonts.cairo(),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          if (_pendingRequests.isEmpty)
            Container(
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: Colors.green.withOpacity(0.15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.verified, color: Colors.green),
                  SizedBox(width: 10.w),
                  Text(
                    'لا توجد طلبات معلقة حالياً',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            )
          else
            ..._pendingRequests
                .take(2)
                .map(
                  (r) => _buildRequestItem(
                    context,
                    r,
                    onTap: () => _showRequestDetailsDialog(context, r),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(
    BuildContext context,
    Map<String, dynamic> request, {
    required VoidCallback onTap,
  }) {
    final priority = (request['priority'] ?? 'متوسط') as String;
    final title = (request['title'] ?? '') as String;
    final from = (request['from'] ?? '') as String;
    final time = (request['time'] ?? '') as String;
    final chipColor = priority == 'عاجل'
        ? Colors.red
        : priority == 'متوسط'
        ? Colors.orange
        : Colors.blueGrey;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 10.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.blueGrey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: chipColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(Icons.pending_actions, color: chipColor, size: 18.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    from,
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      color: Colors.grey,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: 8.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    priority,
                    style: GoogleFonts.cairo(
                      color: chipColor,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  time,
                  style: GoogleFonts.cairo(fontSize: 10.sp, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(width: 6.w),
            Icon(Icons.chevron_left, color: Colors.blueGrey.shade400),
          ],
        ),
      ),
    );
  }

  void _showMaintenanceRequestDialog(
    BuildContext context, {
    String? prefillAssetId,
  }) {
    final assetIdController = TextEditingController(text: prefillAssetId ?? '');
    String? type;
    String? priority;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('طلب صيانة للأصول', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: assetIdController,
                    decoration: InputDecoration(
                      labelText: 'رقم الأصل',
                      prefixIcon: const Icon(Icons.qr_code),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: type,
                    decoration: const InputDecoration(labelText: 'نوع الصيانة'),
                    items: ['ميكانيكي', 'كهربائي', 'شبكات', 'أجهزة', 'أخرى']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => type = v),
                  ),
                  SizedBox(height: 12.h),
                  DropdownButtonFormField<String>(
                    value: priority,
                    decoration: const InputDecoration(labelText: 'الأولوية'),
                    items: ['عاجل', 'متوسط', 'منخفض']
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                    onChanged: (v) => setStateDialog(() => priority = v),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () {
                  final assetId = assetIdController.text.trim().isEmpty
                      ? 'AST-${DateTime.now().millisecondsSinceEpoch % 10000}'
                      : assetIdController.text.trim();
                  final t = type ?? 'أخرى';
                  final p = priority ?? 'متوسط';
                  setState(() {
                    _maintenanceTickets.insert(0, {
                      'assetId': assetId,
                      'type': t,
                      'priority': p,
                      'time': 'الآن',
                      'status': 'مفتوح',
                    });
                    if (_enableAuditTrail) {
                      _activityLog.insert(0, {
                        'title': 'تم إنشاء طلب صيانة للأصل: $assetId ($t)',
                        'time': 'الآن',
                        'icon': Icons.build,
                        'color': Colors.brown,
                      });
                    }
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'تم إنشاء طلب الصيانة',
                        style: GoogleFonts.cairo(),
                      ),
                    ),
                  );
                },
                child: Text('إنشاء', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showBarcodePrintDialog(BuildContext context, {String? prefillAssetId}) {
    final assetIdController = TextEditingController(text: prefillAssetId ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طباعة باركود', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 420.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: assetIdController,
                decoration: InputDecoration(
                  labelText: 'رقم الأصل / الباركود',
                  prefixIcon: const Icon(Icons.qr_code),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.teal.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.teal.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.print, color: Colors.teal),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Text(
                        'يدعم الطباعة لملصقات QR/Barcode وربطها بسجل الأصل.',
                        style: GoogleFonts.cairo(fontSize: 12.sp),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              final id = assetIdController.text.trim().isEmpty
                  ? 'AST-${DateTime.now().millisecondsSinceEpoch % 10000}'
                  : assetIdController.text.trim();
              if (_enableAuditTrail) {
                setState(() {
                  _activityLog.insert(0, {
                    'title': 'تم إصدار باركود للأصل: $id',
                    'time': 'الآن',
                    'icon': Icons.print,
                    'color': Colors.teal,
                  });
                });
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم إرسال أمر الطباعة',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              );
            },
            child: Text('طباعة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAssetReportsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقارير العهد والممتلكات', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 520.w,
          height: 420.h,
          child: ListView(
            children: [
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(
                  'تقرير الأصول حسب التصنيف',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'توزيع الأصول والقيمة والاستخدام',
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('تقرير الجرد الدوري', style: GoogleFonts.cairo()),
                subtitle: Text(
                  'الالتزام بالجرد ومؤشرات الانحراف',
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text(
                  'تقرير الإتلاف والفقدان',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'المحاضر والإجراءات والتدقيق',
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
                onTap: () {},
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Colors.red),
                title: Text('تقرير الصيانة', style: GoogleFonts.cairo()),
                subtitle: Text(
                  'معدل الأعطال والاستجابة',
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAssetSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: Text('إعدادات العهد والممتلكات', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 480.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(
                      'طباعة باركود تلقائياً بعد التسجيل',
                      style: GoogleFonts.cairo(),
                    ),
                    value: _autoBarcodeAfterRegister,
                    onChanged: (v) {
                      setState(() => _autoBarcodeAfterRegister = v);
                      setStateDialog(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      'يتطلب نقل العهدة اعتماد',
                      style: GoogleFonts.cairo(),
                    ),
                    value: _requireTransferApproval,
                    onChanged: (v) {
                      setState(() => _requireTransferApproval = v);
                      setStateDialog(() {});
                    },
                  ),
                  SwitchListTile(
                    title: Text(
                      'تفعيل سجل التدقيق (Audit Trail)',
                      style: GoogleFonts.cairo(),
                    ),
                    value: _enableAuditTrail,
                    onChanged: (v) {
                      setState(() => _enableAuditTrail = v);
                      setStateDialog(() {});
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إغلاق', style: GoogleFonts.cairo()),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showAssetCategoryDialog(
    BuildContext context,
    Map<String, dynamic> category,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(category['name'] as String, style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 520.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'الكمية: ${category['qty']} ${category['unit']}',
                    style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    category['status'] as String,
                    style: GoogleFonts.cairo(
                      color: category['color'] as Color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Wrap(
                spacing: 10.w,
                runSpacing: 10.h,
                children: [
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showAddAssetDialog(context);
                    },
                    icon: const Icon(Icons.add_box),
                    label: Text('إضافة', style: GoogleFonts.cairo()),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showInventoryCheckDialog(context);
                    },
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text('جرد', style: GoogleFonts.cairo()),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      _showMaintenanceRequestDialog(context);
                    },
                    icon: const Icon(Icons.build),
                    label: Text('صيانة', style: GoogleFonts.cairo()),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      _showDamageReportDialog(context);
                    },
                    icon: const Icon(Icons.delete_forever),
                    label: Text('إتلاف/فقدان', style: GoogleFonts.cairo()),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showRequestsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طلبات العهد المعلقة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 560.w,
          height: 460.h,
          child: ListView.builder(
            itemCount: _pendingRequests.length,
            itemBuilder: (context, index) {
              final r = _pendingRequests[index];
              return _buildRequestItem(
                context,
                r,
                onTap: () => _showRequestDetailsDialog(context, r),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showRequestDetailsDialog(
    BuildContext context,
    Map<String, dynamic> request,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(request['title'] as String, style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 520.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('الجهة: ${request['from']}', style: GoogleFonts.cairo()),
              SizedBox(height: 8.h),
              Text('الوقت: ${request['time']}', style: GoogleFonts.cairo()),
              SizedBox(height: 8.h),
              Text(
                'الأولوية: ${request['priority']}',
                style: GoogleFonts.cairo(),
              ),
              SizedBox(height: 16.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(12.r),
                  border: Border.all(color: Colors.blueGrey.withOpacity(0.15)),
                ),
                child: Text(
                  'يمكن ربط الطلب بمسار موافقات (مدير المدرسة → الشؤون الإدارية → المستودع) وفق سياسات الحوكمة.',
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _pendingRequests.remove(request);
                if (_enableAuditTrail) {
                  _activityLog.insert(0, {
                    'title': 'تم رفض الطلب: ${request['title']}',
                    'time': 'الآن',
                    'icon': Icons.block,
                    'color': Colors.red,
                  });
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم رفض الطلب', style: GoogleFonts.cairo()),
                ),
              );
            },
            child: Text('رفض', style: GoogleFonts.cairo(color: Colors.red)),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _pendingRequests.remove(request);
                if (_enableAuditTrail) {
                  _activityLog.insert(0, {
                    'title': 'تم اعتماد الطلب: ${request['title']}',
                    'time': 'الآن',
                    'icon': Icons.verified,
                    'color': Colors.green,
                  });
                }
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('تم اعتماد الطلب', style: GoogleFonts.cairo()),
                ),
              );
            },
            child: Text('اعتماد', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceTicketsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('طلبات الصيانة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 560.w,
          height: 460.h,
          child: ListView.separated(
            itemCount: _maintenanceTickets.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final t = _maintenanceTickets[index];
              final p = (t['priority'] ?? 'متوسط') as String;
              final color = p == 'عاجل'
                  ? Colors.red
                  : p == 'متوسط'
                  ? Colors.orange
                  : Colors.blueGrey;
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: color.withOpacity(0.15),
                  child: Icon(Icons.build, color: color),
                ),
                title: Text(
                  'الأصل: ${t['assetId']}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  '${t['type']} • ${t['status']} • ${t['time']}',
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
                trailing: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 4.h,
                  ),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    p,
                    style: GoogleFonts.cairo(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 10.sp,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _showMaintenanceRequestDialog(context);
            },
            icon: const Icon(Icons.add),
            label: Text('طلب جديد', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAssetsOverviewDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('نظرة عامة على الأصول', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 600.w,
          height: 480.h,
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.inventory_2),
                      title: Text(
                        'الأصناف',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'اضغط لعرض تفاصيل كل صنف',
                        style: GoogleFonts.cairo(fontSize: 12.sp),
                      ),
                    ),
                    ..._assetCategories.map((c) {
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: (c['color'] as Color).withOpacity(
                            0.15,
                          ),
                          child: Icon(
                            Icons.category,
                            color: c['color'] as Color,
                          ),
                        ),
                        title: Text(
                          c['name'] as String,
                          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          'الكمية: ${c['qty']} ${c['unit']} • ${c['status']}',
                          style: GoogleFonts.cairo(fontSize: 12.sp),
                        ),
                        onTap: () => _showAssetCategoryDialog(context, c),
                      );
                    }),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.history),
                      title: Text(
                        'سجل النشاط',
                        style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        'تتبع العمليات (إضافة/نقل/جرد/محاضر)',
                        style: GoogleFonts.cairo(fontSize: 12.sp),
                      ),
                      onTap: () => _showActivityLogDialog(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showActivityLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سجل النشاط', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 560.w,
          height: 460.h,
          child: ListView.separated(
            itemCount: _activityLog.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final e = _activityLog[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: (e['color'] as Color).withOpacity(0.15),
                  child: Icon(
                    e['icon'] as IconData,
                    color: e['color'] as Color,
                  ),
                ),
                title: Text(
                  e['title'] as String,
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  e['time'] as String,
                  style: GoogleFonts.cairo(fontSize: 12.sp),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showValueBreakdownDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحليل قيمة الأصول', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 560.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.attach_money, color: Colors.green),
                title: Text(
                  'القيمة الإجمالية (مليون)',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '$_assetsValue',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              ..._assetCategories.map((c) {
                final qty = c['qty'] as int;
                final ratio = _totalAssets == 0
                    ? 0.0
                    : (qty / _totalAssets).clamp(0.0, 1.0);
                final color = c['color'] as Color;
                return Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              c['name'] as String,
                              style: GoogleFonts.cairo(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.sp,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${(ratio * 100).toStringAsFixed(1)}%',
                            style: GoogleFonts.cairo(color: color),
                          ),
                        ],
                      ),
                      SizedBox(height: 6.h),
                      LinearProgressIndicator(
                        value: ratio,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: AlwaysStoppedAnimation(color),
                        minHeight: 6.h,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showUtilizationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('معدل استخدام الأصول', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 520.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.pie_chart, color: Colors.purple),
                title: Text(
                  'المعدل الحالي',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                trailing: Text(
                  '$_utilizationRate%',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
              ),
              SizedBox(height: 12.h),
              LinearProgressIndicator(
                value: (_utilizationRate / 100).clamp(0.0, 1.0),
                backgroundColor: Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation(Colors.purple),
                minHeight: 8.h,
                borderRadius: BorderRadius.circular(6.r),
              ),
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _utilizationRate = (_utilizationRate + 0.5).clamp(
                            0,
                            100,
                          );
                          if (_enableAuditTrail) {
                            _activityLog.insert(0, {
                              'title':
                                  'تم تحديث معدل الاستخدام إلى $_utilizationRate%',
                              'time': 'الآن',
                              'icon': Icons.pie_chart,
                              'color': Colors.purple,
                            });
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Text('تحسين', style: GoogleFonts.cairo()),
                    ),
                  ),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        setState(() {
                          _utilizationRate = (_utilizationRate - 0.5).clamp(
                            0,
                            100,
                          );
                          if (_enableAuditTrail) {
                            _activityLog.insert(0, {
                              'title':
                                  'تم تحديث معدل الاستخدام إلى $_utilizationRate%',
                              'time': 'الآن',
                              'icon': Icons.pie_chart,
                              'color': Colors.purple,
                            });
                          }
                        });
                        Navigator.pop(context);
                      },
                      child: Text('خفض', style: GoogleFonts.cairo()),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

// --- 7. Permissions & Roles Dashboard ---

class PermissionsDashboard extends StatefulWidget {
  const PermissionsDashboard({super.key});

  @override
  State<PermissionsDashboard> createState() => _PermissionsDashboardState();
}

class _PermissionsDashboardState extends State<PermissionsDashboard> {
  @override
  Widget build(BuildContext context) {
    return SpecializedDashboardScaffold(
      title: 'إدارة التكليفات والصلاحيات',
      themeColor: Colors.indigo.shade900,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildSmartCommandCenter(),
              SizedBox(height: 24.h),
              _buildQuickAssignmentGrid(context),
              SizedBox(height: 24.h),
              _buildActiveAssignments(),
              SizedBox(height: 24.h),
              _buildPermissionsAudit(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmartCommandCenter() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade900, Colors.indigo.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'مركز القيادة الذكي',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    'توزيع المهام والصلاحيات بناءً على الكفاءة',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome,
                      color: Colors.amberAccent,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'تحليل AI نشط',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Consumer(
            builder: (context, ref, _) {
              final user = ref.watch(authStateProvider).value;
              final schoolId = (user?.schoolId ?? '').trim();
              final staff = ref.watch(staffProvider).value ?? const <User>[];

              if (schoolId.isEmpty) {
                return Row(
                  children: [
                    _buildStatCard(
                      'التكليفات النشطة',
                      '0',
                      Icons.assignment,
                      Colors.blue,
                    ),
                    SizedBox(width: 12.w),
                    _buildStatCard(
                      'معدل الإنجاز',
                      '0%',
                      Icons.check_circle_outline,
                      Colors.green,
                    ),
                    SizedBox(width: 12.w),
                    _buildStatCard(
                      'عبء العمل',
                      '—',
                      Icons.balance,
                      Colors.orange,
                    ),
                    SizedBox(width: 12.w),
                    _buildStatCard(
                      'مؤشر الأمان',
                      '—',
                      Icons.security,
                      Colors.purple,
                    ),
                  ],
                );
              }

              return StreamBuilder<List<StaffAssignment>>(
                stream: StaffAssignmentService().getAssignmentsBySchool(
                  schoolId,
                ),
                builder: (context, snapshot) {
                  final assignments =
                      snapshot.data ?? const <StaffAssignment>[];
                  final activeCount = assignments.length;
                  final completionRate = 0;
                  final ratio = staff.isEmpty
                      ? 0
                      : (activeCount / staff.length);
                  final workload = ratio == 0
                      ? '—'
                      : (ratio <= 1.2
                            ? 'متوازن'
                            : (ratio <= 2.0 ? 'مرتفع' : 'عال'));

                  return Row(
                    children: [
                      _buildStatCard(
                        'التكليفات النشطة',
                        '$activeCount',
                        Icons.assignment,
                        Colors.blue,
                      ),
                      SizedBox(width: 12.w),
                      _buildStatCard(
                        'معدل الإنجاز',
                        '$completionRate%',
                        Icons.check_circle_outline,
                        Colors.green,
                      ),
                      SizedBox(width: 12.w),
                      _buildStatCard(
                        'عبء العمل',
                        workload,
                        Icons.balance,
                        Colors.orange,
                      ),
                      SizedBox(width: 12.w),
                      _buildStatCard(
                        'مؤشر الأمان',
                        '—',
                        Icons.security,
                        Colors.purple,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAssignmentGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الإسناد السريع',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            color: Colors.indigo.shade900,
          ),
        ),
        SizedBox(height: 16.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 4 : 8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.9,
              children: [
                _buildActionCard(
                  'تكليف جديد',
                  Icons.person_add,
                  Colors.blue,
                  () => _showNewAssignmentDialog(context),
                ),
                _buildActionCard(
                  'منصب إداري',
                  Icons.admin_panel_settings,
                  Colors.purple,
                  () => _showRoleAssignmentDialog(context),
                ),
                _buildActionCard(
                  'لجنة مدرسية',
                  Icons.groups,
                  Colors.orange,
                  () => _showCommitteeDialog(context),
                ),
                _buildActionCard(
                  'صلاحية مؤقتة',
                  Icons.timer,
                  Colors.teal,
                  () => _showTemporaryPermissionDialog(context),
                ),
                _buildActionCard(
                  'تقييم الأداء',
                  Icons.assessment,
                  Colors.indigo,
                  () => _showPerformanceDialog(context),
                ),
                _buildActionCard(
                  'الهيكل التنظيمي',
                  Icons.account_tree,
                  Colors.brown,
                  () => _showOrgStructureDialog(context),
                ),
                _buildActionCard(
                  'سجل الصلاحيات',
                  Icons.history_edu,
                  Colors.red,
                  () => _showPermissionsLogDialog(context),
                ),
                _buildActionCard(
                  'الإعدادات',
                  Icons.settings,
                  Colors.grey,
                  () => _showSettingsDialog(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveAssignments() {
    return Consumer(
      builder: (context, ref, _) {
        final user = ref.watch(authStateProvider).value;
        final schoolId = (user?.schoolId ?? '').trim();

        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24.r),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'التكليفات الإدارية النشطة',
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  TextButton(
                    onPressed: schoolId.isEmpty
                        ? null
                        : () => context.push(
                            '/staff-assignments',
                            extra: schoolId,
                          ),
                    child: Text('عرض الكل', style: GoogleFonts.cairo()),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (schoolId.isEmpty)
                Text(
                  'لا توجد مدرسة مرتبطة بالحساب.',
                  style: GoogleFonts.cairo(color: Colors.grey),
                )
              else
                StreamBuilder<List<StaffAssignment>>(
                  stream: StaffAssignmentService().getAssignmentsBySchool(
                    schoolId,
                  ),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data ?? const <StaffAssignment>[];
                    if (items.isEmpty) {
                      return Text(
                        'لا توجد تكليفات حالياً',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      );
                    }
                    final visible = items.take(3).toList();
                    return Column(
                      children: visible
                          .map(
                            (a) => _buildAssignmentItem(
                              a.assignmentTitle,
                              a.assignedUserName,
                              'مستمر',
                              Colors.green,
                            ),
                          )
                          .toList(),
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAssignmentItem(
    String task,
    String assignee,
    String status,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.1),
              child: Text(
                assignee[0],
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                  Text(
                    assignee,
                    style: GoogleFonts.cairo(
                      fontSize: 11.sp,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                status,
                style: GoogleFonts.cairo(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionsAudit() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(24.r),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.verified_user, color: Colors.indigo.shade800),
              SizedBox(width: 8.w),
              Text(
                'تدقيق الصلاحيات الآلي',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 15.sp,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'لا توجد بيانات تدقيق للصلاحيات حالياً.',
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              color: Colors.indigo.shade800,
            ),
          ),
        ],
      ),
    );
  }

  void _showNewAssignmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final user = ref.watch(authStateProvider).value;
          final schoolId = (user?.schoolId ?? '').trim();
          final staff = ref.watch(staffProvider).value ?? const <User>[];

          String? selectedTaskType;
          User? selectedStaff = staff.isNotEmpty ? staff.first : null;
          final otherTaskController = TextEditingController();
          final descriptionController = TextEditingController();

          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: Text('إسناد تكليف جديد', style: GoogleFonts.cairo()),
              content: SizedBox(
                width: 520.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedTaskType,
                      decoration: const InputDecoration(
                        labelText: 'نوع المهمة / التكليف',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const [
                                'الإشراف الصحي',
                                'ريادة النشاط',
                                'الإرشاد الطلابي',
                                'مراقبة الدخول',
                                'مسؤول الأمن والسلامة',
                                'وكيل مرحلة',
                                'سفير الثقافة المؤسسية',
                                'أخرى',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (value) =>
                          setStateDialog(() => selectedTaskType = value),
                    ),
                    if (selectedTaskType == 'أخرى') ...[
                      SizedBox(height: 12.h),
                      TextField(
                        controller: otherTaskController,
                        decoration: const InputDecoration(
                          labelText: 'اكتب اسم التكليف',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                    SizedBox(height: 12.h),
                    if (staff.isEmpty)
                      Text(
                        'لا يوجد موظفين لاختيارهم. أضف موظفين أولاً من قسم الموظفين.',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<User>(
                        value: selectedStaff,
                        decoration: const InputDecoration(
                          labelText: 'الموظف المكلف',
                          border: OutlineInputBorder(),
                        ),
                        items: staff
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.name),
                              ),
                            )
                            .toList(),
                        onChanged: (u) =>
                            setStateDialog(() => selectedStaff = u),
                      ),
                    SizedBox(height: 12.h),
                    TextField(
                      controller: descriptionController,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'تفاصيل المهمة (اختياري)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
                ElevatedButton(
                  onPressed: schoolId.isEmpty || selectedStaff == null
                      ? null
                      : () async {
                          final task = (selectedTaskType == null)
                              ? ''
                              : (selectedTaskType == 'أخرى'
                                    ? otherTaskController.text.trim()
                                    : selectedTaskType!.trim());
                          if (task.isEmpty) return;

                          await StaffAssignmentService().createAssignment(
                            schoolId: schoolId,
                            assignedUserId: selectedStaff!.id,
                            assignedUserName: selectedStaff!.name,
                            assignedUserRole: selectedStaff!.role.name,
                            assignmentTitle: task,
                            assignmentType: task,
                            description:
                                descriptionController.text.trim().isEmpty
                                ? null
                                : descriptionController.text.trim(),
                            createdBy: user!.id,
                            createdByName: user.name,
                          );

                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('تم إسناد التكليف بنجاح'),
                              ),
                            );
                          }
                        },
                  child: Text('إسناد التكليف', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showRoleAssignmentDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final user = ref.watch(authStateProvider).value;
          final schoolId = (user?.schoolId ?? '').trim();
          final staff = ref.watch(staffProvider).value ?? const <User>[];
          var selectedRole = 'وكيل شؤون طلاب';
          User? selectedStaff = staff.isNotEmpty ? staff.first : null;

          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: Text('تعيين منصب إداري', style: GoogleFonts.cairo()),
              content: SizedBox(
                width: 420.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<String>(
                      value: selectedRole,
                      decoration: const InputDecoration(
                        labelText: 'المنصب',
                        border: OutlineInputBorder(),
                      ),
                      items:
                          const [
                                'وكيل شؤون طلاب',
                                'وكيل شؤون تعليمية',
                                'رائد نشاط',
                                'موجه طلابي',
                              ]
                              .map(
                                (e) =>
                                    DropdownMenuItem(value: e, child: Text(e)),
                              )
                              .toList(),
                      onChanged: (v) {
                        if (v == null) return;
                        setStateDialog(() => selectedRole = v);
                      },
                    ),
                    SizedBox(height: 12.h),
                    if (staff.isEmpty)
                      Text(
                        'لا يوجد موظفين لاختيارهم.',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<User>(
                        value: selectedStaff,
                        decoration: const InputDecoration(
                          labelText: 'الموظف',
                          border: OutlineInputBorder(),
                        ),
                        items: staff
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setStateDialog(() => selectedStaff = v),
                      ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إلغاء', style: GoogleFonts.cairo()),
                ),
                ElevatedButton(
                  onPressed: schoolId.isEmpty || selectedStaff == null
                      ? null
                      : () async {
                          await StaffAssignmentService().createAssignment(
                            schoolId: schoolId,
                            assignedUserId: selectedStaff!.id,
                            assignedUserName: selectedStaff!.name,
                            assignedUserRole: selectedStaff!.role.name,
                            assignmentTitle: selectedRole,
                            assignmentType: 'RoleAssignment',
                            createdBy: user!.id,
                            createdByName: user.name,
                          );
                          if (context.mounted) {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('تم حفظ التكليف')),
                            );
                          }
                        },
                  child: Text('حفظ', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showCommitteeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تشكيل لجنة مدرسية', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(labelText: 'اسم اللجنة'),
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'رئيس اللجنة'),
                items: ['المدير', 'الوكيل', 'رائد النشاط']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم تشكيل اللجنة بنجاح')),
              );
            },
            child: Text('إنشاء', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showTemporaryPermissionDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('منح صلاحية مؤقتة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع الصلاحية'),
                items: ['دخول النظام', 'تعديل درجات', 'مراسلة أولياء الأمور']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              TextField(
                decoration: const InputDecoration(labelText: 'المدة (بالأيام)'),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم منح الصلاحية')));
            },
            child: Text('منح', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showPerformanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final staff = ref.watch(staffProvider).value ?? const <User>[];
          User? selected = staff.isNotEmpty ? staff.first : null;
          return StatefulBuilder(
            builder: (context, setStateDialog) => AlertDialog(
              title: Text('تقييم الأداء الوظيفي', style: GoogleFonts.cairo()),
              content: SizedBox(
                width: 420.w,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (staff.isEmpty)
                      Text(
                        'لا يوجد موظفين.',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      )
                    else
                      DropdownButtonFormField<User>(
                        value: selected,
                        decoration: const InputDecoration(
                          labelText: 'الموظف',
                          border: OutlineInputBorder(),
                        ),
                        items: staff
                            .map(
                              (u) => DropdownMenuItem(
                                value: u,
                                child: Text(u.name),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setStateDialog(() => selected = v),
                      ),
                    SizedBox(height: 12.h),
                    Text(
                      'لا تتوفر بيانات تقييم الأداء حالياً.',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('إغلاق', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showOrgStructureDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('الهيكل التنظيمي', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 600.w,
          height: 400.h,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.account_tree, size: 60.sp, color: Colors.indigo),
                SizedBox(height: 16.h),
                Text(
                  'الهيكل التنظيمي للمدرسة 1447هـ',
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'مدير المدرسة -> الوكلاء -> المعلمون / الإداريون',
                  style: GoogleFonts.cairo(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showPermissionsLogDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('سجل الصلاحيات', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 500.w,
          height: 300.h,
          child: ListView(
            children: [
              ListTile(
                leading: Icon(Icons.history, color: Colors.grey),
                title: Text(
                  'تم منح صلاحية "تعديل" لـ أ. محمد',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'قبل 2 ساعة',
                  style: GoogleFonts.cairo(fontSize: 10.sp),
                ),
              ),
              ListTile(
                leading: Icon(Icons.history, color: Colors.grey),
                title: Text(
                  'تم سحب صلاحية "حذف" من أ. خالد',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'أمس',
                  style: GoogleFonts.cairo(fontSize: 10.sp),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعدادات الصلاحيات', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  'تفعيل الصلاحيات التلقائية',
                  style: GoogleFonts.cairo(),
                ),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: Text(
                  'إشعار المدير عند التغيير',
                  style: GoogleFonts.cairo(),
                ),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم حفظ الإعدادات')));
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }
}

// --- 8. Meetings & Committees Dashboard ---

class MeetingsDashboard extends ConsumerWidget {
  const MeetingsDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    return SpecializedDashboardScaffold(
      title: 'سجل الاجتماعات واللجان',
      themeColor: Colors.indigo.shade800,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: FutureBuilder<_MeetingsComputed>(
          future: _MeetingsComputed.load(schoolId),
          builder: (context, snap) {
            final data = snap.data ?? _MeetingsComputed.empty();
            return Column(
              children: [
                _buildMeetingCalendarStrip(data.calendarDays),
                SizedBox(height: 24.h),
                _buildActiveCommittees(data.committees),
                SizedBox(height: 24.h),
                _buildUpcomingMeetingsList(data.meetings),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMeetingCalendarStrip(List<DateTime> days) {
    final monthNames = const [
      'يناير',
      'فبراير',
      'مارس',
      'أبريل',
      'مايو',
      'يونيو',
      'يوليو',
      'أغسطس',
      'سبتمبر',
      'أكتوبر',
      'نوفمبر',
      'ديسمبر',
    ];
    return Container(
      height: 90.h,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final dt = days[index];
          final now = DateTime.now();
          final isToday =
              dt.year == now.year && dt.month == now.month && dt.day == now.day;
          final monthLabel =
              monthNames[(dt.month - 1).clamp(0, monthNames.length - 1)];
          return Container(
            width: 60.w,
            margin: EdgeInsets.only(left: 12.w),
            decoration: BoxDecoration(
              color: isToday ? Colors.indigo.shade800 : Colors.white,
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                if (!isToday) BoxShadow(color: Colors.black12, blurRadius: 5),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  monthLabel,
                  style: GoogleFonts.cairo(
                    color: isToday ? Colors.white70 : Colors.grey,
                    fontSize: 10.sp,
                  ),
                ),
                Text(
                  '${dt.day}',
                  style: GoogleFonts.cairo(
                    color: isToday ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveCommittees(List<_CommitteeItem> committees) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'اللجان المدرسية المفعلة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
          ),
        ),
        SizedBox(height: 12.h),
        if (committees.isEmpty)
          Container(
            width: double.infinity,
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20.r),
              border: Border.all(color: Colors.black12),
            ),
            child: Text(
              'لا توجد لجان مفعلة.',
              style: GoogleFonts.cairo(color: Colors.grey.shade700),
              textAlign: TextAlign.right,
            ),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in committees)
                  _buildCommitteeCard(c.name, c.icon, c.color),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildCommitteeCard(String name, IconData icon, Color color) {
    return Container(
      width: 140.w,
      margin: EdgeInsets.only(left: 12.w),
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 30.sp),
          SizedBox(height: 12.h),
          Text(
            name,
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 13.sp,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUpcomingMeetingsList(List<_MeetingItem> meetings) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الاجتماعات القادمة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 15.sp,
            ),
          ),
          SizedBox(height: 16.h),
          if (meetings.isEmpty)
            Text(
              'لا توجد اجتماعات قادمة.',
              style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
              textAlign: TextAlign.right,
            )
          else
            for (final m in meetings)
              _buildMeetingItem(m.title, m.time, m.location),
        ],
      ),
    );
  }

  Widget _buildMeetingItem(String title, String time, String location) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.event, color: Colors.indigo),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 13.sp,
                  ),
                ),
                Text(
                  '$time | $location',
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 12.sp, color: Colors.grey),
        ],
      ),
    );
  }
}

class _CommitteeItem {
  final String name;
  final IconData icon;
  final Color color;
  const _CommitteeItem({
    required this.name,
    required this.icon,
    required this.color,
  });
}

class _MeetingItem {
  final String title;
  final String time;
  final String location;
  const _MeetingItem({
    required this.title,
    required this.time,
    required this.location,
  });
}

class _MeetingsComputed {
  final List<DateTime> calendarDays;
  final List<_CommitteeItem> committees;
  final List<_MeetingItem> meetings;

  const _MeetingsComputed({
    required this.calendarDays,
    required this.committees,
    required this.meetings,
  });

  factory _MeetingsComputed.empty() {
    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );
    return _MeetingsComputed(
      calendarDays: days,
      committees: const [],
      meetings: const [],
    );
  }

  static IconData _iconForCommittee(String name) {
    final s = name.toLowerCase();
    if (s.contains('توجيه')) return Icons.psychology;
    if (s.contains('تحصيل')) return Icons.auto_graph;
    if (s.contains('انضباط')) return Icons.gavel;
    if (s.contains('سلام') || s.contains('أمن') || s.contains('امن'))
      return Icons.security;
    return Icons.groups;
  }

  static Color _colorForCommittee(String name) {
    final s = name.toLowerCase();
    if (s.contains('توجيه')) return Colors.purple;
    if (s.contains('تحصيل')) return Colors.green;
    if (s.contains('انضباط')) return Colors.red;
    if (s.contains('سلام') || s.contains('أمن') || s.contains('امن'))
      return Colors.orange;
    return Colors.indigo;
  }

  static String _relativeLabel(DateTime dt, String? startTime) {
    final now = DateTime.now();
    final d0 = DateTime(now.year, now.month, now.day);
    final d1 = DateTime(dt.year, dt.month, dt.day);
    final diff = d1.difference(d0).inDays;
    final time = (startTime ?? '').trim();
    if (diff == 0) return time.isEmpty ? 'اليوم' : 'اليوم، $time';
    if (diff == 1) return time.isEmpty ? 'غداً' : 'غداً، $time';
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return time.isEmpty ? '${dt.year}-$m-$d' : '${dt.year}-$m-$d، $time';
  }

  static Future<_MeetingsComputed> load(String schoolId) async {
    final sid = schoolId.trim();
    if (sid.isEmpty) return _MeetingsComputed.empty();
    final fs = FirebaseFirestore.instance;

    final now = DateTime.now();
    final days = List<DateTime>.generate(
      7,
      (i) => DateTime(now.year, now.month, now.day).add(Duration(days: i)),
    );

    final committees = <_CommitteeItem>[];
    try {
      final snap = await fs
          .collection('Schools')
          .doc(sid)
          .collection('Committees')
          .limit(10)
          .get();
      for (final d in snap.docs) {
        final m = d.data();
        final name = (m['name'] ?? m['title'] ?? '').toString().trim();
        if (name.isEmpty) continue;
        final isActive =
            (m['active'] == true) || (m['status']?.toString() == 'active');
        if (!isActive) continue;
        committees.add(
          _CommitteeItem(
            name: name,
            icon: _iconForCommittee(name),
            color: _colorForCommittee(name),
          ),
        );
      }
    } catch (_) {}

    final meetings = <_MeetingItem>[];
    try {
      final start = DateTime(now.year, now.month, now.day);
      final snap = await fs
          .collection('Schools')
          .doc(sid)
          .collection('Meetings')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .orderBy('date')
          .limit(6)
          .get();
      for (final d in snap.docs) {
        final m = d.data();
        final title = (m['title'] ?? m['name'] ?? '').toString().trim();
        final ts = m['date'];
        final date = ts is Timestamp ? ts.toDate() : null;
        if (title.isEmpty || date == null) continue;
        final startTime = (m['startTime'] ?? '').toString();
        final location = (m['location'] ?? m['room'] ?? 'غير محدد')
            .toString()
            .trim();
        meetings.add(
          _MeetingItem(
            title: title,
            time: _relativeLabel(date, startTime),
            location: location.isEmpty ? 'غير محدد' : location,
          ),
        );
      }
    } catch (_) {}

    return _MeetingsComputed(
      calendarDays: days,
      committees: committees,
      meetings: meetings,
    );
  }
}

// --- 9. Maintenance & Safety Dashboard ---

class MaintenanceDashboard extends ConsumerStatefulWidget {
  const MaintenanceDashboard({super.key});

  @override
  ConsumerState<MaintenanceDashboard> createState() =>
      _MaintenanceDashboardState();
}

class _MaintenanceDashboardState extends ConsumerState<MaintenanceDashboard> {
  int _activeTickets = 0;
  int _completedToday = 0;
  double _readiness = 0;
  String _mttr = '0 دقيقة';
  List<Map<String, dynamic>> _liveTickets = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final firestore = FirebaseFirestore.instance;
    final col = firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('MaintenanceTickets');

    var active = 0;
    var completedToday = 0;
    var readiness = 0.0;
    var mttrMinutes = 0.0;
    var mttrCount = 0;
    List<Map<String, dynamic>> feed = [];

    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);

    try {
      final all = await col.get();
      for (final d in all.docs) {
        final data = d.data();
        final status = (data['status'] ?? '').toString();
        final createdAt = data['createdAt'];
        final closedAt = data['closedAt'];
        DateTime? toDate(dynamic v) {
          if (v is Timestamp) return v.toDate();
          return DateTime.tryParse(v?.toString() ?? '');
        }

        final created = toDate(createdAt);
        final closed = toDate(closedAt);

        final isClosed = status == 'completed' || status == 'closed';
        if (!isClosed) active++;
        if (isClosed && closed != null && closed.isAfter(start)) {
          completedToday++;
        }
        if (isClosed && created != null && closed != null) {
          mttrMinutes += closed.difference(created).inMinutes.toDouble();
          mttrCount++;
        }
      }
      if (mttrCount > 0) mttrMinutes = mttrMinutes / mttrCount;
    } catch (_) {}

    try {
      final kpi = await firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Kpis')
          .doc('Maintenance')
          .get();
      final v = kpi.data()?['readiness'];
      readiness = (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
    } catch (_) {}

    if (readiness == 0) {
      final total = active + completedToday;
      readiness = total == 0 ? 0 : ((completedToday / total) * 100);
    }

    try {
      final snap = await col
          .orderBy('createdAt', descending: true)
          .limit(3)
          .get();
      feed = snap.docs.map((d) {
        final data = d.data();
        return {
          'id': d.id,
          'title': (data['title'] ?? data['subject'] ?? '').toString(),
          'priority': (data['priority'] ?? '').toString(),
          'status': (data['status'] ?? '').toString(),
        };
      }).toList();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _activeTickets = active;
      _completedToday = completedToday;
      _readiness = readiness;
      _mttr = '${mttrMinutes.isNaN ? 0 : mttrMinutes.round()} دقيقة';
      _liveTickets = feed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SpecializedDashboardScaffold(
      title: 'مركز العمليات والصيانة',
      themeColor: Colors.brown.shade800,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: SingleChildScrollView(
          child: Column(
            children: [
              _buildMaintenanceControlRoom(),
              SizedBox(height: 24.h),
              _buildQuickActionsGrid(context),
              SizedBox(height: 24.h),
              _buildLiveTicketsFeed(),
              SizedBox(height: 24.h),
              _buildSafetyChecklist(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceControlRoom() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.brown.shade900, Colors.brown.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(
            color: Colors.brown.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'غرفة التحكم المركزية',
                    style: GoogleFonts.cairo(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                    ),
                  ),
                  Text(
                    'مراقبة كفاءة التشغيل والصيانة (CAFM)',
                    style: GoogleFonts.cairo(
                      color: Colors.white70,
                      fontSize: 12.sp,
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20.r),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.health_and_safety,
                      color: Colors.greenAccent,
                      size: 14.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'المرافق آمنة',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 10.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 24.h),
          Row(
            children: [
              _buildStatCard(
                'البلاغات النشطة',
                '$_activeTickets',
                Icons.confirmation_number,
                Colors.orange,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'تم الإنجاز اليوم',
                '$_completedToday',
                Icons.check_circle,
                Colors.green,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'جاهزية المبنى',
                '$_readiness%',
                Icons.domain_verification,
                Colors.blue,
              ),
              SizedBox(width: 12.w),
              _buildStatCard(
                'متوسط زمن الإصلاح',
                _mttr,
                Icons.timer,
                Colors.purple,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24.sp),
            SizedBox(height: 8.h),
            Text(
              value,
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18.sp,
              ),
            ),
            Text(
              label,
              style: GoogleFonts.cairo(color: Colors.white70, fontSize: 10.sp),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionsGrid(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'الخدمات والإجراءات السريعة',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            fontSize: 16.sp,
            color: Colors.brown.shade800,
          ),
        ),
        SizedBox(height: 16.h),
        LayoutBuilder(
          builder: (context, constraints) {
            final isMobile = constraints.maxWidth < 600;
            return GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: isMobile ? 4 : 8,
              crossAxisSpacing: 12.w,
              mainAxisSpacing: 12.h,
              childAspectRatio: 0.9,
              children: [
                _buildActionCard(
                  'بلاغ جديد',
                  Icons.add_alert,
                  Colors.red,
                  () => _showCreateTicketDialog(context),
                ),
                _buildActionCard(
                  'تعيين فني',
                  Icons.person_add_alt,
                  Colors.blue,
                  () => _showAssignTechnicianDialog(context),
                ),
                _buildActionCard(
                  'جدولة صيانة',
                  Icons.calendar_month,
                  Colors.orange,
                  () => _showScheduleMaintenanceDialog(context),
                ),
                _buildActionCard(
                  'إغلاق تذكرة',
                  Icons.task_alt,
                  Colors.green,
                  () => _showCloseTicketDialog(context),
                ),
                _buildActionCard(
                  'قطع الغيار',
                  Icons.settings_input_component,
                  Colors.purple,
                  () => _showSparePartsDialog(context),
                ),
                _buildActionCard(
                  'عقود الصيانة',
                  Icons.description,
                  Colors.teal,
                  () => _showContractsDialog(context),
                ),
                _buildActionCard(
                  'التقارير',
                  Icons.analytics,
                  Colors.indigo,
                  () => _showMaintenanceReportsDialog(context),
                ),
                _buildActionCard(
                  'الإعدادات',
                  Icons.settings,
                  Colors.grey,
                  () => _showMaintenanceSettingsDialog(context),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildActionCard(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 8.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveTicketsFeed() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'سجل البلاغات الحي',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 16.sp,
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Text(
                  'Live Feed',
                  style: GoogleFonts.cairo(
                    color: Colors.red,
                    fontSize: 10.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          if (_liveTickets.isEmpty)
            Text(
              'لا توجد بيانات',
              style: GoogleFonts.cairo(color: Colors.grey.shade600),
            )
          else
            ..._liveTickets.map((t) {
              final status = (t['status'] ?? '').toString();
              final priority = (t['priority'] ?? '').toString();
              Color color;
              if (status == 'completed' || status == 'closed') {
                color = Colors.green;
              } else if (priority == 'urgent' || priority == 'high') {
                color = Colors.orange;
              } else {
                color = Colors.blue;
              }
              return _buildTicketItem(
                (t['id'] ?? '').toString(),
                (t['title'] ?? '').toString(),
                priority.isEmpty ? '—' : priority,
                status.isEmpty ? '—' : status,
                color,
              );
            }),
        ],
      ),
    );
  }

  Widget _buildTicketItem(
    String id,
    String title,
    String priority,
    String status,
    Color color,
  ) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Text(
                id,
                style: GoogleFonts.cairo(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.cairo(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.sp,
                    ),
                  ),
                  Row(
                    children: [
                      Icon(Icons.flag, size: 12.sp, color: Colors.grey),
                      SizedBox(width: 4.w),
                      Text(
                        priority,
                        style: GoogleFonts.cairo(
                          fontSize: 11.sp,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20.r),
              ),
              child: Text(
                status,
                style: GoogleFonts.cairo(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11.sp,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateTicketDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إنشاء بلاغ صيانة جديد', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'الموقع'),
                items: ['المبنى الرئيسي', 'الصالة الرياضية', 'المعامل']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع العطل'),
                items: ['كهرباء', 'سباكة', 'تكييف', 'نظافة']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'الأولوية'),
                items: ['عادية', 'متوسطة', 'حرجة']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              TextField(
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'وصف المشكلة',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إنشاء البلاغ بنجاح')),
              );
            },
            child: Text('إرسال البلاغ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAssignTechnicianDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تعيين فني لمهمة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'اختر البلاغ'),
                items: ['T-1024 (تكييف)', 'T-1023 (سباكة)']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'اختر الفني'),
                items:
                    [
                          'محمد حسن (كهربائي)',
                          'علي سعيد (سباك)',
                          'شركة الصيانة الخارجية',
                        ]
                        .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                        .toList(),
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('تأكيد التعيين', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showScheduleMaintenanceDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('جدولة صيانة دورية', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'نوع الصيانة'),
                items: ['صيانة المصاعد', 'فحص أجهزة الإنذار', 'تنظيف الخزانات']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              TextField(
                decoration: const InputDecoration(
                  labelText: 'تاريخ الاستحقاق',
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                onTap: () async {
                  // Show Date Picker
                },
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('جدولة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showCloseTicketDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إغلاق تذكرة صيانة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'رقم التذكرة'),
                items: ['T-1022', 'T-1020']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (_) {},
              ),
              SizedBox(height: 12.h),
              TextField(
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'ملاحظات الإغلاق',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق وأرشفة', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showSparePartsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إدارة قطع الغيار', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(
                  Icons.settings_input_component,
                  color: Colors.purple,
                ),
                title: Text('مصابيح LED', style: GoogleFonts.cairo()),
                subtitle: Text(
                  'الكمية المتوفرة: 50',
                  style: GoogleFonts.cairo(),
                ),
                trailing: TextButton(
                  onPressed: () {},
                  child: Text('طلب شراء', style: GoogleFonts.cairo()),
                ),
              ),
              ListTile(
                leading: Icon(Icons.ac_unit, color: Colors.blue),
                title: Text('فلاتر تكييف', style: GoogleFonts.cairo()),
                subtitle: Text(
                  'الكمية المتوفرة: 12',
                  style: GoogleFonts.cairo(),
                ),
                trailing: TextButton(
                  onPressed: () {},
                  child: Text('طلب شراء', style: GoogleFonts.cairo()),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showContractsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('عقود الصيانة الخارجية', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.business, color: Colors.teal),
                title: Text(
                  'شركة الصيانة المتكاملة',
                  style: GoogleFonts.cairo(),
                ),
                subtitle: Text(
                  'صيانة المصاعد - ساري حتى 2025',
                  style: GoogleFonts.cairo(),
                ),
                trailing: Icon(Icons.check_circle, color: Colors.green),
              ),
              ListTile(
                leading: Icon(Icons.security, color: Colors.orange),
                title: Text('مؤسسة الأمن والسلامة', style: GoogleFonts.cairo()),
                subtitle: Text(
                  'أجهزة الإنذار - ينتهي قريباً',
                  style: GoogleFonts.cairo(),
                ),
                trailing: Icon(Icons.warning, color: Colors.orange),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text('تجديد العقود', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceReportsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تقارير الأداء والصيانة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.bar_chart, color: Colors.indigo),
                title: Text('تقرير الأعطال الشهري', style: GoogleFonts.cairo()),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.pie_chart, color: Colors.indigo),
                title: Text('تحليل تكاليف الصيانة', style: GoogleFonts.cairo()),
                onTap: () {},
              ),
              ListTile(
                leading: Icon(Icons.timer, color: Colors.indigo),
                title: Text(
                  'تقرير سرعة الاستجابة (SLA)',
                  style: GoogleFonts.cairo(),
                ),
                onTap: () {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showMaintenanceSettingsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعدادات نظام الصيانة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 400.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(
                  'الإشعارات التلقائية للفنيين',
                  style: GoogleFonts.cairo(),
                ),
                value: true,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: Text(
                  'الموافقة التلقائية على المواد',
                  style: GoogleFonts.cairo(),
                ),
                value: false,
                onChanged: (_) {},
              ),
              SwitchListTile(
                title: Text(
                  'تنبيهات الصيانة الوقائية',
                  style: GoogleFonts.cairo(),
                ),
                value: true,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  Widget _buildAlertItem(String title, String time) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: Colors.red.shade900,
            ),
          ),
          Text(
            time,
            style: GoogleFonts.cairo(
              fontSize: 11.sp,
              color: Colors.red.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadinessGauges() {
    return Row(
      children: [
        _buildGauge('جاهزية المبنى', 0.95, Colors.green),
        SizedBox(width: 12.w),
        _buildGauge('أجهزة الإطفاء', 0.88, Colors.orange),
      ],
    );
  }

  Widget _buildGauge(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24.r),
        ),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 70.w,
                  height: 70.w,
                  child: CircularProgressIndicator(
                    value: val,
                    strokeWidth: 8,
                    backgroundColor: color.withOpacity(0.1),
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                Text(
                  '%${(val * 100).toInt()}',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Text(
              label,
              style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyChecklist() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'فحص السلامة اليومي',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 15.sp,
            ),
          ),
          SizedBox(height: 16.h),
          _buildCheckItem('مخارج الطوارئ سالكة', true),
          _buildCheckItem('خزانات المياه نظيفة', true),
          _buildCheckItem('مولدات الاحتياط جاهزة', false),
        ],
      ),
    );
  }

  Widget _buildCheckItem(String label, bool done) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        children: [
          Icon(
            done ? Icons.check_circle : Icons.pending,
            color: done ? Colors.green : Colors.orange,
            size: 20.sp,
          ),
          SizedBox(width: 12.w),
          Text(label, style: GoogleFonts.cairo(fontSize: 13.sp)),
        ],
      ),
    );
  }
}

// --- 10. Security & Safety Dashboard ---

class SafetyDashboard extends ConsumerStatefulWidget {
  const SafetyDashboard({super.key});

  @override
  ConsumerState<SafetyDashboard> createState() => _SafetyDashboardState();
}

class _SafetyDashboardState extends ConsumerState<SafetyDashboard> {
  static const _guardStatuses = <String>[
    'متواجد',
    'في جولة',
    'استراحة',
    'غير متواجد',
  ];

  String _nextGuardStatus(String current) {
    final idx = _guardStatuses.indexOf(current);
    if (idx < 0) return _guardStatuses.first;
    return _guardStatuses[(idx + 1) % _guardStatuses.length];
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'متواجد':
        return Colors.green;
      case 'في جولة':
        return Colors.blue;
      case 'استراحة':
        return Colors.orange;
      case 'غير متواجد':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(safetySettingsProvider).value;
    final guards =
        ref.watch(safetyGuardsProvider).value ?? const <SafetyGuard>[];
    return SpecializedDashboardScaffold(
      title: 'نظام الأمن والسلامة الحي',
      themeColor: Colors.red.shade700,
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildSafetyStatusHeader(),
            SizedBox(height: 24.h),
            _buildSecurityGrid(context, settings, guards.length),
            SizedBox(height: 24.h),
            _buildEmergencyProcedures(context, settings),
          ],
        ),
      ),
    );
  }

  Widget _buildSafetyStatusHeader() {
    return Container(
      padding: EdgeInsets.all(24.w),
      decoration: BoxDecoration(
        color: Colors.red.shade900,
        borderRadius: BorderRadius.circular(24.r),
        boxShadow: [
          BoxShadow(color: Colors.red.withOpacity(0.3), blurRadius: 15),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.security, color: Colors.white, size: 50.sp),
          SizedBox(width: 20.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نظام الأمان النشط',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18.sp,
                  ),
                ),
                Text(
                  'المدرسة تحت المراقبة الأمنية الكاملة',
                  style: GoogleFonts.cairo(
                    color: Colors.white70,
                    fontSize: 12.sp,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(10.w),
            decoration: BoxDecoration(
              color: Colors.white24,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.videocam, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityGrid(
    BuildContext context,
    SafetySettings? settings,
    int guardsCount,
  ) {
    final camA = settings?.camerasActive;
    final camT = settings?.camerasTotal;
    final camerasStatus = (camA == null && camT == null)
        ? 'غير مسجل'
        : '${camA ?? 0}/${camT ?? 0}';

    final alarmsStatus = settings?.alarmsReady == null
        ? 'غير مسجل'
        : (settings!.alarmsReady! ? 'جاهز' : 'غير جاهز');

    final evacuationStatus =
        (settings?.meetingPoint.trim().isNotEmpty ?? false) ||
            (settings?.evacuationOfficer.trim().isNotEmpty ?? false)
        ? 'مسجلة'
        : 'غير مسجلة';

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: isMobile ? 2 : 4,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: isMobile ? 1.1 : 1.5,
          children: [
            _buildSecurityCard(
              'كاميرات المراقبة',
              camerasStatus,
              Icons.visibility,
              Colors.blue,
              () => _showCamerasDialog(context),
            ),
            _buildSecurityCard(
              'أنظمة الإنذار',
              alarmsStatus,
              Icons.notifications_active,
              Colors.green,
              () => _showAlarmsDialog(context),
            ),
            _buildSecurityCard(
              'خطة الإخلاء',
              evacuationStatus,
              Icons.exit_to_app,
              Colors.orange,
              () => _showEvacuationPlanDialog(context),
            ),
            _buildSecurityCard(
              'حراس الأمن',
              '$guardsCount مسجلين',
              Icons.person_search,
              Colors.teal,
              () => _showGuardsDialog(context),
            ),
          ],
        );
      },
    );
  }

  Widget _buildSecurityCard(
    String label,
    String status,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20.r),
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: color.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28.sp),
            SizedBox(height: 12.h),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
              textAlign: TextAlign.center,
            ),
            Text(
              status,
              style: GoogleFonts.cairo(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 11.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCamerasDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final settings =
        ref.read(safetySettingsProvider).value ?? SafetySettings.empty();
    final totalController = TextEditingController(
      text: settings.camerasTotal?.toString() ?? '',
    );
    final activeController = TextEditingController(
      text: settings.camerasActive?.toString() ?? '',
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('إعدادات كاميرات المراقبة', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 420.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: totalController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'إجمالي عدد الكاميرات',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 12.h),
              TextField(
                controller: activeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'عدد الكاميرات النشطة',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              final total = int.tryParse(totalController.text.trim());
              final active = int.tryParse(activeController.text.trim());
              await ref
                  .read(safetyRepositoryProvider)
                  .upsertSettings(
                    schoolId,
                    camerasTotal: total,
                    camerasActive: active,
                  );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حفظ إعدادات الكاميرات')),
                );
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showAlarmsDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final settings =
        ref.read(safetySettingsProvider).value ?? SafetySettings.empty();
    var current = settings.alarmsReady ?? false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          title: Text('حالة أنظمة الإنذار', style: GoogleFonts.cairo()),
          content: SizedBox(
            width: 420.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'الحالة الحالية: ${settings.alarmsReady == null ? 'غير مسجل' : (settings.alarmsReady! ? 'جاهز' : 'غير جاهز')}',
                  style: GoogleFonts.cairo(fontSize: 12.sp, color: Colors.grey),
                ),
                SizedBox(height: 12.h),
                SwitchListTile(
                  value: current,
                  onChanged: (v) => setStateDialog(() => current = v),
                  title: Text('النظام جاهز', style: GoogleFonts.cairo()),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('إلغاء', style: GoogleFonts.cairo()),
            ),
            ElevatedButton(
              onPressed: () async {
                await ref
                    .read(safetyRepositoryProvider)
                    .upsertSettings(schoolId, alarmsReady: current);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث حالة الإنذار')),
                  );
                }
              },
              child: Text('حفظ', style: GoogleFonts.cairo()),
            ),
          ],
        ),
      ),
    );
  }

  void _showEvacuationPlanDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final settings =
        ref.read(safetySettingsProvider).value ?? SafetySettings.empty();

    final meetingPoint = settings.meetingPoint.trim().isEmpty
        ? '—'
        : settings.meetingPoint;
    final officer = settings.evacuationOfficer.trim().isEmpty
        ? '—'
        : settings.evacuationOfficer;
    final updatedAt = settings.updatedAt == null
        ? '—'
        : settings.updatedAt!.toIso8601String().split('T').first;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('خطة الإخلاء والطوارئ', style: GoogleFonts.cairo()),
        content: SizedBox(
          width: 520.w,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildProcedureItem(
                'نقطة التجمع الرئيسية: $meetingPoint',
                Icons.place,
                Colors.green,
                () {},
              ),
              _buildProcedureItem(
                'مسؤول الإخلاء: $officer',
                Icons.person,
                Colors.blue,
                () {},
              ),
              _buildProcedureItem(
                'آخر تحديث: $updatedAt',
                Icons.update,
                Colors.orange,
                () {},
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showEditEvacuationPlanDialog(context);
            },
            child: Text('تعديل', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showEditEvacuationPlanDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    final settings =
        ref.read(safetySettingsProvider).value ?? SafetySettings.empty();
    final meetingPointController = TextEditingController(
      text: settings.meetingPoint,
    );
    final officerController = TextEditingController(
      text: settings.evacuationOfficer,
    );

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('تحديث بيانات خطة الإخلاء', style: GoogleFonts.cairo()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: meetingPointController,
              decoration: const InputDecoration(
                labelText: 'نقطة التجمع الرئيسية',
              ),
            ),
            TextField(
              controller: officerController,
              decoration: const InputDecoration(labelText: 'مسؤول الإخلاء'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo()),
          ),
          ElevatedButton(
            onPressed: () async {
              await ref
                  .read(safetyRepositoryProvider)
                  .upsertSettings(
                    schoolId,
                    meetingPoint: meetingPointController.text,
                    evacuationOfficer: officerController.text,
                  );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تحديث الخطة بنجاح')),
                );
              }
            },
            child: Text('حفظ', style: GoogleFonts.cairo()),
          ),
        ],
      ),
    );
  }

  void _showGuardsDialog(BuildContext context) {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    Future<void> showAddDialog(BuildContext context, List<User> staff) async {
      if (staff.isEmpty) return;
      User selected = staff.first;
      final locationController = TextEditingController();

      await showDialog<void>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) => AlertDialog(
            title: Text('إضافة حارس', style: GoogleFonts.cairo()),
            content: SizedBox(
              width: 420.w,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<User>(
                    value: selected,
                    items: staff
                        .map(
                          (u) =>
                              DropdownMenuItem(value: u, child: Text(u.name)),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null) return;
                      setStateDialog(() => selected = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'الموظف',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'الموقع',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('إلغاء', style: GoogleFonts.cairo()),
              ),
              ElevatedButton(
                onPressed: () async {
                  final guardId = DateTime.now().microsecondsSinceEpoch
                      .toString();
                  await ref
                      .read(safetyRepositoryProvider)
                      .upsertGuard(
                        schoolId,
                        guardId: guardId,
                        staffId: selected.id,
                        name: selected.name,
                        location: locationController.text,
                        status: 'متواجد',
                      );
                  if (context.mounted) Navigator.pop(context);
                },
                child: Text('حفظ', style: GoogleFonts.cairo()),
              ),
            ],
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (context) => Consumer(
        builder: (context, ref, _) {
          final guardsAsync = ref.watch(safetyGuardsProvider);
          final staffAsync = ref.watch(staffProvider);
          final guards = guardsAsync.value ?? const <SafetyGuard>[];
          final staff = staffAsync.value ?? const <User>[];

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Container(
              width: 650.w,
              padding: EdgeInsets.all(24.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'جدول المناوبة الأمنية',
                        style: GoogleFonts.cairo(
                          fontSize: 20.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.add, color: Colors.blue),
                            onPressed: staff.isEmpty
                                ? null
                                : () => showAddDialog(context, staff),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(),
                  SizedBox(height: 16.h),
                  if (guardsAsync.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(),
                    )
                  else if (guards.isEmpty)
                    Padding(
                      padding: EdgeInsets.all(12.w),
                      child: Text(
                        'لا يوجد حراس مسجلين حتى الآن.',
                        style: GoogleFonts.cairo(color: Colors.grey),
                      ),
                    )
                  else
                    ...guards.map((g) {
                      final color = _statusColor(g.status);
                      return Row(
                        children: [
                          Expanded(
                            child: _buildGuardItem(
                              g.name,
                              g.location.isEmpty ? '—' : g.location,
                              g.status,
                              color,
                              () async {
                                final next = _nextGuardStatus(g.status);
                                await ref
                                    .read(safetyRepositoryProvider)
                                    .upsertGuard(
                                      schoolId,
                                      guardId: g.id,
                                      staffId: g.staffId,
                                      name: g.name,
                                      location: g.location,
                                      status: next,
                                    );
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              await ref
                                  .read(safetyRepositoryProvider)
                                  .deleteGuard(schoolId, g.id);
                            },
                          ),
                        ],
                      );
                    }).toList(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildGuardItem(
    String name,
    String location,
    String status,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 8.h),
        child: ListTile(
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(Icons.security, color: color),
          ),
          title: Text(
            name,
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(location, style: GoogleFonts.cairo(fontSize: 12.sp)),
          trailing: Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.r),
            ),
            child: Text(
              status,
              style: GoogleFonts.cairo(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 10.sp,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmergencyProcedures(
    BuildContext context,
    SafetySettings? settings,
  ) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'إجراءات الطوارئ العاجلة',
            style: GoogleFonts.cairo(
              fontWeight: FontWeight.bold,
              fontSize: 15.sp,
            ),
          ),
          SizedBox(height: 16.h),
          _buildProcedureItem(
            'تفعيل جرس الإنذار',
            Icons.notifications_on,
            Colors.red,
            () => _showEmergencyConfirmation(
              context,
              'تفعيل جرس الإنذار',
              'هل أنت متأكد من رغبتك في تفعيل جرس الإنذار في جميع أنحاء المدرسة؟ سيؤدي هذا إلى بدء إجراءات الإخلاء.',
              Colors.red,
            ),
          ),
          _buildProcedureItem(
            'الاتصال بالدفاع المدني',
            Icons.phone_forwarded,
            Colors.red,
            () => _showEmergencyConfirmation(
              context,
              'الاتصال بالدفاع المدني',
              'سيتم إجراء اتصال طوارئ مباشر مع عمليات الدفاع المدني (998). هل تود المتابعة؟',
              Colors.red,
            ),
          ),
          _buildProcedureItem(
            'فتح جميع مخارج الطوارئ',
            Icons.open_in_new,
            Colors.blue,
            () => _showEmergencyConfirmation(
              context,
              'فتح مخارج الطوارئ',
              'سيتم فتح جميع الأبواب الإلكترونية ومخارج الطوارئ تلقائياً. هذا الإجراء لا يمكن التراجع عنه عن بعد.',
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProcedureItem(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        margin: EdgeInsets.only(bottom: 12.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20.sp),
            SizedBox(width: 12.w),
            Text(
              label,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            Spacer(),
            Icon(Icons.arrow_back_ios, size: 12.sp, color: color),
          ],
        ),
      ),
    );
  }

  void _showEmergencyConfirmation(
    BuildContext context,
    String title,
    String message,
    Color color,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 28.sp),
            SizedBox(width: 8.w),
            Text(
              title,
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
        content: Text(message, style: GoogleFonts.cairo(fontSize: 14.sp)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء', style: GoogleFonts.cairo(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم تنفيذ الإجراء: $title',
                    style: GoogleFonts.cairo(),
                  ),
                  backgroundColor: color,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(
              'تأكيد التنفيذ',
              style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Helper Animations ---

class _PulseAnimation extends StatefulWidget {
  const _PulseAnimation();

  @override
  State<_PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<_PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: 250.w * (1 + _controller.value * 0.2),
          height: 250.w * (1 + _controller.value * 0.2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: Colors.indigoAccent.withOpacity(1 - _controller.value),
              width: 2,
            ),
          ),
        );
      },
    );
  }
}
