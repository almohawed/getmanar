import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exams_providers.dart';
import '../../data/firestore_exams_repository.dart';
import '../../../academic/domain/classroom.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';

class GradesTrackingTab extends ConsumerStatefulWidget {
  const GradesTrackingTab({super.key});
  @override
  ConsumerState<GradesTrackingTab> createState() => _GradesTrackingTabState();
}

class _GradesTrackingTabState extends ConsumerState<GradesTrackingTab> {
  String? _termId;
  String? _classId;

  String _termLabel(String termId) {
    final t = termId.trim();
    final lower = t.toLowerCase();
    if (lower == 'term1' || lower == 't1' || t == '1') return 'الفصل الأول';
    if (lower == 'term2' || lower == 't2' || t == '2') return 'الفصل الثاني';
    if (lower == 'term3' || lower == 't3' || t == '3') return 'الفصل الثالث';
    if (lower == 'current') return 'الفصل الحالي';
    return t;
  }

  Future<void> _openTermFilter(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => _TermFilterSheet(
        initialTerm: _termId,
        initialClassId: _classId,
        onApply: (t, c) => setState(() {
          _termId = t;
          _classId = c;
        }),
      ),
    );
    ref.invalidate(
      gradesTrackingProvider((termId: _termId, classId: _classId)),
    );
  }

  Future<void> _openAddEntryFromTop(
    BuildContext context,
    List<ExamGradesTrack> tracks,
  ) async {
    if (tracks.isEmpty) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('إدخال درجة'),
          content: const Text(
            'لا توجد مسارات رصد متاحة الآن. غيّر الفصل أو تأكد من إنشاء مسارات الرصد للصفوف والمواد.',
          ),
        ),
      );
      return;
    }
    final selected = await showModalBottomSheet<ExamGradesTrack>(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => _PickTrackSheet(tracks: tracks),
    );
    if (selected == null || !context.mounted) return;
    await showDialog(
      context: context,
      builder: (_) => _AddGradeDialog(
        trackId: selected.id,
        termId: selected.termId,
        subjectId: selected.subjectId,
        teacherId: selected.teacherId,
      ),
    );
    ref.invalidate(
      gradesTrackingProvider((termId: _termId, classId: _classId)),
    );
  }

  ({String label, Color color}) _statusMeta(String status) {
    switch (status) {
      case 'complete':
        return (label: 'مكتمل', color: const Color(0xFF22C55E));
      case 'late':
        return (label: 'متأخر', color: const Color(0xFFEF4444));
      default:
        return (label: 'قيد الرصد', color: const Color(0xFFF59E0B));
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracks = ref.watch(
      gradesTrackingProvider((termId: _termId, classId: _classId)),
    );
    final classes =
        ref.watch(examClassesProvider).asData?.value ?? const <Classroom>[];
    const primary = Color(0xFF7C3AED);
    const primaryDark = Color(0xFF4C1D95);
    const bg = Color(0xFFF8FAFC);

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    final list = tracks.asData?.value ?? const <ExamGradesTrack>[];
    final total = list.length;
    final complete = list.where((t) => t.status == 'complete').length;
    final late = list.where((t) => t.status == 'late').length;
    final inProgress = total - complete;
    final avg = total == 0
        ? 0.0
        : list.map((t) => t.completionRate).reduce((a, b) => a + b) / total;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [bg, Color(0xFFF1F5F9)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Stack(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.fact_check_outlined,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'متابعة رصد الدرجات',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'لوحة متابعة احترافية لمدى إدخال درجات الطلاب حسب الصف والمادة مع مؤشرات واضحة.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _HeaderStatPill(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'الإجمالي',
                                    value: '$total',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.verified_outlined,
                                    label: 'مكتمل',
                                    value: '$complete',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.pending_actions,
                                    label: 'قيد الرصد',
                                    value: '$inProgress',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.warning_amber_rounded,
                                    label: 'متأخر',
                                    value: '$late',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.percent,
                                    label: 'المتوسط',
                                    value: '${avg.toStringAsFixed(0)}%',
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    PositionedDirectional(
                      top: 0,
                      end: 0,
                      child: _HeaderBackButton(
                        label: 'العودة للوحة',
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Wrap(
                    runSpacing: 10,
                    spacing: 10,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            'فلترة وإجراءات',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blueGrey.shade900,
                            ),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if ((_termId ?? '').trim().isNotEmpty)
                            _FilterChip(
                              label: 'الفصل: ${_termLabel(_termId!.trim())}',
                              onClear: () => setState(() => _termId = null),
                            ),
                          if ((_classId ?? '').trim().isNotEmpty)
                            _FilterChip(
                              label:
                                  'الشعبة: ${() {
                                    final id = _classId!.trim();
                                    for (final c in classes) {
                                      if (c.id == id) return c.preferredLabel;
                                    }
                                    return id;
                                  }()}',
                              onClear: () => setState(() => _classId = null),
                            ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _openTermFilter(context),
                            icon: const Icon(Icons.filter_alt_outlined),
                            label: const Text('تصفية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                          const SizedBox(width: 10),
                          OutlinedButton.icon(
                            onPressed: () => ref.invalidate(
                              gradesTrackingProvider((
                                termId: _termId,
                                classId: _classId,
                              )),
                            ),
                            icon: const Icon(Icons.refresh),
                            label: const Text('تحديث'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryDark,
                              side: BorderSide(
                                color: primaryDark.withValues(alpha: 0.35),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: tracks.asData == null
                                ? null
                                : () => _openAddEntryFromTop(context, list),
                            icon: const Icon(Icons.add),
                            label: const Text('إدخال'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            sliver: SliverToBoxAdapter(
              child: tracks.when(
                data: (items) {
                  if (items.isEmpty) {
                    return glass(
                      Padding(
                        padding: const EdgeInsets.all(18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    color: primary.withValues(alpha: 0.12),
                                  ),
                                  child: const Icon(
                                    Icons.fact_check_outlined,
                                    color: primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'لا توجد مسارات رصد لهذا الفصل',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blueGrey.shade900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'جرّب تغيير الفصل الدراسي أو التحقق من إنشاء مسارات الرصد للصفوف والمواد.',
                                        style: TextStyle(
                                          color: Colors.blueGrey.shade700,
                                          fontWeight: FontWeight.w600,
                                          height: 1.25,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            ElevatedButton.icon(
                              onPressed: () => _openTermFilter(context),
                              icon: const Icon(Icons.filter_alt_outlined),
                              label: const Text('تغيير الفصل'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryDark,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final t = items[i];
                      final meta = _statusMeta(t.status);
                      final progress = (t.completionRate / 100.0)
                          .clamp(0.0, 1.0)
                          .toDouble();

                      return glass(
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 46,
                                    height: 46,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(16),
                                      color: meta.color.withValues(alpha: 0.12),
                                    ),
                                    child: Icon(
                                      Icons.class_outlined,
                                      color: meta.color,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'فصل ${t.classId} • مادة ${t.subjectId}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Colors.blueGrey.shade900,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'إجمالي الطلاب: ${t.expectedCount} • تم الإدخال: ${t.enteredCount} • ${t.completionRate.toStringAsFixed(1)}٪',
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade700,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: meta.color.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color: meta.color.withValues(
                                          alpha: 0.35,
                                        ),
                                      ),
                                    ),
                                    child: Text(
                                      meta.label,
                                      style: TextStyle(
                                        color: meta.color,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 10,
                                  backgroundColor: Colors.black.withValues(
                                    alpha: 0.06,
                                  ),
                                  valueColor: AlwaysStoppedAnimation(
                                    meta.color,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () async {
                                        await ref.read(
                                          recalcGradesTrackProvider(
                                            t.id,
                                          ).future,
                                        );
                                        ref.invalidate(
                                          gradesTrackingProvider((
                                            termId: _termId,
                                            classId: _classId,
                                          )),
                                        );
                                      },
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('إعادة حساب'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor:
                                            Colors.blueGrey.shade900,
                                        side: BorderSide(
                                          color: Colors.black.withValues(
                                            alpha: 0.14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (_) => _AddGradeDialog(
                                            trackId: t.id,
                                            termId: t.termId,
                                            subjectId: t.subjectId,
                                            teacherId: t.teacherId,
                                          ),
                                        );
                                        ref.invalidate(
                                          gradesTrackingProvider((
                                            termId: _termId,
                                            classId: _classId,
                                          )),
                                        );
                                      },
                                      icon: const Icon(Icons.add),
                                      label: const Text('إدخال درجة'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryDark,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                        elevation: 0,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'جاري تحميل بيانات الرصد...',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.blueGrey.shade700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      height: 220,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(22),
                      ),
                    ),
                  ],
                ),
                error: (e, _) => UnifiedEmptyState(
                  message: 'خطأ: $e',
                  onRetry: () => ref.invalidate(
                    gradesTrackingProvider((
                      termId: _termId,
                      classId: _classId,
                    )),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderStatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _HeaderStatPill({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 16),
          const SizedBox(width: 8),
          Text(
            '$label: $value',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 11.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;

  const _HeaderBackButton({required this.label, required this.onPressed});

  @override
  State<_HeaderBackButton> createState() => _HeaderBackButtonState();
}

class _HeaderBackButtonState extends State<_HeaderBackButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedScale(
          scale: _hover ? 1.03 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.28),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      widget.label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final VoidCallback onClear;

  const _FilterChip({required this.label, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsetsDirectional.only(end: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.black.withValues(alpha: 0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.blueGrey.shade900,
              fontSize: 11.5,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 16, color: Colors.blueGrey.shade700),
          ),
        ],
      ),
    );
  }
}

class _PickTrackSheet extends StatefulWidget {
  final List<ExamGradesTrack> tracks;

  const _PickTrackSheet({required this.tracks});

  @override
  State<_PickTrackSheet> createState() => _PickTrackSheetState();
}

class _PickTrackSheetState extends State<_PickTrackSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final filtered = widget.tracks.where((t) {
      if (q.trim().isEmpty) return true;
      final s = q.trim();
      return t.classId.contains(s) || t.subjectId.contains(s);
    }).toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          16,
          16,
          16 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'اختر مسار الرصد',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey.shade900,
                      fontSize: 14,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              decoration: InputDecoration(
                labelText: 'بحث بالصف/المادة',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (v) => setState(() => q = v),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: ListView.separated(
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final t = filtered[i];
                  return ListTile(
                    onTap: () => Navigator.pop(context, t),
                    title: Text('فصل ${t.classId} • مادة ${t.subjectId}'),
                    subtitle: Text(
                      'الاكتمال: ${t.completionRate.toStringAsFixed(1)}٪',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TermFilterSheet extends ConsumerStatefulWidget {
  final String? initialTerm;
  final String? initialClassId;
  final void Function(String?, String?) onApply;
  const _TermFilterSheet({
    this.initialTerm,
    this.initialClassId,
    required this.onApply,
  });
  @override
  ConsumerState<_TermFilterSheet> createState() => _TermFilterSheetState();
}

class _TermFilterSheetState extends ConsumerState<_TermFilterSheet> {
  String? _selected;
  String? _selectedClassId;
  @override
  void initState() {
    super.initState();
    _selected = widget.initialTerm;
    _selectedClassId = widget.initialClassId;
  }

  @override
  Widget build(BuildContext context) {
    final termsAsync = ref.watch(examTermsProvider);
    final classesAsync = ref.watch(examClassesProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'تصفية العرض',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    color: Colors.blueGrey.shade900,
                    fontSize: 14,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const SizedBox(height: 10),
          termsAsync.when(
            data: (terms) {
              String termLabel(String termId) {
                final t = termId.trim();
                final lower = t.toLowerCase();
                if (lower == 'term1' || lower == 't1' || t == '1') {
                  return 'الفصل الأول';
                }
                if (lower == 'term2' || lower == 't2' || t == '2') {
                  return 'الفصل الثاني';
                }
                if (lower == 'term3' || lower == 't3' || t == '3') {
                  return 'الفصل الثالث';
                }
                if (lower == 'current') return 'الفصل الحالي';
                return t;
              }

              return DropdownButtonFormField<String?>(
                value: _selected,
                decoration: InputDecoration(
                  labelText: 'الفصل الدراسي',
                  prefixIcon: const Icon(Icons.event_note_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('الكل'),
                  ),
                  ...terms.map(
                    (t) => DropdownMenuItem<String?>(
                      value: t,
                      child: Text(termLabel(t)),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selected = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => DropdownButtonFormField<String?>(
              value: _selected,
              decoration: InputDecoration(
                labelText: 'الفصل الدراسي',
                prefixIcon: const Icon(Icons.event_note_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('الكل')),
              ],
              onChanged: (v) => setState(() => _selected = v),
            ),
          ),
          const SizedBox(height: 10),
          classesAsync.when(
            data: (classes) {
              return DropdownButtonFormField<String?>(
                value: _selectedClassId,
                decoration: InputDecoration(
                  labelText: 'الفصل/الشعبة',
                  prefixIcon: const Icon(Icons.class_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('الكل'),
                  ),
                  ...classes.map(
                    (c) => DropdownMenuItem<String?>(
                      value: c.id,
                      child: Text(c.preferredLabel),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _selectedClassId = v),
              );
            },
            loading: () => const LinearProgressIndicator(),
            error: (_, __) => DropdownButtonFormField<String?>(
              value: _selectedClassId,
              decoration: InputDecoration(
                labelText: 'الفصل/الشعبة',
                prefixIcon: const Icon(Icons.class_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('الكل')),
              ],
              onChanged: (v) => setState(() => _selectedClassId = v),
            ),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () {
              widget.onApply(_selected, _selectedClassId);
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _AddGradeDialog extends ConsumerStatefulWidget {
  final String trackId;
  final String termId;
  final String subjectId;
  final String teacherId;
  const _AddGradeDialog({
    required this.trackId,
    required this.termId,
    required this.subjectId,
    required this.teacherId,
  });
  @override
  ConsumerState<_AddGradeDialog> createState() => _AddGradeDialogState();
}

class _AddGradeDialogState extends ConsumerState<_AddGradeDialog> {
  final _student = TextEditingController();
  final _score = TextEditingController();
  String? _error;
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة درجة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(labelText: 'معرّف الطالب'),
            controller: _student,
          ),
          TextField(
            decoration: const InputDecoration(labelText: 'الدرجة'),
            controller: _score,
            keyboardType: TextInputType.number,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              final s = double.tryParse(_score.text) ?? 0.0;
              await ref.read(
                addGradeEntryProvider(
                  AddGradeEntryParams(
                    trackId: widget.trackId,
                    studentId: _student.text,
                    subjectId: widget.subjectId,
                    termId: widget.termId,
                    teacherId: widget.teacherId,
                    score: s,
                  ),
                ).future,
              );
              if (mounted) Navigator.pop(context);
            } catch (e) {
              setState(() => _error = e.toString());
            }
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}
