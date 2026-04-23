import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../exams_providers.dart';
import '../../data/firestore_exams_repository.dart';
import '../../../academic/domain/classroom.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';

class ExamAbsenceTab extends ConsumerStatefulWidget {
  const ExamAbsenceTab({super.key});
  @override
  ConsumerState<ExamAbsenceTab> createState() => _ExamAbsenceTabState();
}

class _ExamAbsenceTabState extends ConsumerState<ExamAbsenceTab> {
  String? _termId;
  String? _classId;
  String? _subjectId;
  DateTime? _date;

  String _termLabel(String termId) {
    final t = termId.trim();
    final lower = t.toLowerCase();
    if (lower == 'term1' || lower == 't1' || t == '1') return 'الفصل الأول';
    if (lower == 'term2' || lower == 't2' || t == '2') return 'الفصل الثاني';
    if (lower == 'term3' || lower == 't3' || t == '3') return 'الفصل الثالث';
    if (lower == 'current') return 'الفصل الحالي';
    return t;
  }

  Future<void> _openFilters(BuildContext context) async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      builder: (_) => _AbsenceFilterSheet(
        initialTermId: _termId,
        initialClassId: _classId,
        initialSubjectId: _subjectId,
        initialDate: _date,
        onApply: (t, c, s, d) => setState(() {
          _termId = t;
          _classId = c;
          _subjectId = s;
          _date = d;
        }),
      ),
    );
    ref.invalidate(
      examAttendanceProvider(
        ExamScheduleFilters(
          termId: _termId,
          classId: _classId,
          subjectId: _subjectId,
          date: _date,
        ),
      ),
    );
  }

  Future<void> _openRecordDialog(BuildContext context) async {
    await showDialog(
      context: context,
      builder: (_) => const _RecordAbsenceDialog(),
    );
    ref.invalidate(
      examAttendanceProvider(
        ExamScheduleFilters(
          termId: _termId,
          classId: _classId,
          subjectId: _subjectId,
          date: _date,
        ),
      ),
    );
  }

  ({String label, Color color, IconData icon}) _statusMeta(String status) {
    if (status == 'present') {
      return (
        label: 'حاضر',
        color: const Color(0xFF22C55E),
        icon: Icons.check_circle_outline,
      );
    }
    if (status == 'late') {
      return (
        label: 'متأخر',
        color: const Color(0xFFF59E0B),
        icon: Icons.access_time,
      );
    }
    if (status.contains('excused')) {
      return (
        label: 'غائب بعذر',
        color: const Color(0xFF0EA5E9),
        icon: Icons.event_available,
      );
    }
    return (
      label: 'غائب بدون عذر',
      color: const Color(0xFFEF4444),
      icon: Icons.person_off,
    );
  }

  @override
  Widget build(BuildContext context) {
    final recordsAsync = ref.watch(
      examAttendanceProvider(
        ExamScheduleFilters(
          termId: _termId,
          classId: _classId,
          subjectId: _subjectId,
          date: _date,
        ),
      ),
    );
    final classes =
        ref.watch(examClassesProvider).asData?.value ?? const <Classroom>[];
    final records =
        recordsAsync.asData?.value ?? const <ExamAttendanceRecord>[];

    const primary = Color(0xFF0EA5E9);
    const primaryDark = Color(0xFF1D4ED8);
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

    final total = records.length;
    final present = records.where((r) => r.status == 'present').length;
    final late = records.where((r) => r.status == 'late').length;
    final excused = records.where((r) => r.status.contains('excused')).length;
    final absent = records
        .where(
          (r) =>
              r.status != 'present' &&
              r.status != 'late' &&
              !r.status.contains('excused'),
        )
        .length;

    String classLabel(String id) {
      final key = id.trim();
      for (final c in classes) {
        if (c.id == key) return c.preferredLabel;
      }
      return key;
    }

    String dateLabel(DateTime d) => d.toString().split(' ').first;

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
                            Icons.person_off,
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
                                'غياب الاختبارات',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'لوحة متابعة حضور/غياب الاختبارات مع مؤشرات واضحة وفرز سريع.',
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
                                    icon: Icons.check_circle_outline,
                                    label: 'حاضر',
                                    value: '$present',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.access_time,
                                    label: 'متأخر',
                                    value: '$late',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.event_available,
                                    label: 'بعذر',
                                    value: '$excused',
                                  ),
                                  _HeaderStatPill(
                                    icon: Icons.person_off,
                                    label: 'بدون عذر',
                                    value: '$absent',
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
                              label: 'الشعبة: ${classLabel(_classId!)}',
                              onClear: () => setState(() => _classId = null),
                            ),
                          if ((_subjectId ?? '').trim().isNotEmpty)
                            _FilterChip(
                              label: 'المادة: ${_subjectId!.trim()}',
                              onClear: () => setState(() => _subjectId = null),
                            ),
                          if (_date != null)
                            _FilterChip(
                              label: 'التاريخ: ${dateLabel(_date!)}',
                              onClear: () => setState(() => _date = null),
                            ),
                          const SizedBox(width: 10),
                          ElevatedButton.icon(
                            onPressed: () => _openFilters(context),
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
                              examAttendanceProvider(
                                ExamScheduleFilters(
                                  termId: _termId,
                                  classId: _classId,
                                  subjectId: _subjectId,
                                  date: _date,
                                ),
                              ),
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
                            onPressed: () => _openRecordDialog(context),
                            icon: const Icon(Icons.person_off),
                            label: const Text('تسجيل غياب'),
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
              child: recordsAsync.when(
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
                                    Icons.person_off,
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
                                        'لا توجد سجلات لعرضها',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: Colors.blueGrey.shade900,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'جرّب تغيير التصفية أو قم بتسجيل غياب جديد.',
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
                              onPressed: () => _openRecordDialog(context),
                              icon: const Icon(Icons.person_off),
                              label: const Text('تسجيل غياب'),
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
                      final r = items[i];
                      final meta = _statusMeta(r.status);
                      final dl = dateLabel(r.recordedAt);
                      return glass(
                        Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: meta.color.withValues(alpha: 0.12),
                                ),
                                child: Icon(meta.icon, color: meta.color),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'طالب ${r.studentId} • ${classLabel(r.classId)}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        color: Colors.blueGrey.shade900,
                                        fontSize: 14,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '$dl • مادة ${r.subjectId} • ${meta.label}',
                                      style: TextStyle(
                                        color: Colors.blueGrey.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              if (r.excuseDocUrl != null)
                                const Icon(Icons.attachment, size: 18),
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
                      'جاري تحميل سجلات الغياب...',
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
                    examAttendanceProvider(
                      ExamScheduleFilters(
                        termId: _termId,
                        classId: _classId,
                        subjectId: _subjectId,
                        date: _date,
                      ),
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
}

class _AbsenceFilterSheet extends ConsumerStatefulWidget {
  final String? initialTermId;
  final String? initialClassId;
  final String? initialSubjectId;
  final DateTime? initialDate;
  final void Function(String?, String?, String?, DateTime?) onApply;
  const _AbsenceFilterSheet({
    this.initialTermId,
    this.initialClassId,
    this.initialSubjectId,
    this.initialDate,
    required this.onApply,
  });
  @override
  ConsumerState<_AbsenceFilterSheet> createState() =>
      _AbsenceFilterSheetState();
}

class _AbsenceFilterSheetState extends ConsumerState<_AbsenceFilterSheet> {
  String? _termId;
  String? _classId;
  late TextEditingController _termCtrl;
  late TextEditingController _subjectCtrl;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _termId = widget.initialTermId;
    _classId = widget.initialClassId;
    _termCtrl = TextEditingController(text: widget.initialTermId ?? '');
    _subjectCtrl = TextEditingController(text: widget.initialSubjectId ?? '');
    _date = widget.initialDate;
  }

  @override
  void dispose() {
    _termCtrl.dispose();
    _subjectCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String termLabel(String termId) {
      final t = termId.trim();
      final lower = t.toLowerCase();
      if (lower == 'term1' || lower == 't1' || t == '1') return 'الفصل الأول';
      if (lower == 'term2' || lower == 't2' || t == '2') return 'الفصل الثاني';
      if (lower == 'term3' || lower == 't3' || t == '3') return 'الفصل الثالث';
      if (lower == 'current') return 'الفصل الحالي';
      return t;
    }

    final termsAsync = ref.watch(examTermsProvider);
    final classesAsync = ref.watch(examClassesProvider);
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
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'تصفية الغياب',
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
                if (terms.isEmpty) {
                  return TextField(
                    controller: _termCtrl,
                    decoration: InputDecoration(
                      labelText: 'الفصل الدراسي (اختياري)',
                      prefixIcon: const Icon(Icons.event_note_outlined),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    textDirection: TextDirection.ltr,
                  );
                }
                return DropdownButtonFormField<String?>(
                  value: _termId,
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
                  onChanged: (v) => setState(() => _termId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            classesAsync.when(
              data: (classes) => DropdownButtonFormField<String?>(
                value: _classId,
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
                onChanged: (v) => setState(() => _classId = v),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _subjectCtrl,
              decoration: InputDecoration(
                labelText: 'المادة (اختياري)',
                prefixIcon: const Icon(Icons.book_outlined),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date ?? DateTime(now.year, now.month, now.day),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(now.year + 2),
                );
                if (picked == null) return;
                setState(() {
                  _date = DateTime(picked.year, picked.month, picked.day);
                });
              },
              icon: const Icon(Icons.event),
              label: Text(
                _date == null
                    ? 'تحديد تاريخ'
                    : _date!.toString().split(' ').first,
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () {
                widget.onApply(
                  _termId ??
                      (_termCtrl.text.trim().isEmpty
                          ? null
                          : _termCtrl.text.trim()),
                  _classId,
                  _subjectCtrl.text.trim().isEmpty
                      ? null
                      : _subjectCtrl.text.trim(),
                  _date,
                );
                Navigator.pop(context);
              },
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordAbsenceDialog extends ConsumerStatefulWidget {
  const _RecordAbsenceDialog();
  @override
  ConsumerState<_RecordAbsenceDialog> createState() =>
      _RecordAbsenceDialogState();
}

class _RecordAbsenceDialogState extends ConsumerState<_RecordAbsenceDialog> {
  String? _termId;
  String? _classId;
  final _termCtrl = TextEditingController();
  final _schedule = TextEditingController();
  final _student = TextEditingController();
  final _subject = TextEditingController();
  String _status = 'absent_unexcused';
  final _docUrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _termCtrl.dispose();
    _schedule.dispose();
    _student.dispose();
    _subject.dispose();
    _docUrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    String termLabel(String termId) {
      final t = termId.trim();
      final lower = t.toLowerCase();
      if (lower == 'term1' || lower == 't1' || t == '1') return 'الفصل الأول';
      if (lower == 'term2' || lower == 't2' || t == '2') return 'الفصل الثاني';
      if (lower == 'term3' || lower == 't3' || t == '3') return 'الفصل الثالث';
      if (lower == 'current') return 'الفصل الحالي';
      return t;
    }

    final termsAsync = ref.watch(examTermsProvider);
    final classesAsync = ref.watch(examClassesProvider);
    return AlertDialog(
      title: const Text('تسجيل غياب اختبار'),
      content: SingleChildScrollView(
        child: Column(
          children: [
            termsAsync.when(
              data: (terms) {
                if (terms.isEmpty) {
                  return TextField(
                    controller: _termCtrl,
                    decoration: const InputDecoration(
                      labelText: 'الفصل الدراسي',
                    ),
                    textDirection: TextDirection.ltr,
                  );
                }
                return DropdownButtonFormField<String?>(
                  value: _termId,
                  items: terms
                      .map(
                        (t) => DropdownMenuItem<String?>(
                          value: t,
                          child: Text(termLabel(t)),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _termId = v),
                  decoration: const InputDecoration(labelText: 'الفصل الدراسي'),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            classesAsync.when(
              data: (classes) => DropdownButtonFormField<String?>(
                value: _classId,
                items: classes
                    .map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.preferredLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _classId = v),
                decoration: const InputDecoration(labelText: 'الفصل/الشعبة'),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'معرّف جدول الاختبار',
                hintText: 'انسخ المعرف من جدول الاختبارات',
              ),
              controller: _schedule,
              textDirection: TextDirection.ltr,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'معرّف الطالب',
                hintText: 'اكتب معرف الطالب المستخدم في النظام',
              ),
              controller: _student,
              textDirection: TextDirection.ltr,
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'رمز المادة',
                hintText: 'اكتب رمز المادة كما في جدول المواد',
              ),
              controller: _subject,
              textDirection: TextDirection.ltr,
            ),
            DropdownButtonFormField<String>(
              value: _status,
              items: const [
                DropdownMenuItem(value: 'present', child: Text('حاضر')),
                DropdownMenuItem(value: 'late', child: Text('متأخر')),
                DropdownMenuItem(
                  value: 'absent_excused',
                  child: Text('غائب بعذر'),
                ),
                DropdownMenuItem(
                  value: 'absent_unexcused',
                  child: Text('غائب بدون عذر'),
                ),
              ],
              onChanged: (v) => setState(() => _status = v ?? _status),
              decoration: const InputDecoration(labelText: 'الحالة'),
            ),
            TextField(
              decoration: const InputDecoration(
                labelText: 'رابط العذر (اختياري)',
              ),
              controller: _docUrl,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              if ((_termId ?? '').trim().isEmpty) {
                final t = _termCtrl.text.trim();
                if (t.isEmpty) {
                  setState(() => _error = 'اختر الفصل الدراسي');
                  return;
                }
                _termId = t;
              }
              if ((_classId ?? '').trim().isEmpty) {
                setState(() => _error = 'اختر الفصل/الشعبة');
                return;
              }
              if (_schedule.text.trim().isEmpty ||
                  _student.text.trim().isEmpty ||
                  _subject.text.trim().isEmpty) {
                setState(() => _error = 'أكمل الحقول المطلوبة');
                return;
              }
              await ref.read(
                recordExamAttendanceProvider(
                  RecordExamAttendanceParams(
                    termId: (_termId ?? '').trim(),
                    scheduleId: _schedule.text,
                    studentId: _student.text,
                    classId: (_classId ?? '').trim(),
                    subjectId: _subject.text,
                    status: _status,
                    excuseDocUrl: _docUrl.text.isEmpty ? null : _docUrl.text,
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
