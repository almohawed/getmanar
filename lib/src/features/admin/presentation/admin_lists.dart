import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/email_generator.dart';
import '../../../core/presentation/session_timeout_manager.dart';
import '../data/mock_teacher_repository.dart';
import '../data/mock_class_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/mock_staff_repository.dart';
import '../../academic/presentation/students_provider.dart';
import '../../academic/domain/classroom.dart';
import '../../academic/data/student_repository.dart';
import '../../../core/utils/text_utils.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import '../../common/services/pdf_export_service.dart';

// Teachers List Screen
class TeachersListScreen extends ConsumerStatefulWidget {
  const TeachersListScreen({super.key});

  @override
  ConsumerState<TeachersListScreen> createState() => _TeachersListScreenState();
}

class _TeachersListScreenState extends ConsumerState<TeachersListScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد بالتأكيد حذف المعلمين ؟'),
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

    if (shouldDelete == true) {
      try {
        final user = ref.read(authStateProvider).value;
        final schoolId = user?.schoolId;
        if (schoolId != null && schoolId.isNotEmpty) {
          final repo = ref.read(firestoreTeacherRepositoryProvider);
          await repo.deleteTeachersForSchool(schoolId, _selectedIds.toList());
        } else {
          final repo = ref.read(mockTeacherRepositoryProvider);
          await repo.deleteTeachers(_selectedIds.toList());
        }

        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        ref.invalidate(teachersProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف المعلمين بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(teachersProvider);

    return SmartSectionScaffold(
      title: _isSelectionMode
          ? '${_selectedIds.length} محدد'
          : 'قائمة المعلمين',
      icon: Icons.school,
      themeColor: Colors.orange,
      initialRecommendation:
          'توصي الوزارة بمتابعة النصاب التدريسي وتفعيل مجتمعات التعلم المهنية لرفع كفاءة الأداء.',
      actions: [
        if (_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          )
        else
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(teachersProvider),
            tooltip: 'تحديث القائمة',
          ),
      ],
      body: teachersAsync.when(
        data: (teachers) {
          if (teachers.isEmpty) {
            return const Center(child: Text('لا يوجد معلمين'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: teachers.length,
            itemBuilder: (context, index) {
              final teacher = teachers[index];
              final isSelected = _selectedIds.contains(teacher.id);

              return Card(
                color: isSelected ? Colors.blue.shade50 : null,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black26),
                ),
                child: ListTile(
                  leading: _isSelectionMode
                      ? Checkbox(
                          value: isSelected,
                          onChanged: (val) => _toggleSelection(teacher.id),
                        )
                      : CircleAvatar(
                          backgroundColor: Colors.orange.shade100,
                          child: const Icon(Icons.person, color: Colors.orange),
                        ),
                  title: Text(teacher.name),
                  subtitle: Text(teacher.stage ?? 'غير محدد'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isSelectionMode) ...[
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            await context.push('/add-teacher', extra: teacher);
                            // Refresh not needed as we watch provider
                          },
                          tooltip: 'تعديل',
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.calendar_month,
                            color: Colors.indigo,
                          ),
                          onPressed: () => context.push(
                            Uri(
                              path: '/teacher-schedule',
                              queryParameters: {'teacherId': teacher.id},
                            ).toString(),
                          ),
                          tooltip: 'عرض الجدول',
                        ),
                        const Icon(Icons.arrow_forward_ios, size: 16),
                      ],
                    ],
                  ),
                  onTap: () {
                    if (_isSelectionMode) {
                      _toggleSelection(teacher.id);
                    } else {
                      context.push('/teacher-details', extra: teacher);
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode) {
                      setState(() {
                        _isSelectionMode = true;
                        _toggleSelection(teacher.id);
                      });
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/add-teacher');
              },
              label: const Text('إضافة معلم'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}

// Staff List Screen
class StaffListScreen extends ConsumerStatefulWidget {
  const StaffListScreen({super.key});

  @override
  ConsumerState<StaffListScreen> createState() => _StaffListScreenState();
}

class _StaffListScreenState extends ConsumerState<StaffListScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  UserRole _parseStaffRole(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return UserRole.administrative;
    final lower = s.toLowerCase();
    if (s.contains('وكيل') || lower.contains('deputy')) return UserRole.deputy;
    if (s.contains('مرشد') || lower.contains('counselor')) {
      return UserRole.counselor;
    }
    if (s.contains('إداري') || s.contains('اداري') || lower.contains('admin')) {
      return UserRole.administrative;
    }
    return UserRole.administrative;
  }

  Future<void> _exportStaffPdf(List<User> staff) async {
    if (staff.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يوجد موظفين للتصدير')));
      return;
    }
    final svc = PdfExportService(
      schoolName: '',
      signerTitle: 'الإدارة',
      defaultShowClassInfo: false,
    );
    await svc.printStaffRoster(staff);
  }

  Future<void> _deleteAllStaff(List<User> staff) async {
    final currentUser = ref.read(authStateProvider).value;
    final ids = staff
        .map((e) => e.id)
        .where((id) => id.isNotEmpty && id != currentUser?.id)
        .toList();
    if (ids.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('لا يوجد موظفين للحذف')));
      return;
    }

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف جميع الموظفين'),
        content: Text('سيتم حذف ${ids.length} موظف. هل أنت متأكد؟'),
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

    try {
      final schoolId = (currentUser?.schoolId ?? '').trim();
      if (schoolId.isNotEmpty) {
        final repo = ref.read(firestoreStaffRepositoryProvider);
        await repo.deleteStaffForSchool(schoolId, ids);
      } else {
        final repo = ref.read(mockStaffRepositoryProvider);
        await repo.deleteStaff(ids);
      }
      ref.invalidate(staffProvider);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الموظفين بنجاح')));
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

  Future<void> _importStaffFromExcel() async {
    try {
      sessionTimeoutPausedNotifier.value = true;
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
      );
      if (picked == null || picked.files.isEmpty) return;

      final bytes = picked.files.single.bytes;
      if (bytes == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تعذر قراءة الملف')));
        return;
      }

      final excelFile = Excel.decodeBytes(bytes);
      if (excelFile.tables.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف لا يحتوي على بيانات')),
        );
        return;
      }

      final sheet = excelFile.tables.values.first;
      final rows = sheet.rows;
      if (rows.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الملف لا يحتوي على صفوف')),
        );
        return;
      }

      var startRow = 0;
      final first = rows.first;
      final firstCell = first.isNotEmpty ? first[0]?.value?.toString() : null;
      final s = (firstCell ?? '').toString();
      final isHeader = s.contains('اسم') || s.toLowerCase().contains('name');
      startRow = isHeader ? 1 : 0;

      final currentUser = ref.read(authStateProvider).value;
      final schoolId = (currentUser?.schoolId ?? '').trim();
      final repo = schoolId.isNotEmpty
          ? ref.read(firestoreStaffRepositoryProvider)
          : ref.read(mockStaffRepositoryProvider);

      final report = <_StaffImportRowReport>[];
      for (var i = startRow; i < rows.length; i++) {
        final row = rows[i];
        final name = (row.isNotEmpty ? (row[0]?.value?.toString() ?? '') : '')
            .trim();
        if (name.isEmpty) continue;

        final roleRaw =
            (row.length > 1 ? (row[1]?.value?.toString() ?? '') : '').trim();
        final phone = (row.length > 2 ? (row[2]?.value?.toString() ?? '') : '')
            .trim();
        final nationalId =
            (row.length > 3 ? (row[3]?.value?.toString() ?? '') : '').trim();

        final role = _parseStaffRole(roleRaw);
        final email = EmailGenerator.generateEmail(
          role,
          identityNumber: nationalId.isNotEmpty ? nationalId : null,
          phoneNumber: phone.isNotEmpty ? phone : null,
        );
        final password = '123456';

        final user = User(
          id: const Uuid().v4(),
          name: name,
          email: email,
          role: role,
          phoneNumber: phone.isNotEmpty ? phone : null,
          nationalId: nationalId.isNotEmpty ? nationalId : null,
          schoolId: schoolId.isNotEmpty ? schoolId : null,
        );

        try {
          await repo.addStaff(user, password);
          report.add(
            _StaffImportRowReport(
              name: name,
              role: role,
              phone: phone,
              nationalId: nationalId,
              status: _StaffImportRowStatus.completed,
            ),
          );
        } catch (e) {
          report.add(
            _StaffImportRowReport(
              name: name,
              role: role,
              phone: phone,
              nationalId: nationalId,
              status: _StaffImportRowStatus.failed,
              error: e.toString(),
            ),
          );
        }
      }

      if (mounted) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'تقرير الاستيراد (تم: ${report.where((r) => r.status == _StaffImportRowStatus.completed).length}، فشل: ${report.where((r) => r.status == _StaffImportRowStatus.failed).length})',
            ),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('الاسم')),
                    DataColumn(label: Text('الوظيفة')),
                    DataColumn(label: Text('الجوال')),
                    DataColumn(label: Text('رقم الهوية')),
                    DataColumn(label: Text('الحالة')),
                  ],
                  rows: report
                      .map(
                        (r) => DataRow(
                          cells: [
                            DataCell(Text(r.name)),
                            DataCell(Text(_getRoleName(r.role))),
                            DataCell(Text(r.phone.isEmpty ? '—' : r.phone)),
                            DataCell(
                              Text(r.nationalId.isEmpty ? '—' : r.nationalId),
                            ),
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
                onPressed: () => Navigator.pop(context),
                child: const Text('إغلاق'),
              ),
            ],
          ),
        );
      }

      ref.invalidate(staffProvider);
    } finally {
      sessionTimeoutPausedNotifier.value = false;
    }
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
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد بالتأكيد حذف الموظفين ؟'),
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

    if (shouldDelete == true) {
      try {
        final user = ref.read(authStateProvider).value;
        final schoolId = user?.schoolId;
        if (schoolId != null && schoolId.isNotEmpty) {
          final repo = ref.read(firestoreStaffRepositoryProvider);
          await repo.deleteStaffForSchool(schoolId, _selectedIds.toList());
        } else {
          final repo = ref.read(mockStaffRepositoryProvider);
          await repo.deleteStaff(_selectedIds.toList());
        }

        setState(() {
          _selectedIds.clear();
          _isSelectionMode = false;
        });
        ref.invalidate(staffProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم حذف الموظفين بنجاح')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('حدث خطأ أثناء الحذف: $e')));
        }
      }
    }
  }

  String _getRoleName(UserRole role) {
    switch (role) {
      case UserRole.administrative:
        return 'إداري';
      case UserRole.counselor:
        return 'مرشد طلابي';
      case UserRole.deputy:
        return 'وكيل';
      default:
        return 'موظف';
    }
  }

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffProvider);
    final currentUser = ref.watch(authStateProvider).value;

    return SmartSectionScaffold(
      title: _isSelectionMode
          ? '${_selectedIds.length} محدد'
          : 'الكادر الإداري',
      icon: Icons.badge,
      themeColor: Colors.indigo,
      initialRecommendation:
          'توصي الوزارة بتعيين وكيل لكل 200 طالب ومرشد طلابي لكل 300 طالب لضمان جودة العمل الإداري.',
      actions: [
        if (_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
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
        PopupMenuButton<String>(
          onSelected: (v) async {
            if (v == 'import') {
              await _importStaffFromExcel();
              return;
            }
            if (v == 'export_pdf') {
              final staff = ref.read(staffProvider).value ?? [];
              await _exportStaffPdf(staff);
              return;
            }
            if (v == 'delete_all') {
              final staff = ref.read(staffProvider).value ?? [];
              await _deleteAllStaff(staff);
              return;
            }
            if (v == 'refresh') {
              ref.invalidate(staffProvider);
            }
          },
          itemBuilder: (context) => const [
            PopupMenuItem(
              value: 'import',
              child: ListTile(
                leading: Icon(Icons.upload_file),
                title: Text('استيراد Excel'),
              ),
            ),
            PopupMenuItem(
              value: 'export_pdf',
              child: ListTile(
                leading: Icon(Icons.picture_as_pdf),
                title: Text('تصدير PDF'),
              ),
            ),
            PopupMenuItem(
              value: 'delete_all',
              child: ListTile(
                leading: Icon(Icons.delete_forever, color: Colors.red),
                title: Text('حذف جميع الموظفين'),
              ),
            ),
            PopupMenuItem(
              value: 'refresh',
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('تحديث القائمة'),
              ),
            ),
          ],
        ),
      ],
      body: staffAsync.when(
        data: (staff) {
          if (staff.isEmpty) {
            return const Center(child: Text('لا يوجد موظفين'));
          }
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: staff.length,
            itemBuilder: (context, index) {
              final user = staff[index];
              final isSelected = _selectedIds.contains(user.id);
              final isSelf = currentUser != null && currentUser.id == user.id;

              return Card(
                color: isSelected ? Colors.blue.shade50 : Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.black26),
                ),
                child: ListTile(
                  leading: _isSelectionMode
                      ? (isSelf
                            ? const SizedBox.shrink()
                            : Checkbox(
                                value: isSelected,
                                onChanged: (val) => _toggleSelection(user.id),
                              ))
                      : CircleAvatar(
                          backgroundColor: Colors.indigo.shade50,
                          child: Icon(
                            Icons.person,
                            color: Colors.indigo.shade700,
                          ),
                        ),
                  title: Text(
                    user.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_getRoleName(user.role)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_isSelectionMode && !isSelf) ...[
                        IconButton(
                          icon: const Icon(
                            Icons.assignment_ind,
                            color: Colors.purple,
                          ),
                          onPressed: () {
                            context.push(
                              Uri(
                                path: '/create-admin-task',
                                queryParameters: {'staffId': user.id},
                              ).toString(),
                            );
                          },
                          tooltip: 'إسناد مهمة',
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit, color: Colors.blue),
                          onPressed: () async {
                            String route;
                            if (user.role == UserRole.counselor) {
                              route = '/add-counselor';
                            } else if (user.role == UserRole.deputy) {
                              route = '/add-deputy';
                            } else {
                              route = '/add-admin-staff';
                            }
                            await context.push(route, extra: user);
                            if (mounted) {
                              ref.invalidate(staffProvider);
                            }
                          },
                          tooltip: 'تعديل',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.red),
                          onPressed: () async {
                            setState(() {
                              _selectedIds
                                ..clear()
                                ..add(user.id);
                              _isSelectionMode = true;
                            });
                            await _deleteSelected();
                          },
                          tooltip: 'حذف',
                        ),
                      ],
                    ],
                  ),
                  onTap: () {
                    if (_isSelectionMode && !isSelf) {
                      _toggleSelection(user.id);
                    }
                  },
                  onLongPress: () {
                    if (!_isSelectionMode && !isSelf) {
                      setState(() {
                        _isSelectionMode = true;
                        _toggleSelection(user.id);
                      });
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
      floatingActionButton: !_isSelectionMode
          ? FloatingActionButton.extended(
              onPressed: () => _showAddStaffDialog(context),
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              label: const Text('إضافة موظف'),
              icon: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  void _showAddStaffDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Container(
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'إضافة موظف جديد',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 24.h),
            ListTile(
              leading: const Icon(Icons.person_add, color: Colors.indigo),
              title: const Text('إضافة وكيل'),
              onTap: () async {
                Navigator.pop(ctx);
                await context.push('/add-deputy');
                if (mounted) {
                  ref.invalidate(staffProvider);
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.psychology, color: Colors.purple),
              title: const Text('إضافة مرشد طلابي'),
              onTap: () async {
                Navigator.pop(ctx);
                await context.push('/add-counselor');
                if (mounted) {
                  ref.invalidate(staffProvider);
                }
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.blue,
              ),
              title: const Text('إضافة إداري / موظف'),
              onTap: () async {
                Navigator.pop(ctx);
                await context.push('/add-admin-staff');
                if (mounted) {
                  ref.invalidate(staffProvider);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

enum _StaffImportRowStatus { completed, failed }

extension on _StaffImportRowStatus {
  String get label {
    switch (this) {
      case _StaffImportRowStatus.completed:
        return 'تم';
      case _StaffImportRowStatus.failed:
        return 'فشل';
    }
  }
}

class _StaffImportRowReport {
  final String name;
  final UserRole role;
  final String phone;
  final String nationalId;
  final _StaffImportRowStatus status;
  final String? error;

  const _StaffImportRowReport({
    required this.name,
    required this.role,
    required this.phone,
    required this.nationalId,
    required this.status,
    this.error,
  });
}

// Classes List Screen
class ClassesListScreen extends ConsumerStatefulWidget {
  const ClassesListScreen({super.key});

  @override
  ConsumerState<ClassesListScreen> createState() => _ClassesListScreenState();
}

class _ClassesListScreenState extends ConsumerState<ClassesListScreen> {
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

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

  Future<void> _addStudentToClass(Classroom classroom) async {
    final currentUser = ref.read(authStateProvider).value;
    final schoolId = currentUser?.schoolId;
    if (schoolId == null || schoolId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يمكن تحديد المدرسة الحالية')),
      );
      return;
    }

    final idController = TextEditingController();
    final identity = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('إضافة طالب إلى الفصل'),
          content: TextField(
            controller: idController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'رقم هوية الطالب'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            TextButton(
              onPressed: () {
                final normalized = TextUtils.normalizeDigits(
                  idController.text.trim(),
                );
                Navigator.pop(context, normalized);
              },
              child: const Text('متابعة'),
            ),
          ],
        );
      },
    );

    if (identity == null || identity.isEmpty) return;

    try {
      final studentRepo = ref.read(studentRepositoryProvider);
      final student = await studentRepo.findStudentByIdentity(
        schoolId,
        identity,
      );

      if (student == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('لم يتم العثور على طالب بهذا الرقم')),
        );
        return;
      }

      final currentClassIds = student.assignedClassIds ?? [];
      final currentClassId = currentClassIds.isNotEmpty
          ? currentClassIds.first
          : null;

      final firestoreClassRepo = ref.read(firestoreClassRepositoryProvider);
      final mockClassRepo = ref.read(mockClassRepositoryProvider);
      final isSchoolMode = schoolId.isNotEmpty;

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
          currentClassId != classroom.id) {
        final shouldMove =
            await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('نقل الطالب بين الفصول'),
                content: Text(
                  currentClassName != null
                      ? 'الطالب موجود حالياً في الفصل $currentClassName. هل تريد نقله إلى الفصل ${classroom.preferredLabel}؟'
                      : 'الطالب موجود حالياً في فصل آخر. هل تريد نقله إلى الفصل ${classroom.preferredLabel}؟',
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

      if (currentClassId == classroom.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('الطالب مسند بالفعل إلى هذا الفصل')),
        );
        return;
      }

      final updatedStudent = student.copyWith(assignedClassIds: [classroom.id]);
      await studentRepo.updateStudent(schoolId, updatedStudent);

      if (isSchoolMode) {
        final existingTarget =
            await firestoreClassRepo.getClassById(schoolId, classroom.id) ??
            classroom;
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
            currentClassId != classroom.id) {
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
        final target = allClasses.firstWhere(
          (c) => c.id == classroom.id,
          orElse: () {
            return classroom;
          },
        );
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
            currentClassId != classroom.id) {
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
        SnackBar(
          content: Text(
            'تم إسناد الطالب إلى الفصل ${classroom.preferredLabel}',
          ),
        ),
      );

      ref.invalidate(classesProvider);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('حدث خطأ أثناء إضافة الطالب: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSelected() async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد الحذف'),
        content: const Text('هل تريد بالتأكيد حذف الفصول ؟'),
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

    if (shouldDelete == true) {
      final user = ref.read(authStateProvider).value;
      final schoolId = user?.schoolId;
      if (schoolId != null && schoolId.isNotEmpty) {
        final repo = ref.read(firestoreClassRepositoryProvider);
        await repo.deleteClasses(schoolId, _selectedIds.toList());
      } else {
        final repo = ref.read(mockClassRepositoryProvider);
        await repo.deleteClasses(_selectedIds.toList());
      }

      ref.invalidate(classesProvider);
      setState(() {
        _selectedIds.clear();
        _isSelectionMode = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم حذف الفصول بنجاح')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final classesAsync = ref.watch(classesProvider);
    final studentsAsync = ref.watch(studentsProvider);
    final user = ref.watch(authStateProvider).value;
    final isTeacher = user?.role == UserRole.teacher;

    return SmartSectionScaffold(
      title: _isSelectionMode
          ? '${_selectedIds.length} محدد'
          : 'الفصول الدراسية',
      icon: Icons.class_,
      themeColor: Colors.teal,
      initialRecommendation:
          'بيئة الصف الجاذبة ترفع التحصيل الدراسي. تأكد من توازن أعداد الطلاب في الفصول.',
      actions: [
        if (_isSelectionMode)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: _deleteSelected,
          ),
      ],
      body: classesAsync.when(
        data: (classes) {
          return studentsAsync.when(
            data: (students) {
              var displayClasses = classes;
              if (isTeacher && user != null) {
                displayClasses = classes
                    .where(
                      (c) => user.assignedClassIds?.contains(c.id) ?? false,
                    )
                    .toList();
              }

              if (displayClasses.isEmpty) {
                return const Center(child: Text('لا يوجد فصول'));
              }
              return ListView.builder(
                padding: EdgeInsets.all(16.w),
                itemCount: displayClasses.length,
                itemBuilder: (context, index) {
                  final classroom = displayClasses[index];
                  final isSelected = _selectedIds.contains(classroom.id);
                  final studentCount = students
                      .where(
                        (s) =>
                            (s.assignedClassIds ?? []).contains(classroom.id),
                      )
                      .length;

                  return Card(
                    color: isSelected ? Colors.blue.shade50 : null,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.black26),
                    ),
                    child: ListTile(
                      leading: _isSelectionMode
                          ? Checkbox(
                              value: isSelected,
                              onChanged: (val) =>
                                  _toggleSelection(classroom.id),
                            )
                          : CircleAvatar(
                              backgroundColor: Colors.teal.shade100,
                              child: const Icon(
                                Icons.class_,
                                color: Colors.teal,
                              ),
                            ),
                      title: Text(classroom.preferredLabel),
                      subtitle: Text('الصف: ${classroom.gradeLevel}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_isSelectionMode) ...[
                            Text('$studentCount طالب'),
                            SizedBox(width: 8.w),
                            if (!isTeacher)
                              IconButton(
                                icon: const Icon(
                                  Icons.person_add,
                                  color: Colors.green,
                                ),
                                onPressed: () => _addStudentToClass(classroom),
                                tooltip: 'إضافة طالب إلى هذا الفصل',
                              ),
                            if (!isTeacher)
                              IconButton(
                                icon: const Icon(
                                  Icons.edit,
                                  color: Colors.blue,
                                ),
                                onPressed: () async {
                                  await context.push(
                                    '/add-class',
                                    extra: classroom,
                                  );
                                },
                                tooltip: 'تعديل',
                              ),
                            IconButton(
                              icon: const Icon(
                                Icons.calendar_month,
                                color: Colors.indigo,
                              ),
                              onPressed: () => context.push(
                                Uri(
                                  path: '/student-schedule',
                                  queryParameters: {
                                    'className': classroom.name,
                                  },
                                ).toString(),
                              ),
                              tooltip: 'عرض الجدول',
                            ),
                          ],
                        ],
                      ),
                      onTap: () {
                        if (_isSelectionMode) {
                          _toggleSelection(classroom.id);
                        } else {
                          context.push('/class/${classroom.id}');
                        }
                      },
                      onLongPress: () {
                        if (!_isSelectionMode && !isTeacher) {
                          setState(() {
                            _isSelectionMode = true;
                            _toggleSelection(classroom.id);
                          });
                        }
                      },
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, s) => Center(child: Text('حدث خطأ أثناء تحميل الطلاب')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
      floatingActionButton: (!_isSelectionMode && !isTeacher)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await context.push('/add-class');
              },
              label: const Text('إضافة فصل'),
              icon: const Icon(Icons.add),
              backgroundColor: Colors.teal.shade700,
              foregroundColor: Colors.white,
            )
          : null,
    );
  }
}
