import 'dart:typed_data';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/mock_class_repository.dart';

class StudentLabelsScreen extends ConsumerStatefulWidget {
  const StudentLabelsScreen({super.key});

  @override
  ConsumerState<StudentLabelsScreen> createState() =>
      _StudentLabelsScreenState();
}

class _StudentLabelsScreenState extends ConsumerState<StudentLabelsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _classId;
  final _selectedIds = <String>{};
  bool _showGuides = false;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _printDialog({
    required List<User> students,
    required Map<String, String> classLabelById,
  }) async {
    if (students.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب للطباعة'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final mode = await showDialog<_PrintMode>(
      context: context,
      builder: (ctx) =>
          _PrintModeDialog(canPrintSelected: _selectedIds.isNotEmpty),
    );
    if (mode == null) return;

    List<User> target = [];
    if (mode == _PrintMode.all) {
      target = students;
    } else if (mode == _PrintMode.selected) {
      target = students.where((s) => _selectedIds.contains(s.id)).toList();
    } else if (mode == _PrintMode.single) {
      final id = await showDialog<String>(
        context: context,
        builder: (ctx) => _PickSingleStudentDialog(students: students),
      );
      if (id == null || id.trim().isEmpty) return;
      final student = students.firstWhere(
        (s) => s.id == id,
        orElse: () => students.first,
      );
      target = [student];
    }

    if (target.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب للطباعة حسب الاختيار'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final bytes = await _buildLabelsPdf(
      students: target,
      schoolId: (ref.read(authStateProvider).value?.schoolId ?? '').trim(),
      classLabelById: classLabelById,
      showGuides: _showGuides,
    );
    await Printing.layoutPdf(
      onLayout: (_) async => Uint8List.fromList(bytes),
      name: 'Student_Labels_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  Future<List<int>> _buildLabelsPdf({
    required List<User> students,
    required String schoolId,
    required Map<String, String> classLabelById,
    required bool showGuides,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();

    const cols = 5;
    const rows = 13;
    const perPage = cols * rows;

    final labelW = 38.1 * PdfPageFormat.mm;
    final labelH = 21.2 * PdfPageFormat.mm;

    final pageW = PdfPageFormat.a4.width;
    final pageH = PdfPageFormat.a4.height;

    final left = max(0.0, (pageW - cols * labelW) / 2);
    final top = max(0.0, (pageH - rows * labelH) / 2);

    List<List<User>> chunks = [];
    for (var i = 0; i < students.length; i += perPage) {
      chunks.add(students.sublist(i, min(i + perPage, students.length)));
    }
    if (chunks.isEmpty) chunks = [[]];

    for (final chunk in chunks) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: pw.ThemeData.withFont(base: font, bold: bold),
          build: (_) {
            final cells = List<User?>.generate(
              perPage,
              (i) => i < chunk.length ? chunk[i] : null,
            );

            return pw.Padding(
              padding: pw.EdgeInsets.only(left: left, top: top),
              child: pw.Table(
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                children: List.generate(rows, (r) {
                  return pw.TableRow(
                    children: List.generate(cols, (c) {
                      final idx = r * cols + c;
                      final student = cells[idx];
                      return pw.Container(
                        width: labelW,
                        height: labelH,
                        padding: const pw.EdgeInsets.all(2),
                        decoration: showGuides
                            ? pw.BoxDecoration(
                                border: pw.Border.all(
                                  color: PdfColors.grey300,
                                  width: 0.4,
                                ),
                              )
                            : null,
                        child: student == null
                            ? pw.SizedBox()
                            : _labelCell(
                                student: student,
                                schoolId: schoolId,
                                classLabelById: classLabelById,
                              ),
                      );
                    }),
                  );
                }),
              ),
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  pw.Widget _labelCell({
    required User student,
    required String schoolId,
    required Map<String, String> classLabelById,
  }) {
    final sid = schoolId.trim().isEmpty
        ? (student.schoolId ?? '').trim()
        : schoolId.trim();
    final code = 'MNAR|$sid|${student.id}';

    final classId = (student.assignedClassIds ?? const []).isNotEmpty
        ? student.assignedClassIds!.first
        : '';
    final classLabel = (classLabelById[classId] ?? '').trim();
    final name = student.name.trim();

    final qrSize = 17.5 * PdfPageFormat.mm;

    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.BarcodeWidget(
          barcode: pw.Barcode.qrCode(),
          data: code,
          width: qrSize,
          height: qrSize,
          drawText: false,
        ),
        pw.SizedBox(width: 2),
        pw.Expanded(
          child: pw.Column(
            mainAxisAlignment: pw.MainAxisAlignment.center,
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                name,
                maxLines: 2,
                overflow: pw.TextOverflow.clip,
                textDirection: pw.TextDirection.rtl,
                style: pw.TextStyle(
                  fontSize: 7.2,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (classLabel.isNotEmpty) ...[
                pw.SizedBox(height: 1.5),
                pw.Text(
                  'فصل: $classLabel',
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pw.TextDirection.rtl,
                  style: const pw.TextStyle(fontSize: 6.6),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final studentsAsync = ref.watch(studentsProvider);
    final classesAsync = ref.watch(classesProvider);

    return UnifiedPageScaffold(
      title: 'ملصقات تعريف الطلاب',
      subtitle: 'طباعة ملصقات A4 (5×13) مناسبة للورق اللاصق المقسم',
      allowedRoles: const [
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.deputy,
        UserRole.supportAdmin,
        UserRole.technicalSupport,
      ],
      body: (user?.schoolId ?? '').trim().isEmpty
          ? const UnifiedEmptyState(
              message: 'لا يمكن عرض هذه الصفحة بدون مدرسة مرتبطة بالحساب.',
              icon: Icons.qr_code_2,
            )
          : studentsAsync.when(
              data: (students) {
                final list = students
                    .where((s) => s.role == UserRole.student)
                    .toList();
                if (list.isEmpty) {
                  return Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      children: [
                        const UnifiedEmptyState(
                          message:
                              'لا يوجد طلاب في المدرسة حالياً.\nأضف الطلاب أولاً ثم ارجع لطباعة الملصقات.',
                          icon: Icons.qr_code_2,
                        ),
                        SizedBox(height: 12.h),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => context.push('/students-list'),
                            icon: const Icon(Icons.people_alt),
                            label: const Text('فتح قائمة الطلاب'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 14.h),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                final classes = classesAsync.value ?? const [];
                final classLabelById = <String, String>{
                  for (final c in classes) c.id: c.preferredLabel,
                };

                var filtered = list;
                if (_classId != null && _classId!.trim().isNotEmpty) {
                  filtered = filtered.where((s) {
                    final ids = s.assignedClassIds ?? const [];
                    return ids.contains(_classId);
                  }).toList();
                }
                if (_query.trim().isNotEmpty) {
                  final q = _query.trim();
                  filtered = filtered.where((s) {
                    final code = (s.studentCode ?? s.identityNumber ?? '')
                        .toString();
                    final classId = (s.assignedClassIds ?? const []).isNotEmpty
                        ? s.assignedClassIds!.first
                        : '';
                    final classLabel = classLabelById[classId] ?? '';
                    return s.name.contains(q) ||
                        code.contains(q) ||
                        classLabel.contains(q);
                  }).toList();
                }

                return Padding(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    children: [
                      Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16.r),
                          side: BorderSide(color: Colors.grey.shade200),
                        ),
                        child: Padding(
                          padding: EdgeInsets.all(12.w),
                          child: Column(
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      decoration: const InputDecoration(
                                        labelText: 'بحث (اسم/كود/فصل)',
                                        prefixIcon: Icon(Icons.search),
                                        border: OutlineInputBorder(),
                                      ),
                                      onChanged: (v) => setState(() {
                                        _query = v;
                                      }),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  SizedBox(
                                    width: 220.w,
                                    child: DropdownButtonFormField<String?>(
                                      value: _classId,
                                      decoration: const InputDecoration(
                                        labelText: 'الفصل',
                                        border: OutlineInputBorder(),
                                      ),
                                      items: [
                                        const DropdownMenuItem<String?>(
                                          value: null,
                                          child: Text('الكل'),
                                        ),
                                        ...classes.map((c) {
                                          return DropdownMenuItem<String?>(
                                            value: c.id,
                                            child: Text(c.preferredLabel),
                                          );
                                        }),
                                      ],
                                      onChanged: (v) => setState(() {
                                        _classId = v;
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 10.h),
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title: const Text('إظهار خطوط إرشادية'),
                                      subtitle: const Text(
                                        'للمعايرة فقط (يفضل إيقافها عند الطباعة على الملصقات).',
                                      ),
                                      value: _showGuides,
                                      onChanged: (v) =>
                                          setState(() => _showGuides = v),
                                    ),
                                  ),
                                  SizedBox(width: 10.w),
                                  ElevatedButton.icon(
                                    onPressed: () => _printDialog(
                                      students: filtered,
                                      classLabelById: classLabelById,
                                    ),
                                    icon: const Icon(Icons.print),
                                    label: const Text('تصدير للطباعة'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.indigo.shade700,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 16.w,
                                        vertical: 14.h,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 12.h),
                      Expanded(
                        child: filtered.isEmpty
                            ? const UnifiedEmptyState(
                                message: 'لا توجد نتائج مطابقة.',
                                icon: Icons.qr_code_2,
                              )
                            : Card(
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16.r),
                                  side: BorderSide(color: Colors.grey.shade200),
                                ),
                                child: ListView.separated(
                                  itemCount: filtered.length.clamp(0, 3000),
                                  separatorBuilder: (_, __) => Divider(
                                    height: 1,
                                    color: Colors.grey.shade200,
                                  ),
                                  itemBuilder: (context, index) {
                                    final s = filtered[index];
                                    final selected = _selectedIds.contains(
                                      s.id,
                                    );
                                    final classId =
                                        (s.assignedClassIds ?? const [])
                                            .isNotEmpty
                                        ? s.assignedClassIds!.first
                                        : '';
                                    final classLabel =
                                        (classLabelById[classId] ?? '').trim();
                                    final code =
                                        (s.studentCode ??
                                                s.identityNumber ??
                                                '')
                                            .toString()
                                            .trim();
                                    return CheckboxListTile(
                                      value: selected,
                                      onChanged: (v) => setState(() {
                                        if (v == true) {
                                          _selectedIds.add(s.id);
                                        } else {
                                          _selectedIds.remove(s.id);
                                        }
                                      }),
                                      title: Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        [
                                          if (classLabel.isNotEmpty)
                                            'الفصل: $classLabel',
                                          if (code.isNotEmpty) 'الكود: $code',
                                        ].join(' • '),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      secondary: Container(
                                        width: 34.w,
                                        height: 34.w,
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10.r,
                                          ),
                                        ),
                                        child: Icon(
                                          Icons.qr_code_2,
                                          color: Colors.indigo.shade700,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                      ),
                    ],
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'تعذر تحميل الطلاب.\n$e',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13.sp),
                ),
              ),
            ),
    );
  }
}

enum _PrintMode { single, selected, all }

class _PrintModeDialog extends StatefulWidget {
  final bool canPrintSelected;

  const _PrintModeDialog({required this.canPrintSelected});

  @override
  State<_PrintModeDialog> createState() => _PrintModeDialogState();
}

class _PrintModeDialogState extends State<_PrintModeDialog> {
  _PrintMode _mode = _PrintMode.all;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('خيارات الطباعة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RadioListTile<_PrintMode>(
            value: _PrintMode.all,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text('جميع الطلاب'),
          ),
          RadioListTile<_PrintMode>(
            value: _PrintMode.selected,
            groupValue: _mode,
            onChanged: widget.canPrintSelected
                ? (v) => setState(() => _mode = v!)
                : null,
            title: const Text('مجموعة طلاب (المحدد)'),
            subtitle: widget.canPrintSelected
                ? null
                : const Text('لم يتم تحديد أي طالب بعد'),
          ),
          RadioListTile<_PrintMode>(
            value: _PrintMode.single,
            groupValue: _mode,
            onChanged: (v) => setState(() => _mode = v!),
            title: const Text('طالب معين'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, _mode),
          child: const Text('متابعة'),
        ),
      ],
    );
  }
}

class _PickSingleStudentDialog extends StatefulWidget {
  final List<User> students;

  const _PickSingleStudentDialog({required this.students});

  @override
  State<_PickSingleStudentDialog> createState() =>
      _PickSingleStudentDialogState();
}

class _PickSingleStudentDialogState extends State<_PickSingleStudentDialog> {
  String _q = '';
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final list = _q.trim().isEmpty
        ? widget.students.take(200).toList()
        : widget.students
              .where(
                (s) =>
                    s.name.contains(_q.trim()) ||
                    (s.studentCode ?? s.identityNumber ?? '').contains(
                      _q.trim(),
                    ),
              )
              .take(200)
              .toList();

    return AlertDialog(
      title: const Text('اختر طالب'),
      content: SizedBox(
        width: 520,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'بحث سريع',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _q = v),
            ),
            SizedBox(height: 12.h),
            DropdownButtonFormField<String>(
              value: _selected,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'الطالب',
                border: OutlineInputBorder(),
              ),
              items: list
                  .map(
                    (s) => DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (v) => setState(() => _selected = v),
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
          onPressed: _selected == null
              ? null
              : () => Navigator.pop(context, _selected),
          child: const Text('اختيار'),
        ),
      ],
    );
  }
}
