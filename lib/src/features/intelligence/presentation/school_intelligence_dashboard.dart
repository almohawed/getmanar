import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../data/firestore_school_intelligence_repository.dart';
import 'school_intelligence_providers.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';
import '../domain/school_health_index.dart';
import '../application/manar_intelligence_engine.dart';

class SchoolIntelligenceDashboard extends ConsumerStatefulWidget {
  final String? titleOverride;

  const SchoolIntelligenceDashboard({super.key, this.titleOverride});

  @override
  ConsumerState<SchoolIntelligenceDashboard> createState() =>
      _SchoolIntelligenceDashboardState();
}

class _SchoolIntelligenceDashboardState
    extends ConsumerState<SchoolIntelligenceDashboard> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolAsync = ref.watch(schoolProvider(user?.schoolId ?? ''));
    final snapshotAsync = ref.watch(
      schoolIntelligenceSnapshotProvider('current'),
    );
    final predsAsync = ref.watch(riskPredictionsProvider);
    final plansAsync = ref.watch(remedialPlansProvider(null));

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.go('/dashboard'),
          tooltip: 'العودة إلى الصفحة الرئيسية',
        ),
        title: schoolAsync.when(
          data: (school) => Text(
            school != null
                ? 'منصة منار | ${school.name}'
                : (widget.titleOverride ??
                      'منصة منار | مؤشر صحة المدرسة وتحليلات الأداء'),
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          loading: () => Text(
            widget.titleOverride ?? 'منصة منار',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
          error: (_, __) => Text(
            widget.titleOverride ?? 'منصة منار',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'تحديث التحليل',
            onPressed: () async {
              try {
                await ref.read(
                  computeIntelligenceProvider(
                    ComputeIntelligenceParams('current'),
                  ).future,
                );
                ref.invalidate(schoolIntelligenceSnapshotProvider('current'));
                ref.invalidate(riskPredictionsProvider);
                ref.invalidate(remedialPlansProvider(null));
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم تحديث التحليل بنجاح'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              } catch (e) {
                if (!context.mounted) return;
                final msg = e.toString().replaceFirst('Exception: ', '').trim();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(msg.isEmpty ? 'تعذر تحديث التحليل' : msg),
                    behavior: SnackBarBehavior.floating,
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Get engine instance
            Builder(
              builder: (context) {
                final engine = ref.read(manarIntelligenceEngineProvider);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
            // 1. Health Index Header + AI Status
            snapshotAsync.when(
              data: (s) {
                if (s == null) {
                  return _buildErrorWidget(
                    'لا تتوفر بيانات للمدرسة حالياً. اضغط "تحديث التحليل" لإنشاء التقرير.',
                    () => ref.invalidate(
                      schoolIntelligenceSnapshotProvider('current'),
                    ),
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // _buildHealthSnapshotCard(s),
                    // const SizedBox(height: 12),
                    // _buildSchoolRiskBanner(s),
                    const SizedBox(height: 12),
                    Text(
                      'لوحة التحكم الذكية',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _buildErrorWidget(
                'تعذر تحميل بيانات المدرسة: $e',
                () => ref.invalidate(
                  schoolIntelligenceSnapshotProvider('current'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // 2. AI Insights Section
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.indigo.shade900),
                const SizedBox(width: 6),
                Text(
                  'تحليلات الأداء المدرسي',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'مؤشرات وصفية لمستويات السلوك والمواظبة والاستقرار المدرسي.',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<String>>(
              future: engine.analyzePatterns(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: LinearProgressIndicator());
                }
                if (snapshot.hasError) {
                  debugPrint('AI Insights Error: ${snapshot.error}');
                  return _buildErrorWidget(
                    'تعذر تحميل الرؤى الذكية',
                    () => setState(() {}),
                  );
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const SizedBox();
                }
                return _buildInsightsGrid(snapshot.data!);
              },
            ),
            const SizedBox(height: 20),

            // 3. Escalation Prediction
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Colors.red.shade800),
                const SizedBox(width: 6),
                Text(
                  'تنبيهات ارتفاع حالات السلوك',
                  style: GoogleFonts.cairo(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'قائمة تنبيهية داخلية لمتابعة المؤشرات المرتفعة في السلوك والانضباط.',
              style: GoogleFonts.cairo(
                fontSize: 13,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<String>>(
              future: engine.predictStudentEscalation(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const SizedBox();
                return Column(
                  children: snapshot.data!
                      .map((alert) => _buildAlertCard(alert))
                      .toList(),
                );
              },
            ),
            const SizedBox(height: 20),

            // 4. Teacher Motivation
            _buildTeacherMotivationSection(engine),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHealthIndexCard(SchoolHealthIndex index) {
    final overall = index.overallScore.clamp(0, 100).toDouble();
    final behavior = index.behaviorScore.clamp(0, 100).toDouble();
    final attendance = index.attendanceScore.clamp(0, 100).toDouble();
    final stability = index.stabilityScore.clamp(0, 100).toDouble();
    final family = index.familyEngagementScore.clamp(0, 100).toDouble();
    final levelLabel = _levelLabel(overall);
    final levelColor = _levelColor(overall);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.indigo.shade900, Colors.indigo.shade700],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.indigo.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'مؤشر صحة المدرسة',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${overall.toStringAsFixed(1)}٪',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      levelLabel,
                      style: GoogleFonts.cairo(
                        color: levelColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'آخر ٧ أيام',
                      style: GoogleFonts.cairo(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 90,
                height: 90,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 84,
                      height: 84,
                      child: CircularProgressIndicator(
                        value: overall / 100,
                        backgroundColor: Colors.white24,
                        valueColor: AlwaysStoppedAnimation<Color>(levelColor),
                        strokeWidth: 8,
                      ),
                    ),
                    Text(
                      '${overall.toStringAsFixed(0)}%',
                      style: GoogleFonts.cairo(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                title: 'السلوك',
                value: '${behavior.toStringAsFixed(1)}٪',
                color: Colors.orange.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStatCard(
                title: 'الحضور والانضباط',
                value: '${attendance.toStringAsFixed(1)}٪',
                color: Colors.teal.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _MiniStatCard(
                title: 'استقرار المدرسة',
                value: '${stability.toStringAsFixed(1)}٪',
                color: Colors.indigo.shade700,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _MiniStatCard(
                title: 'تفاعل الأسرة',
                value: '${family.toStringAsFixed(1)}٪',
                color: Colors.purple.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.indigo.shade50),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'توزيع التقديرات',
                style: GoogleFonts.cairo(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.indigo.shade900,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _LevelPill(label: 'ممتاز', color: Colors.green.shade700),
                  _LevelPill(label: 'جيد جداً', color: Colors.teal.shade600),
                  _LevelPill(label: 'جيد', color: Colors.blue.shade600),
                  _LevelPill(label: 'مقبول', color: Colors.orange.shade700),
                  _LevelPill(label: 'ضعيف', color: Colors.red.shade700),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                height: 120,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    _BarColumn(
                      label: 'السلوك',
                      value: behavior,
                      color: Colors.orange.shade700,
                    ),
                    _BarColumn(
                      label: 'الحضور',
                      value: attendance,
                      color: Colors.teal.shade700,
                    ),
                    _BarColumn(
                      label: 'الاستقرار',
                      value: stability,
                      color: Colors.indigo.shade700,
                    ),
                    _BarColumn(
                      label: 'الأسرة',
                      value: family,
                      color: Colors.purple.shade700,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (index.criticalAlerts.isNotEmpty) ...[
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.red.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'تنبيهات مهمة',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: Colors.red.shade900,
                  ),
                ),
                const SizedBox(height: 8),
                ...index.criticalAlerts.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.bolt, size: 16, color: Colors.red.shade700),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            a,
                            style: GoogleFonts.cairo(fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  String _levelLabel(double score) {
    if (score >= 90) {
      return 'ممتاز';
    }
    if (score >= 80) {
      return 'جيد جداً';
    }
    if (score >= 70) {
      return 'جيد';
    }
    if (score >= 60) {
      return 'مقبول';
    }
    return 'ضعيف';
  }

  Color _levelColor(double score) {
    if (score >= 90) {
      return Colors.green.shade400;
    }
    if (score >= 80) {
      return Colors.teal.shade300;
    }
    if (score >= 70) {
      return Colors.blue.shade300;
    }
    if (score >= 60) {
      return Colors.orange.shade300;
    }
    return Colors.red.shade300;
  }

  Widget _buildAiUnderstandingBanner(SchoolHealthIndex index) {
    final overall = index.overallScore.clamp(0, 100).toDouble();
    String summary;
    String detail;
    IconData icon;
    Color color;

    if (overall >= 85) {
      summary = 'منار يفهم سلوك مدرستك ويطمّنك أن الصورة العامة ممتازة.';
      detail =
          'النظام رصد انسجاماً بين السلوك والحضور واستقرار المدرسة، ويعتبر هذه الفترة نقطة قوة يمكن البناء عليها.';
      icon = Icons.auto_awesome;
      color = Colors.green.shade700;
    } else if (overall >= 70) {
      summary = 'منار يلتقط صورة متوازنة ويشير إلى فرص تحسين محددة.';
      detail =
          'الذكاء يعرف أين تتركز ملاحظات السلوك والمواظبة، ويقترح متابعة مركزة للفصول أو المراحل ذات المؤشرات المتوسطة.';
      icon = Icons.analytics_outlined;
      color = Colors.orange.shade700;
    } else {
      summary = 'منار يرفع الراية الصفراء: هناك ملفات تحتاج تدخل قيادي.';
      detail =
          'النظام يلاحظ تكراراً في تنبيهات السلوك أو الغياب، ويشجّع على عقد اجتماعات مركزة مع الرواد والمعلمين لمعالجة الجذور.';
      icon = Icons.warning_amber_rounded;
      color = Colors.red.shade700;
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  summary,
                  style: GoogleFonts.cairo(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  detail,
                  style: GoogleFonts.cairo(
                    fontSize: 11,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsightCard(String text) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline, color: Colors.amber.shade700),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: GoogleFonts.cairo(fontSize: 14))),
          ],
        ),
      ),
    );
  }

  Widget _buildInsightsGrid(List<String> insights) {
    final categorized = insights.map(_categorizeInsight).toList();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.2,
      ),
      itemCount: categorized.length,
      itemBuilder: (context, index) {
        final item = categorized[index];
        return Card(
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: item.iconColor.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(item.icon, size: 16, color: item.iconColor),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.tag,
                      style: GoogleFonts.cairo(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: item.iconColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    item.text,
                    style: GoogleFonts.cairo(
                      fontSize: 11,
                      color: Colors.grey.shade800,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _InsightCategory {
  final String text;
  final String tag;
  final IconData icon;
  final Color iconColor;

  const _InsightCategory({
    required this.text,
    required this.tag,
    required this.icon,
    required this.iconColor,
  });
}

_InsightCategory _categorizeInsight(String text) {
  String tag = 'نظرة عامة';
  IconData icon = Icons.insights;
  Color color = Colors.indigo;

  final lower = text;
  if (lower.contains('سلوك') || lower.contains('مخال')) {
    tag = 'سلوك وانضباط';
    icon = Icons.gavel;
    color = Colors.orange.shade700;
  } else if (lower.contains('حضور') ||
      lower.contains('غياب') ||
      lower.contains('مواظبة')) {
    tag = 'مواظبة';
    icon = Icons.schedule;
    color = Colors.teal.shade700;
  } else if (lower.contains('أسرة') ||
      lower.contains('ولي') ||
      lower.contains('تواصل')) {
    tag = 'تفاعل الأسرة';
    icon = Icons.family_restroom;
    color = Colors.purple.shade700;
  } else if (lower.contains('صيانة') || lower.contains('بلاغ')) {
    tag = 'بيئة المدرسة';
    icon = Icons.home_repair_service;
    color = Colors.brown.shade700;
  } else if (lower.contains('ممتاز') || lower.contains('مستقر')) {
    tag = 'قوة';
    icon = Icons.verified;
    color = Colors.green.shade700;
  } else if (lower.contains('تحتاج') ||
      lower.contains('انخفاض') ||
      lower.contains('خطر')) {
    tag = 'مجال حساس';
    icon = Icons.priority_high;
    color = Colors.red.shade700;
  }

  return _InsightCategory(text: text, tag: tag, icon: icon, iconColor: color);
}

Widget _buildAlertCard(String text) {
  return Card(
    color: Colors.red.shade50,
    elevation: 0,
    margin: const EdgeInsets.only(bottom: 10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(color: Colors.red.shade200),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 14,
                color: Colors.red.shade900,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildTeacherMotivationSection(ManarIntelligenceEngine engine) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.purple.shade50,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.purple.shade100),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.stars, color: Colors.purple),
            const SizedBox(width: 8),
            Text(
              'رسائل تعزيز للمعلمين',
              style: GoogleFonts.cairo(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.purple.shade900,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        FutureBuilder<String?>(
          future: engine.generateTeacherMotivation('teacher1'),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Text(
                'تعذر عرض رسالة التعزيز حالياً. يرجى المحاولة لاحقاً.',
                style: const TextStyle(color: Colors.red),
              );
            }
            if (snapshot.hasData) {
              return Text(
                snapshot.data!,
                style: GoogleFonts.cairo(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  color: Colors.purple.shade800,
                ),
              );
            }
            return const SizedBox();
          },
        ),
      ],
    ),
  );
}

class _MiniStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;

  const _MiniStatCard({
    required this.title,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LevelPill extends StatelessWidget {
  final String label;
  final Color color;

  const _LevelPill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: GoogleFonts.cairo(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _BarColumn({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(0, 100);
    final height = 40 + (clamped / 100) * 60;
    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            height: height,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                '${clamped.toStringAsFixed(0)}%',
                style: GoogleFonts.cairo(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: GoogleFonts.cairo(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}

Widget _buildErrorWidget(String message, VoidCallback onRetry) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.shade50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.red.shade200),
    ),
    child: Column(
      children: [
        Icon(Icons.error_outline, color: Colors.red.shade700, size: 32),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: GoogleFonts.cairo(color: Colors.red.shade900),
        ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('إعادة المحاولة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red.shade100,
            foregroundColor: Colors.red.shade900,
            elevation: 0,
          ),
        ),
      ],
    ),
  );
}
