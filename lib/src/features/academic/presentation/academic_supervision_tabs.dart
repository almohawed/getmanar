import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../reports/domain/ministry_pdf_template.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/school_repository.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../data/academic_supervision_repository.dart';
import '../../../core/domain/models/user.dart';
import 'academic_supervision_providers.dart';

Future<Map<String, String>> _loadSchoolHeaderLabel(WidgetRef ref) async {
  String schoolName = '';
  String adminRegion = '';
  try {
    final user = ref.read(authStateProvider).value;
    if (user?.schoolId != null && (user!.schoolId ?? '').isNotEmpty) {
      final school = await ref
          .read(schoolRepositoryProvider)
          .getSchool(user.schoolId!);
      if (school != null) {
        schoolName = school.name;
        adminRegion = school.adminRegion;
      }
    }
  } catch (_) {
    // Ignore and fall back to empty header
  }
  return {'schoolName': schoolName, 'adminRegion': adminRegion};
}

class CurriculumProgressTab extends ConsumerStatefulWidget {
  const CurriculumProgressTab({super.key});
  @override
  ConsumerState<CurriculumProgressTab> createState() =>
      _CurriculumProgressTabState();
}

class _CurriculumProgressTabState extends ConsumerState<CurriculumProgressTab> {
  String? _classId;
  String? _subjectId;

  void _openFilters(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18.r)),
      builder: (_) => _FiltersSheet(
        onApply: (cls, sub) => setState(() {
          _classId = cls;
          _subjectId = sub;
        }),
      ),
    );
  }

  Future<void> _exportPdf(
    BuildContext context,
    List<CurriculumProgress> data,
  ) async {
    try {
      final header = await _loadSchoolHeaderLabel(ref);
      final schoolName = header['schoolName'] ?? '';
      final adminRegion = header['adminRegion'] ?? '';
      final doc = await MinistryPdfTemplate.generateReport(
        title: 'نسبة إنجاز المنهج',
        subTitle: '',
        schoolName: schoolName,
        adminRegion: adminRegion,
        dateFrom: '',
        dateTo: '',
        tableHeaders: ['الصف', 'المادة', 'المفترض', 'المنجز', 'الفارق'],
        tableData: data
            .map(
              (p) => [
                p.className ?? p.classId,
                p.subjectName ?? p.subjectId,
                p.expectedUnits.toString(),
                p.coveredUnits.toString(),
                (p.expectedUnits - p.coveredUnits).toString(),
              ],
            )
            .toList(),
        footerText: 'متابعة الإشراف الأكاديمي',
      );
      await Printing.layoutPdf(
        onLayout: (format) async => doc.save(),
        name: 'CurriculumProgress_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
    } catch (e) {
      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('تصدير PDF'),
          content: Text('تعذر فتح ملف PDF: $e'),
        ),
      );
    }
  }

  Future<void> _openEntrySheet(
    BuildContext context, {
    required Map<String, User> teachersById,
    required List<CurriculumProgress> current,
  }) async {
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CurriculumProgressEntrySheet(
        schoolId: schoolId,
        teachersById: teachersById,
        initialClassId: _classId,
        initialSubjectId: _subjectId,
        current: current,
      ),
    );

    ref.invalidate(
      curriculumProgressProvider(
        CurriculumFilters(classId: _classId, subjectId: _subjectId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final progress = ref.watch(
      curriculumProgressProvider(
        CurriculumFilters(classId: _classId, subjectId: _subjectId),
      ),
    );
    final teachersAsync = ref.watch(schoolTeachersMapProvider);
    final teachersMap = teachersAsync.maybeWhen(
      data: (map) => map,
      orElse: () => const <String, User>{},
    );
    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);
    const bg = Color(0xFFF8FAFC);

    final data = progress.asData?.value ?? const <CurriculumProgress>[];

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

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
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
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
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'مستوى الالتزام بالخطة الدراسية',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'لوحة متابعة تنفيذ المنهج حسب الصف والمادة مع توصيات إشرافية واضحة.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
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
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'بحث وفلترة',
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
                          if ((_classId ?? '').trim().isNotEmpty)
                            _FilterChip(
                              label: 'الصف: ${_classId!.trim()}',
                              onClear: () => setState(() => _classId = null),
                            ),
                          if ((_subjectId ?? '').trim().isNotEmpty)
                            _FilterChip(
                              label: 'المادة: ${_subjectId!.trim()}',
                              onClear: () => setState(() => _subjectId = null),
                            ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () => _openFilters(context),
                            icon: const Icon(Icons.filter_alt_outlined),
                            label: const Text('تصفية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: () => _openEntrySheet(
                              context,
                              teachersById: teachersMap,
                              current: data,
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('إدخال'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primary,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          OutlinedButton.icon(
                            onPressed: () => _exportPdf(context, data),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryDark,
                              side: BorderSide(
                                color: primaryDark.withValues(alpha: 0.35),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
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
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: SliverToBoxAdapter(
              child: progress.when(
                data: (list) => _CurriculumDashboard(
                  progressList: list,
                  teachersById: teachersMap,
                  isLoading: false,
                  onAddEntry: () => _openEntrySheet(
                    context,
                    teachersById: teachersMap,
                    current: list,
                  ),
                ),
                loading: () => _CurriculumDashboard(
                  progressList: const [],
                  teachersById: teachersMap,
                  isLoading: true,
                  onAddEntry: () => _openEntrySheet(
                    context,
                    teachersById: teachersMap,
                    current: const [],
                  ),
                ),
                error: (e, _) => UnifiedEmptyState(
                  message: 'خطأ: $e',
                  onRetry: () => setState(() {}),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBackButton extends StatefulWidget {
  final VoidCallback onPressed;

  const _HeaderBackButton({required this.onPressed});

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
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
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
                    SizedBox(width: 8.w),
                    Text(
                      'العودة للوحة',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.sp,
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
      margin: EdgeInsetsDirectional.only(end: 8.w),
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
              fontSize: 11.sp,
            ),
          ),
          SizedBox(width: 6.w),
          GestureDetector(
            onTap: onClear,
            child: Icon(Icons.close, size: 16, color: Colors.blueGrey.shade700),
          ),
        ],
      ),
    );
  }
}

class _CurriculumProgressEntrySheet extends StatefulWidget {
  final String schoolId;
  final Map<String, User> teachersById;
  final String? initialClassId;
  final String? initialSubjectId;
  final List<CurriculumProgress> current;

  const _CurriculumProgressEntrySheet({
    required this.schoolId,
    required this.teachersById,
    required this.initialClassId,
    required this.initialSubjectId,
    required this.current,
  });

  @override
  State<_CurriculumProgressEntrySheet> createState() =>
      _CurriculumProgressEntrySheetState();
}

class _CurriculumProgressEntrySheetState
    extends State<_CurriculumProgressEntrySheet> {
  late final TextEditingController _classIdCtrl;
  late final TextEditingController _classNameCtrl;
  late final TextEditingController _subjectIdCtrl;
  late final TextEditingController _subjectNameCtrl;
  late final TextEditingController _expectedCtrl;
  late final TextEditingController _coveredCtrl;
  String? _teacherId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _classIdCtrl = TextEditingController(
      text: (widget.initialClassId ?? '').trim(),
    );
    _classNameCtrl = TextEditingController();
    _subjectIdCtrl = TextEditingController(
      text: (widget.initialSubjectId ?? '').trim(),
    );
    _subjectNameCtrl = TextEditingController();
    _expectedCtrl = TextEditingController();
    _coveredCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _classIdCtrl.dispose();
    _classNameCtrl.dispose();
    _subjectIdCtrl.dispose();
    _subjectNameCtrl.dispose();
    _expectedCtrl.dispose();
    _coveredCtrl.dispose();
    super.dispose();
  }

  String _toDocKey(String input) {
    final s = input.trim();
    return s.replaceAll(RegExp(r'[/\\]'), '_').replaceAll(RegExp(r'\s+'), '_');
  }

  Future<void> _save() async {
    final classId = _classIdCtrl.text.trim();
    final subjectId = _subjectIdCtrl.text.trim();
    final expected = int.tryParse(_expectedCtrl.text.trim()) ?? -1;
    final covered = int.tryParse(_coveredCtrl.text.trim()) ?? -1;

    if (classId.isEmpty || subjectId.isEmpty || expected < 0 || covered < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تأكد من إدخال الصف والمادة والقيم بشكل صحيح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final className = _classNameCtrl.text.trim();
      final subjectName = _subjectNameCtrl.text.trim();
      final callable = FirebaseFunctions.instance.httpsCallable(
        'upsertCurriculumProgress',
      );
      await callable.call({
        'schoolId': widget.schoolId,
        'classId': classId,
        'subjectId': subjectId,
        'expectedUnits': expected,
        'coveredUnits': covered,
        if (className.isNotEmpty) 'className': className,
        if (subjectName.isNotEmpty) 'subjectName': subjectName,
        if ((_teacherId ?? '').trim().isNotEmpty) 'teacherId': _teacherId,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ إنجاز المنهج بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تعذر الحفظ: $e'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _prefillFrom(CurriculumProgress p) {
    _classIdCtrl.text = p.classId;
    _subjectIdCtrl.text = p.subjectId;
    _expectedCtrl.text = p.expectedUnits.toString();
    _coveredCtrl.text = p.coveredUnits.toString();
    _classNameCtrl.text = (p.className ?? '').toString();
    _subjectNameCtrl.text = (p.subjectName ?? '').toString();
    _teacherId = p.teacherId;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    final teacherItems =
        widget.teachersById.values
            .where((t) => t.role == UserRole.teacher)
            .toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          12.w,
          12.h,
          12.w,
          12.h + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: glass(
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: EdgeInsets.fromLTRB(16.w, 12.h, 12.w, 12.h),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(
                    top: Radius.circular(22.r),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42.w,
                      height: 42.w,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(16.r),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.22),
                        ),
                      ),
                      child: const Icon(Icons.edit_note, color: Colors.white),
                    ),
                    SizedBox(width: 12.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إدخال إنجاز المنهج',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 14.5.sp,
                            ),
                          ),
                          SizedBox(height: 4.h),
                          Text(
                            'ادخل المفترض والمنجز لكل صف ومادة.',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.92),
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _classIdCtrl,
                              decoration: InputDecoration(
                                labelText: 'الصف/الشعبة (ID)',
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              controller: _classNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'اسم الصف (اختياري)',
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _subjectIdCtrl,
                              decoration: InputDecoration(
                                labelText: 'المادة (ID)',
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              controller: _subjectNameCtrl,
                              decoration: InputDecoration(
                                labelText: 'اسم المادة (اختياري)',
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 10.h),
                      DropdownButtonFormField<String>(
                        value: (_teacherId ?? '').isEmpty ? null : _teacherId,
                        decoration: InputDecoration(
                          labelText: 'المعلم (اختياري)',
                          filled: true,
                          fillColor: Colors.black.withValues(alpha: 0.03),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                        ),
                        items: teacherItems
                            .map(
                              (t) => DropdownMenuItem(
                                value: t.id,
                                child: Text(t.name),
                              ),
                            )
                            .toList(),
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _teacherId = v),
                      ),
                      SizedBox(height: 10.h),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _expectedCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'المفترض',
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: TextField(
                              controller: _coveredCtrl,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'المنجز',
                                filled: true,
                                fillColor: Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 14.h),
                      ElevatedButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'جاري الحفظ...' : 'حفظ'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryDark,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                          ),
                          elevation: 0,
                        ),
                      ),
                      if (widget.current.isNotEmpty) ...[
                        SizedBox(height: 16.h),
                        Text(
                          'سجلات حالية (اضغط للتعديل)',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey.shade900,
                          ),
                        ),
                        SizedBox(height: 10.h),
                        ...widget.current.take(12).map((p) {
                          final title =
                              '${p.className ?? p.classId} • ${p.subjectName ?? p.subjectId}';
                          final percent = p.expectedUnits == 0
                              ? 0.0
                              : (p.coveredUnits / p.expectedUnits) * 100.0;
                          return ListTile(
                            onTap: _saving ? null : () => _prefillFrom(p),
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'المنجز: ${p.coveredUnits} • المفترض: ${p.expectedUnits} • ${percent.toStringAsFixed(0)}%',
                            ),
                            trailing: const Icon(Icons.edit),
                          );
                        }),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurriculumDashboard extends StatelessWidget {
  final List<CurriculumProgress> progressList;
  final Map<String, User> teachersById;
  final bool isLoading;
  final VoidCallback onAddEntry;

  const _CurriculumDashboard({
    required this.progressList,
    required this.teachersById,
    required this.isLoading,
    required this.onAddEntry,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isWide = size.width > 900;

    final valid = progressList.where((p) => p.expectedUnits > 0).toList();

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    if (isLoading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.only(bottom: 10.h),
            child: Text(
              'جاري تحميل بيانات تنفيذ الخطة...',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 210.h,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Container(
                  height: 210.h,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 14.h),
          Container(
            height: 240.h,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
          SizedBox(height: 14.h),
          Container(
            height: 220.h,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(20.r),
            ),
          ),
        ],
      );
    }

    if (valid.isEmpty) {
      return glass(
        Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.r),
                      color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      color: Color(0xFF1E3A8A),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لا توجد بيانات لعرضها حالياً',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey.shade900,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'هذا القسم يعتمد على تسجيل إنجاز المنهج (المفترض/المنجز) لكل صف ومادة داخل المدرسة.',
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
              SizedBox(height: 14.h),
              ElevatedButton.icon(
                onPressed: onAddEntry,
                icon: const Icon(Icons.add),
                label: const Text('إدخال إنجاز المنهج'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  elevation: 0,
                ),
              ),
              SizedBox(height: 12.h),
              Container(
                padding: EdgeInsets.all(14.w),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18.r),
                  color: Colors.black.withValues(alpha: 0.04),
                  border: Border.all(
                    color: Colors.black.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'ماذا تفعل الآن؟',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      '1) تأكد من إدخال بيانات “المفترض/المنجز” للمواد.\n'
                      '2) إذا كنت تستخدم التصفية، جرّب إزالة التصفية ثم إعادة العرض.\n'
                      '3) بعد إدخال أول سجل، ستظهر البطاقات والرسوم تلقائيًا هنا.',
                      style: TextStyle(
                        color: Colors.blueGrey.shade700,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    double overallPercent = 0;
    if (valid.isNotEmpty) {
      final ratios = valid
          .map((p) => (p.coveredUnits / p.expectedUnits).clamp(0.0, 2.0))
          .toList();
      final avgRatio =
          ratios.fold<double>(0, (sum, r) => sum + r) / ratios.length;
      overallPercent = (avgRatio * 100).clamp(0.0, 200.0);
    }

    int onTrack = 0;
    int needsSupport = 0;
    int advanced = 0;

    for (final p in valid) {
      final delay = p.expectedUnits - p.coveredUnits;
      if (delay == 0) {
        onTrack++;
      } else if (delay > 0) {
        needsSupport++;
      } else {
        advanced++;
      }
    }

    final subjectGroups = <String, List<double>>{};
    for (final p in valid) {
      final name = p.subjectName ?? p.subjectId;
      final ratio = (p.coveredUnits / p.expectedUnits)
          .clamp(0.0, 2.0)
          .toDouble();
      subjectGroups.putIfAbsent(name, () => []).add(ratio);
    }

    final subjectAverages = subjectGroups.map(
      (k, v) => MapEntry(k, v.fold<double>(0, (s, r) => s + r) / v.length),
    );

    final sortedSubjects = subjectAverages.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final timeline = _buildWeeklyTimeline(valid);

    final details = valid
        .map(
          (p) => _CurriculumDetailRow.fromProgress(
            p,
            teachersById[p.teacherId ?? ''],
          ),
        )
        .toList();

    final teacherAggregates = <_TeacherAggregate>[];
    final Map<String, _TeacherAggregate> teacherMap = {};
    for (final p in valid) {
      final teacherId = p.teacherId;
      if (teacherId == null || teacherId.isEmpty) {
        continue;
      }
      final teacher = teachersById[teacherId];
      final ratio = p.expectedUnits == 0
          ? 0.0
          : (p.coveredUnits / p.expectedUnits) * 100.0;
      final percent = ratio.clamp(0.0, 200.0);
      final existing = teacherMap[teacherId];
      if (existing == null) {
        teacherMap[teacherId] = _TeacherAggregate(
          teacherName: teacher?.name ?? 'غير محدد',
          totalPercent: percent,
          subjectsCount: 1,
          below80Count: percent < 80 ? 1 : 0,
        );
      } else {
        teacherMap[teacherId] = _TeacherAggregate(
          teacherName: existing.teacherName,
          totalPercent: existing.totalPercent + percent,
          subjectsCount: existing.subjectsCount + 1,
          below80Count: existing.below80Count + (percent < 80 ? 1 : 0),
        );
      }
    }
    teacherAggregates.addAll(teacherMap.values);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isWide)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: _OverallGaugeCard(percent: overallPercent),
              ),
              SizedBox(width: 12.w),
              Expanded(
                flex: 3,
                child: _TopOverviewStats(
                  onTrack: onTrack,
                  needsSupport: needsSupport,
                  advanced: advanced,
                ),
              ),
            ],
          )
        else ...[
          _OverallGaugeCard(percent: overallPercent),
          SizedBox(height: 12.h),
          _TopOverviewStats(
            onTrack: onTrack,
            needsSupport: needsSupport,
            advanced: advanced,
          ),
        ],
        SizedBox(height: 20.h),
        if (sortedSubjects.isNotEmpty)
          _SubjectLevelChart(subjects: sortedSubjects),
        SizedBox(height: 20.h),
        if (timeline.isNotEmpty) _ExecutionTrendChart(points: timeline),
        SizedBox(height: 20.h),
        if (teacherAggregates.isNotEmpty)
          _TeacherHighlights(aggregates: teacherAggregates),
        SizedBox(height: 20.h),
        _SmartRecommendationsBox(
          needsSupport: needsSupport,
          advanced: advanced,
        ),
        SizedBox(height: 20.h),
        _ExpectationCard(overallPercent: overallPercent),
        SizedBox(height: 20.h),
        _CurriculumDetailsTable(rows: details),
      ],
    );
  }

  List<_TimelinePoint> _buildWeeklyTimeline(List<CurriculumProgress> list) {
    final items = list
        .where((p) => p.updatedAt != null)
        .toList(growable: false);
    if (items.isEmpty) return [];

    final groups = <DateTime, List<double>>{};

    for (final p in items) {
      final date = p.updatedAt!;
      final startOfWeek = DateTime(
        date.year,
        date.month,
        date.day,
      ).subtract(Duration(days: date.weekday % 7));
      final ratio = (p.coveredUnits / p.expectedUnits)
          .clamp(0.0, 2.0)
          .toDouble();
      groups.putIfAbsent(startOfWeek, () => []).add(ratio);
    }

    final entries = groups.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    final result = <_TimelinePoint>[];
    for (var i = 0; i < entries.length; i++) {
      final e = entries[i];
      final avg =
          e.value.fold<double>(0, (s, r) => s + r) / e.value.length.toDouble();
      result.add(
        _TimelinePoint(
          x: i.toDouble(),
          percent: (avg * 100).clamp(0.0, 200.0),
          label: '${e.key.month}/${e.key.day}',
        ),
      );
    }
    return result;
  }
}

class _TimelinePoint {
  final double x;
  final double percent;
  final String label;

  _TimelinePoint({required this.x, required this.percent, required this.label});
}

class _TeacherAggregate {
  final String teacherName;
  final double totalPercent;
  final int subjectsCount;
  final int below80Count;

  const _TeacherAggregate({
    required this.teacherName,
    required this.totalPercent,
    required this.subjectsCount,
    required this.below80Count,
  });

  double get avgPercent =>
      subjectsCount == 0 ? 0.0 : totalPercent / subjectsCount;
}

class _CurriculumDetailRow {
  final String subjectName;
  final String teacherName;
  final double percent;
  final String statusLabel;
  final String recommendation;

  _CurriculumDetailRow({
    required this.subjectName,
    required this.teacherName,
    required this.percent,
    required this.statusLabel,
    required this.recommendation,
  });

  factory _CurriculumDetailRow.fromProgress(
    CurriculumProgress p,
    User? teacher,
  ) {
    final ratio = p.expectedUnits == 0
        ? 0.0
        : (p.coveredUnits / p.expectedUnits) * 100.0;
    final percent = ratio.clamp(0.0, 200.0);
    final delay = p.expectedUnits - p.coveredUnits;

    String status;
    String recommendation;

    if (delay <= 0 && percent >= 80) {
      status = 'ضمن الخطة';
      recommendation = 'استمرار بنفس الوتيرة الحالية.';
    } else if (delay > 0 && delay <= 2) {
      status = 'بحاجة متابعة';
      recommendation = 'تنسيق خطة دعم بسيطة لموازنة التنفيذ.';
    } else if (delay > 2) {
      status = 'يحتاج دعم';
      recommendation = 'مراجعة الخطة الزمنية وعقد نقاش تطويري قصير.';
    } else {
      status = 'بحاجة متابعة';
      recommendation = 'متابعة محايدة للتأكد من وضوح الخطة.';
    }

    return _CurriculumDetailRow(
      subjectName: p.subjectName ?? p.subjectId,
      teacherName: teacher?.name ?? 'غير محدد',
      percent: percent,
      statusLabel: status,
      recommendation: recommendation,
    );
  }
}

class _TeacherHighlights extends StatelessWidget {
  final List<_TeacherAggregate> aggregates;

  const _TeacherHighlights({required this.aggregates});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF1E3A8A);
    const success = Color(0xFF22C55E);
    const warn = Color(0xFFF59E0B);
    if (aggregates.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = List<_TeacherAggregate>.from(aggregates)
      ..sort((a, b) => b.avgPercent.compareTo(a.avgPercent));

    final top = sorted.take(3).toList();

    final needingSupport = sorted
        .where((t) => t.avgPercent < 80 && t.subjectsCount > 0)
        .take(3)
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'نماذج متميزة في تنفيذ الخطة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryDark,
                ),
              ),
              SizedBox(height: 8.h),
              if (top.isNotEmpty)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'أعلى المعلمين التزاماً بالخطة:',
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade800,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    ...top.map(
                      (t) => Padding(
                        padding: EdgeInsets.symmetric(vertical: 2.h),
                        child: Row(
                          children: [
                            Icon(Icons.verified, color: success),
                            SizedBox(width: 6.w),
                            Expanded(
                              child: Text(
                                t.teacherName,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                            ),
                            Text(
                              '${t.avgPercent.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                                color: success,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              if (needingSupport.isNotEmpty) ...[
                SizedBox(height: 10.h),
                Divider(height: 1, color: Colors.black.withValues(alpha: 0.08)),
                SizedBox(height: 10.h),
                Text(
                  'معلمون بحاجة إلى دعم تطويري تشاركي:',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 6.h),
                ...needingSupport.map(
                  (t) => Padding(
                    padding: EdgeInsets.symmetric(vertical: 2.h),
                    child: Row(
                      children: [
                        Icon(Icons.handshake, color: warn),
                        SizedBox(width: 6.w),
                        Expanded(
                          child: Text(
                            t.teacherName,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade900,
                            ),
                          ),
                        ),
                        Text(
                          '${t.avgPercent.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: warn,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _OverallGaugeCard extends StatelessWidget {
  final double percent;

  const _OverallGaugeCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);
    final clamped = percent.clamp(0.0, 100.0);
    final value = clamped / 100.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'متوسط تنفيذ الخطة على مستوى المدرسة',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: primaryDark,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 140.w,
                width: 140.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 140.w,
                      width: 140.w,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 10.w,
                        backgroundColor: Colors.black.withValues(alpha: 0.06),
                        valueColor: AlwaysStoppedAnimation<Color>(primary),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${clamped.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.bold,
                            color: primaryDark,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'مؤشر تنفيذ المدرسة حتى تاريخه',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey.shade700,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'يعكس مستوى التقدم في تنفيذ الخطة الدراسية المعتمدة حتى تاريخه.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopOverviewStats extends StatelessWidget {
  final int onTrack;
  final int needsSupport;
  final int advanced;

  const _TopOverviewStats({
    required this.onTrack,
    required this.needsSupport,
    required this.advanced,
  });

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const success = Color(0xFF22C55E);
    const warn = Color(0xFFF59E0B);
    final total = onTrack + needsSupport + advanced;

    final cards = [
      _OverviewStatCard(
        title: 'ضمن الخطة',
        value: onTrack.toString(),
        color: success,
        icon: Icons.check_circle_outline,
        description: 'متوافقة مع الإطار الزمني.',
      ),
      _OverviewStatCard(
        title: 'بحاجة متابعة',
        value: needsSupport.toString(),
        color: warn,
        icon: Icons.warning_amber_rounded,
        description: 'تتطلب متابعة داعمة.',
      ),
      _OverviewStatCard(
        title: 'متقدمة',
        value: advanced.toString(),
        color: primary,
        icon: Icons.trending_up,
        description: 'تجاوزت التقدم المتوقع.',
      ),
      _OverviewStatCard(
        title: 'الإجمالي',
        value: total.toString(),
        color: Colors.blueGrey,
        icon: Icons.inventory_2_outlined,
        description: 'إجمالي المواد في النطاق.',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 760;
        final w = wide
            ? (constraints.maxWidth - 12.w) / 2
            : constraints.maxWidth;
        return Wrap(
          runSpacing: 10.h,
          spacing: 12.w,
          children: cards.map((c) => SizedBox(width: w, child: c)).toList(),
        );
      },
    );
  }
}

class _OverviewStatCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData? icon;
  final String description;

  const _OverviewStatCard({
    required this.title,
    required this.value,
    required this.color,
    this.icon,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(14.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(20.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (icon != null)
                    Container(
                      width: 36.w,
                      height: 36.w,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14.r),
                      ),
                      child: Icon(icon, color: color),
                    ),
                  if (icon != null) SizedBox(width: 10.w),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w800,
                        color: Colors.blueGrey.shade900,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 6.h),
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
                description,
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SubjectLevelChart extends StatelessWidget {
  final List<MapEntry<String, double>> subjects;

  const _SubjectLevelChart({required this.subjects});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF1E3A8A);
    const success = Color(0xFF22C55E);
    const warn = Color(0xFFF59E0B);
    const danger = Color(0xFFEF4444);
    final maxPercent = subjects
        .map((e) => (e.value * 100).clamp(0.0, 200.0))
        .fold<double>(0, (m, v) => v > m ? v : m);
    final safeMax = maxPercent == 0 ? 100.0 : maxPercent;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'مستوى تنفيذ المنهج حسب المادة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryDark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'الأخضر: ضمن الخطة • البرتقالي: بحاجة متابعة • الأحمر: يحتاج دعم إشرافي',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
              ),
              SizedBox(height: 12.h),
              Column(
                children: subjects.map((e) {
                  final percent = (e.value * 100).clamp(0.0, 200.0).toDouble();
                  final ratio = (percent / safeMax).clamp(0.0, 1.0);

                  Color barColor;
                  if (percent >= 80) {
                    barColor = success;
                  } else if (percent >= 60) {
                    barColor = warn;
                  } else {
                    barColor = danger;
                  }

                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 4.h),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 80.w,
                          child: Text(
                            e.key,
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade900,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(999.r),
                            child: LinearProgressIndicator(
                              value: ratio,
                              minHeight: 10.h,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                barColor,
                              ),
                              backgroundColor: Colors.black.withValues(
                                alpha: 0.06,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 8.w),
                        SizedBox(
                          width: 40.w,
                          child: Text(
                            '${percent.toStringAsFixed(0)}%',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w600,
                              color: barColor,
                            ),
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExecutionTrendChart extends StatelessWidget {
  final List<_TimelinePoint> points;

  const _ExecutionTrendChart({required this.points});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);
    final spots = points
        .map((p) => FlSpot(p.x, p.percent.clamp(0.0, 200.0)))
        .toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تطور تنفيذ الخطة خلال الفترة الحالية',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryDark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'يوضح الاتجاه العام لمستوى التنفيذ مقارنة بالخطة الزمنية.',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade700),
              ),
              SizedBox(height: 12.h),
              SizedBox(
                height: 160.h,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (v, meta) {
                            final index = v.toInt();
                            if (index < 0 || index >= points.length) {
                              return const SizedBox.shrink();
                            }
                            return Padding(
                              padding: EdgeInsets.only(top: 4.h),
                              child: Text(
                                points[index].label,
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      topTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                      rightTitles: AxisTitles(
                        sideTitles: SideTitles(showTitles: false),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    minY: 0,
                    maxY: 100,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: primary,
                        barWidth: 3,
                        dotData: FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: primary.withValues(alpha: 0.12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmartRecommendationsBox extends StatelessWidget {
  final int needsSupport;
  final int advanced;

  const _SmartRecommendationsBox({
    required this.needsSupport,
    required this.advanced,
  });

  @override
  Widget build(BuildContext context) {
    const warn = Color(0xFFF59E0B);
    const primaryDark = Color(0xFF1E3A8A);
    final total = needsSupport + advanced;

    final message = total == 0
        ? 'لا توجد مواد بحاجة متابعة خاصة حالياً، مؤشرات التنفيذ تسير بشكل مطمئن.'
        : 'توجد $total مادة بحاجة متابعة داعمة لضمان الالتزام بالإطار الزمني المعتمد. يُقترح عقد اجتماع تنسيقي لمراجعة توزيع الخطة ودعم الفرق التعليمية.';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: warn.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: warn.withValues(alpha: 0.35)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb, color: warn),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'توصيات متابعة تنفيذ الخطة',
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: primaryDark,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpectationCard extends StatelessWidget {
  final double overallPercent;

  const _ExpectationCard({required this.overallPercent});

  @override
  Widget build(BuildContext context) {
    const primary = Color(0xFF4F46E5);
    const primaryDark = Color(0xFF1E3A8A);
    final clamped = overallPercent.clamp(0.0, 100.0);

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: primary.withValues(alpha: 0.25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'التوقع العام لنسبة التنفيذ بنهاية الفترة',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: primaryDark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'في حال استمرار المعدل الحالي للتنفيذ، من المتوقع الحفاظ على مستوى قريب من ${clamped.toStringAsFixed(0)}% من تنفيذ الخطة بنهاية الفترة.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade800),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CurriculumDetailsTable extends StatelessWidget {
  final List<_CurriculumDetailRow> rows;

  const _CurriculumDetailsTable({required this.rows});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF1E3A8A);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(12.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(vertical: 8.h),
                child: Text(
                  'تحليل تنفيذ الخطة حسب المواد والمعلمين',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: primaryDark,
                  ),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('المادة')),
                    DataColumn(label: Text('المعلم')),
                    DataColumn(label: Text('نسبة التنفيذ')),
                    DataColumn(label: Text('حالة التنفيذ')),
                    DataColumn(label: Text('التوصية')),
                  ],
                  rows: rows
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text(r.subjectName)),
                            DataCell(Text(r.teacherName)),
                            DataCell(Text('${r.percent.toStringAsFixed(0)}%')),
                            DataCell(Text(r.statusLabel)),
                            DataCell(Text(r.recommendation)),
                          ],
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class LessonPrepTab extends ConsumerStatefulWidget {
  const LessonPrepTab({super.key});
  @override
  ConsumerState<LessonPrepTab> createState() => _LessonPrepTabState();
}

class _LessonPrepTabState extends ConsumerState<LessonPrepTab> {
  late DateTime _from;
  late DateTime _to;
  String? _teacherId;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    _from = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
    _to = _from.add(const Duration(days: 6));
  }

  @override
  Widget build(BuildContext context) {
    final complianceAsync = ref.watch(
      lessonPrepComplianceProvider(
        WeekRange(from: _from, to: _to, teacherId: _teacherId),
      ),
    );
    final teachersAsync = ref.watch(schoolTeachersMapProvider);

    final teachersMap = teachersAsync.asData?.value ?? <String, User>{};

    final hasError = complianceAsync.hasError || teachersAsync.hasError;
    final error = complianceAsync.error ?? teachersAsync.error;

    const primaryDark = Color(0xFF0F766E);
    const primary = Color(0xFF14B8A6);
    const bg = Color(0xFFF8FAFC);

    final c = complianceAsync.asData?.value;
    final totalLessons = c?.totalRecords ?? 0;
    final preparedLessons = c?.preparedCount ?? 0;
    final pendingLessons = totalLessons > preparedLessons
        ? totalLessons - preparedLessons
        : 0;
    final readiness = (c?.complianceRate ?? 0.0).clamp(0.0, 100.0);

    Widget headerStat({
      required IconData icon,
      required String label,
      required String value,
    }) {
      return Container(
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 16),
            SizedBox(width: 8.w),
            Text(
              '$label: $value',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 11.5.sp,
              ),
            ),
          ],
        ),
      );
    }

    void openFilterSheet() {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18.r),
        ),
        builder: (_) => _WeekFilterSheet(
          from: _from,
          to: _to,
          onApply: (f, t, tid) => setState(() {
            _from = f;
            _to = t;
            _teacherId = tid;
          }),
        ),
      );
    }

    Future<void> exportPdf(LessonPrepCompliance compliance) async {
      try {
        final rows = compliance.records
            .map(
              (r) => [
                r.date.toString().split(' ').first,
                teachersMap[r.teacherId]?.name ?? r.teacherId,
                r.classId,
                r.subjectId,
                r.prepared ? 'محضر' : 'غير محضر',
              ],
            )
            .toList();
        final header = await _loadSchoolHeaderLabel(ref);
        final doc = await MinistryPdfTemplate.generateReport(
          title: 'الجاهزية التعليمية والتخطيط التدريسي',
          subTitle: '',
          schoolName: header['schoolName'] ?? '',
          adminRegion: header['adminRegion'] ?? '',
          dateFrom: _from.toString().split(' ').first,
          dateTo: _to.toString().split(' ').first,
          tableHeaders: ['التاريخ', 'المعلم', 'الفصل', 'المادة', 'الحالة'],
          tableData: rows,
          footerText: 'متابعة الجاهزية التعليمية على مستوى المدرسة',
        );
        await Printing.layoutPdf(
          onLayout: (format) async => doc.save(),
          name:
              'EducationalReadiness_${DateTime.now().millisecondsSinceEpoch}.pdf',
        );
      } catch (e) {
        if (!context.mounted) return;
        await showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('تصدير PDF'),
            content: Text('تعذر فتح ملف PDF: $e'),
          ),
        );
      }
    }

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(18.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    final rangeLabel =
        '${_from.toString().split(' ').first} → ${_to.toString().split(' ').first}';
    final teacherLabel = (_teacherId ?? '').trim().isEmpty
        ? ''
        : (teachersMap[_teacherId!]?.name ?? _teacherId!);

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
            padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 10.h),
            sliver: SliverToBoxAdapter(
              child: Container(
                padding: EdgeInsets.fromLTRB(18.w, 20.h, 18.w, 20.h),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24.r),
                  gradient: const LinearGradient(
                    colors: [primaryDark, primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryDark.withValues(alpha: 0.20),
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
                          width: 58.w,
                          height: 58.w,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(20.r),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.25),
                            ),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                        SizedBox(width: 14.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'الجاهزية التعليمية والتخطيط التدريسي',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 17.sp,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Text(
                                'قياس جاهزية المعلمين وخطط التدريس للأسبوع المحدد مع توصيات تحسين واضحة.',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                children: [
                                  headerStat(
                                    icon: Icons.inventory_2_outlined,
                                    label: 'الإجمالي',
                                    value: '$totalLessons',
                                  ),
                                  headerStat(
                                    icon: Icons.check_circle_outline,
                                    label: 'محضر',
                                    value: '$preparedLessons',
                                  ),
                                  headerStat(
                                    icon: Icons.pending_actions,
                                    label: 'غير محضر',
                                    value: '$pendingLessons',
                                  ),
                                  headerStat(
                                    icon: Icons.percent,
                                    label: 'الجاهزية',
                                    value: '${readiness.toStringAsFixed(0)}%',
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
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            sliver: SliverToBoxAdapter(
              child: glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Wrap(
                    runSpacing: 10.h,
                    spacing: 10.w,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    alignment: WrapAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune, color: primaryDark, size: 18.sp),
                          SizedBox(width: 8.w),
                          Text(
                            'بحث وفلترة',
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
                          _FilterChip(
                            label: 'الفترة: $rangeLabel',
                            onClear: () => setState(() {
                              final now = DateTime.now();
                              final startOfWeek = now.subtract(
                                Duration(days: now.weekday % 7),
                              );
                              _from = DateTime(
                                startOfWeek.year,
                                startOfWeek.month,
                                startOfWeek.day,
                              );
                              _to = _from.add(const Duration(days: 6));
                            }),
                          ),
                          if (teacherLabel.isNotEmpty)
                            _FilterChip(
                              label: 'المعلم: $teacherLabel',
                              onClear: () => setState(() => _teacherId = null),
                            ),
                          SizedBox(width: 10.w),
                          ElevatedButton.icon(
                            onPressed: openFilterSheet,
                            icon: const Icon(Icons.filter_alt_outlined),
                            label: const Text('تصفية'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryDark,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                              elevation: 0,
                            ),
                          ),
                          SizedBox(width: 10.w),
                          OutlinedButton.icon(
                            onPressed: () => ref.invalidate(
                              lessonPrepComplianceProvider(
                                WeekRange(
                                  from: _from,
                                  to: _to,
                                  teacherId: _teacherId,
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
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          OutlinedButton.icon(
                            onPressed: complianceAsync.asData == null
                                ? null
                                : () =>
                                      exportPdf(complianceAsync.asData!.value),
                            icon: const Icon(Icons.picture_as_pdf),
                            label: const Text('PDF'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: primaryDark,
                              side: BorderSide(
                                color: primaryDark.withValues(alpha: 0.35),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 14.w,
                                vertical: 12.h,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16.r),
                              ),
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
            padding: EdgeInsets.fromLTRB(16.w, 14.h, 16.w, 18.h),
            sliver: SliverToBoxAdapter(
              child: hasError
                  ? UnifiedEmptyState(
                      message: 'حدث خطأ أثناء تحميل بيانات الجاهزية: $error',
                      onRetry: () => setState(() {}),
                    )
                  : complianceAsync.when(
                      data: (c) => _LessonPrepContent(
                        compliance: c,
                        teachers: teachersMap,
                      ),
                      loading: () => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 220.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(22.r),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            height: 220.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(22.r),
                            ),
                          ),
                          SizedBox(height: 12.h),
                          Container(
                            height: 260.h,
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(22.r),
                            ),
                          ),
                        ],
                      ),
                      error: (e, _) => UnifiedEmptyState(
                        message: 'حدث خطأ أثناء تحميل بيانات الجاهزية: $e',
                        onRetry: () => setState(() {}),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LessonPrepContent extends StatelessWidget {
  final LessonPrepCompliance compliance;
  final Map<String, User> teachers;

  const _LessonPrepContent({required this.compliance, required this.teachers});

  @override
  Widget build(BuildContext context) {
    final completed = compliance.preparedCount;
    final inProgress = compliance.totalRecords > completed
        ? compliance.totalRecords - completed
        : 0;
    final readinessPercent = compliance.complianceRate;

    final bySubject = <String, List<bool>>{};
    for (final r in compliance.records) {
      bySubject.putIfAbsent(r.subjectId, () => []).add(r.prepared);
    }

    final teacherStats = <String, Map<String, dynamic>>{};
    for (final r in compliance.records) {
      final t = teacherStats.putIfAbsent(r.teacherId, () {
        return {'prepared': 0, 'total': 0, 'last': r.date};
      });
      t['total'] = (t['total'] as int) + 1;
      if (r.prepared) {
        t['prepared'] = (t['prepared'] as int) + 1;
      }
      final last = t['last'] as DateTime;
      if (r.date.isAfter(last)) {
        t['last'] = r.date;
      }
    }

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    if (compliance.totalRecords == 0) {
      return glass(
        Padding(
          padding: EdgeInsets.all(18.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 46.w,
                    height: 46.w,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18.r),
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Color(0xFF0F766E),
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'لا توجد بيانات جاهزية للمدة المحددة',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey.shade900,
                            fontSize: 14.sp,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          'جرّب تغيير الفترة الزمنية أو اختيار معلم، وتأكد من وجود سجلات تحضير في النظام.',
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
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 900;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: _ReadinessGaugeCard(percent: readinessPercent),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 3,
                    child: _ReadinessStatsRow(
                      completed: completed,
                      inProgress: inProgress,
                      total: compliance.totalRecords,
                    ),
                  ),
                ],
              )
            else ...[
              _ReadinessGaugeCard(percent: readinessPercent),
              SizedBox(height: 12.h),
              _ReadinessStatsRow(
                completed: completed,
                inProgress: inProgress,
                total: compliance.totalRecords,
              ),
            ],
            SizedBox(height: 12.h),
            if (bySubject.isNotEmpty) ...[
              glass(
                Padding(
                  padding: EdgeInsets.all(14.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38.w,
                            height: 38.w,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14.r),
                              color: const Color(
                                0xFF14B8A6,
                              ).withValues(alpha: 0.14),
                            ),
                            child: const Icon(
                              Icons.pie_chart_outline,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                          SizedBox(width: 10.w),
                          Expanded(
                            child: Text(
                              'الجاهزية حسب المادة',
                              style: TextStyle(
                                fontWeight: FontWeight.w900,
                                color: Colors.blueGrey.shade900,
                                fontSize: 13.5.sp,
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12.h),
                      SizedBox(
                        height: 172.h,
                        child: _ReadinessBySubjectChart(bySubject: bySubject),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 12.h),
            ],
            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ReadinessTeachersTable(
                      stats: teacherStats,
                      teachers: teachers,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    flex: 2,
                    child: _ReadinessRecommendationsBox(
                      readinessPercent: readinessPercent,
                    ),
                  ),
                ],
              )
            else ...[
              _ReadinessTeachersTable(stats: teacherStats, teachers: teachers),
              SizedBox(height: 12.h),
              _ReadinessRecommendationsBox(readinessPercent: readinessPercent),
            ],
          ],
        );
      },
    );
  }
}

class _ReadinessGaugeCard extends StatelessWidget {
  final double percent;

  const _ReadinessGaugeCard({required this.percent});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0F766E);
    const primary = Color(0xFF14B8A6);
    final clamped = percent.clamp(0.0, 100.0);
    final value = clamped / 100.0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'مؤشر الجاهزية التعليمية للأسبوع الحالي',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w800,
                    color: primaryDark,
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              SizedBox(
                height: 140.w,
                width: 140.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      height: 140.w,
                      width: 140.w,
                      child: CircularProgressIndicator(
                        value: value,
                        strokeWidth: 10.w,
                        backgroundColor: Colors.black.withValues(alpha: 0.06),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          primary,
                        ),
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${clamped.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 28.sp,
                            fontWeight: FontWeight.w900,
                            color: primaryDark,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Text(
                          'نسبة الحصص المخططة من إجمالي الحصص المسجلة.',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReadinessStatsRow extends StatelessWidget {
  final int completed;
  final int inProgress;
  final int total;

  const _ReadinessStatsRow({
    required this.completed,
    required this.inProgress,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    const success = Color(0xFF22C55E);
    const warn = Color(0xFFF59E0B);
    const primary = Color(0xFF14B8A6);
    final width = MediaQuery.of(context).size.width;
    final isMobile = width < 600;
    final completedPercent = total == 0
        ? '0٪'
        : '${((completed / total) * 100).round()}٪';
    final inProgressPercent = total == 0
        ? '0٪'
        : '${((inProgress / total) * 100).round()}٪';

    if (isMobile) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _OverviewStatCard(
            title: 'نسبة التخطيط المكتمل',
            value: completedPercent,
            description: 'حصة تم تحضيرها وتوثيقها في النظام.',
            color: success,
            icon: Icons.check_circle_outline,
          ),
          SizedBox(height: 8.h),
          _OverviewStatCard(
            title: 'نسبة التخطيط الجاري',
            value: inProgressPercent,
            description: 'حصة مسجلة بدون تحضير مكتمل حتى الآن.',
            color: warn,
            icon: Icons.pending_actions,
          ),
          SizedBox(height: 8.h),
          _OverviewStatCard(
            title: 'فرص تطوير التخطيط',
            value: '$inProgress',
            description: 'عدد الحصص التي يمكن تحسين جاهزيتها قبل بدء الأسبوع.',
            color: primary,
            icon: Icons.bolt,
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _OverviewStatCard(
                title: 'نسبة التخطيط المكتمل',
                value: completedPercent,
                description: 'حصة تم تحضيرها وتوثيقها في النظام.',
                color: success,
                icon: Icons.check_circle_outline,
              ),
            ),
            SizedBox(width: 8.w),
            Expanded(
              child: _OverviewStatCard(
                title: 'نسبة التخطيط الجاري',
                value: inProgressPercent,
                description: 'حصة مسجلة بدون تحضير مكتمل حتى الآن.',
                color: warn,
                icon: Icons.pending_actions,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        _OverviewStatCard(
          title: 'فرص تطوير التخطيط',
          value: '$inProgress',
          description: 'عدد الحصص التي يمكن تحسين جاهزيتها قبل بدء الأسبوع.',
          color: primary,
          icon: Icons.bolt,
        ),
      ],
    );
  }
}

class _ReadinessBySubjectChart extends StatelessWidget {
  final Map<String, List<bool>> bySubject;

  const _ReadinessBySubjectChart({required this.bySubject});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0F766E);
    const primary = Color(0xFF14B8A6);
    final entries = bySubject.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: entries.length,
      separatorBuilder: (_, __) => SizedBox(width: 8.w),
      itemBuilder: (_, i) {
        final e = entries[i];
        final total = e.value.length;
        final prepared = e.value.where((v) => v).length;
        final percent = total == 0
            ? 0.0
            : (prepared / total * 100).clamp(0.0, 100.0);
        return ClipRRect(
          borderRadius: BorderRadius.circular(18.r),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              width: 152.w,
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.72),
                borderRadius: BorderRadius.circular(18.r),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    e.key,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w800,
                      color: Colors.blueGrey.shade900,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (percent / 100.0).clamp(0.0, 1.0),
                      minHeight: 10.h,
                      backgroundColor: Colors.black.withValues(alpha: 0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(primary),
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Text(
                        '${percent.toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w900,
                          color: primaryDark,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '$prepared/$total',
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: Colors.blueGrey.shade700,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ReadinessTeachersTable extends StatelessWidget {
  final Map<String, Map<String, dynamic>> stats;
  final Map<String, User> teachers;

  const _ReadinessTeachersTable({required this.stats, required this.teachers});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0F766E);
    final rows = stats.entries.toList()
      ..sort(
        (a, b) =>
            (a.value['prepared'] as int).compareTo(b.value['prepared'] as int),
      );

    Widget glass(Widget child) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(22.r),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(22.r),
              border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
            ),
            child: child,
          ),
        ),
      );
    }

    if (rows.isEmpty) {
      return glass(
        SizedBox(
          height: 140.h,
          child: Center(
            child: Text(
              'لا توجد سجلات تحضير للمدة المحددة.',
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w700,
                color: Colors.blueGrey.shade700,
              ),
            ),
          ),
        ),
      );
    }
    return glass(
      Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Text(
                'تفاصيل الجاهزية حسب المعلمين',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w900,
                  color: primaryDark,
                ),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('المعلم')),
                  DataColumn(label: Text('نسبة الجاهزية')),
                  DataColumn(label: Text('غير محضر')),
                  DataColumn(label: Text('آخر تحديث')),
                ],
                rows: rows.map((e) {
                  final total = e.value['total'] as int;
                  final prepared = e.value['prepared'] as int;
                  final percent = total == 0
                      ? 0.0
                      : (prepared / total * 100.0).clamp(0.0, 100.0);
                  final missing = total - prepared;
                  final last = e.value['last'] as DateTime;
                  final name = teachers[e.key]?.name ?? e.key;
                  return DataRow(
                    cells: [
                      DataCell(Text(name)),
                      DataCell(Text('${percent.toStringAsFixed(1)}%')),
                      DataCell(Text('$missing')),
                      DataCell(Text(last.toString().split(' ').first)),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReadinessRecommendationsBox extends StatelessWidget {
  final double readinessPercent;

  const _ReadinessRecommendationsBox({required this.readinessPercent});

  @override
  Widget build(BuildContext context) {
    const primaryDark = Color(0xFF0F766E);
    const primary = Color(0xFF14B8A6);
    const warn = Color(0xFFF59E0B);
    const danger = Color(0xFFEF4444);
    String headline;
    List<String> bullets;

    if (readinessPercent >= 85) {
      headline = 'جاهزية عالية مع فرص تعزيز الاستدامة.';
      bullets = [
        'مشاركة الممارسات المميزة بين المعلمين ذوي الجاهزية المرتفعة.',
        'الاستمرار في متابعة تحديث الخطط قبل بداية الأسبوع الدراسي.',
        'تخصيص تكريم دوري للمعلمين الملتزمين بالتخطيط المبكر.',
      ];
    } else if (readinessPercent >= 60) {
      headline = 'جاهزية متوسطة مع فرص تطوير واضحة.';
      bullets = [
        'تحديد المعلمين ذوي الجاهزية الأقل من 70٪ وتقديم دعم إشرافي لهم.',
        'تفعيل جلسات سريعة لمراجعة نماذج الخطط وتحسين توحيدها.',
        'متابعة رفع الجاهزية في المواد الحرجة قبل تقييمات الوزارة.',
      ];
    } else {
      headline = 'جاهزية تحتاج إلى تدخل قيادي مباشر.';
      bullets = [
        'إعداد خطة عاجلة لتحسين التخطيط في المواد الأساسية.',
        'تحديد الفصول ذات الجاهزية المنخفضة ووضع خطة دعم خاصة بها.',
        'رفع تقرير موجز لإدارة التعليم يوضح خطة التحسين الزمنية.',
      ];
    }

    final tone = readinessPercent >= 85
        ? primary
        : readinessPercent >= 60
        ? warn
        : danger;

    return ClipRRect(
      borderRadius: BorderRadius.circular(22.r),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            color: tone.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(22.r),
            border: Border.all(color: tone.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توصيات تطويرية',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                  color: primaryDark,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                headline,
                style: TextStyle(
                  fontSize: 12.sp,
                  color: Colors.blueGrey.shade800,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 8.h),
              ...bullets.map(
                (b) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ',
                        style: TextStyle(fontSize: 12.sp, color: primaryDark),
                      ),
                      Expanded(
                        child: Text(
                          b,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.blueGrey.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PacingDelayTab extends ConsumerWidget {
  const PacingDelayTab({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final delays = ref.watch(pacingDelayProvider);
    return Column(
      children: [
        const UnifiedToolbar(extraActions: []),
        Expanded(
          child: delays.when(
            data: (items) {
              if (items.isEmpty) {
                return const UnifiedEmptyState(
                  message: 'لا توجد تأخيرات مسجلة',
                );
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (_, i) {
                  final x = items[i];
                  return ListTile(
                    title: Text('${x['className']} • ${x['subjectName']}'),
                    subtitle: Text(
                      'المفترض: ${x['expected']} — المنجز: ${x['covered']}',
                    ),
                    trailing: Text(
                      '${x['delay']}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () {},
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => UnifiedEmptyState(message: 'خطأ: $e'),
          ),
        ),
      ],
    );
  }
}

class AcademicAlertsTab extends ConsumerStatefulWidget {
  const AcademicAlertsTab({super.key});
  @override
  ConsumerState<AcademicAlertsTab> createState() => _AcademicAlertsTabState();
}

class _AcademicAlertsTabState extends ConsumerState<AcademicAlertsTab> {
  String? _severity;
  String? _status;

  @override
  Widget build(BuildContext context) {
    final alerts = ref.watch(
      academicAlertsProvider(
        AlertFilters(severity: _severity, status: _status),
      ),
    );
    return Column(
      children: [
        UnifiedToolbar(
          onFilter: () {
            showModalBottomSheet(
              context: context,
              builder: (_) => _AlertFilterSheet(
                initialSeverity: _severity,
                initialStatus: _status,
                onApply: (sev, sts) => setState(() {
                  _severity = sev;
                  _status = sts;
                }),
              ),
            );
          },
          extraActions: [
            IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: () async {
                final list = alerts.asData?.value ?? [];
                final header = await _loadSchoolHeaderLabel(ref);
                final doc = await MinistryPdfTemplate.generateReport(
                  title: 'تنبيهات الأداء',
                  subTitle: 'Academic Alerts',
                  schoolName: header['schoolName'] ?? '',
                  adminRegion: header['adminRegion'] ?? '',
                  dateFrom: '',
                  dateTo: '',
                  tableHeaders: ['التاريخ', 'المستوى', 'الحالة', 'العنوان'],
                  tableData: list
                      .map(
                        (a) => [
                          a.createdAt.toString().split(' ').first,
                          a.severity,
                          a.status,
                          a.title,
                        ],
                      )
                      .toList(),
                  footerText: 'متابعة الإشراف الأكاديمي',
                );
                final pdf = await doc.save();
                await showDialog(
                  context: context,
                  builder: (_) => AlertDialog(
                    content: Text(
                      'تم تجهيز تقرير PDF (${pdf.lengthInBytes} bytes)',
                    ),
                  ),
                );
              },
              tooltip: 'تصدير PDF',
            ),
          ],
        ),
        Expanded(
          child: alerts.when(
            data: (list) {
              if (list.isEmpty) {
                return const UnifiedEmptyState(message: 'لا توجد تنبيهات');
              }
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, __) =>
                    Divider(height: 1, color: Colors.grey.shade200),
                itemBuilder: (_, i) {
                  final a = list[i];
                  final color = a.severity == 'high'
                      ? Colors.red
                      : a.severity == 'medium'
                      ? Colors.orange
                      : Colors.blueGrey;
                  return ListTile(
                    leading: Icon(Icons.notification_important, color: color),
                    title: Text(a.title),
                    subtitle: Text(
                      '${a.severity.toUpperCase()} • ${a.status} • ${a.createdAt.toString().split(' ').first}',
                    ),
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('عرض التفاصيل'),
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => UnifiedEmptyState(message: 'خطأ: $e'),
          ),
        ),
      ],
    );
  }
}

class _FiltersSheet extends StatefulWidget {
  final void Function(String?, String?) onApply;
  const _FiltersSheet({required this.onApply});
  @override
  State<_FiltersSheet> createState() => _FiltersSheetState();
}

class _FiltersSheetState extends State<_FiltersSheet> {
  final TextEditingController _classCtrl = TextEditingController();
  final TextEditingController _subjectCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'الصف / الشعبة',
              hintText: 'مثال: 3/1 أو 3A',
            ),
            controller: _classCtrl,
            textDirection: TextDirection.rtl,
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'المادة',
              hintText: 'مثال: رياضيات، علوم',
            ),
            controller: _subjectCtrl,
            textDirection: TextDirection.rtl,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              widget.onApply(
                _classCtrl.text.isEmpty ? null : _classCtrl.text,
                _subjectCtrl.text.isEmpty ? null : _subjectCtrl.text,
              );
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _WeekFilterSheet extends StatefulWidget {
  final DateTime from;
  final DateTime to;
  final void Function(DateTime, DateTime, String?) onApply;
  const _WeekFilterSheet({
    required this.from,
    required this.to,
    required this.onApply,
  });
  @override
  State<_WeekFilterSheet> createState() => _WeekFilterSheetState();
}

class _WeekFilterSheetState extends State<_WeekFilterSheet> {
  late DateTime _from;
  late DateTime _to;
  late TextEditingController _fromCtrl;
  late TextEditingController _toCtrl;
  final TextEditingController _teacherCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _from = widget.from;
    _to = widget.to;
    _fromCtrl = TextEditingController(
      text:
          '${_from.day.toString().padLeft(2, '0')}-${_from.month.toString().padLeft(2, '0')}-${_from.year}',
    );
    _toCtrl = TextEditingController(
      text:
          '${_to.day.toString().padLeft(2, '0')}-${_to.month.toString().padLeft(2, '0')}-${_to.year}',
    );
  }

  DateTime? _parseDate(String text) {
    final parts = text.split('-');
    if (parts.length != 3) return null;
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    return DateTime(year, month, day);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            decoration: const InputDecoration(
              labelText: 'تاريخ البداية',
              hintText: 'مثال: 22-02-2026',
            ),
            controller: _fromCtrl,
            keyboardType: TextInputType.datetime,
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'تاريخ النهاية',
              hintText: 'مثال: 28-02-2026',
            ),
            controller: _toCtrl,
            keyboardType: TextInputType.datetime,
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'المعلم (اختياري)',
              hintText: 'اكتب اسم المعلم أو معرّفه',
            ),
            controller: _teacherCtrl,
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              final parsedFrom = _parseDate(_fromCtrl.text);
              final parsedTo = _parseDate(_toCtrl.text);
              widget.onApply(
                parsedFrom ?? _from,
                parsedTo ?? _to,
                _teacherCtrl.text.isEmpty ? null : _teacherCtrl.text,
              );
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}

class _AlertFilterSheet extends StatefulWidget {
  final String? initialSeverity;
  final String? initialStatus;
  final void Function(String?, String?) onApply;
  const _AlertFilterSheet({
    this.initialSeverity,
    this.initialStatus,
    required this.onApply,
  });
  @override
  State<_AlertFilterSheet> createState() => _AlertFilterSheetState();
}

class _AlertFilterSheetState extends State<_AlertFilterSheet> {
  String? _severity;
  String? _status;
  @override
  void initState() {
    super.initState();
    _severity = widget.initialSeverity;
    _status = widget.initialStatus;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            value: _severity,
            items: const [
              DropdownMenuItem(value: 'high', child: Text('عالية')),
              DropdownMenuItem(value: 'medium', child: Text('متوسطة')),
              DropdownMenuItem(value: 'low', child: Text('منخفضة')),
            ],
            onChanged: (v) => setState(() => _severity = v),
            decoration: const InputDecoration(labelText: 'الحدة'),
          ),
          DropdownButtonFormField<String>(
            value: _status,
            items: const [
              DropdownMenuItem(value: 'open', child: Text('مفتوحة')),
              DropdownMenuItem(
                value: 'in_progress',
                child: Text('قيد المتابعة'),
              ),
              DropdownMenuItem(value: 'closed', child: Text('مغلقة')),
            ],
            onChanged: (v) => setState(() => _status = v),
            decoration: const InputDecoration(labelText: 'الحالة'),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () {
              widget.onApply(_severity, _status);
              Navigator.pop(context);
            },
            child: const Text('تطبيق'),
          ),
        ],
      ),
    );
  }
}
