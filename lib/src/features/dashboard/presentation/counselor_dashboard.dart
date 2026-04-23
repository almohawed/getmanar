import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../counselor/presentation/counselor_providers.dart';

class CounselorDashboard extends ConsumerWidget {
  const CounselorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeCases = ref.watch(activeCasesProvider).value ?? const [];
    final todaySessions = ref.watch(todaySessionsProvider).value ?? const [];
    final activePlans = ref.watch(activePlansProvider).value ?? const [];
    final recommendations = <String>[
      if (activeCases.isEmpty)
        'لا توجد حالات نشطة حالياً. ابدأ بإضافة حالة جديدة عند الحاجة.',
      if (activeCases.isNotEmpty && todaySessions.isEmpty)
        'يوصى بجدولة جلسة متابعة للحالات النشطة.',
      if (activeCases.isNotEmpty && activePlans.isEmpty)
        'يوصى بإنشاء خطة تعديل للحالات التي تتكرر.',
    ].take(4).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.teal.shade800, Colors.teal.shade600, Colors.cyan.shade600],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('التوجيه الطلابي', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
            Text('إدارة الحالات والجلسات الإرشادية', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;

          final summary = _CounselorSummaryCard(
            activeCases: activeCases.length,
            todaySessions: todaySessions.length,
            activePlans: activePlans.length,
          );

          final actions = _CounselorActionsPanel(
            onAddCase: () => context.push('/add-student-case'),
            onAddSession: () => context.push('/add-counseling-session'),
            onAddFollowUp: () => context.push('/add-case-followup'),
            onCloseCase: () => context.push('/close-student-case'),
            onSessions: () => context.push('/counselor/sessions'),
            onPlans: () => context.push('/counselor/plans'),
            onHealthCases: () => context.push('/counselor/health-cases'),
          );

          final recs = _CounselorRecommendationsCard(items: recommendations);

          final latest = _CounselorLatestCasesCard(
            cases: activeCases.take(6).toList(),
          );

          if (!isWide) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(16.w),
              child: Column(
                children: [
                  summary,
                  SizedBox(height: 16.h),
                  actions,
                  SizedBox(height: 16.h),
                  recs,
                  SizedBox(height: 16.h),
                  latest,
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
                      recs,
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                Expanded(
                  flex: 1,
                  child: Column(
                    children: [
                      summary,
                      SizedBox(height: 16.h),
                      latest,
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

class _CounselorSummaryCard extends StatelessWidget {
  final int activeCases;
  final int todaySessions;
  final int activePlans;

  const _CounselorSummaryCard({
    required this.activeCases,
    required this.todaySessions,
    required this.activePlans,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.teal.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'ملخص اليوم',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 8.h),
          _RowKV(label: 'الحالات النشطة:', value: '$activeCases'),
          _RowKV(label: 'جلسات اليوم:', value: '$todaySessions'),
          _RowKV(label: 'الخطط النشطة:', value: '$activePlans'),
        ],
      ),
    );
  }
}

class _CounselorActionsPanel extends StatelessWidget {
  final VoidCallback onAddCase;
  final VoidCallback onAddSession;
  final VoidCallback onAddFollowUp;
  final VoidCallback onCloseCase;
  final VoidCallback onSessions;
  final VoidCallback onPlans;
  final VoidCallback onHealthCases;

  const _CounselorActionsPanel({
    required this.onAddCase,
    required this.onAddSession,
    required this.onAddFollowUp,
    required this.onCloseCase,
    required this.onSessions,
    required this.onPlans,
    required this.onHealthCases,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ActionButton(
          icon: Icons.add,
          label: 'إضافة حالة',
          onTap: onAddCase,
          color: Colors.teal,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.meeting_room,
          label: 'تسجيل جلسة',
          onTap: onAddSession,
          color: Colors.teal,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.playlist_add_check,
          label: 'إضافة متابعة',
          onTap: onAddFollowUp,
          color: Colors.teal,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.check_circle,
          label: 'إغلاق حالة',
          onTap: onCloseCase,
          color: Colors.teal,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.today,
          label: 'جلسات اليوم',
          onTap: onSessions,
          color: Colors.teal,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.assignment,
          label: 'خطط التعديل',
          onTap: onPlans,
          color: Colors.teal,
        ),
        SizedBox(height: 10.h),
        _ActionButton(
          icon: Icons.health_and_safety,
          label: 'الحالات الصحية',
          onTap: onHealthCases,
          color: Colors.teal,
        ),
      ],
    );
  }
}

class _CounselorRecommendationsCard extends StatelessWidget {
  final List<String> items;

  const _CounselorRecommendationsCard({required this.items});

  @override
  Widget build(BuildContext context) {
    final recs = items.isEmpty ? const ['لا توجد توصيات حالياً.'] : items;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.teal.shade50),
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

class _CounselorLatestCasesCard extends StatelessWidget {
  final List cases;

  const _CounselorLatestCasesCard({required this.cases});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: Colors.teal.shade50),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'أحدث الحالات',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
            textAlign: TextAlign.right,
          ),
          SizedBox(height: 8.h),
          if (cases.isEmpty)
            Text('لا توجد حالات', style: GoogleFonts.cairo(color: Colors.grey))
          else
            ...cases.map(
              (c) => Padding(
                padding: EdgeInsets.only(top: 8.h),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      (c.title ?? '').toString(),
                      style: GoogleFonts.cairo(
                        fontSize: 12.sp,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        (c.studentName ?? '').toString(),
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

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final MaterialColor color;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 18, color: color.shade700),
        label: Text(label, style: GoogleFonts.cairo(color: color.shade700)),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color.shade100),
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

class _RowKV extends StatelessWidget {
  final String label;
  final String value;

  const _RowKV({required this.label, required this.value});

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
