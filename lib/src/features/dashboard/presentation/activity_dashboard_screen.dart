import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../activity/data/firestore_activity_repository.dart';
import '../../auth/presentation/auth_controller.dart';

class ActivityDashboardScreen extends ConsumerWidget {
  const ActivityDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final activities = ref.watch(schoolActivitiesProvider).value ?? const [];
    final participations =
        ref.watch(activityParticipationsProvider).value ?? const [];

    final total = activities.length;
    final completed = activities.where((a) => a.status == 'completed').length;
    final planned = activities.where((a) => a.status == 'planned').length;
    final inProgress = activities
        .where((a) => a.status == 'in_progress' || a.status == 'active')
        .length;
    final latest = activities.take(6).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade800, Colors.indigo.shade600, Colors.blue.shade600],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('النشاط الطلابي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('إدارة الأنشطة والفعاليات المدرسية', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final summaryCard = _SummaryCard(
            total: total,
            planned: planned,
            inProgress: inProgress,
            completed: completed,
            participations: participations.length,
          );

          final actions = _ActionsPanel(
            onAdd: () => context.push('/add-activity'),
            onRegister: () => context.push('/register-student-activity'),
            onUpdate: () => context.push('/update-activity'),
            onEnd: () => context.push('/end-activity'),
            onDeletePrevious: () async {
              if (schoolId.isEmpty) return;

              DateTime cutoff = DateTime.now().subtract(
                const Duration(days: 30),
              );
              bool onlyCompleted = true;

              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => StatefulBuilder(
                  builder: (context, setLocal) => AlertDialog(
                    title: Text(
                      'حذف الأنشطة السابقة',
                      style: GoogleFonts.cairo(),
                    ),
                    content: SizedBox(
                      width: 420.w,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سيتم حذف الأنشطة قبل التاريخ المحدد، مع حذف سجلات المشاركات القديمة.',
                            style: GoogleFonts.cairo(fontSize: 12.sp),
                            textAlign: TextAlign.right,
                          ),
                          SizedBox(height: 12.h),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      firstDate: DateTime(2020),
                                      lastDate: DateTime(2100),
                                      initialDate: cutoff,
                                    );
                                    if (picked == null) return;
                                    setLocal(() => cutoff = picked);
                                  },
                                  icon: const Icon(Icons.date_range),
                                  label: Text(
                                    '${cutoff.year}-${cutoff.month.toString().padLeft(2, '0')}-${cutoff.day.toString().padLeft(2, '0')}',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SwitchListTile(
                            value: onlyCompleted,
                            onChanged: (v) => setLocal(() => onlyCompleted = v),
                            title: Text(
                              'حذف الأنشطة المكتملة فقط',
                              style: GoogleFonts.cairo(fontSize: 12.sp),
                              textAlign: TextAlign.right,
                            ),
                          ),
                        ],
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: Text('إلغاء', style: GoogleFonts.cairo()),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade600,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('حذف', style: GoogleFonts.cairo()),
                      ),
                    ],
                  ),
                ),
              );

              if (confirm != true) return;
              if (!context.mounted) return;

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'جاري حذف الأنشطة...',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              );

              final result = await ref
                  .read(activityRepositoryProvider)
                  .deletePreviousActivities(
                    schoolId,
                    beforeDate: cutoff,
                    onlyCompleted: onlyCompleted,
                  );

              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'تم الحذف: ${result['activities']} نشاط، ${result['participations']} مشاركة',
                    style: GoogleFonts.cairo(),
                  ),
                ),
              );
            },
          );

          final latestCard = _LatestActivitiesCard(activities: latest);

          final recommendations = _RecommendationsCard(
            total: total,
            planned: planned,
            participations: participations.length,
          );

          if (!isWide) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  summaryCard,
                  SizedBox(height: 16.h),
                  actions,
                  SizedBox(height: 16.h),
                  recommendations,
                  SizedBox(height: 16.h),
                  latestCard,
                ],
              ),
            );
          }

          return Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      actions,
                      SizedBox(height: 16.h),
                      recommendations,
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      summaryCard,
                      SizedBox(height: 16.h),
                      latestCard,
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final int total;
  final int planned;
  final int inProgress;
  final int completed;
  final int participations;

  const _SummaryCard({
    required this.total,
    required this.planned,
    required this.inProgress,
    required this.completed,
    required this.participations,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.indigo.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'ملخص',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 8.h),
          _SummaryRow(label: 'عدد الأنشطة:', value: '$total'),
          _SummaryRow(label: 'أنشطة مخطط لها:', value: '$planned'),
          _SummaryRow(label: 'أنشطة جارية:', value: '$inProgress'),
          _SummaryRow(label: 'أنشطة مكتملة:', value: '$completed'),
          _SummaryRow(label: 'سجلات مشاركات:', value: '$participations'),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: 6.h),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(value, style: GoogleFonts.cairo(fontWeight: FontWeight.bold)),
          SizedBox(width: 6.w),
          Text(label, style: GoogleFonts.cairo(color: Colors.grey.shade700)),
        ],
      ),
    );
  }
}

class _ActionsPanel extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onRegister;
  final VoidCallback onUpdate;
  final VoidCallback onEnd;
  final VoidCallback onDeletePrevious;

  const _ActionsPanel({
    required this.onAdd,
    required this.onRegister,
    required this.onUpdate,
    required this.onEnd,
    required this.onDeletePrevious,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(icon: Icons.add, label: 'إضافة نشاط', onTap: onAdd),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.how_to_reg,
          label: 'تسجيل مشاركة طالب',
          onTap: onRegister,
        ),
        SizedBox(height: 10.h),
        _ActionButton(icon: Icons.edit, label: 'تحديث نشاط', onTap: onUpdate),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.check_circle,
          label: 'إنهاء نشاط',
          onTap: onEnd,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.delete_outline,
          label: 'حذف الأنشطة السابقة',
          onTap: onDeletePrevious,
          iconColor: Colors.red.shade600,
          labelColor: Colors.red.shade600,
          borderColor: Colors.red.shade100,
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? iconColor;
  final Color? labelColor;
  final Color? borderColor;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.labelColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: iconColor ?? Colors.indigo.shade700),
        label: Text(
          label,
          style: GoogleFonts.cairo(color: labelColor ?? Colors.indigo.shade700),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: borderColor ?? Colors.indigo.shade100),
          backgroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 12.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24.r),
          ),
        ),
      ),
    );
  }
}

class _LatestActivitiesCard extends StatelessWidget {
  final List<ActivityRecord> activities;

  const _LatestActivitiesCard({required this.activities});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.indigo.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'آخر الأنشطة',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 8.h),
          if (activities.isEmpty)
            Text('لا توجد أنشطة', style: GoogleFonts.cairo(color: Colors.grey))
          else
            ...activities.map(
              (a) => Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      a.type,
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        a.name,
                        style: GoogleFonts.cairo(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.right,
                        overflow: TextOverflow.ellipsis,
                      ),
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

class _RecommendationsCard extends StatelessWidget {
  final int total;
  final int planned;
  final int participations;

  const _RecommendationsCard({
    required this.total,
    required this.planned,
    required this.participations,
  });

  @override
  Widget build(BuildContext context) {
    final recs = <String>[];
    if (total == 0) {
      recs.add('ابدأ بإضافة نشاط واحد على الأقل لتظهر المؤشرات والتقارير.');
    }
    if (planned > 0 && participations == 0) {
      recs.add('يوصى بتسجيل المشاركات لقياس أثر النشاط وعدد المستفيدين.');
    }
    if (recs.isEmpty) {
      recs.add(
        'استمر في تحديث الأنشطة وتسجيل المشاركات للحصول على تقارير أدق.',
      );
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.indigo.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'توصيات ذكية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 8.h),
          ...recs.map(
            (t) => Padding(
              padding: EdgeInsets.only(top: 6.h),
              child: Text('• $t', style: GoogleFonts.cairo()),
            ),
          ),
        ],
      ),
    );
  }
}
