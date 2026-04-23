import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import 'schedule_management_screen.dart';
import 'create_campaign_screen.dart';
import 'workload_analysis_screen.dart';
import 'modifications_log_screen.dart';

/// 🎯 لوحة تحكم وكيل الشؤون التعليمية - تجمع جميع الأقسام
class EducationalAffairsDashboard extends ConsumerWidget {
  final String schoolId;

  const EducationalAffairsDashboard({Key? key, required this.schoolId})
    : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final userId = user?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text('وكيل الشؤون التعليمية'),
        centerTitle: true,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor.withValues(alpha: 0.1),
              Colors.white,
            ],
          ),
        ),
        child: GridView.count(
          crossAxisCount: 2,
          padding: const EdgeInsets.all(16),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          children: [
            _buildSectionCard(
              context,
              title: 'الجدول الذكي',
              icon: Icons.auto_awesome,
              color: Colors.purple,
              description: 'توليد جدول ذكي تلقائياً',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ScheduleManagementScreen(),
                ),
              ),
            ),
            _buildSectionCard(
              context,
              title: 'الجدول التشاركي',
              icon: Icons.people,
              color: Colors.blue,
              description: 'إشراك المعلمين في بناء الجدول',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      CreateCampaignScreen(schoolId: schoolId, userId: userId),
                ),
              ),
            ),
            _buildSectionCard(
              context,
              title: 'توزيع النصاب',
              icon: Icons.balance,
              color: Colors.green,
              description: 'تحليل ذكي لنصاب المعلمين',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkloadAnalysisScreen(schoolId: schoolId),
                ),
              ),
            ),
            _buildSectionCard(
              context,
              title: 'سجل التعديلات',
              icon: Icons.history,
              color: Colors.orange,
              description: 'تتبع وتحليل جميع التعديلات',
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      ModificationsLogScreen(schoolId: schoolId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Color color,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color.withValues(alpha: 0.7), color],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 48, color: Colors.white),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
