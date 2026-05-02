/// excel_import_wizard.dart
/// Wizard استيراد جدول Excel — تصميم Obsidian Premium
library;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as excel;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cross_file/cross_file.dart';
import '../services/subject_matcher.dart';

// ─── Palette ─────────────────────────────────────────────────────────────────
class _C {
  static const bg        = Color(0xFF0A0A0F);
  static const surface   = Color(0xFF13131A);
  static const card      = Color(0xFF1C1C28);
  static const violet    = Color(0xFF7C3AED);
  static const violetLt  = Color(0xFFA78BFA);
  static const amber     = Color(0xFFF59E0B);
  static const emerald   = Color(0xFF10B981);
  static const sky       = Color(0xFF38BDF8);
  static const rose      = Color(0xFFF43F5E);
  static const border    = Color(0xFF2D2D3F);
  static const text      = Color(0xFFF1F5F9);
  static const textMuted = Color(0xFF64748B);
}

enum ImportStep { upload, analyze, review, confirm }

class ImportedLesson {
  final String teacherName;
  final String rawSubject;
  SubjectMatchResult matchResult;
  final String className;
  final String dayName;
  final int dayIndex;
  final int period;

  ImportedLesson({
    required this.teacherName,
    required this.rawSubject,
    required this.matchResult,
    required this.className,
    required this.dayName,
    required this.dayIndex,
    required this.period,
  });

  String get resolvedSubject => matchResult.matched?.officialName ?? rawSubject;
}

class ExcelImportWizard extends StatefulWidget {
  final String schoolId;
  final VoidCallback onImportComplete;
  const ExcelImportWizard({super.key, required this.schoolId, required this.onImportComplete});
  @override
  State<ExcelImportWizard> createState() => _ExcelImportWizardState();
}

class _ExcelImportWizardState extends State<ExcelImportWizard>
    with SingleTickerProviderStateMixin {
  ImportStep _step = ImportStep.upload;
  bool _isLoading = false;
  String _fileName = '';
  excel.Excel? _workbook;
  List<ImportedLesson> _allLessons = [];
  List<ImportedLesson> _reviewLessons = [];
  Map<String, int> _subjectStats = {};
  int _knownCount = 0;
  int _unknownCount = 0;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  final List<String> _days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس'];

  @override
  void initState() {
    super.initState();
    SubjectMatcher.loadFromFirestore(widget.schoolId);
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile() async {
    setState(() => _isLoading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
          type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);
      if (result == null) { setState(() => _isLoading = false); return; }
      final pf = result.files.first;
      final bytes = kIsWeb ? pf.bytes! : (pf.bytes ?? await XFile(pf.path!).readAsBytes());
      _workbook = excel.Excel.decodeBytes(bytes);
      _fileName = pf.name;
      setState(() { _isLoading = false; _step = ImportStep.analyze; });
      await _analyzeFile();
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('فشل قراءة الملف');
    }
  }

  Future<void> _analyzeFile() async {
    if (_workbook == null) return;
    setState(() => _isLoading = true);
    try {
      final sheetName = _workbook!.tables.keys.first;
      final sheet = _workbook!.tables[sheetName]!;
      if (sheet.rows.length < 3) { _showError('الملف لا يحتوي على بيانات كافية'); setState(() => _isLoading = false); return; }
      final dayRow = sheet.rows[1];
      final periodRow = sheet.rows[2];
      final colInfo = <int, Map<String, dynamic>>{};
      String currentDay = '';
      for (var c = 1; c < dayRow.length; c++) {
        final dv = dayRow[c]?.value?.toString().trim() ?? '';
        if (_days.contains(dv)) currentDay = dv;
        final pv = periodRow.length > c ? periodRow[c]?.value?.toString().trim() : null;
        final period = int.tryParse(pv ?? '');
        if (currentDay.isNotEmpty && period != null) colInfo[c] = {'day': currentDay, 'period': period};
      }
      final lessons = <ImportedLesson>[];
      final rawSubjects = <String>{};
      for (var r = 3; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;
        final teacherName = row[0]?.value?.toString().trim() ?? '';
        if (teacherName.isEmpty) continue;
        for (var c = 1; c < row.length; c++) {
          final info = colInfo[c]; if (info == null) continue;
          final rawVal = row[c]?.value;
          if (rawVal == null) continue;
          final content = rawVal.toString().trim();
          if (content.isEmpty) continue;
          if (content.startsWith('=') || content.contains('COUNTIF') ||
              content.contains('COUNTA') || content.contains('SUM(') ||
              content.contains('IF(') || content.contains('VLOOKUP')) continue;
          if (RegExp(r'^[\d\.\,\s]+\$').hasMatch(content)) continue;
          if (content.length <= 1) continue;
          String subject = content; String className = '';
          if (content.contains('\n')) { final pts = content.split('\n'); className = pts[0].trim(); subject = pts.length > 1 ? pts[1].trim() : pts[0].trim(); }
          else if (content.contains('-')) { final pts = content.split('-'); className = pts[0].trim(); subject = pts.length > 1 ? pts[1].trim() : pts[0].trim(); }
          rawSubjects.add(subject);
          final dayName = info['day'] as String;
          final dayIndex = _days.indexOf(dayName);
          lessons.add(ImportedLesson(teacherName: teacherName, rawSubject: subject,
            matchResult: SubjectMatcher.match(subject), className: className,
            dayName: dayName, dayIndex: dayIndex >= 0 ? dayIndex : 0, period: info['period'] as int));
        }
      }
      _knownCount = rawSubjects.where((s) => !SubjectMatcher.match(s).needsReview).length;
      _unknownCount = rawSubjects.where((s) => SubjectMatcher.match(s).needsReview).length;
      _subjectStats = {};
      for (final s in rawSubjects) { _subjectStats[s] = (_subjectStats[s] ?? 0) + 1; }
      final reviewSubjects = rawSubjects.where((s) => SubjectMatcher.match(s).needsReview).toSet();
      _reviewLessons = reviewSubjects.map((s) => lessons.firstWhere((l) => l.rawSubject == s)).toList();
      _allLessons = lessons;
      setState(() { _isLoading = false; _step = _reviewLessons.isEmpty ? ImportStep.confirm : ImportStep.review; });
    } catch (e) { setState(() => _isLoading = false); _showError('خطأ في التحليل'); }
  }

  Future<void> _executeImport() async {
    setState(() => _isLoading = true);
    try {
      final classesSnap = await FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('Classes').get();
      final classNameToId = <String, String>{};
      for (final cls in classesSnap.docs) {
        final data = cls.data(); final name = (data['name'] ?? '').toString().trim();
        if (name.isNotEmpty) { classNameToId[name] = cls.id; classNameToId[name.replaceAll(' ', '')] = cls.id; }
      }
      final teachersSnap = await FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('Teachers').get();
      final teacherNameToId = <String, String>{};
      for (final t in teachersSnap.docs) { final name = (t.data()['name'] ?? '').toString().trim(); if (name.isNotEmpty) teacherNameToId[name] = t.id; }
      final teacherLessons = <String, List<Map<String, dynamic>>>{};
      final classLessons = <String, List<Map<String, dynamic>>>{};
      for (final lesson in _allLessons) {
        final classId = classNameToId[lesson.className] ?? classNameToId[lesson.className.replaceAll(' ', '')];
        final lessonMap = {'period': lesson.period, 'dayIndex': lesson.dayIndex, 'dayName': lesson.dayName, 'day': lesson.dayName,
          'subject': lesson.resolvedSubject, 'rawSubject': lesson.rawSubject, 'className': lesson.className, 'teacherName': lesson.teacherName,
          if (classId != null) 'classId': classId};
        teacherLessons.putIfAbsent(lesson.teacherName, () => []).add(lessonMap);
        if (classId != null) classLessons.putIfAbsent(classId, () => []).add(lessonMap);
      }
      await FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('GeneralSchedule').add(
          {'teacherSchedules': teacherLessons, 'source': 'excel_import_wizard', 'status': 'approved', 'createdAt': FieldValue.serverTimestamp()});
      for (final entry in teacherLessons.entries) {
        String? tid = teacherNameToId[entry.key];
        if (tid == null) { for (final e in teacherNameToId.entries) { if (entry.key.contains(e.key) || e.key.contains(entry.key)) { tid = e.value; break; } } }
        if (tid == null) continue;
        await FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('Teachers').doc(tid)
            .update({'schedule': entry.value, 'scheduleUpdatedAt': FieldValue.serverTimestamp()});
        await FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('TeacherSchedules').doc(tid)
            .set({'slots': entry.value, 'updatedAt': FieldValue.serverTimestamp(), 'source': 'excel_import_wizard'});
      }
      for (final entry in classLessons.entries) {
        await FirebaseFirestore.instance.collection('Schools').doc(widget.schoolId).collection('Classes').doc(entry.key)
            .collection('ClassSchedules').add({'lessons': entry.value, 'source': 'excel_import_wizard', 'status': 'approved', 'createdAt': FieldValue.serverTimestamp()});
      }
      setState(() => _isLoading = false);
      widget.onImportComplete();
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) { setState(() => _isLoading = false); _showError('فشل الاستيراد'); }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: _C.rose,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))));
  }

  // ─── BUILD ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 760,
        constraints: const BoxConstraints(maxHeight: 740),
        decoration: BoxDecoration(
          color: _C.bg,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _C.violet.withOpacity(0.25), width: 1),
          boxShadow: [
            BoxShadow(color: _C.violet.withOpacity(0.15), blurRadius: 60, spreadRadius: -10),
            BoxShadow(color: Colors.black.withOpacity(0.6), blurRadius: 30),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(),
              _buildStepRail(),
              Flexible(child: _buildStepContent()),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ──────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.violet.withOpacity(0.18), _C.surface],
          begin: Alignment.centerRight, end: Alignment.centerLeft),
        border: Border(bottom: BorderSide(color: _C.border)),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [_C.violet, _C.sky], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [BoxShadow(color: _C.violet.withOpacity(0.4), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: const Icon(Icons.table_chart_rounded, color: Colors.white, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('استيراد جدول Excel', style: TextStyle(color: _C.text, fontSize: 17, fontWeight: FontWeight.bold)),
          Text('مطابقة ذكية للمواد مع حفظ تلقائي للمرادفات',
              style: TextStyle(color: _C.textMuted, fontSize: 11)),
        ])),
        IconButton(
          icon: Icon(Icons.close_rounded, color: _C.textMuted),
          onPressed: () => Navigator.of(context).pop(),
          style: IconButton.styleFrom(backgroundColor: _C.card),
        ),
      ]),
    );
  }

  // ─── Step Rail ───────────────────────────────────────────────────────────
  Widget _buildStepRail() {
    final steps = [
      (Icons.upload_file_rounded, 'رفع الملف'),
      (Icons.analytics_rounded, 'تحليل'),
      (Icons.rate_review_rounded, 'مراجعة'),
      (Icons.rocket_launch_rounded, 'استيراد'),
    ];
    final idx = _step.index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      color: _C.surface,
      child: Row(children: List.generate(steps.length, (i) {
        final done = i < idx;
        final active = i == idx;
        final color = done ? _C.emerald : active ? _C.violet : _C.border;
        return Expanded(child: Row(children: [
          Expanded(child: Column(children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: active ? 36 : 30, height: active ? 36 : 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? _C.emerald.withOpacity(0.15) : active ? _C.violet.withOpacity(0.15) : Colors.transparent,
                border: Border.all(color: color, width: active ? 2 : 1),
                boxShadow: active ? [BoxShadow(color: _C.violet.withOpacity(0.4), blurRadius: 12)] : [],
              ),
              child: Center(child: done
                  ? Icon(Icons.check_rounded, color: _C.emerald, size: 14)
                  : Icon(steps[i].$1, color: active ? _C.violetLt : _C.textMuted, size: active ? 16 : 13)),
            ),
            const SizedBox(height: 5),
            Text(steps[i].$2, style: TextStyle(
                color: active ? _C.violetLt : done ? _C.emerald : _C.textMuted,
                fontSize: 10, fontWeight: active ? FontWeight.bold : FontWeight.normal),
                textAlign: TextAlign.center),
          ])),
          if (i < steps.length - 1)
            Expanded(child: Container(
              height: 1, margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  done ? _C.emerald : _C.border,
                  i + 1 <= idx ? _C.emerald : _C.border,
                ])),
            )),
        ]));
      })),
    );
  }

  Widget _buildStepContent() {
    if (_isLoading) return _buildLoadingState();
    switch (_step) {
      case ImportStep.upload:  return _buildUploadStep();
      case ImportStep.analyze: return _buildAnalyzeStep();
      case ImportStep.review:  return _buildReviewStep();
      case ImportStep.confirm: return _buildConfirmStep();
    }
  }

  Widget _buildLoadingState() {
    return Center(child: Padding(
      padding: const EdgeInsets.all(60),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 72, height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _C.violet.withOpacity(_pulseAnim.value), width: 2),
              boxShadow: [BoxShadow(color: _C.violet.withOpacity(_pulseAnim.value * 0.4), blurRadius: 24)],
            ),
            child: const Center(child: CircularProgressIndicator(
              color: _C.violetLt, strokeWidth: 2)),
          ),
        ),
        const SizedBox(height: 20),
        const Text('جاري التحليل الذكي...', style: TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        Text('يتم مطابقة المواد مع قاعدة البيانات', style: TextStyle(color: _C.textMuted, fontSize: 12)),
      ]),
    ));
  }

  // ─── STEP 1: Upload ──────────────────────────────────────────────────────
  Widget _buildUploadStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(32),
      child: Column(children: [
        const SizedBox(height: 8),
        // Drop zone
        GestureDetector(
          onTap: _pickFile,
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (_, __) => Container(
              width: double.infinity, height: 180,
              decoration: BoxDecoration(
                color: _C.card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _C.violet.withOpacity(0.3 + _pulseAnim.value * 0.2), width: 1.5,
                  style: BorderStyle.solid),
                boxShadow: [BoxShadow(color: _C.violet.withOpacity(_pulseAnim.value * 0.08), blurRadius: 30)],
              ),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_C.violet.withOpacity(0.2), _C.sky.withOpacity(0.1)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.violet.withOpacity(0.4)),
                  ),
                  child: const Icon(Icons.cloud_upload_rounded, color: _C.violetLt, size: 30),
                ),
                const SizedBox(height: 14),
                const Text('اسحب الملف هنا أو اضغط للاختيار',
                    style: TextStyle(color: _C.text, fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 6),
                Text('يدعم .xlsx و .xls', style: TextStyle(color: _C.textMuted, fontSize: 12)),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Format guide
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: _C.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _C.border),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(width: 3, height: 16, decoration: BoxDecoration(color: _C.amber, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 8),
              const Text('تنسيق الملف المطلوب', style: TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 13)),
            ]),
            const SizedBox(height: 12),
            _formatRow('1', 'الصف الأول', 'عناوين الأعمدة', _C.textMuted),
            _formatRow('2', 'الصف الثاني', 'أسماء الأيام (الاحد، الاثنين...)', _C.sky),
            _formatRow('3', 'الصف الثالث', 'أرقام الحصص (1، 2، 3...)', _C.amber),
            _formatRow('4+', 'الصفوف التالية', 'اسم المعلم + بيانات الحصص', _C.emerald),
          ]),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: _primaryBtn('اختيار الملف', Icons.folder_open_rounded, _pickFile, _C.violet)),
      ]),
    );
  }

  Widget _formatRow(String num, String label, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.4))),
          child: Center(child: Text(num, style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.bold))),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: _C.text, fontSize: 12, fontWeight: FontWeight.w500)),
        const SizedBox(width: 6),
        Text('— $desc', style: TextStyle(color: _C.textMuted, fontSize: 11)),
      ]),
    );
  }

  // ─── STEP 2: Analyze ─────────────────────────────────────────────────────
  Widget _buildAnalyzeStep() {
    final total = _subjectStats.length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // File badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _C.card, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _C.border)),
          child: Row(children: [
            const Icon(Icons.insert_drive_file_rounded, color: _C.emerald, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(_fileName, style: const TextStyle(color: _C.text, fontSize: 13), overflow: TextOverflow.ellipsis)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: _C.emerald.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
              child: const Text('تم التحليل', style: TextStyle(color: _C.emerald, fontSize: 10))),
          ]),
        ),
        const SizedBox(height: 20),
        // Stats row
        Row(children: [
          _glowStat(total.toString(), 'مادة مكتشفة', _C.sky, Icons.auto_awesome),
          const SizedBox(width: 12),
          _glowStat(_knownCount.toString(), 'معروفة', _C.emerald, Icons.check_circle_rounded),
          const SizedBox(width: 12),
          _glowStat(_unknownCount.toString(), 'تحتاج مراجعة',
              _unknownCount > 0 ? _C.amber : _C.emerald, Icons.pending_rounded),
        ]),
        const SizedBox(height: 20),
        Row(children: [
          Container(width: 3, height: 14, decoration: BoxDecoration(color: _C.violet, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          const Text('المواد المكتشفة', style: TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        ..._subjectStats.entries.map((e) => _subjectRow(e.key, SubjectMatcher.match(e.key), e.value)),
        const SizedBox(height: 20),
        SizedBox(width: double.infinity, child: _primaryBtn(
          _reviewLessons.isEmpty ? 'متابعة للتأكيد' : 'مراجعة المواد غير المعروفة',
          Icons.arrow_forward_rounded,
          () => setState(() => _step = _reviewLessons.isEmpty ? ImportStep.confirm : ImportStep.review),
          _C.violet)),
      ]),
    );
  }

  Widget _glowStat(String value, String label, Color color, IconData icon) {
    return Expanded(child: Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 20)],
      ),
      child: Column(children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 28, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: color.withOpacity(0.5), blurRadius: 8)])),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: _C.textMuted, fontSize: 10), textAlign: TextAlign.center),
      ]),
    ));
  }

  Widget _subjectRow(String raw, SubjectMatchResult result, int count) {
    Color color; String badge; IconData icon;
    if (result.confidence == MatchConfidence.high) { color = _C.emerald; badge = 'معروفة'; icon = Icons.check_circle_rounded; }
    else if (result.confidence == MatchConfidence.medium) { color = _C.amber; badge = 'مقترحة'; icon = Icons.help_rounded; }
    else { color = _C.rose; badge = 'غير معروفة'; icon = Icons.error_rounded; }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        Icon(icon, color: color, size: 15),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(raw, style: const TextStyle(color: _C.text, fontWeight: FontWeight.w600, fontSize: 13)),
          if (result.matched != null)
            Text('→ ' + result.matched!.officialName, style: TextStyle(color: color, fontSize: 11)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(20)),
          child: Text(badge, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600)),
        ),
        const SizedBox(width: 8),
        Text(count.toString() + ' حصة', style: const TextStyle(color: _C.textMuted, fontSize: 10)),
      ]),
    );
  }

  // ─── STEP 3: Review ──────────────────────────────────────────────────────
  Widget _buildReviewStep() {
    return Column(children: [
      Container(
        margin: const EdgeInsets.fromLTRB(24, 18, 24, 0),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _C.amber.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _C.amber.withOpacity(0.25)),
        ),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(color: _C.amber.withOpacity(0.15), shape: BoxShape.circle),
            child: const Icon(Icons.rate_review_rounded, color: _C.amber, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_reviewLessons.length.toString() + ' مادة تحتاج تحديد يدوي',
                style: const TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 14)),
            const Text('كل تصحيح يُحفظ تلقائياً للمرات القادمة',
                style: TextStyle(color: _C.textMuted, fontSize: 11)),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      Expanded(child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        itemCount: _reviewLessons.length,
        itemBuilder: (context, i) => _buildReviewCard(_reviewLessons[i]),
      )),
      Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(width: double.infinity, child: _primaryBtn(
          'تأكيد المراجعة والمتابعة', Icons.check_rounded,
          () => setState(() => _step = ImportStep.confirm), _C.emerald)),
      ),
    ]);
  }

  Widget _buildReviewCard(ImportedLesson lesson) {
    final isResolved = lesson.matchResult.matched != null;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: isResolved ? _C.emerald.withOpacity(0.3) : _C.amber.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isResolved ? _C.emerald.withOpacity(0.06) : _C.amber.withOpacity(0.06),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          ),
          child: Row(children: [
            Icon(isResolved ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                color: isResolved ? _C.emerald : _C.amber, size: 16),
            const SizedBox(width: 8),
            Text('"' + lesson.rawSubject + '"',
                style: const TextStyle(color: _C.text, fontWeight: FontWeight.bold, fontSize: 14)),
            if (isResolved) ...[
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, color: _C.textMuted, size: 12),
              const SizedBox(width: 4),
              Text(lesson.matchResult.matched!.officialName,
                  style: const TextStyle(color: _C.emerald, fontSize: 12)),
            ],
          ]),
        ),
        Padding(
          padding: const EdgeInsets.all(14),
          child: DropdownButtonFormField<String>(
            value: lesson.matchResult.matched?.id,
            dropdownColor: _C.surface,
            style: const TextStyle(color: _C.text, fontSize: 13),
            decoration: InputDecoration(
              labelText: 'اختر التصنيف الصحيح',
              labelStyle: const TextStyle(color: _C.textMuted, fontSize: 12),
              filled: true, fillColor: _C.surface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _C.violet, width: 1.5)),
            ),
            items: [
              const DropdownMenuItem<String>(value: null, child: Text('-- غير محدد --', style: TextStyle(color: _C.textMuted))),
              ...SubjectMatcher.defaultSubjects.map((s) => DropdownMenuItem(
                value: s.id, child: Text(s.officialName, style: const TextStyle(color: _C.text)))),
            ],
            onChanged: (id) {
              if (id == null) return;
              final master = SubjectMatcher.findById(id);
              if (master == null) return;
              setState(() {
                lesson.matchResult = SubjectMatchResult(rawName: lesson.rawSubject, matched: master, confidence: MatchConfidence.high);
                for (final l in _allLessons) { if (l.rawSubject == lesson.rawSubject) l.matchResult = lesson.matchResult; }
              });
              SubjectMatcher.saveAlias(widget.schoolId, lesson.rawSubject, id);
            },
          ),
        ),
        if (isResolved)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
            child: Row(children: [
              const Icon(Icons.bookmark_added_rounded, color: _C.emerald, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'سيُحفظ كمرادف دائم: "' + lesson.rawSubject + '" → ' + (lesson.matchResult.matched?.officialName ?? ''),
                style: const TextStyle(color: _C.emerald, fontSize: 11))),
            ]),
          ),
      ]),
    );
  }

  // ─── STEP 4: Confirm ─────────────────────────────────────────────────────
  Widget _buildConfirmStep() {
    final teacherCount = _allLessons.map((l) => l.teacherName).toSet().length;
    final subjectCount = _allLessons.map((l) => l.resolvedSubject).toSet().length;
    final classCount = _allLessons.map((l) => l.className).where((c) => c.isNotEmpty).toSet().length;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(children: [
        // Success icon with glow
        AnimatedBuilder(
          animation: _pulseAnim,
          builder: (_, __) => Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [_C.emerald.withOpacity(0.2), Colors.transparent]),
              boxShadow: [BoxShadow(color: _C.emerald.withOpacity(_pulseAnim.value * 0.3), blurRadius: 30)],
              border: Border.all(color: _C.emerald.withOpacity(0.4), width: 1.5),
            ),
            child: const Icon(Icons.rocket_launch_rounded, color: _C.emerald, size: 40),
          ),
        ),
        const SizedBox(height: 16),
        const Text('جاهز للاستيراد', style: TextStyle(color: _C.text, fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text('سيتم حفظ الجدول وتوزيعه على المعلمين والفصول', style: TextStyle(color: _C.textMuted, fontSize: 12)),
        const SizedBox(height: 24),
        // Stats grid
        Row(children: [
          _confirmTile(Icons.people_rounded, teacherCount.toString(), 'معلم', _C.violet),
          const SizedBox(width: 10),
          _confirmTile(Icons.menu_book_rounded, subjectCount.toString(), 'مادة', _C.sky),
          const SizedBox(width: 10),
          _confirmTile(Icons.class_rounded, classCount.toString(), 'فصل', _C.amber),
          const SizedBox(width: 10),
          _confirmTile(Icons.event_note_rounded, _allLessons.length.toString(), 'حصة', _C.emerald),
        ]),
        const SizedBox(height: 28),
        SizedBox(width: double.infinity, child: _primaryBtn(
          'إكمال الاستيراد', Icons.cloud_upload_rounded, _executeImport, _C.emerald)),
        const SizedBox(height: 10),
        TextButton(
          onPressed: () => setState(() => _step = _reviewLessons.isEmpty ? ImportStep.analyze : ImportStep.review),
          child: const Text('رجوع للمراجعة', style: TextStyle(color: _C.textMuted, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _confirmTile(IconData icon, String value, String label, Color color) {
    return Expanded(child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.2)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 16)],
      ),
      child: Column(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 18)),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.bold,
            shadows: [Shadow(color: color.withOpacity(0.4), blurRadius: 8)])),
        Text(label, style: const TextStyle(color: _C.textMuted, fontSize: 10)),
      ]),
    ));
  }

  // ─── Shared Button ────────────────────────────────────────────────────────
  Widget _primaryBtn(String label, IconData icon, VoidCallback onTap, Color color) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 18),
      label: Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        elevation: 0,
        shadowColor: color.withOpacity(0.4),
      ).copyWith(elevation: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.hovered) ? 8 : 0)),
    );
  }
}

Future<bool?> showExcelImportWizard(
    BuildContext context, String schoolId, VoidCallback onComplete) {
  return showDialog<bool>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.7),
    builder: (_) => ExcelImportWizard(schoolId: schoolId, onImportComplete: onComplete),
  );
}
