import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../domain/announcement.dart';
import 'widgets/create_announcement_dialog.dart';
import 'widgets/announcements_report_dialog.dart';
import '../application/announcement_service.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../auth/presentation/auth_controller.dart';

class AnnouncementsDashboardScreen extends ConsumerStatefulWidget {
  const AnnouncementsDashboardScreen({super.key});

  @override
  ConsumerState<AnnouncementsDashboardScreen> createState() =>
      _AnnouncementsDashboardScreenState();
}

class _AnnouncementsDashboardScreenState
    extends ConsumerState<AnnouncementsDashboardScreen> {
  final AnnouncementService _service = AnnouncementService();
  late List<Announcement> _announcements;
  late Map<String, dynamic> _stats;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) {
      setState(() {
        _announcements = const [];
        _stats = const {
          'today': 0,
          'thisWeek': 0,
          'active': 0,
          'totalViews': 0,
        };
      });
      return;
    }
    final announcements = await _service.fetchAnnouncements(schoolId);
    final stats = await _service.fetchStatistics(schoolId);
    if (!mounted) return;
    setState(() {
      _announcements = announcements;
      _stats = stats;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF8E1), // Light Amber Background
      appBar: AppBar(
        title: const Text(
          'مركز الإعلانات المدرسية',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.amber.shade800,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _refreshData(),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatsRow(),
            SizedBox(height: 24.h),
            _buildActionButtons(),
            SizedBox(height: 24.h),
            _buildSectionTitle('الإعلانات النشطة'),
            SizedBox(height: 16.h),
            _buildAnnouncementsList(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsRow() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final children = [
          _buildStatCard(
            'إعلانات اليوم',
            '${_stats['today']}',
            Icons.today,
            Colors.amber.shade900,
          ),
          _buildStatCard(
            'إعلانات الأسبوع',
            '${_stats['thisWeek']}',
            Icons.calendar_view_week,
            Colors.orange,
          ),
          _buildStatCard(
            'الإعلانات النشطة',
            '${_stats['active']}',
            Icons.campaign,
            Colors.green,
          ),
          _buildStatCard(
            'عدد المشاهدات',
            '${_stats['totalViews']}',
            Icons.visibility,
            Colors.blue,
          ),
        ];

        if (isMobile) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.3,
            children: children,
          );
        }

        return Row(
          children: children
              .map(
                (c) => Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6.w),
                    child: c,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          right: BorderSide(color: color, width: 4.w),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 12.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => CreateAnnouncementDialog(
                  creatorName: ref.read(authStateProvider).value?.name,
                  onSave: (a) {
                    final user = ref.read(authStateProvider).value;
                    final schoolId = (user?.schoolId ?? '').trim();
                    if (schoolId.isNotEmpty) {
                      _service.createAnnouncement(schoolId, a);
                      _refreshData();
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم نشر الإعلان بنجاح')),
                    );
                  },
                ),
              );
            },
            icon: const Icon(Icons.add_alert, color: Colors.white),
            label: const Text(
              'إنشاء إعلان جديد',
              style: TextStyle(color: Colors.white),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber.shade800,
              padding: EdgeInsets.symmetric(vertical: 16.h),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
        SizedBox(width: 12.w),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) =>
                    AnnouncementsReportDialog(announcements: _announcements),
              );
            },
            icon: Icon(Icons.analytics_outlined, color: Colors.amber.shade900),
            label: Text(
              'تقرير الإعلانات',
              style: TextStyle(color: Colors.amber.shade900),
            ),
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              side: BorderSide(color: Colors.amber.shade900),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.r),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAnnouncementsList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _announcements.length,
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        final announcement = _announcements[index];
        return _buildAnnouncementCard(announcement);
      },
    );
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    return Container(
      padding: EdgeInsets.all(16.w),
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
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Chip(
                label: Text(
                  Announcement.getTypeLabel(announcement.type),
                  style: TextStyle(fontSize: 10.sp, color: Colors.white),
                ),
                backgroundColor: _getTypeColor(announcement.type),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
              ),
              Text(
                timeago.format(announcement.publishDate, locale: 'ar'),
                style: TextStyle(fontSize: 11.sp, color: Colors.grey),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            announcement.title,
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade900,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            announcement.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade700),
          ),
          SizedBox(height: 12.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.visibility, size: 14.sp, color: Colors.grey),
                  SizedBox(width: 4.w),
                  Text(
                    '${announcement.viewCount}',
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                  ),
                ],
              ),
              Text(
                'الفئة: ${Announcement.getAudienceLabel(announcement.targetAudience)}',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
}
