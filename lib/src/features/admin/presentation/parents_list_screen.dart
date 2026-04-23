import 'package:flutter/material.dart';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:excel/excel.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/firestore_parent_repository.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import 'package:flutter/services.dart';

final parentsProvider = StreamProvider<List<User>>((ref) {
  final userAsync = ref.watch(authStateProvider);

  return userAsync.when(
    data: (user) {
      if (user == null || user.schoolId == null) return Stream.value([]);
      final repo = ref.watch(firestoreParentRepositoryProvider);
      return repo.watchParents(user.schoolId!);
    },
    loading: () => Stream.value([]),
    error: (e, st) => Stream.value([]),
  );
});

class ParentsListScreen extends ConsumerStatefulWidget {
  const ParentsListScreen({super.key});

  @override
  ConsumerState<ParentsListScreen> createState() => _ParentsListScreenState();
}

class _ParentsListScreenState extends ConsumerState<ParentsListScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;
  String _searchQuery = '';

  String _escapeCsv(String s) {
    final v = s.replaceAll('"', '""');
    if (v.contains(',') || v.contains('"') || v.contains('\n')) {
      return '"$v"';
    }
    return v;
  }

  String _buildParentsCredentialsCsv(List<User> parents) {
    final buf = StringBuffer();
    buf.writeln('name,phone,email,default_password');
    for (final p in parents) {
      buf.writeln(
        [
          _escapeCsv(p.name),
          _escapeCsv(p.phoneNumber ?? ''),
          _escapeCsv(p.email),
          '123456',
        ].join(','),
      );
    }
    return buf.toString();
  }

  Uint8List? _buildParentsCredentialsXlsxBytes(List<User> parents) {
    if (parents.isEmpty) return null;
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
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 10);

    final centeredStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = ['اسم ولي الأمر', 'الجوال', 'البريد', 'كلمة المرور'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = centeredStyle;
    }

    var rowIndex = 1;
    for (final p in parents) {
      final c0 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      c0.value = TextCellValue(p.name);
      c0.cellStyle = centeredStyle;

      final c1 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      c1.value = TextCellValue(p.phoneNumber ?? '');
      c1.cellStyle = centeredStyle;

      final c2 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
      );
      c2.value = TextCellValue(p.email);
      c2.cellStyle = centeredStyle;

      final c3 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
      );
      c3.value = TextCellValue('123456');
      c3.cellStyle = centeredStyle;

      rowIndex++;
    }

    final bytes = excel.save();
    if (bytes == null) return null;
    return Uint8List.fromList(bytes);
  }

  void _downloadParentsCredentialsXlsxWeb({
    required List<User> parents,
    required String fileName,
  }) {
    if (parents.isEmpty) return;
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
    sheet.setColumnWidth(1, 18);
    sheet.setColumnWidth(2, 30);
    sheet.setColumnWidth(3, 10);

    final centeredStyle = CellStyle(
      fontSize: 11,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    final headers = ['اسم ولي الأمر', 'الجوال', 'البريد', 'كلمة المرور'];
    for (var i = 0; i < headers.length; i++) {
      final cell = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
      );
      cell.value = TextCellValue(headers[i]);
      cell.cellStyle = centeredStyle;
    }

    var rowIndex = 1;
    for (final p in parents) {
      final c0 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex),
      );
      c0.value = TextCellValue(p.name);
      c0.cellStyle = centeredStyle;

      final c1 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex),
      );
      c1.value = TextCellValue(p.phoneNumber ?? '');
      c1.cellStyle = centeredStyle;

      final c2 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 2, rowIndex: rowIndex),
      );
      c2.value = TextCellValue(p.email);
      c2.cellStyle = centeredStyle;

      final c3 = sheet.cell(
        CellIndex.indexByColumnRow(columnIndex: 3, rowIndex: rowIndex),
      );
      c3.value = TextCellValue('123456');
      c3.cellStyle = centeredStyle;

      rowIndex++;
    }

    excel.save(fileName: fileName);
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: Text('حذف ${_selectedIds.length} من أولياء الأمور؟'),
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

    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    try {
      final repo = ref.read(firestoreParentRepositoryProvider);
      final count = await repo.deleteParents(schoolId, _selectedIds.toList());
      ref.invalidate(parentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف $count من أولياء الأمور')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    }
  }

  Future<void> _deleteAllParents() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جميع أولياء الأمور'),
        content: const Text(
          'سيتم حذف جميع أولياء الأمور من النظام. هل أنت متأكد؟',
        ),
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

    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (schoolId.isEmpty) return;

    try {
      final repo = ref.read(firestoreParentRepositoryProvider);
      final count = await repo.deleteAllParents(schoolId);
      ref.invalidate(parentsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم حذف $count من أولياء الأمور')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('فشل الحذف: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final parentsAsync = ref.watch(parentsProvider);

    return SmartSectionScaffold(
      title: _isSelectionMode ? '${_selectedIds.length} محدد' : 'أولياء الأمور',
      icon: Icons.family_restroom,
      themeColor: Colors.brown,
      initialRecommendation:
          'توصي الوزارة بتفعيل الشراكة المجتمعية والتواصل المستمر مع أولياء الأمور.',
      actions: [
        if (_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          ),
        PopupMenuButton<String>(
          tooltip: 'قائمة الخيارات',
          onSelected: (v) async {
            if (v == 'select') {
              setState(() {
                _isSelectionMode = true;
                _selectedIds.clear();
              });
              return;
            }
            if (v == 'cancel_select') {
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
              return;
            }
            if (v == 'delete_all') {
              await _deleteAllParents();
              return;
            }

            if (v == 'export_copy' || v == 'export_excel') {
              final parents = (ref.read(parentsProvider).value ?? []).toList();
              if (parents.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('لا يوجد أولياء أمور للتصدير')),
                );
                return;
              }
              final csv = _buildParentsCredentialsCsv(parents);
              if (v == 'export_copy') {
                await Clipboard.setData(ClipboardData(text: csv));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم نسخ بيانات أولياء الأمور')),
                );
                return;
              }
              final date = DateTime.now().toIso8601String().split('T').first;
              final fileName = 'بيانات_دخول_اولياء_الامور_$date.xlsx';
              if (kIsWeb) {
                _downloadParentsCredentialsXlsxWeb(
                  parents: parents,
                  fileName: fileName,
                );
              } else {
                final bytes = _buildParentsCredentialsXlsxBytes(parents);
                if (bytes == null) return;
                final xFile = XFile.fromData(
                  bytes,
                  name: fileName,
                  mimeType:
                      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
                );
                await SharePlus.instance.share(
                  ShareParams(
                    files: [xFile],
                    text: 'بيانات دخول أولياء الأمور',
                  ),
                );
              }
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('تم تنزيل ملف بيانات أولياء الأمور'),
                ),
              );
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              enabled: false,
              child: ListTile(title: Text('بيانات الدخول (أولياء الأمور)')),
            ),
            const PopupMenuItem(
              value: 'export_copy',
              child: ListTile(
                leading: Icon(Icons.copy),
                title: Text('نسخ بيانات الدخول'),
              ),
            ),
            const PopupMenuItem(
              value: 'export_excel',
              child: ListTile(
                leading: Icon(Icons.download),
                title: Text('تصدير Excel'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              enabled: false,
              child: ListTile(title: Text('إدارة أولياء الأمور')),
            ),
            if (_isSelectionMode)
              const PopupMenuItem(
                value: 'cancel_select',
                child: ListTile(
                  leading: Icon(Icons.close),
                  title: Text('إلغاء التحديد'),
                ),
              ),
            if (!_isSelectionMode)
              const PopupMenuItem(
                value: 'select',
                child: ListTile(
                  leading: Icon(Icons.check_box),
                  title: Text('تحديد للحذف'),
                ),
              ),
            const PopupMenuItem(
              value: 'delete_all',
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text('حذف جميع أولياء الأمور'),
              ),
            ),
          ],
        ),
        if (_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              setState(() {
                _selectedIds.clear();
                _isSelectionMode = false;
              });
            },
          ),
      ],
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () {
                // TODO: Implement add parent logic or redirect to student add
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('يمكن إضافة ولي الأمر عند إضافة الطالب'),
                  ),
                );
              },
              label: const Text('إضافة ولي أمر'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.brown,
              foregroundColor: Colors.white,
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث عن ولي أمر (بالاسم أو الهاتف)',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (val) {
                setState(() => _searchQuery = val);
              },
            ),
          ),
          Expanded(
            child: parentsAsync.when(
              data: (parents) {
                final filteredParents = parents.where((p) {
                  if (_searchQuery.isEmpty) return true;
                  return p.name.contains(_searchQuery) ||
                      (p.identityNumber?.contains(_searchQuery) ?? false) ||
                      (p.phoneNumber?.contains(_searchQuery) ?? false);
                }).toList();

                if (filteredParents.isEmpty) {
                  return const Center(child: Text('لا يوجد أولياء أمور'));
                }

                return ListView.builder(
                  padding: EdgeInsets.symmetric(horizontal: 16.w),
                  itemCount: filteredParents.length,
                  itemBuilder: (context, index) {
                    final parent = filteredParents[index];
                    final isSelected = _selectedIds.contains(parent.id);

                    return Card(
                      color: isSelected ? Colors.blue.shade50 : null,
                      elevation: 2,
                      margin: EdgeInsets.only(bottom: 8.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: const BorderSide(color: Colors.black26),
                      ),
                      child: ListTile(
                        leading: _isSelectionMode
                            ? Checkbox(
                                value: isSelected,
                                onChanged: (val) => _toggleSelection(parent.id),
                              )
                            : CircleAvatar(
                                backgroundColor: Colors.brown.shade100,
                                child: const Icon(
                                  Icons.person,
                                  color: Colors.brown,
                                ),
                              ),
                        title: Text(parent.name),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (parent.phoneNumber != null)
                              Text('جوال: ${parent.phoneNumber}'),
                            if (parent.identityNumber != null)
                              Text('هوية: ${parent.identityNumber}'),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!_isSelectionMode) ...[
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () {
                                  // TODO: Navigate to edit parent
                                },
                              ),
                            ],
                          ],
                        ),
                        onTap: () {
                          if (_isSelectionMode) {
                            _toggleSelection(parent.id);
                          } else {
                            // TODO: Show parent details
                          }
                        },
                        onLongPress: () {
                          if (!_isSelectionMode) {
                            setState(() {
                              _isSelectionMode = true;
                              _toggleSelection(parent.id);
                            });
                          }
                        },
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('خطأ: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
