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

// ─── نماذج مقاسات الورق ───────────────────────────────────────────────────────
class _LabelFormat {
  final String id;
  final String name;
  final String description;
  final int cols;
  final int rows;
  final double labelWidthMm;
  final double labelHeightMm;
  final PdfPageFormat pageFormat;

  const _LabelFormat({
    required this.id,
    required this.name,
    required this.description,
    required this.cols,
    required this.rows,
    required this.labelWidthMm,
    required this.labelHeightMm,
    required this.pageFormat,
  });

  int get perPage => cols * rows;
}

final _labelFormats = <_LabelFormat>[
  _LabelFormat(
    id: 'a4_5x13',
    name: 'A4 — 5×13 (65 ملصق)',
    description: '38.1 × 21.2 مم — ورق A4 لاصق مقسم',
    cols: 5,
    rows: 13,
    labelWidthMm: 38.1,
    labelHeightMm: 21.2,
    pageFormat: PdfPageFormat.a4,
  ),
  _LabelFormat(
    id: 'a4_3x7_dragon',
    name: 'A4 — دبل دراجون 3×7 (21 ملصق)',
    description: '63.5 × 38.1 مم — مقاس A4 دبل دراجون',
    cols: 3,
    rows: 7,
    labelWidthMm: 63.5,
    labelHeightMm: 38.1,
    pageFormat: PdfPageFormat.a4,
  ),
  _LabelFormat(
    id: 'a4_4x10',
    name: 'A4 — 4×10 (40 ملصق)',
    description: '48.5 × 25.4 مم — ورق A4 لاصق',
    cols: 4,
    rows: 10,
    labelWidthMm: 48.5,
    labelHeightMm: 25.4,
    pageFormat: PdfPageFormat.a4,
  ),
  _LabelFormat(
    id: 'a4_2x7',
    name: 'A4 — 2×7 (14 ملصق)',
    description: '99.1 × 38.1 مم — ملصقات كبيرة',
    cols: 2,
    rows: 7,
    labelWidthMm: 99.1,
    labelHeightMm: 38.1,
    pageFormat: PdfPageFormat.a4,
  ),
  _LabelFormat(
    id: 'a4_3x11',
    name: 'A4 — 3×11 (33 ملصق)',
    description: '70.0 × 25.4 مم — ورق A4 لاصق',
    cols: 3,
    rows: 11,
    labelWidthMm: 70.0,
    labelHeightMm: 25.4,
    pageFormat: PdfPageFormat.a4,
  ),
];

class _StudentLabelsScreenState extends ConsumerState<StudentLabelsScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  String? _classId;
  final _selectedIds = <String>{};
  bool _showGuides = false;
  late _LabelFormat _selectedFormat;

  @override
  void initState() {
    super.initState();
    _selectedFormat = _labelFormats[0];
  }

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
      format: _selectedFormat,
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
    required _LabelFormat format,
  }) async {
    final pdf = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final bold = await PdfGoogleFonts.cairoBold();

    final cols = format.cols;
    final rows = format.rows;
    final perPage = format.perPage;

    final labelW = format.labelWidthMm * PdfPageFormat.mm;
    final labelH = format.labelHeightMm * PdfPageFormat.mm;

    final pageW = format.pageFormat.width;
    final pageH = format.pageFormat.height;

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
          pageFormat: format.pageFormat,
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
                                format: format,
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
    required _LabelFormat format,
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

    // حجم QR يتناسب مع حجم الملصق
    final qrSize = (format.labelHeightMm * 0.80) * PdfPageFormat.mm;
    // حجم الخط يتناسب مع حجم الملصق
    final nameFontSize = format.labelHeightMm >= 35 ? 9.5 : 7.2;
    final classFontSize = format.labelHeightMm >= 35 ? 8.5 : 6.6;

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
        pw.SizedBox(width: 3),
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
                  fontSize: nameFontSize,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (classLabel.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'فصل: $classLabel',
                  maxLines: 1,
                  overflow: pw.TextOverflow.clip,
                  textDirection: pw.TextDirection.rtl,
                  style: pw.TextStyle(fontSize: classFontSize),
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
      subtitle: 'اختر مقاس الورق ثم صدّر للطباعة',
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
                        // ─── قائمة المقاسات تظهر دائماً ──────────────
                        Card(
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: BorderSide(color: Colors.grey.shade200),
                          ),
                          child: Padding(
                            padding: EdgeInsets.all(12.w),
                            child: DropdownButtonFormField<_LabelFormat>(
                              value: _selectedFormat,
                              decoration: InputDecoration(
                                labelText: 'مقاس ورق الملصقات',
                                prefixIcon: const Icon(Icons.straighten,
                                    color: Colors.indigo),
                                border: const OutlineInputBorder(),
                                filled: true,
                                fillColor: Colors.indigo.shade50,
                              ),
                              items: _labelFormats.map((fmt) {
                                return DropdownMenuItem<_LabelFormat>(
                                  value: fmt,
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 4),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(fmt.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        Text(fmt.description,
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey.shade600)),
                                      ],
                                    ),
                                  ),
                                );
                              }).toList(),
                              onChanged: (v) {
                                if (v != null) setState(() => _selectedFormat = v);
                              },
                              selectedItemBuilder: (context) {
                                return _labelFormats.map((fmt) {
                                  return Row(children: [
                                    const Icon(Icons.label_outline,
                                        size: 16, color: Colors.indigo),
                                    const SizedBox(width: 6),
                                    Text(fmt.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13)),
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.indigo.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text('${fmt.perPage} ملصق/ورقة',
                                          style: TextStyle(
                                              fontSize: 10,
                                              color: Colors.indigo.shade800)),
                                    ),
                                  ]);
                                }).toList();
                              },
                            ),
                          ),
                        ),
                        SizedBox(height: 12.h),
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
                              // ─── صف 1: بحث + فصل ───────────────────────
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
                                    width: 200.w,
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
                              // ─── صف 2: مقاس ورق الملصقات ───────────────
                              DropdownButtonFormField<_LabelFormat>(
                                value: _selectedFormat,
                                decoration: InputDecoration(
                                  labelText: 'مقاس ورق الملصقات',
                                  prefixIcon: const Icon(Icons.straighten,
                                      color: Colors.indigo),
                                  border: const OutlineInputBorder(),
                                  filled: true,
                                  fillColor: Colors.indigo.shade50,
                                ),
                                items: _labelFormats.map((fmt) {
                                  return DropdownMenuItem<_LabelFormat>(
                                    value: fmt,
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 4),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(fmt.name,
                                              style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13)),
                                          Text(fmt.description,
                                              style: TextStyle(
                                                  fontSize: 11,
                                                  color:
                                                      Colors.grey.shade600)),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (v) {
                                  if (v != null) {
                                    setState(() => _selectedFormat = v);
                                  }
                                },
                                selectedItemBuilder: (context) {
                                  return _labelFormats.map((fmt) {
                                    return Row(
                                      children: [
                                        const Icon(Icons.label_outline,
                                            size: 16, color: Colors.indigo),
                                        const SizedBox(width: 6),
                                        Text(fmt.name,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13)),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.indigo.shade100,
                                            borderRadius:
                                                BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            '${fmt.perPage} ملصق/ورقة',
                                            style: TextStyle(
                                                fontSize: 10,
                                                color:
                                                    Colors.indigo.shade800),
                                          ),
                                        ),
                                      ],
                                    );
                                  }).toList();
                                },
                              ),
                              SizedBox(height: 10.h),
                              // ─── صف 3: خطوط إرشادية + طباعة ───────────
                              Row(
                                children: [
                                  Expanded(
                                    child: SwitchListTile(
                                      contentPadding: EdgeInsets.zero,
                                      title:
                                          const Text('إظهار خطوط إرشادية'),
                                      subtitle: const Text(
                                        'للمعايرة فقط (يفضل إيقافها عند الطباعة).',
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
