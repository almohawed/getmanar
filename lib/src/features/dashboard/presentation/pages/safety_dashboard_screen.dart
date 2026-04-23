import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../common/presentation/smart_section_scaffold.dart';
import '../../../safety/data/firestore_safety_repository.dart';

class SafetyDashboardScreen extends ConsumerWidget {
  const SafetyDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(safetySettingsProvider).value;
    final guardsCount =
        (ref.watch(safetyGuardsProvider).value ?? const <SafetyGuard>[]).length;
    return SmartSectionScaffold(
      title: 'الأمن والسلامة',
      icon: Icons.security,
      themeColor: Colors.orange,
      initialRecommendation:
          'توصي الوزارة بتنفيذ فرضية إخلاء مرة واحدة على الأقل كل فصل دراسي.',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildActionGrid(context),
            SizedBox(height: 24.h),
            _buildQuickStats(context, settings, guardsCount),
          ],
        ),
      ),
    );
  }

  Widget _buildActionGrid(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = width >= 1100 ? 4 : (width >= 740 ? 3 : 2);
    final ratio = width >= 1100 ? 1.35 : (width >= 740 ? 1.55 : 2.35);

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxisCount,
      mainAxisSpacing: 8.h,
      crossAxisSpacing: 8.w,
      childAspectRatio: ratio,
      children: [
        _buildActionCard(
          context,
          title: 'خطة الإخلاء',
          icon: Icons.run_circle,
          color: Colors.red,
          onTap: () => context.push('/evacuation-plan'),
        ),
        _buildActionCard(
          context,
          title: 'سجل التجارب',
          icon: Icons.history_edu,
          color: Colors.blue,
          onTap: () => context.push('/drills-log'),
        ),
        _buildActionCard(
          context,
          title: 'فحص الطفايات',
          icon: Icons.fire_extinguisher,
          color: Colors.orange,
          onTap: () => context.push('/extinguishers-check'),
        ),
        _buildActionCard(
          context,
          title: 'مخارج الطوارئ',
          icon: Icons.meeting_room,
          color: Colors.green,
          onTap: () => context.push('/emergency-exits'),
        ),
      ],
    );
  }

  Widget _buildActionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: Colors.black26),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(6.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20.sp),
            ),
            SizedBox(height: 6.h),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(
    BuildContext context,
    SafetySettings? settings,
    int guardsCount,
  ) {
    final camA = settings?.camerasActive;
    final camT = settings?.camerasTotal;
    final camerasValue = (camA == null && camT == null)
        ? 'غير مسجل'
        : '${camA ?? 0}/${camT ?? 0}';

    final alarmsValue = settings?.alarmsReady == null
        ? 'غير مسجل'
        : (settings!.alarmsReady! ? 'جاهز' : 'غير جاهز');

    final planValue =
        (settings?.meetingPoint.trim().isNotEmpty ?? false) ||
            (settings?.evacuationOfficer.trim().isNotEmpty ?? false)
        ? 'مسجلة'
        : 'غير مسجلة';

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.black26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'حالة الجاهزية',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          _buildStatRow('كاميرات المراقبة', camerasValue, Colors.blue),
          Divider(height: 24.h),
          _buildStatRow('أنظمة الإنذار', alarmsValue, Colors.green),
          Divider(height: 24.h),
          _buildStatRow('خطة الإخلاء', planValue, Colors.orange),
          Divider(height: 24.h),
          _buildStatRow('حراس الأمن', guardsCount.toString(), Colors.teal),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade700),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }
}
