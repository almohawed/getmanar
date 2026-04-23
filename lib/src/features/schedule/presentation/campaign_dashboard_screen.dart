import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../auth/presentation/auth_controller.dart';
import '../application/campaign_service.dart';
import '../domain/schedule_campaign.dart';
import '../domain/teacher_response.dart';

class CampaignDashboardScreen extends ConsumerWidget {
  final String campaignId;

  const CampaignDashboardScreen({Key? key, required this.campaignId})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final service = ref.read(campaignServiceProvider);
    final user = ref.watch(authStateProvider).value;

    if (user == null || user.schoolId == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final schoolId = user.schoolId!;

    return Scaffold(
      appBar: AppBar(title: const Text('📊 لوحة تحكم الحملة'), elevation: 0),
      body: StreamBuilder<CampaignStatistics>(
        stream: service.getCampaignStatistics(campaignId, schoolId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('خطأ: ${snapshot.error}'));
          }

          if (!snapshot.hasData) {
            return const Center(child: Text('لا توجد بيانات'));
          }

          final stats = snapshot.data!;
          final campaign = stats.campaign;

          return RefreshIndicator(
            onRefresh: () async {
              // Refresh handled by stream
            },
            child: ListView(
              padding: EdgeInsets.all(16.w),
              children: [
                _buildTimeRemaining(campaign),
                SizedBox(height: 16.h),
                _buildResponseRate(campaign),
                SizedBox(height: 16.h),
                _buildMostBlockedSlots(stats.mostBlockedSlots),
                SizedBox(height: 16.h),
                _buildSmartRecommendations(stats),
                SizedBox(height: 16.h),
                _buildTeachersList(context, service, campaignId, schoolId),
                SizedBox(height: 16.h),
                _buildActions(context, service, campaign, schoolId),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTimeRemaining(ScheduleCampaign campaign) {
    final remaining = campaign.timeRemaining;
    final days = remaining.inDays;
    final hours = remaining.inHours % 24;
    final minutes = remaining.inMinutes % 60;

    return Card(
      color: campaign.isExpired ? Colors.red.shade50 : Colors.blue.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            Text(
              '⏰ الوقت المتبقي',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              campaign.isExpired
                  ? 'انتهت الحملة'
                  : '$days يوم و $hours ساعة و $minutes دقيقة',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: campaign.isExpired ? Colors.red : Colors.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseRate(ScheduleCampaign campaign) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📈 نسبة الاستجابة',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            _buildResponseBar(
              '✅ رد بنعم',
              campaign.respondedYes,
              campaign.totalTeachers,
              Colors.green,
            ),
            SizedBox(height: 8.h),
            _buildResponseBar(
              '❌ رد بلا',
              campaign.respondedNo,
              campaign.totalTeachers,
              Colors.orange,
            ),
            SizedBox(height: 8.h),
            _buildResponseBar(
              '⏳ لم يرد',
              campaign.notResponded,
              campaign.totalTeachers,
              Colors.grey,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponseBar(String label, int count, int total, Color color) {
    final percentage = total > 0 ? (count / total) * 100 : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label),
            Text(
              '$count معلم (${percentage.toStringAsFixed(0)}%)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SizedBox(height: 4.h),
        LinearProgressIndicator(
          value: percentage / 100,
          backgroundColor: Colors.grey.shade200,
          valueColor: AlwaysStoppedAnimation<Color>(color),
          minHeight: 8.h,
        ),
      ],
    );
  }

  Widget _buildMostBlockedSlots(List<MapEntry<String, int>> mostBlocked) {
    if (mostBlocked.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔥 الحصص الأكثر استبعاداً',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            ...mostBlocked.take(5).map((entry) {
              final parts = entry.key.split('_');
              final day = parts[0];
              final period = parts[1];
              final count = entry.value;

              Color color = Colors.green;
              if (count > 5) color = Colors.orange;
              if (count > 10) color = Colors.red;

              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    Container(
                      width: 8.w,
                      height: 40.h,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(4.r),
                      ),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Text(
                        '$day - الحصة $period',
                        style: TextStyle(fontSize: 16.sp),
                      ),
                    ),
                    Text(
                      '$count معلم',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSmartRecommendations(CampaignStatistics stats) {
    final recommendations = <String>[];

    // تحليل ذكي
    if (stats.mostBlockedSlots.isNotEmpty) {
      final topBlocked = stats.mostBlockedSlots.first;
      if (topBlocked.value > 10) {
        recommendations.add(
          '⚠️ تعارض محتمل: ${topBlocked.value} معلم يرفضون نفس الحصة!',
        );
        recommendations.add('✅ حل مقترح: توزيع حصص الانتظار في هذا الوقت');
      }
    }

    if (stats.campaign.responseRate < 50) {
      recommendations.add('📧 نسبة الاستجابة منخفضة، يُنصح بإرسال تذكير');
    }

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      color: Colors.amber.shade50,
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '💡 توصيات ذكية',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            ...recommendations
                .map(
                  (rec) => Padding(
                    padding: EdgeInsets.only(bottom: 8.h),
                    child: Text(rec),
                  ),
                )
                .toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeachersList(
    BuildContext context,
    CampaignService service,
    String campaignId,
    String schoolId,
  ) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '📋 قائمة المعلمين',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            FutureBuilder<List<TeacherResponse>>(
              future: service.getResponses(campaignId, schoolId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final responses = snapshot.data!;
                return Column(
                  children: responses.take(5).map((response) {
                    IconData icon;
                    Color color;
                    String status;

                    switch (response.response) {
                      case ResponseType.yes:
                        icon = Icons.check_circle;
                        color = Colors.green;
                        status =
                            'رد بنعم (${response.blockedSlotsCount} حصص مستبعدة)';
                        break;
                      case ResponseType.no:
                        icon = Icons.cancel;
                        color = Colors.orange;
                        status = 'رد بلا';
                        break;
                      case ResponseType.noResponse:
                        icon = Icons.access_time;
                        color = Colors.grey;
                        status = 'لم يرد بعد';
                        break;
                    }

                    return ListTile(
                      leading: Icon(icon, color: color),
                      title: Text(response.teacherName),
                      subtitle: Text(status),
                    );
                  }).toList(),
                );
              },
            ),
            TextButton(
              onPressed: () {
                // عرض القائمة الكاملة
              },
              child: const Text('عرض الكل...'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions(
    BuildContext context,
    CampaignService service,
    ScheduleCampaign campaign,
    String schoolId,
  ) {
    return Column(
      children: [
        if (!campaign.isExpired)
          ElevatedButton.icon(
            onPressed: () async {
              await service.sendReminder(campaign.id, schoolId);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('تم إرسال تذكير للمعلمين')),
              );
            },
            icon: const Icon(Icons.notifications_active),
            label: const Text('إرسال تذكير'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              minimumSize: Size(double.infinity, 50.h),
            ),
          ),
        SizedBox(height: 12.h),
        if (campaign.status == CampaignStatus.active)
          ElevatedButton.icon(
            onPressed: () async {
              await service.closeCampaign(campaign.id, schoolId);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('تم إغلاق الحملة')));
            },
            icon: const Icon(Icons.check_circle),
            label: const Text('إغلاق الحملة وبدء التوزيع'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: Size(double.infinity, 50.h),
            ),
          ),
      ],
    );
  }
}
