import 'package:universal_io/io.dart';
import 'dart:math';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/email_generator.dart';
import '../../../core/utils/text_utils.dart';
import '../../../core/presentation/session_timeout_manager.dart';
import '../../../core/utils/web_utils.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import 'students_provider.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/student_repository.dart';
import '../data/firestore_parent_repository.dart';
import '../domain/classroom.dart';

class StudentsListScreen extends ConsumerStatefulWidget {
  final String? initialSearchQuery;
  const StudentsListScreen({super.key, this.initialSearchQuery});

  @override
  ConsumerState<StudentsListScreen> createState() => _StudentsListScreenState();
}

class _StudentsListScreenState extends ConsumerState<StudentsListScreen> {
  String _searchQuery = '';
  String? _selectedClassId;
  List<_ImportRowReport> _lastImportRows = const [];
  final _firestore = FirebaseFirestore.instance;

  static const _bulkUsernamePrefix = 'ST';

  bool _canAccessStudentsSection(User? user) {
    if (user == null) return false;
    return isStaffRole(user.role);
  }

  String _sanitizeUsername(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return '';
    return s.replaceAll(' ', '').toUpperCase();
  }

  String _generateUsername(Random rnd) {
    final digits = rnd.nextInt(1000000).toString().padLeft(6, '0');
    return '$_bulkUsernamePrefix$digits';
  }

  String _generatePin(Random rnd) {
    final code = String.fromCharCodes(
      Iterable.generate(6, (_) => 48 + rnd.nextInt(10)),
    );
    return code;
  }

  String _escapeCsv(String s) {
    final v = s.replaceAll('"', '""');
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }

  String _buildStudentCredentialsCsv(List<_ImportRowReport> rows) {
    final buf = StringBuffer();
    buf.writeln('name,class,username,pin');
    for (final r in rows) {
      if (r.status == _ImportRowStatus.failed) continue;
      final u = (r.username ?? '').trim();
      final p = (r.pin ?? '').trim();
      if (u.isEmpty || p.isEmpty) continue;
      buf.writeln(
        [
          _escapeCsv(r.name),
          _escapeCsv((r.classLabel ?? '').toString()),
          _escapeCsv(u),
          _escapeCsv(p),
        ].join(','),
      );
    }
    return buf.toString();
  }

  Uint8List? _buildStudentCredentialsXlsxBytesFromRows(
    List<_ImportRowReport> rows,
  ) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.sheets.keys.isNotEmpty
        ? excel.sheets.keys.first
        : 'Sheet1';
    try {
      excel.rename(defaultSheetName, 'بيانات الدخول');
    } catch (_) {}
    final sheet = excel['بيانات الدخول'];
    excel.setDefaultSheet('بيانات الدخول');
    final toDelete = excel.sheets.keys
        .where((k) => k != 'بيانات الدخول')
        .toList();
    for (final k in toDelete) {
      try {
        excel.delete(k);
      } catch (_) {}
    }

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 10);

    final centeredStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = ['اسم الطالب', 'الفصل', 'اسم المستخدم', 'PIN'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = centeredStyle;
    }

    var rowIndex = 1;
    for (final r in rows) {
      if (r.status == _ImportRowStatus.failed) continue;
      final u = (r.username ?? '').trim();
      final p = (r.pin ?? '').trim();
      if (u.isEmpty || p.isEmpty) continue;

      final c0 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      c0.value = TextCellValue(r.name);
      c0.cellStyle = centeredStyle;

      final c1 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      c1.value = TextCellValue((r.classLabel ?? '').toString());
      c1.cellStyle = centeredStyle;

      final c2 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
      );
      c2.value = TextCellValue(u);
      c2.cellStyle = centeredStyle;

      final c3 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
      );
      c3.value = TextCellValue(p);
      c3.cellStyle = centeredStyle;
      rowIndex++;
    }

    final bytes = excel.save();
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }

  void _downloadStudentCredentialsXlsxWebFromRows({
    required List<_ImportRowReport> rows,
    required String fileName,
  }) {
    final excel = Excel.createExcel();
    final defaultSheetName = excel.sheets.keys.isNotEmpty
        ? excel.sheets.keys.first
        : 'Sheet1';
    try {
      excel.rename(defaultSheetName, 'بيانات الدخول');
    } catch (_) {}
    final sheet = excel['بيانات الدخول'];
    excel.setDefaultSheet('بيانات الدخول');
    final toDelete = excel.sheets.keys
        .where((k) => k != 'بيانات الدخول')
        .toList();
    for (final k in toDelete) {
      try {
        excel.delete(k);
      } catch (_) {}
    }

    sheet.setColumnWidth(0, 30);
    sheet.setColumnWidth(1, 10);
    sheet.setColumnWidth(2, 18);
    sheet.setColumnWidth(3, 10);

    final centeredStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = ['اسم الطالب', 'الفصل', 'اسم المستخدم', 'PIN'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = centeredStyle;
    }

    var rowIndex = 1;
    for (final r in rows) {
      if (r.status == _ImportRowStatus.failed) continue;
      final u = (r.username ?? '').trim();
      final p = (r.pin ?? '').trim();
      if (u.isEmpty || p.isEmpty) continue;

      final c0 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      c0.value = TextCellValue(r.name);
      c0.cellStyle = centeredStyle;

      final c1 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      c1.value = TextCellValue((r.classLabel ?? '').toString());
      c1.cellStyle = centeredStyle;

      final c2 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
      );
      c2.value = TextCellValue(u);
      c2.cellStyle = centeredStyle;

      final c3 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
      );
      c3.value = TextCellValue(p);
      c3.cellStyle = centeredStyle;
      rowIndex++;
    }

    excel.save(fileName: fileName);
  }

  Uint8List? _buildStudentCredentialsXlsxBytesFromCsv(String csv) {
    final lines = csv
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length <= 1) return null;

    final rows = <_ImportRowReport>[];
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 4) continue;
      final name = parts[0].replaceAll('"', '').trim();
      final cls = parts[1].replaceAll('"', '').trim();
      final user = parts[2].replaceAll('"', '').trim();
      final pin = parts[3].replaceAll('"', '').trim();
      if (user.isEmpty || pin.isEmpty) continue;
      rows.add(
        _ImportRowReport(
          name: name.isEmpty ? '—' : name,
          classLabel: cls.isEmpty ? null : cls,
          username: user,
          pin: pin,
          status: _ImportRowStatus.completed,
        ),
      );
    }

    return _buildStudentCredentialsXlsxBytesFromRows(rows);
  }

  void _downloadStudentCredentialsXlsxWebFromCsv({
    required String csv,
    required String fileName,
  }) {
    final lines = csv
        .split('\n')
        .map((l) => l.trimRight())
        .where((l) => l.isNotEmpty)
        .toList();
    if (lines.length <= 1) return;

    final rows = <_ImportRowReport>[];
    for (var i = 1; i < lines.length; i++) {
      final parts = lines[i].split(',');
      if (parts.length < 4) continue;
      final name = parts[0].replaceAll('"', '').trim();
      final cls = parts[1].replaceAll('"', '').trim();
      final user = parts[2].replaceAll('"', '').trim();
      final pin = parts[3].replaceAll('"', '').trim();
      if (user.isEmpty || pin.isEmpty) continue;
      rows.add(
        _ImportRowReport(
          name: name.isEmpty ? '—' : name,
          classLabel: cls.isEmpty ? null : cls,
          username: user,
          pin: pin,
          status: _ImportRowStatus.completed,
        ),
      );
    }

    _downloadStudentCredentialsXlsxWebFromRows(rows: rows, fileName: fileName);
  }

  Future<void> _persistStudentCredentialsExport({
    required String schoolId,
    required String csv,
    required int rowCount,
  }) async {
    if (schoolId.trim().isEmpty) return;
    if (rowCount <= 0) return;

    final user = ref.read(authStateProvider).value;
    final createdAtMs = DateTime.now().millisecondsSinceEpoch;

    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CredentialExportsStudents')
        .add({
          'createdAt': FieldValue.serverTimestamp(),
          'createdAtMs': createdAtMs,
          'createdBy': user?.id,
          'rowCount': rowCount,
          'csv': csv,
        });

    final snap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CredentialExportsStudents')
        .orderBy('createdAtMs', descending: true)
        .get();
    if (snap.docs.length <= 20) return;
    final extra = snap.docs.skip(20).toList();
    for (final d in extra) {
      await d.reference.delete();
    }
  }

  Future<String?> _fetchLatestStudentCredentialsCsv(String schoolId) async {
    if (schoolId.trim().isEmpty) return null;
    final snap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CredentialExportsStudents')
        .orderBy('createdAtMs', descending: true)
        .limit(1)
        .get();
    if (snap.docs.isEmpty) return null;
    final data = snap.docs.first.data();
    final csv = (data['csv'] ?? '').toString();
    return csv.trim().isEmpty ? null : csv;
  }

  Future<List<_CredentialExportItem>> _fetchStudentExports(
    String schoolId,
  ) async {
    if (schoolId.trim().isEmpty) return const [];
    final snap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CredentialExportsStudents')
        .orderBy('createdAtMs', descending: true)
        .limit(25)
        .get();
    return snap.docs.map((d) {
      final data = d.data();
      return _CredentialExportItem(
        id: d.id,
        createdAtMs: (data['createdAtMs'] as int?) ?? 0,
        rowCount: (data['rowCount'] as int?) ?? 0,
        csv: (data['csv'] ?? '').toString(),
      );
    }).toList();
  }

  Future<void> _deleteStudentExport(String schoolId, String exportId) async {
    if (schoolId.trim().isEmpty) return;
    if (exportId.trim().isEmpty) return;
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CredentialExportsStudents')
        .doc(exportId)
        .delete();
  }

  Future<void> _showStudentExportHistoryDialog(String schoolId) async {
    final items = await _fetchStudentExports(schoolId);
    if (!mounted) return;
    if (items.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا توجد دفعات محفوظة')));
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('سجل دفعات طلاب'),
        content: SizedBox(
          width: 720,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: items.length,
            itemBuilder: (context, index) {
              final it = items[index];
              final dt = DateTime.fromMillisecondsSinceEpoch(it.createdAtMs);
              final label =
                  '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} '
                  '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
              return ListTile(
                title: Text('دفعة: $label'),
                subtitle: Text('عدد السجلات: ${it.rowCount}'),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    IconButton(
                      tooltip: 'نسخ',
                      icon: const Icon(Icons.copy),
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: it.csv));
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم نسخ CSV')),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'تنزيل/مشاركة',
                      icon: const Icon(Icons.download),
                      onPressed: () async {
                        final date = DateTime.now()
                            .toIso8601String()
                            .split('T')
                            .first;
                        if (kIsWeb) {
                          _downloadStudentCredentialsXlsxWebFromCsv(
                            csv: it.csv,
                            fileName: 'بيانات_دخول_الطلاب_$date.xlsx',
                          );
                        } else {
                          final bytes =
                              _buildStudentCredentialsXlsxBytesFromCsv(it.csv);
                          if (bytes == null) return;
                          final xFile = XFile.fromData(
                            bytes,
                            name: 'بيانات_دخول_الطلاب_$date.xlsx',
                            mimeType:
                                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                          );
                          await SharePlus.instance.share(
                            ShareParams(
                              files: [xFile],
                              text: 'بيانات دخول الطلاب',
                            ),
                          );
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: dctx,
                          builder: (c) => AlertDialog(
                            title: const Text('تأكيد الحذف'),
                            content: const Text('حذف هذه الدفعة؟'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c, false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c, true),
                                child: const Text(
                                  'حذف',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (ok != true) return;
                        await _deleteStudentExport(schoolId, it.id);
                        if (dctx.mounted) Navigator.pop(dctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم حذف الدفعة')),
                          );
                        }
                      },
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  void _openImportProgressDialog(
    ValueNotifier<_ImportProgressSnapshot> progress,
  ) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      useRootNavigator: true,
      builder: (context) {
        return AlertDialog(
          title: const Text('جاري الاستيراد...'),
          content: SizedBox(
            width: 520,
            child: ValueListenableBuilder<_ImportProgressSnapshot>(
              valueListenable: progress,
              builder: (context, snap, _) {
                final fraction = snap.total == 0
                    ? null
                    : (snap.processed / snap.total).clamp(0.0, 1.0);
                final percent = snap.total == 0
                    ? '—'
                    : '${((fraction ?? 0) * 100).round()}%';

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(value: fraction),
                    SizedBox(height: 12.h),
                    Text(
                      'تمت المعالجة: ${snap.processed} / ${snap.total} ($percent)',
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'تم: ${snap.completed}  |  مكرر: ${snap.duplicate}  |  فشل: ${snap.failed}',
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Future<(_ImportRowStatus, String, String?, String?)>
  _addStudentWithAutoUsername({
    required String schoolId,
    required String studentName,
    required String preferredUsername,
    required String parentPhone,
    required String parentIdentity,
    required DateTime? dob,
    required Set<String> reservedUsernames,
    List<String> assignedClassIds = const [],
  }) async {
    final repo = ref.read(studentRepositoryProvider);
    final rnd = Random(DateTime.now().microsecondsSinceEpoch);

    final requested = _sanitizeUsername(preferredUsername);
    var candidate = requested;
    var status = _ImportRowStatus.completed;
    if (candidate.isNotEmpty && reservedUsernames.contains(candidate)) {
      status = _ImportRowStatus.duplicate;
      candidate = '';
    }

    if (candidate.isNotEmpty &&
        !RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(candidate)) {
      status = _ImportRowStatus.duplicate;
      candidate = '';
    }

    final pin = _generatePin(rnd);
    String? createdUserId;

    String? lastError;
    for (var attempt = 0; attempt < 8; attempt++) {
      if (candidate.isEmpty) {
        candidate = _generateUsername(rnd);
        while (reservedUsernames.contains(candidate)) {
          candidate = _generateUsername(rnd);
        }
      }

      reservedUsernames.add(candidate);

      final email = EmailGenerator.generateEmail(
        UserRole.student,
        identityNumber: candidate,
      );

      final newStudent = User(
        id: const Uuid().v4(),
        name: studentName,
        email: email,
        role: UserRole.student,
        identityNumber: candidate,
        schoolId: schoolId,
        phoneNumber: parentPhone.isNotEmpty ? parentPhone : null,
        parentIdentityNumber: parentIdentity.isNotEmpty ? parentIdentity : null,
        assignedClassIds: assignedClassIds,
        dateOfBirth: dob,
      );

      try {
        await repo.addStudent(schoolId, newStudent, pin);
        return (status, candidate, pin, null);
      } catch (e) {
        lastError = e.toString();
        final isDup =
            lastError.contains('مستخدم بالفعل') ||
            lastError.toLowerCase().contains('already') ||
            lastError.toLowerCase().contains('exists') ||
            lastError.toLowerCase().contains('email');
        if (!isDup) {
          return (_ImportRowStatus.failed, candidate, null, null);
        }
        status = _ImportRowStatus.duplicate;
        candidate = '';
      }
    }

    return (
      _ImportRowStatus.failed,
      requested.isEmpty ? '' : requested,
      null,
      null,
    );
  }

  Future<void> _showImportReportDialog(List<_ImportRowReport> rows) async {
    if (!mounted) return;

    _lastImportRows = rows;
    final rootContext = context;
    final completed = rows
        .where((r) => r.status == _ImportRowStatus.completed)
        .length;
    final duplicated = rows
        .where((r) => r.status == _ImportRowStatus.duplicate)
        .length;
    final failed = rows
        .where((r) => r.status == _ImportRowStatus.failed)
        .length;

    final csvForDialog = _buildStudentCredentialsCsv(rows);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            'تقرير الاستيراد (تم: $completed، مكرر: $duplicated، فشل: $failed)',
          ),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('اسم الطالب')),
                  DataColumn(label: Text('الفصل')),
                  DataColumn(label: Text('اسم المستخدم')),
                  DataColumn(label: Text('PIN')),
                  DataColumn(label: Text('الحالة')),
                ],
                rows: rows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(Text(r.name)),
                          DataCell(Text(r.classLabel ?? '—')),
                          DataCell(Text(r.username ?? '—')),
                          DataCell(Text(r.pin ?? '—')),
                          DataCell(Text(r.status.label)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () async {
                if (csvForDialog.trim().split('\n').length <= 1) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(
                      content: Text('لا توجد بيانات دخول جاهزة للنسخ'),
                    ),
                  );
                  return;
                }
                await Clipboard.setData(ClipboardData(text: csvForDialog));
                if (rootContext.mounted) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(content: Text('تم نسخ بيانات الدخول (CSV)')),
                  );
                }
              },
              child: const Text('نسخ اليوزر والباسورد'),
            ),
            TextButton(
              onPressed: () async {
                final hasAny = rows.any((r) {
                  if (r.status == _ImportRowStatus.failed) return false;
                  final u = (r.username ?? '').trim();
                  final p = (r.pin ?? '').trim();
                  return u.isNotEmpty && p.isNotEmpty;
                });
                if (!hasAny) {
                  ScaffoldMessenger.of(rootContext).showSnackBar(
                    const SnackBar(
                      content: Text('لا توجد بيانات دخول للتصدير'),
                    ),
                  );
                  return;
                }
                final date = DateTime.now().toIso8601String().split('T').first;
                final fileName = 'بيانات_دخول_الطلاب_$date.xlsx';
                if (kIsWeb) {
                  _downloadStudentCredentialsXlsxWebFromRows(
                    rows: rows,
                    fileName: fileName,
                  );
                } else {
                  final bytes = _buildStudentCredentialsXlsxBytesFromRows(rows);
                  if (bytes == null) {
                    ScaffoldMessenger.of(rootContext).showSnackBar(
                      const SnackBar(
                        content: Text('لا توجد بيانات دخول للتصدير'),
                      ),
                    );
                    return;
                  }
                  final xFile = XFile.fromData(
                    bytes,
                    name: fileName,
                    mimeType:
                        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  );
                  await SharePlus.instance.share(
                    ShareParams(files: [xFile], text: 'بيانات دخول الطلاب'),
                  );
                }
                ScaffoldMessenger.of(rootContext).showSnackBar(
                  const SnackBar(content: Text('تم تنزيل ملف بيانات الدخول')),
                );
              },
              child: const Text('تصدير Excel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إغلاق'),
            ),
          ],
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialSearchQuery != null) {
      _searchQuery = widget.initialSearchQuery!;
    }
  }

  Future<void> _showImportOptions() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.table_chart),
                title: const Text('استيراد من ملف Excel (قالب عام)'),
                subtitle: const Text(
                  'الاسم، اسم المستخدم، الفصل، رقم ولي الأمر',
                ),
                onTap: () {
                  Navigator.pop(context);
                  _importFromExcel();
                },
              ),
              ListTile(
                leading: const Icon(Icons.school),
                title: const Text('استيراد من نظام نور'),
                subtitle: const Text('ملف Excel المصدر من نظام نور مباشرة'),
                onTap: () {
                  Navigator.pop(context);
                  _importFromNoor();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _importFromNoor() async {
    try {
      sessionTimeoutPausedNotifier.value = true;
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        List<int> bytes;
        if (platformFile.bytes != null) {
          bytes = platformFile.bytes!;
        } else if (platformFile.path != null) {
          final file = File(platformFile.path!);
          bytes = await file.readAsBytes();
        } else {
          return;
        }

        final excel = Excel.decodeBytes(bytes);
        final sheet = excel.tables[excel.tables.keys.first];

        if (sheet == null) {
          return;
        }

        final user = ref.read(authStateProvider).value;
        final schoolId = user?.schoolId ?? 'school_1';
        final classes = ref.read(classesProvider).value ?? [];

        // 1. Identify Headers
        int headerRowIndex = -1;
        Map<String, int> colMap = {};

        // Search first 20 rows for headers
        for (
          var i = 0;
          i < (sheet.rows.length < 20 ? sheet.rows.length : 20);
          i++
        ) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          for (var j = 0; j < row.length; j++) {
            final cell = row[j];
            if (cell == null) continue;

            String val = '';
            if (cell.value is TextCellValue) {
              val = (cell.value as TextCellValue).value.toString().trim();
            } else {
              val = cell.value.toString().trim();
            }

            if (val.contains('اسم الطالب') || val.contains('الاسم الرباعي'))
              colMap['name'] = j;
            if (val.contains('اسم المستخدم') ||
                val.contains('اليوزر') ||
                val.contains('mncode') ||
                val.contains('mn code') ||
                val.contains('رمز الدخول'))
              colMap['identity'] = j;
            if (val.contains('رقم الجوال') || val.contains('جوال ولي الأمر'))
              colMap['phone'] = j;
            if (val.contains('هوية ولي الأمر') || val.contains('سجل ولي الأمر'))
              colMap['parent_id'] = j;
            if (val.contains('تاريخ الميلاد')) colMap['dob'] = j;
            if (val.contains('الفصل') || val.contains('الصف'))
              colMap['class'] = j;
          }
          if (colMap.containsKey('name')) {
            headerRowIndex = i;
            break;
          }
        }

        if (headerRowIndex == -1) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لم يتم العثور على ترويسة البيانات (اسم الطالب)'),
            ),
          );
          return;
        }

        var total = 0;
        for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;
          final cell =
              colMap.containsKey('name') && colMap['name']! < row.length
              ? row[colMap['name']!]
              : null;
          final nameVal = cell?.value?.toString().trim() ?? '';
          if (nameVal.isNotEmpty) total++;
        }

        final progress = ValueNotifier<_ImportProgressSnapshot>(
          _ImportProgressSnapshot(total: total),
        );
        if (mounted) _openImportProgressDialog(progress);

        final reservedUsernames = <String>{};
        final report = <_ImportRowReport>[];

        for (var i = headerRowIndex + 1; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          // Helper to get cell value
          String getVal(String key) {
            if (!colMap.containsKey(key) || colMap[key]! >= row.length)
              return '';
            final cell = row[colMap[key]!];
            if (cell == null) return '';
            if (cell.value is TextCellValue) {
              return (cell.value as TextCellValue).value.toString().trim();
            }
            return cell.value.toString().trim();
          }

          String name = getVal('name');
          String identity = getVal('identity');
          String phone = getVal('phone');
          String parentIdentity = getVal('parent_id');
          String dobStr = getVal('dob');
          String classLabel = getVal('class');

          if (name.isEmpty) continue;

          // If parent identity is missing, try to use phone or generate one if strictly needed
          // But repository logic requires parentIdentity for auto-creation.
          // If Noor file doesn't have it, we might fall back to a placeholder or ask user.
          // For now, if missing, we use phone as fallback for ID if it looks like an ID, else skip parent auto-creation logic
          if (parentIdentity.isEmpty &&
              phone.isNotEmpty &&
              phone.startsWith('1')) {
            // Heuristic: IDs often start with 1 or 2. Phones start with 05.
            // Actually, don't guess.
          }

          String? classId;
          if (classLabel.isNotEmpty) {
            for (final c in classes) {
              if (c.preferredLabel == classLabel ||
                  c.name == classLabel ||
                  '${c.gradeLevel}/${c.sectionNumber}' == classLabel ||
                  classLabel.contains(c.preferredLabel) ||
                  c.preferredLabel.contains(classLabel)) {
                classId = c.id;
                break;
              }
            }
          }

          final dob = dobStr.isNotEmpty ? DateTime.tryParse(dobStr) : null;
          final (
            status,
            username,
            pin,
            createdId,
          ) = await _addStudentWithAutoUsername(
            schoolId: schoolId,
            studentName: name,
            preferredUsername: identity,
            parentPhone: phone,
            parentIdentity: parentIdentity,
            dob: dob,
            reservedUsernames: reservedUsernames,
            assignedClassIds: classId != null ? [classId] : const [],
          );

          if (status == _ImportRowStatus.completed &&
              classId != null &&
              createdId != null &&
              schoolId.isNotEmpty) {
            try {
              final firestoreClassRepo = ref.read(
                firestoreClassRepositoryProvider,
              );
              final c = await firestoreClassRepo.getClassById(
                schoolId,
                classId,
              );
              if (c != null) {
                final newIds = List<String>.from(c.studentIds);
                if (!newIds.contains(createdId)) {
                  newIds.add(createdId);
                  final updatedClass = Classroom(
                    id: c.id,
                    name: c.name,
                    nameCode: c.nameCode,
                    displayName: c.displayName,
                    gradeLevel: c.gradeLevel,
                    studentIds: newIds,
                    secondaryProgramType: c.secondaryProgramType,
                    secondaryTrack: c.secondaryTrack,
                    secondaryPhase: c.secondaryPhase,
                    sectionNumber: c.sectionNumber,
                  );
                  await firestoreClassRepo.updateClass(schoolId, updatedClass);
                }
              }
            } catch (_) {}
          }

          report.add(
            _ImportRowReport(
              name: name,
              classLabel: classLabel.isEmpty ? null : classLabel,
              username: username.isEmpty ? null : username,
              pin: pin,
              status: status,
            ),
          );

          final snap = progress.value;
          progress.value = snap.copyWith(
            processed: snap.processed + 1,
            completed:
                snap.completed + (status == _ImportRowStatus.completed ? 1 : 0),
            duplicate:
                snap.duplicate + (status == _ImportRowStatus.duplicate ? 1 : 0),
            failed: snap.failed + (status == _ImportRowStatus.failed ? 1 : 0),
          );
        }

        if (mounted) {
          final csv = _buildStudentCredentialsCsv(report);
          final rowCount = csv.trim().split('\n').length - 1;
          await _persistStudentCredentialsExport(
            schoolId: schoolId,
            csv: csv,
            rowCount: rowCount,
          );
          Navigator.of(context, rootNavigator: true).pop();
          await _showImportReportDialog(report);
          ref.invalidate(studentsProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('حدث خطأ أثناء الاستيراد: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      sessionTimeoutPausedNotifier.value = false;
    }
  }

  Future<void> _importFromExcel() async {
    try {
      sessionTimeoutPausedNotifier.value = true;
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        final platformFile = result.files.single;
        List<int> bytes;
        if (platformFile.bytes != null) {
          bytes = platformFile.bytes!;
        } else if (platformFile.path != null) {
          final file = File(platformFile.path!);
          bytes = await file.readAsBytes();
        } else {
          return;
        }
        final excel = Excel.decodeBytes(bytes);
        if (excel.tables.isEmpty) return;

        Sheet? sheet;
        var best = -1;
        for (final entry in excel.tables.entries) {
          final t = entry.value;
          if (t == null) continue;
          var count = 0;
          for (final row in t.rows) {
            if (row.isEmpty) continue;
            final v = row[0]?.value?.toString().trim() ?? '';
            if (v.isNotEmpty) count++;
          }
          if (count > best) {
            best = count;
            sheet = t;
          }
        }
        if (sheet == null) return;

        final user = ref.read(authStateProvider).value;
        final schoolId = user?.schoolId ?? 'school_1';
        final classes = ref.read(classesProvider).value ?? [];
        final reservedUsernames = <String>{};
        final report = <_ImportRowReport>[];

        var startRow = 1;
        if (sheet.rows.isNotEmpty) {
          final first = sheet.rows.first;
          final firstCell = first.isNotEmpty
              ? first[0]?.value?.toString()
              : null;
          final s = (firstCell ?? '').toString();
          final isHeader =
              s.contains('اسم') || s.toLowerCase().contains('name');
          startRow = isHeader ? 1 : 0;
        }

        final total = sheet.rows
            .skip(startRow)
            .where(
              (r) =>
                  r.isNotEmpty &&
                  ((r[0]?.value?.toString().trim() ?? '').isNotEmpty),
            )
            .length;
        final progress = ValueNotifier<_ImportProgressSnapshot>(
          _ImportProgressSnapshot(total: total),
        );
        if (mounted) _openImportProgressDialog(progress);

        for (var i = startRow; i < sheet.rows.length; i++) {
          final row = sheet.rows[i];
          if (row.isEmpty) continue;

          try {
            // Expected Columns: Name, Username, Class, ParentPhone
            // Adjust indices based on actual Excel structure
            final name = row[0]?.value?.toString() ?? '';

            // Allow reading from different column arrangements based on the file content
            // If the file is structured like the provided image: Name (A), Class (C), ParentPhone (D)
            String username = '';
            String classLabel = '';
            String parentPhone = '';

            if (row.length > 3) {
              // Standard template: Name, Username, Class, Phone
              username = row[1]?.value?.toString() ?? '';
              classLabel = row[2]?.value?.toString() ?? '';
              parentPhone = row[3]?.value?.toString() ?? '';

              // Check if column 2 is actually empty and 3 has phone, adjust
              if (parentPhone.startsWith('05') && classLabel.isEmpty) {
                // might be different format
              }
            } else if (row.length == 3) {
              // Maybe Name, Class, Phone
              classLabel = row[1]?.value?.toString() ?? '';
              parentPhone = row[2]?.value?.toString() ?? '';
            }

            // Let's do a smarter check based on content
            for (int j = 1; j < row.length; j++) {
              final val = row[j]?.value?.toString().trim() ?? '';
              if (val.isEmpty) continue;

              if (val.startsWith('05') ||
                  val.length >= 9 && int.tryParse(val) != null) {
                parentPhone = val;
                if (!parentPhone.startsWith('0') && parentPhone.length == 9) {
                  parentPhone = '0$parentPhone';
                }
              } else if (val.contains('/') ||
                  val.contains('موهوبين') ||
                  val.contains('فصل') ||
                  val.contains('صف')) {
                classLabel = val;
              } else if (username.isEmpty && !val.startsWith('05')) {
                username = val;
              }
            }

            if (name.isEmpty) continue;

            // 1. Find or Create Parent
            final isSchoolMode = user?.schoolId?.isNotEmpty ?? false;
            bool parentExists = false;

            if (parentPhone.isNotEmpty && schoolId.isNotEmpty) {
              final parent = await ref
                  .read(firestoreParentRepositoryProvider)
                  .getParentByPhone(schoolId, parentPhone);
              parentExists = parent != null;
            } else {
              parentExists = true;
            }

            if (!parentExists) {
              // Create Parent
              final newParent = User(
                id: const Uuid().v4(),
                name: 'ولي أمر $name',
                email: EmailGenerator.generateEmail(
                  UserRole.parent,
                  phoneNumber: parentPhone,
                ),
                role: UserRole.parent,
                phoneNumber: parentPhone,
                schoolId: schoolId,
                isPasswordChangeRequired: true,
              );

              if (isSchoolMode) {
                try {
                  await ref
                      .read(firestoreParentRepositoryProvider)
                      .addParent(schoolId, newParent);
                } catch (e) {
                  final msg = e.toString();
                  final isDup =
                      msg.contains('مستخدم بالفعل') ||
                      msg.toLowerCase().contains('already') ||
                      msg.toLowerCase().contains('exists') ||
                      msg.toLowerCase().contains('email');
                  if (!isDup) {
                    debugPrint('Parent create failed: $e');
                  }
                }
              }
            }

            // 2. Create Student
            String? classId;
            if (classLabel.isNotEmpty) {
              for (final c in classes) {
                if (c.preferredLabel == classLabel ||
                    c.name == classLabel ||
                    '${c.gradeLevel}/${c.sectionNumber}' == classLabel ||
                    classLabel.contains(c.preferredLabel) ||
                    c.preferredLabel.contains(classLabel)) {
                  classId = c.id;
                  break;
                }
              }
            }

            final (
              status,
              finalUsername,
              pin,
              createdId,
            ) = await _addStudentWithAutoUsername(
              schoolId: schoolId,
              studentName: name,
              preferredUsername: username,
              parentPhone: parentPhone,
              parentIdentity: '',
              dob: null,
              reservedUsernames: reservedUsernames,
              assignedClassIds: classId != null ? [classId] : const [],
            );

            if (status == _ImportRowStatus.completed &&
                classId != null &&
                createdId != null &&
                schoolId.isNotEmpty) {
              try {
                final firestoreClassRepo = ref.read(
                  firestoreClassRepositoryProvider,
                );
                final c = await firestoreClassRepo.getClassById(
                  schoolId,
                  classId,
                );
                if (c != null) {
                  final newIds = List<String>.from(c.studentIds);
                  if (!newIds.contains(createdId)) {
                    newIds.add(createdId);
                    final updatedClass = Classroom(
                      id: c.id,
                      name: c.name,
                      nameCode: c.nameCode,
                      displayName: c.displayName,
                      gradeLevel: c.gradeLevel,
                      studentIds: newIds,
                      secondaryProgramType: c.secondaryProgramType,
                      secondaryTrack: c.secondaryTrack,
                      secondaryPhase: c.secondaryPhase,
                      sectionNumber: c.sectionNumber,
                    );
                    await firestoreClassRepo.updateClass(
                      schoolId,
                      updatedClass,
                    );
                  }
                }
              } catch (_) {}
            }

            report.add(
              _ImportRowReport(
                name: name,
                classLabel: classLabel.isEmpty ? null : classLabel,
                username: finalUsername.isEmpty ? null : finalUsername,
                pin: pin,
                status: status,
              ),
            );

            final snap = progress.value;
            progress.value = snap.copyWith(
              processed: snap.processed + 1,
              completed:
                  snap.completed +
                  (status == _ImportRowStatus.completed ? 1 : 0),
              duplicate:
                  snap.duplicate +
                  (status == _ImportRowStatus.duplicate ? 1 : 0),
              failed: snap.failed + (status == _ImportRowStatus.failed ? 1 : 0),
            );
          } catch (e) {
            final snap = progress.value;
            progress.value = snap.copyWith(
              processed: snap.processed + 1,
              failed: snap.failed + 1,
            );
            report.add(
              _ImportRowReport(
                name:
                    (row.isNotEmpty ? (row[0]?.value?.toString() ?? '') : '')
                        .trim()
                        .isEmpty
                    ? '—'
                    : (row[0]?.value?.toString() ?? '').trim(),
                classLabel: null,
                username: null,
                pin: null,
                status: _ImportRowStatus.failed,
              ),
            );
            debugPrint('Import row failed: $e');
            continue;
          }
        }

        if (mounted) {
          final csv = _buildStudentCredentialsCsv(report);
          final rowCount = csv.trim().split('\n').length - 1;
          await _persistStudentCredentialsExport(
            schoolId: schoolId,
            csv: csv,
            rowCount: rowCount,
          );
          Navigator.of(context, rootNavigator: true).pop();
          await _showImportReportDialog(report);
          ref.invalidate(studentsProvider);
        }
      }
    } catch (e) {
      if (mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {}
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الاستيراد: $e')));
      }
    } finally {
      sessionTimeoutPausedNotifier.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final classesAsync = ref.watch(classesProvider);
    final user = ref.watch(authStateProvider).value;
    final isTeacher = user?.role == UserRole.teacher;

    final canAccess = _canAccessStudentsSection(user);

    if (!canAccess) {
      return Scaffold(
        appBar: AppBar(title: const Text('الطلاب')),
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Text(
              'عذراً، لا تملك صلاحية الوصول إلى قسم الطلاب.\nيرجى التواصل مع مدير المدرسة إذا كنت ترى أن هذا خطأ.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.sp, color: Colors.grey.shade800),
            ),
          ),
        ),
      );
    }

    return SmartSectionScaffold(
      title: 'الطلاب',
      icon: Icons.people_alt,
      themeColor: Colors.blue.shade700,
      initialRecommendation:
          'توصي الوزارة بمتابعة حضور الطلاب يومياً وتفعيل برامج تعزيز السلوك الإيجابي.',
      actions: [
        if (!isTeacher)
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _showImportOptions,
            tooltip: 'خيارات الاستيراد',
          ),
        if (!isTeacher)
          PopupMenuButton<String>(
            tooltip: 'قائمة الخيارات',
            onSelected: (v) async {
              final userNow = ref.read(authStateProvider).value;
              final schoolId = (userNow?.schoolId ?? '').trim();
              if (schoolId.isEmpty) return;

              if (v == 'cred_history') {
                await _showStudentExportHistoryDialog(schoolId);
                return;
              }
              if (v == 'cred_copy' || v == 'cred_excel') {
                final csv = await _fetchLatestStudentCredentialsCsv(schoolId);
                if (csv == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('لا توجد دفعة محفوظة للتصدير'),
                    ),
                  );
                  return;
                }
                if (v == 'cred_copy') {
                  await Clipboard.setData(ClipboardData(text: csv));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم نسخ بيانات الدخول')),
                  );
                  return;
                }
                final date = DateTime.now().toIso8601String().split('T').first;
                final fileName = 'بيانات_دخول_الطلاب_$date.xlsx';
                if (kIsWeb) {
                  _downloadStudentCredentialsXlsxWebFromCsv(
                    csv: csv,
                    fileName: fileName,
                  );
                } else {
                  final bytes = _buildStudentCredentialsXlsxBytesFromCsv(csv);
                  if (bytes == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('لا توجد بيانات للتصدير')),
                    );
                    return;
                  }
                  final xFile = XFile.fromData(
                    bytes,
                    name: fileName,
                    mimeType:
                        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                  );
                  await SharePlus.instance.share(
                    ShareParams(files: [xFile], text: 'بيانات دخول الطلاب'),
                  );
                }
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم تصدير بيانات الدخول')),
                );
                return;
              }

              if (v == 'delete_all') {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف جميع الطلاب'),
                    content: const Text(
                      'سيتم حذف جميع الطلاب من النظام وتفريغ الفصول. هل أنت متأكد؟',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'حذف',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  final repo = ref.read(studentRepositoryProvider);
                  final count = await repo.deleteAllStudents(schoolId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('تم حذف $count طالباً وتفريغ الفصول'),
                      ),
                    );
                    ref.invalidate(studentsProvider);
                    ref.invalidate(classesProvider);
                  }
                }
                return;
              }

              if (v == 'delete_class') {
                if (_selectedClassId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('اختر فصلاً أولاً من قائمة التصفية'),
                    ),
                  );
                  return;
                }
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('حذف طلاب الفصل المحدد'),
                    content: const Text(
                      'سيتم حذف جميع طلاب الفصل المحدد فقط. هل أنت متأكد؟',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: const Text(
                          'حذف',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  final repo = ref.read(studentRepositoryProvider);
                  final count = await repo.deleteStudentsByClass(
                    schoolId,
                    _selectedClassId!,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('تم حذف $count طالباً من الفصل')),
                    );
                    ref.invalidate(studentsProvider);
                    ref.invalidate(classesProvider);
                  }
                }
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                enabled: false,
                child: ListTile(title: Text('بيانات الدخول (طلاب)')),
              ),
              const PopupMenuItem(
                value: 'cred_copy',
                child: ListTile(
                  leading: Icon(Icons.copy),
                  title: Text('نسخ آخر دفعة محفوظة'),
                ),
              ),
              const PopupMenuItem(
                value: 'cred_excel',
                child: ListTile(
                  leading: Icon(Icons.download),
                  title: Text('تصدير Excel (آخر دفعة)'),
                ),
              ),
              const PopupMenuItem(
                value: 'cred_history',
                child: ListTile(
                  leading: Icon(Icons.history),
                  title: Text('سجل الدفعات'),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                enabled: false,
                child: ListTile(title: Text('إدارة الطلاب')),
              ),
              const PopupMenuItem(
                value: 'delete_all',
                child: ListTile(
                  leading: Icon(Icons.delete_forever, color: Colors.red),
                  title: Text('حذف جميع الطلاب'),
                ),
              ),
              PopupMenuItem(
                value: 'delete_class',
                enabled: _selectedClassId != null,
                child: const ListTile(
                  leading: Icon(Icons.delete_sweep, color: Colors.red),
                  title: Text('حذف طلاب الفصل المحدد'),
                ),
              ),
            ],
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث عن طالب (بالاسم أو اسم المستخدم)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            child: classesAsync.when(
              data: (classes) {
                final filteredClasses = () {
                  if (isTeacher && user != null) {
                    final teacherClassIds = user.assignedClassIds ?? [];
                    return classes
                        .where((c) => teacherClassIds.contains(c.id))
                        .toList();
                  }
                  return classes;
                }();

                return DropdownButtonFormField<String?>(
                  value: _selectedClassId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'تصفية حسب الفصل',
                    prefixIcon: Icon(Icons.class_),
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('الكل'),
                    ),
                    ...filteredClasses.map(
                      (c) => DropdownMenuItem<String?>(
                        value: c.id,
                        child: Text(c.preferredLabel),
                      ),
                    ),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _selectedClassId = val;
                    });
                  },
                );
              },
              loading: () => const SizedBox.shrink(),
              error: (e, _) => const SizedBox.shrink(),
            ),
          ),
          Expanded(
            child: studentsAsync.when(
              data: (students) {
                final classes = classesAsync.value ?? const <Classroom>[];
                var displayStudents = students;
                final classById = <String, Classroom>{
                  for (final c in classes) c.id: c,
                };

                if (isTeacher && user != null) {
                  final teacherClassIds = user.assignedClassIds ?? [];
                  final allowedStudentIds = <String>{};
                  for (final cid in teacherClassIds) {
                    final c = classById[cid];
                    if (c == null) continue;
                    allowedStudentIds.addAll(c.studentIds);
                  }
                  displayStudents = displayStudents
                      .where((s) => allowedStudentIds.contains(s.id))
                      .toList();
                }

                if (_selectedClassId != null) {
                  final selected = classById[_selectedClassId!];
                  if (selected != null) {
                    final ids = selected.studentIds.toSet();
                    displayStudents = displayStudents.where((s) {
                      final inClass = ids.contains(s.id);
                      final assigned = s.assignedClassIds ?? [];
                      return inClass || assigned.contains(_selectedClassId);
                    }).toList();
                  } else {
                    displayStudents = displayStudents.where((s) {
                      final ids = s.assignedClassIds ?? [];
                      return ids.contains(_selectedClassId);
                    }).toList();
                  }
                }

                final filteredStudents = displayStudents.where((s) {
                  if (_searchQuery.isEmpty) return true;
                  return s.name.contains(_searchQuery) ||
                      (s.identityNumber?.contains(_searchQuery) ?? false);
                }).toList();

                if (filteredStudents.isEmpty) {
                  return const Center(child: Text('لا يوجد طلاب'));
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: filteredStudents.length,
                  itemBuilder: (context, index) {
                    final student = filteredStudents[index];
                    return _StudentListItem(
                      index: index,
                      student: student,
                      canEdit: !isTeacher,
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) {
                final msg = e.toString();
                final isPerm =
                    msg.contains('permission-denied') ||
                    msg.contains('Missing or insufficient permissions');
                return Center(
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'خطأ: $msg',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.red, fontSize: 13.sp),
                        ),
                        if (isPerm) ...[
                          SizedBox(height: 12.h),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                final callable = FirebaseFunctions.instance
                                    .httpsCallable('repairCurrentUserLink');
                                await callable.call({});
                                ref.invalidate(authStateProvider);
                                ref.invalidate(studentsProvider);
                                ref.invalidate(classesProvider);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'تم إصلاح الربط، جارٍ إعادة التحميل...',
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              } catch (_) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('تعذر إصلاح الربط تلقائياً'),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.build),
                            label: const Text('إصلاح الصلاحيات'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo.shade700,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: !isTeacher
          ? FloatingActionButton.extended(
              onPressed: () => showDialog(
                context: context,
                builder: (context) => const _AddStudentDialog(),
              ),
              icon: const Icon(Icons.add),
              label: const Text('إضافة طالب'),
              backgroundColor: Colors.blue.shade700,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

class _AddStudentDialog extends ConsumerStatefulWidget {
  const _AddStudentDialog();

  @override
  ConsumerState<_AddStudentDialog> createState() => _AddStudentDialogState();
}

class _AddStudentDialogState extends ConsumerState<_AddStudentDialog> {
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _nationalIdController = TextEditingController();
  final _parentIdController = TextEditingController();
  final _parentPhoneController = TextEditingController();
  String? _selectedClassId;

  @override
  void initState() {
    super.initState();
    // Auto-generate Student ID
    _idController.text = EmailGenerator.generateEmail(
      UserRole.student,
    ).split('@').first.substring(2); // Remove 'st' prefix
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('إضافة طالب جديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الطالب'),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'المعرّف النظامي (اسم المستخدم للدخول)',
                helperText: 'التنسيق: ST000000 (حرفين ثم 6 أرقام)',
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _nationalIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'رقم الهوية/الإقامة (اختياري - داخلي)',
                helperText: 'بيان داخلي مشفر، لا يستخدم للدخول',
              ),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _parentIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'سجل ولي الأمر'),
            ),
            SizedBox(height: 8.h),
            TextField(
              controller: _parentPhoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'جوال ولي الأمر (لتحقق OTP)',
              ),
            ),
            SizedBox(height: 16.h),
            ref
                .watch(classesProvider)
                .when(
                  data: (classes) => DropdownButtonFormField<String>(
                    value: _selectedClassId,
                    decoration: const InputDecoration(
                      labelText: 'اختر الفصل',
                      border: OutlineInputBorder(),
                    ),
                    items: classes.map((c) {
                      return DropdownMenuItem(
                        value: c.id,
                        child: Text(c.preferredLabel),
                      );
                    }).toList(),
                    onChanged: (val) {
                      setState(() {
                        _selectedClassId = val;
                      });
                    },
                  ),
                  loading: () => const CircularProgressIndicator(),
                  error: (e, _) => Text('خطأ: $e'),
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
              final identityRaw = _idController.text.trim();
              final nationalIdRaw = _nationalIdController.text.trim();
              final parentIdentityRaw = _parentIdController.text.trim();

              if (_nameController.text.isNotEmpty && identityRaw.isNotEmpty) {
                // Remove strict 10-digit validation for students as we now use usernames
                if (identityRaw.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اسم المستخدم يجب أن يكون 3 أحرف على الأقل',
                      ),
                    ),
                  );
                  return;
                }

                final identity = identityRaw.toUpperCase();

                if (!RegExp(r'^[A-Z]{2}[0-9]{6}$').hasMatch(identity)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اسم المستخدم يجب أن يكون حرفين ثم 6 أرقام مثل ST000000',
                      ),
                    ),
                  );
                  return;
                }

                // Ensure username contains only valid characters (letters, numbers, underscores, hyphens)
                if (!RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(identityRaw)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'اسم المستخدم يجب أن يحتوي فقط على أحرف وأرقام و _ -',
                      ),
                    ),
                  );
                  return;
                }
                final user = ref.read(authStateProvider).value;
                if (user == null || user.schoolId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('خطأ: لا يوجد مدرسة محددة')),
                  );
                  return;
                }

                final parentPhone = _parentPhoneController.text.trim();
                final parentIdentity = parentIdentityRaw;

                if (parentPhone.isNotEmpty || parentIdentity.isNotEmpty) {
                  if (parentIdentity.isNotEmpty &&
                      !TextUtils.isValidIdentityNumber(parentIdentity)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('سجل ولي الأمر يجب أن يكون 10 أرقام'),
                      ),
                    );
                    return;
                  }
                  final parentRepo = ref.read(
                    firestoreParentRepositoryProvider,
                  );

                  final pUsername = parentIdentity.isNotEmpty
                      ? parentIdentity
                      : parentPhone;
                  final pEmail = 'p$pUsername@getmanar.com';
                  final newParent = User(
                    id: const Uuid().v4(),
                    name: 'ولي أمر ${_nameController.text}',
                    email: pEmail,
                    role: UserRole.parent,
                    phoneNumber: parentPhone,
                    identityNumber: parentIdentity,
                    schoolId: user.schoolId,
                    isPasswordChangeRequired: true,
                  );
                  try {
                    await parentRepo.addParent(user.schoolId!, newParent);
                  } catch (e) {
                    final msg = e.toString().toLowerCase();
                    final already =
                        msg.contains('already') ||
                        msg.contains('exists') ||
                        msg.contains('موجود');
                    if (!already) rethrow;
                  }
                }

                final newStudent = User(
                  id: const Uuid().v4(),
                  name: _nameController.text.trim(),
                  email: EmailGenerator.generateEmail(
                    UserRole.student,
                    identityNumber: identity,
                  ),
                  role: UserRole.student,
                  identityNumber: identity,
                  nationalId: nationalIdRaw,
                  phoneNumber: parentPhone,
                  schoolId: user.schoolId,
                  assignedClassIds: _selectedClassId != null
                      ? [_selectedClassId!]
                      : [],
                );

                final randomPassword = TextUtils.generateRandomDigits(6);

                await ref
                    .read(studentRepositoryProvider)
                    .addStudent(user.schoolId!, newStudent, randomPassword);

                // 3. Register Global Entry Code via Cloud Function
                // Wrap in try-catch to prevent blocking UI success if this non-critical step fails
                try {
                  final functions = FirebaseFunctions.instance;
                  final callable = functions.httpsCallable('manageUserCode');
                  await callable.call({
                    'action': 'create',
                    'code': identity,
                    'email': newStudent.email,
                    'schoolId': user.schoolId,
                    'role': 'student',
                    'name': newStudent.name,
                  });
                } catch (codeError) {
                  debugPrint('Warning: Failed to create user code: $codeError');
                  // Continue flow, this is secondary
                }

                if (context.mounted) {
                  ref.invalidate(studentsProvider);
                  Navigator.pop(context); // Close Add Dialog

                  // Show Success Dialog with Password
                  await showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (context) => AlertDialog(
                      title: const Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green),
                          SizedBox(width: 8),
                          Text('تمت إضافة الطالب'),
                        ],
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('اسم المستخدم: $identity'),
                          const SizedBox(height: 8),
                          Text(
                            'كلمة المرور: $randomPassword',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'يرجى تزويد الطالب ببيانات الدخول.',
                            style: TextStyle(color: Colors.grey),
                          ),
                          if (parentPhone.isNotEmpty) ...[
                            const Divider(),
                            Text(
                              'تم ربط ولي الأمر (جوال: $parentPhone)',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                      actions: [
                        ElevatedButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('موافق'),
                        ),
                      ],
                    ),
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يرجى إدخال الاسم واسم المستخدم'),
                  ),
                );
              }
            } catch (e) {
              if (context.mounted) {
                String errorMessage = 'حدث خطأ غير متوقع';

                if (e.toString().contains('firebase_functions/internal')) {
                  errorMessage =
                      'خطأ داخلي في الخادم. يرجى التحقق من صحة رقم الهوية (يجب أن يكون 10 أرقام إذا تم إدخاله) أو المحاولة لاحقاً.';
                } else if (e.toString().contains('already-exists')) {
                  errorMessage = 'هذا المستخدم موجود بالفعل';
                } else {
                  errorMessage = e.toString();
                }

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(errorMessage),
                    backgroundColor: Colors.red,
                    duration: const Duration(seconds: 5),
                    action: SnackBarAction(
                      label: 'تفاصيل',
                      textColor: Colors.white,
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('تفاصيل الخطأ'),
                            content: SingleChildScrollView(
                              child: Text(e.toString()),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('حسناً'),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                );
              }
            }
          },
          child: const Text('إضافة'),
        ),
      ],
    );
  }
}

class _StudentListItem extends ConsumerWidget {
  final int index;
  final User student;
  final bool canEdit;

  const _StudentListItem({
    required this.index,
    required this.student,
    this.canEdit = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(authStateProvider);
    final currentUser = userAsync.value;

    // Check if user is allowed to see health status colors
    bool canSeeHealthStatus = false;
    if (currentUser != null) {
      canSeeHealthStatus = [
        UserRole.teacher,
        UserRole.admin,
        UserRole.deputy,
        UserRole.counselor,
        UserRole.administrative,
      ].contains(currentUser.role);
    }

    Color nameColor = Colors.black;
    if (canSeeHealthStatus && student.healthStatus != null) {
      if (student.healthStatus == 'care') {
        nameColor = Colors.amber.shade900;
      } else if (student.healthStatus == 'bathroom') {
        nameColor = Colors.red;
      }
    }

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Colors.black26),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: Text(
            '${index + 1}',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(
          student.name,
          style: TextStyle(
            color: nameColor,
            fontWeight: nameColor != Colors.black
                ? FontWeight.bold
                : FontWeight.normal,
          ),
        ),
        subtitle: Text('اسم المستخدم: ${student.identityNumber ?? '-'}'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.qr_code, color: Colors.teal),
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    content: SizedBox(
                      width: 200.w,
                      height: 200.w,
                      child: Center(
                        child: QrImageView(
                          data: student.identityNumber ?? '',
                          version: QrVersions.auto,
                          size: 200.0,
                        ),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إغلاق'),
                      ),
                    ],
                  ),
                );
              },
            ),
            if (canEdit) ...[
              IconButton(
                icon: const Icon(Icons.swap_horiz, color: Colors.deepPurple),
                onPressed: () => _showAssignClassDialog(context, ref),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.indigo),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => EditStudentDialog(student: student),
                  );
                },
              ),
            ],
          ],
        ),
        onTap: () {
          context.push('/student-behavior-profile', extra: student);
        },
        onLongPress: canEdit ? () => _showStudentActions(context, ref) : null,
      ),
    );
  }

  Future<void> _showStudentActions(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('حذف الطالب'),
                onTap: () => Navigator.pop(context, 'delete'),
              ),
              ListTile(
                leading: const Icon(Icons.close),
                title: const Text('إلغاء'),
                onTap: () => Navigator.pop(context, 'cancel'),
              ),
            ],
          ),
        );
      },
    );

    if (chosen != 'delete') return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف الطالب: ${student.name} ؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final currentUser = ref.read(authStateProvider).value;
    final schoolId = (currentUser?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    try {
      await ref
          .read(studentRepositoryProvider)
          .deleteStudent(schoolId, student.id);
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الطالب')));
        ref.invalidate(studentsProvider);
        ref.invalidate(classesProvider);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل حذف الطالب: $e')));
      }
    }
  }

  Future<void> _showAssignClassDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final classesAsync = ref.read(classesProvider);
    final classes = classesAsync.value ?? [];

    if (classes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد فصول متاحة حالياً')),
      );
      return;
    }

    final Classroom? selectedClass = await showDialog<Classroom>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text('إسناد الطالب لفصل'),
          children: classes
              .map(
                (c) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, c),
                  child: Text('${c.name} (الصف ${c.gradeLevel})'),
                ),
              )
              .toList(),
        );
      },
    );

    if (selectedClass == null) return;

    await _assignStudentToClass(context, ref, selectedClass);
  }

  Future<void> _assignStudentToClass(
    BuildContext context,
    WidgetRef ref,
    Classroom targetClass,
  ) async {
    final currentUser = ref.read(authStateProvider).value;
    if (currentUser == null || currentUser.schoolId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تحديد المدرسة الحالية')),
      );
      return;
    }

    final schoolId = currentUser.schoolId!;
    final studentRepo = ref.read(studentRepositoryProvider);

    final currentClassIds = student.assignedClassIds ?? [];
    final currentClassId = currentClassIds.isNotEmpty
        ? currentClassIds.first
        : null;

    final isSchoolMode = schoolId.isNotEmpty;
    final firestoreClassRepo = ref.read(firestoreClassRepositoryProvider);
    final mockClassRepo = ref.read(mockClassRepositoryProvider);

    String? currentClassName;
    if (currentClassId != null && currentClassId.isNotEmpty) {
      try {
        if (isSchoolMode) {
          final existing = await firestoreClassRepo.getClassById(
            schoolId,
            currentClassId,
          );
          currentClassName = existing?.preferredLabel;
        } else {
          final all = await mockClassRepo.getClasses();
          final existing = all.firstWhere(
            (c) => c.id == currentClassId,
            orElse: () => all.first,
          );
          if (existing.id == currentClassId) {
            currentClassName = existing.preferredLabel;
          }
        }
      } catch (_) {}
    }

    if (currentClassId != null &&
        currentClassId.isNotEmpty &&
        currentClassId != targetClass.id) {
      final shouldMove =
          await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('نقل الطالب بين الفصول'),
              content: Text(
                currentClassName != null
                    ? 'الطالب موجود حالياً في الفصل $currentClassName. هل تريد نقله إلى الفصل ${targetClass.preferredLabel}؟'
                    : 'الطالب موجود حالياً في فصل آخر. هل تريد نقله إلى الفصل ${targetClass.preferredLabel}؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('نقل'),
                ),
              ],
            ),
          ) ??
          false;

      if (!shouldMove) return;
    }

    if (currentClassId == targetClass.id) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الطالب مسند بالفعل إلى هذا الفصل')),
      );
      return;
    }

    try {
      final updatedStudent = student.copyWith(
        assignedClassIds: [targetClass.id],
      );

      await studentRepo.updateStudent(schoolId, updatedStudent);

      if (isSchoolMode) {
        final existingTarget =
            await firestoreClassRepo.getClassById(schoolId, targetClass.id) ??
            targetClass;
        final newStudentIds = List<String>.from(existingTarget.studentIds);
        if (!newStudentIds.contains(student.id)) {
          newStudentIds.add(student.id);
        }

        final updatedTarget = Classroom(
          id: existingTarget.id,
          name: existingTarget.name,
          nameCode: existingTarget.nameCode,
          displayName: existingTarget.displayName,
          gradeLevel: existingTarget.gradeLevel,
          studentIds: newStudentIds,
          secondaryProgramType: existingTarget.secondaryProgramType,
          secondaryTrack: existingTarget.secondaryTrack,
          secondaryPhase: existingTarget.secondaryPhase,
          sectionNumber: existingTarget.sectionNumber,
        );
        await firestoreClassRepo.updateClass(schoolId, updatedTarget);

        if (currentClassId != null &&
            currentClassId.isNotEmpty &&
            currentClassId != targetClass.id) {
          final oldClass = await firestoreClassRepo.getClassById(
            schoolId,
            currentClassId,
          );
          if (oldClass != null) {
            final cleanedIds = oldClass.studentIds
                .where((id) => id != student.id)
                .toList();
            final updatedOld = Classroom(
              id: oldClass.id,
              name: oldClass.name,
              nameCode: oldClass.nameCode,
              displayName: oldClass.displayName,
              gradeLevel: oldClass.gradeLevel,
              studentIds: cleanedIds,
              secondaryProgramType: oldClass.secondaryProgramType,
              secondaryTrack: oldClass.secondaryTrack,
              secondaryPhase: oldClass.secondaryPhase,
              sectionNumber: oldClass.sectionNumber,
            );
            await firestoreClassRepo.updateClass(schoolId, updatedOld);
          }
        }
      } else {
        final allClasses = await mockClassRepo.getClasses();
        final target = allClasses.firstWhere((c) => c.id == targetClass.id);
        final newStudentIds = List<String>.from(target.studentIds);
        if (!newStudentIds.contains(student.id)) {
          newStudentIds.add(student.id);
        }
        await mockClassRepo.updateClass(
          Classroom(
            id: target.id,
            name: target.name,
            nameCode: target.nameCode,
            displayName: target.displayName,
            gradeLevel: target.gradeLevel,
            studentIds: newStudentIds,
            secondaryProgramType: target.secondaryProgramType,
            secondaryTrack: target.secondaryTrack,
            secondaryPhase: target.secondaryPhase,
            sectionNumber: target.sectionNumber,
          ),
        );

        if (currentClassId != null &&
            currentClassId.isNotEmpty &&
            currentClassId != targetClass.id) {
          try {
            final old = allClasses.firstWhere((c) => c.id == currentClassId);
            final cleanedIds = old.studentIds
                .where((id) => id != student.id)
                .toList();
            await mockClassRepo.updateClass(
              Classroom(
                id: old.id,
                name: old.name,
                nameCode: old.nameCode,
                displayName: old.displayName,
                gradeLevel: old.gradeLevel,
                studentIds: cleanedIds,
                secondaryProgramType: old.secondaryProgramType,
                secondaryTrack: old.secondaryTrack,
                secondaryPhase: old.secondaryPhase,
                sectionNumber: old.sectionNumber,
              ),
            );
          } catch (_) {}
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث فصل الطالب بنجاح')),
      );

      ref.invalidate(studentsProvider);
      ref.invalidate(classesProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء تحديث الفصل: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}

class EditStudentDialog extends ConsumerStatefulWidget {
  final User student;

  const EditStudentDialog({super.key, required this.student});

  @override
  ConsumerState<EditStudentDialog> createState() => _EditStudentDialogState();
}

class _EditStudentDialogState extends ConsumerState<EditStudentDialog> {
  late TextEditingController _nameController;
  late TextEditingController _idController;
  late TextEditingController _phoneController;
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.student.name);
    _idController = TextEditingController(text: widget.student.identityNumber);
    _phoneController = TextEditingController(text: widget.student.phoneNumber);
    _selectedDate = widget.student.dateOfBirth;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _idController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('تعديل بيانات الطالب'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'اسم الطالب'),
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _idController,
              decoration: const InputDecoration(labelText: 'اسم المستخدم'),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 12.h),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'رقم الجوال'),
              keyboardType: TextInputType.phone,
            ),
            SizedBox(height: 12.h),
            ListTile(
              title: Text(
                _selectedDate == null
                    ? 'تاريخ الميلاد'
                    : '${_selectedDate!.year}-${_selectedDate!.month}-${_selectedDate!.day}',
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: _pickDate,
              contentPadding: EdgeInsets.zero,
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
          onPressed: () {
            final user = ref.read(authStateProvider).value;
            if (user == null || user.schoolId == null) return;

            final updatedStudent = widget.student.copyWith(
              name: _nameController.text,
              identityNumber: _idController.text,
              phoneNumber: _phoneController.text,
              dateOfBirth: _selectedDate,
            );

            // Use Repository
            ref
                .read(studentRepositoryProvider)
                .updateStudent(user.schoolId!, updatedStudent);
            Navigator.pop(context);
          },
          child: const Text('حفظ'),
        ),
      ],
    );
  }
}

enum _ImportRowStatus { completed, duplicate, failed }

extension _ImportRowStatusLabel on _ImportRowStatus {
  String get label {
    return switch (this) {
      _ImportRowStatus.completed => 'تم',
      _ImportRowStatus.duplicate => 'مكرر',
      _ImportRowStatus.failed => 'فشل',
    };
  }
}

class _ImportRowReport {
  final String name;
  final String? classLabel;
  final String? username;
  final String? pin;
  final _ImportRowStatus status;

  const _ImportRowReport({
    required this.name,
    required this.classLabel,
    required this.username,
    required this.pin,
    required this.status,
  });
}

class _ImportProgressSnapshot {
  final int total;
  final int processed;
  final int completed;
  final int duplicate;
  final int failed;

  const _ImportProgressSnapshot({
    required this.total,
    this.processed = 0,
    this.completed = 0,
    this.duplicate = 0,
    this.failed = 0,
  });

  _ImportProgressSnapshot copyWith({
    int? total,
    int? processed,
    int? completed,
    int? duplicate,
    int? failed,
  }) {
    return _ImportProgressSnapshot(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      completed: completed ?? this.completed,
      duplicate: duplicate ?? this.duplicate,
      failed: failed ?? this.failed,
    );
  }
}

class _CredentialExportItem {
  final String id;
  final int createdAtMs;
  final int rowCount;
  final String csv;

  const _CredentialExportItem({
    required this.id,
    required this.createdAtMs,
    required this.rowCount,
    required this.csv,
  });
}
