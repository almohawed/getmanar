// ignore_for_file: use_build_context_synchronously
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart' as xl;
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';

// ─────────────────────────────────────────────
// Constants
// ─────────────────────────────────────────────
const List<String> _kDays = [
  'الأحد',
  'الاثنين',
  'الثلاثاء',
  'الأربعاء',
  'الخميس',
];

const _kPrimary = Color(0xFF1565C0);
const _kAccent = Color(0xFF0288D1);

// ─────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────
class SupervisionAssignment {
  final String id;
  final String docId; // Firestore document ID (= day name)
  final String day;
  final String teacherId;
  final String teacherName;
  final String location;
  final String? supervisorChief;

  SupervisionAssignment({
    required this.id,
    required this.docId,
    required this.day,
    required this.teacherId,
    required this.teacherName,
    required this.location,
    this.supervisorChief,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'day': day,
    'teacherId': teacherId,
    'teacherName': teacherName,
    'location': location,
    if (supervisorChief != null) 'supervisorChief': supervisorChief,
  };

  factory SupervisionAssignment.fromMap(Map<String, dynamic> m, {String docId = ''}) =>
      SupervisionAssignment(
        id: (m['id'] ?? '').toString().isNotEmpty ? m['id'].toString() : const Uuid().v4(),
        docId: docId,
        day: m['day'] ?? '',
        teacherId: m['teacherId'] ?? '',
        teacherName: m['teacherName'] ?? '',
        location: m['location'] ?? '',
        supervisorChief: m['supervisorChief'],
      );
}

class DutyAssignment {
  final String id;
  final String day;
  final String teacherId;
  final String teacherName;

  DutyAssignment({
    required this.id,
    required this.day,
    required this.teacherId,
    required this.teacherName,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'day': day,
    'teacherId': teacherId,
    'teacherName': teacherName,
  };

  factory DutyAssignment.fromMap(Map<String, dynamic> m) => DutyAssignment(
    id: m['id'] ?? const Uuid().v4(),
    day: m['day'] ?? '',
    teacherId: m['teacherId'] ?? '',
    teacherName: m['teacherName'] ?? '',
  );
}

class DutyWeek {
  final String id;
  final DateTime weekStart;
  final DateTime weekEnd;
  final int? weekIndex;
  final int? totalWeeks;
  final String? durationLabel;
  final List<DutyAssignment> assignments;

  DutyWeek({
    required this.id,
    required this.weekStart,
    required this.weekEnd,
    this.weekIndex,
    this.totalWeeks,
    this.durationLabel,
    required this.assignments,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'weekStart': weekStart.toIso8601String(),
    'weekEnd': weekEnd.toIso8601String(),
    if (weekIndex != null) 'weekIndex': weekIndex,
    if (totalWeeks != null) 'totalWeeks': totalWeeks,
    if (durationLabel != null) 'durationLabel': durationLabel,
    'assignments': assignments.map((a) => a.toMap()).toList(),
  };

  factory DutyWeek.fromMap(Map<String, dynamic> m) {
    final rawAssignments = m['assignments'] as List<dynamic>? ?? [];
    return DutyWeek(
      id: m['id'] ?? const Uuid().v4(),
      weekStart: DateTime.tryParse(m['weekStart'] ?? '') ?? DateTime.now(),
      weekEnd: DateTime.tryParse(m['weekEnd'] ?? '') ??
          DateTime.now().add(const Duration(days: 4)),
      weekIndex: m['weekIndex'],
      totalWeeks: m['totalWeeks'],
      durationLabel: m['durationLabel'],
      assignments: rawAssignments
          .whereType<Map>()
          .map((e) => DutyAssignment.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────
final _teachersProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Teachers')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .toList(),
      );
});

/// جلب أفراد الإدارة (وكلاء + إداريين + مدير) لاستخدامهم كمشرف المشرفين
final _adminStaffProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
  if (schoolId.isEmpty) return const Stream.empty();
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Staff')
      .snapshots()
      .map((snap) {
        const adminRoles = {'deputy', 'administrative', 'admin'};
        final list = snap.docs
            .map((d) => {'id': d.id, ...d.data()})
            .where((u) => adminRoles.contains((u['role'] ?? '').toString()))
            .toList();
        list.sort((a, b) => _roleOrder(a['role']) - _roleOrder(b['role']));
        return list;
      });
});

int _roleOrder(dynamic role) {
  switch (role?.toString()) {
    case 'admin': return 0;
    case 'deputy': return 1;
    case 'administrative': return 2;
    default: return 3;
  }
}

String _roleLabel(dynamic role, dynamic deputyType) {
  switch (role?.toString()) {
    case 'admin': return 'مدير المدرسة';
    case 'administrative': return 'إداري';
    case 'deputy':
      switch (deputyType?.toString()) {
        case 'academic': return 'وكيل شؤون تعليمية';
        case 'school': return 'وكيل شؤون مدرسية';
        case 'student': return 'وكيل شؤون طلاب';
        case 'stage': return 'وكيل مرحلة';
        default: return 'وكيل';
      }
    default: return role?.toString() ?? '';
  }
}

final _supervisionScheduleProvider =
    StreamProvider.family<List<SupervisionAssignment>, String>(
      (ref, schoolId) {
        return FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('SupervisionSchedule')
            .snapshots()
            .map((snap) {
              final List<SupervisionAssignment> result = [];
              for (final doc in snap.docs) {
                final data = doc.data();
                final rawList = data['assignments'] as List<dynamic>? ?? [];
                for (final item in rawList) {
                  if (item is Map) {
                    result.add(
                      SupervisionAssignment.fromMap(
                        Map<String, dynamic>.from(item),
                        docId: doc.id,
                      ),
                    );
                  }
                }
              }
              return result;
            });
      },
    );

final _dutyScheduleProvider =
    StreamProvider.family<List<DutyWeek>, String>((ref, schoolId) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('DutySchedule')
      .orderBy('weekStart')
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => DutyWeek.fromMap({'id': d.id, ...d.data()}))
            .toList(),
      );
});

// ─────────────────────────────────────────────
// Main Screen
// ─────────────────────────────────────────────
class SupervisionDutyScreen extends ConsumerStatefulWidget {
  const SupervisionDutyScreen({super.key});

  @override
  ConsumerState<SupervisionDutyScreen> createState() =>
      _SupervisionDutyScreenState();
}

class _SupervisionDutyScreenState
    extends ConsumerState<SupervisionDutyScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String? _getSchoolId() {
    final user = ref.read(authStateProvider).value;
    return user?.schoolId;
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = _getSchoolId();
    // تحقق من الدور — الإدارة فقط يمكنها التعديل
    final user = ref.read(authStateProvider).value;
    final role = user?.role;
    final deputyType = user?.deputyType;
    final canEdit = role == UserRole.admin ||
        role == UserRole.superAdmin ||
        (role == UserRole.deputy &&
            (deputyType == 'academic' ||
             deputyType == 'school' ||
             deputyType == 'student' ||
             deputyType == 'stage'));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: _kPrimary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'الإشراف والمناوبة',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.supervisor_account), text: 'الإشراف'),
            Tab(icon: Icon(Icons.swap_horiz), text: 'المناوبة'),
          ],
        ),
      ),
      body: schoolId == null
          ? const Center(child: Text('لم يتم تحديد المدرسة'))
          : TabBarView(
              controller: _tabController,
              children: [
                _SupervisionTab(schoolId: schoolId, canEdit: canEdit),
                _DutyTab(schoolId: schoolId, canEdit: canEdit),
              ],
            ),
    );
  }
}

// ─────────────────────────────────────────────
// Supervision Tab
// ─────────────────────────────────────────────
class _SupervisionTab extends ConsumerStatefulWidget {
  final String schoolId;
  final bool canEdit;
  const _SupervisionTab({required this.schoolId, required this.canEdit});

  @override
  ConsumerState<_SupervisionTab> createState() => _SupervisionTabState();
}

class _SupervisionTabState extends ConsumerState<_SupervisionTab> {
  bool _loading = false;

  Future<void> _addAssignment(List<Map<String, dynamic>> teachers) async {
    final result = await showDialog<SupervisionAssignment>(
      context: context,
      builder: (_) => _AddSupervisionDialog(
        teachers: teachers,
        schoolId: widget.schoolId,
      ),
    );
    if (result == null) return;

    setState(() => _loading = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .collection('SupervisionSchedule')
          .doc(result.day);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        final existing = snap.exists
            ? List<Map<String, dynamic>>.from(
                (snap.data()?['assignments'] as List<dynamic>? ?? [])
                    .map((e) => Map<String, dynamic>.from(e as Map)),
              )
            : <Map<String, dynamic>>[];
        existing.add(result.toMap());
        tx.set(docRef, {'day': result.day, 'assignments': existing});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تمت إضافة المشرف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAssignment(
    String day,
    String assignmentId,
    List<SupervisionAssignment> allAssignments,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('حذف المشرف'),
        content: const Text('هل تريد حذف هذا التعيين؟'),
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
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      // إيجاد الـ assignment للحصول على docId الصحيح
      final target = allAssignments.firstWhere(
        (a) => a.id == assignmentId,
        orElse: () => allAssignments.firstWhere(
          (a) => a.day == day,
          orElse: () => SupervisionAssignment(
            id: assignmentId, docId: day, day: day,
            teacherId: '', teacherName: '', location: ''),
        ),
      );

      // استخدام docId (= اسم اليوم) للوصول للـ document الصحيح
      final docId = target.docId.isNotEmpty ? target.docId : day;
      final docRef = FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .collection('SupervisionSchedule')
          .doc(docId);

      await FirebaseFirestore.instance.runTransaction((tx) async {
        final snap = await tx.get(docRef);
        if (!snap.exists) return;
        final existing = List<Map<String, dynamic>>.from(
          (snap.data()?['assignments'] as List<dynamic>? ?? [])
              .map((e) => Map<String, dynamic>.from(e as Map)),
        );
        // حذف بالـ id أو بالـ teacherId+day إذا لم يوجد id
        existing.removeWhere((e) =>
            e['id'] == assignmentId ||
            (e['id'] == null && e['teacherId'] == target.teacherId && e['day'] == day));
        tx.update(docRef, {'assignments': existing});
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ تم حذف المشرف'), backgroundColor: Colors.green));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendBreakNotification(
    List<SupervisionAssignment> assignments,
  ) async {
    final todayName = _kDays[DateTime.now().weekday % 7 == 0
        ? 6
        : DateTime.now().weekday - 1];
    final todayAssignments =
        assignments.where((a) => a.day == todayName).toList();

    if (todayAssignments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد مشرفون لليوم الحالي')),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final batch = FirebaseFirestore.instance.batch();
      final now = DateTime.now();
      final uuid = const Uuid();

      for (final a in todayAssignments) {
        final notifRef = FirebaseFirestore.instance
            .collection('Schools')
            .doc(widget.schoolId)
            .collection('Notifications')
            .doc(uuid.v4());

        batch.set(notifRef, {
          'id': notifRef.id,
          'type': 'supervision_break',
          'title': 'تذكير إشراف الفسحة',
          'body':
              'تذكير: أنت مشرف على موقع "${a.location}" اليوم ($todayName)',
          'targetUserId': a.teacherId,
          'targetUserName': a.teacherName,
          'createdAt': now.toIso8601String(),
          'isRead': false,
        });

        final schedNotifRef = FirebaseFirestore.instance
            .collection('Schools')
            .doc(widget.schoolId)
            .collection('ScheduledNotifications')
            .doc(uuid.v4());

        batch.set(schedNotifRef, {
          'type': 'supervision_break',
          'teacherId': a.teacherId,
          'teacherName': a.teacherName,
          'location': a.location,
          'day': todayName,
          'scheduledAt': now.toIso8601String(),
          'sent': false,
        });
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم إرسال إشعار الفسحة لـ ${todayAssignments.length} مشرف',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importFromExcel(List<Map<String, dynamic>> teachers) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    setState(() => _loading = true);
    try {
      final excel = xl.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      final rows = sheet.rows;
      if (rows.length < 2) {
        throw Exception('الملف فارغ أو لا يحتوي على بيانات');
      }

      final Map<String, List<Map<String, dynamic>>> byDay = {};
      final uuid = const Uuid();

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;
        final day = row[0]?.value?.toString().trim() ?? '';
        final teacherName = row[1]?.value?.toString().trim() ?? '';
        final location = row[2]?.value?.toString().trim() ?? '';
        final chief = row.length > 3
            ? row[3]?.value?.toString().trim()
            : null;

        if (day.isEmpty || teacherName.isEmpty || location.isEmpty) continue;
        if (!_kDays.contains(day)) continue;

        final teacher = teachers.firstWhere(
          (t) => (t['name'] ?? '').toString() == teacherName,
          orElse: () => {'id': uuid.v4(), 'name': teacherName},
        );

        byDay.putIfAbsent(day, () => []).add({
          'id': uuid.v4(),
          'day': day,
          'teacherId': teacher['id'],
          'teacherName': teacherName,
          'location': location,
          if (chief != null && chief.isNotEmpty) 'supervisorChief': chief,
        });
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final entry in byDay.entries) {
        final docRef = FirebaseFirestore.instance
            .collection('Schools')
            .doc(widget.schoolId)
            .collection('SupervisionSchedule')
            .doc(entry.key);
        batch.set(docRef, {
          'day': entry.key,
          'assignments': entry.value,
        });
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم استيراد جدول الإشراف بنجاح')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الاستيراد: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showReport(List<SupervisionAssignment> assignments) async {
    final Map<String, int> countByTeacher = {};
    for (final a in assignments) {
      countByTeacher[a.teacherName] =
          (countByTeacher[a.teacherName] ?? 0) + 1;
    }
    final sorted = countByTeacher.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('تقرير الإشراف'),
        content: SizedBox(
          width: 320,
          child: sorted.isEmpty
              ? const Text('لا توجد بيانات')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: sorted.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      backgroundColor: _kPrimary,
                      radius: 14,
                      child: Text(
                        '${sorted[i].value}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                        ),
                      ),
                    ),
                    title: Text(sorted[i].key),
                    trailing: Text('${sorted[i].value} يوم'),
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

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(_teachersProvider(widget.schoolId));
    final scheduleAsync = ref.watch(_supervisionScheduleProvider(widget.schoolId));
    // للمعلم: نصفّي لإظهار أيامه فقط
    final myTeacherId = widget.canEdit ? null : ref.read(authStateProvider).value?.id;

    return Stack(
      children: [
        Column(
          children: [
            if (widget.canEdit) _SupervisionToolbar(
              onAdd: () {
                final teachers = teachersAsync.value ?? [];
                _addAssignment(teachers);
              },
              onBreakNotif: () {
                final assignments = scheduleAsync.value ?? [];
                _sendBreakNotification(assignments);
              },
              onImport: () {
                final teachers = teachersAsync.value ?? [];
                _importFromExcel(teachers);
              },
              onReport: () {
                final assignments = scheduleAsync.value ?? [];
                _showReport(assignments);
              },
            ),
            if (!widget.canEdit) _ReadOnlyBanner(),
            Expanded(
              child: scheduleAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('خطأ: $e')),
                data: (allAssignments) {
                  // للمعلم: أظهر فقط الأيام التي هو مُعيَّن فيها
                  final assignments = myTeacherId == null
                      ? allAssignments
                      : allAssignments.where((a) => a.teacherId == myTeacherId).toList();

                  if (!widget.canEdit && assignments.isEmpty) {
                    return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.event_available_rounded, size: 56, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      Text('لا يوجد إشراف مُعيَّن لك حالياً',
                          style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                      const SizedBox(height: 6),
                      Text('سيظهر هنا جدول إشرافك عند تعيينه من الإدارة',
                          style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                    ]));
                  }

                  return _SupervisionWeeklyTable(
                    assignments: assignments,
                    onDelete: (day, id) => _deleteAssignment(day, id, allAssignments),
                    canDelete: widget.canEdit,
                    teacherView: !widget.canEdit,
                  );
                },
              ),
            ),
          ],
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Supervision Toolbar
// ─────────────────────────────────────────────
class _SupervisionToolbar extends StatelessWidget {
  final VoidCallback onAdd;
  final VoidCallback onBreakNotif;
  final VoidCallback onImport;
  final VoidCallback onReport;

  const _SupervisionToolbar({
    required this.onAdd,
    required this.onBreakNotif,
    required this.onImport,
    required this.onReport,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade50,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _ToolbarButton(
            icon: Icons.person_add,
            label: 'إضافة مشرف',
            color: _kPrimary,
            onTap: onAdd,
          ),
          _ToolbarButton(
            icon: Icons.notifications_active,
            label: 'إشعار الفسحة',
            color: Colors.orange.shade700,
            onTap: onBreakNotif,
          ),
          _ToolbarButton(
            icon: Icons.upload_file,
            label: 'استيراد Excel',
            color: Colors.green.shade700,
            onTap: onImport,
          ),
          _ToolbarButton(
            icon: Icons.bar_chart,
            label: 'التقارير',
            color: Colors.purple.shade700,
            onTap: onReport,
          ),
        ],
      ),
    );
  }
}

// ─── Read Only Banner — للمعلمين (عرض فقط) ───────────────────────────────────
class _ReadOnlyBanner extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    color: Colors.blue.shade50,
    child: Row(children: [
      Icon(Icons.visibility_rounded, color: Colors.blue.shade700, size: 18),
      const SizedBox(width: 8),
      Expanded(child: Text(
        'وضع العرض — يمكنك الاطلاع على جدول الإشراف والمناوبة',
        style: TextStyle(color: Colors.blue.shade700, fontSize: 12.5),
      )),
    ]),
  );
}

class _ToolbarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ToolbarButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Supervision Weekly Table
// ─────────────────────────────────────────────
class _SupervisionWeeklyTable extends StatelessWidget {
  final List<SupervisionAssignment> assignments;
  final void Function(String day, String id) onDelete;
  final bool canDelete;
  final bool teacherView; // عرض المعلم: يظهر أيامه فقط مع زملائه في نفس اليوم

  const _SupervisionWeeklyTable({
    required this.assignments,
    required this.onDelete,
    this.canDelete = false,
    this.teacherView = false,
  });

  @override
  Widget build(BuildContext context) {
    if (assignments.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.supervisor_account, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text('لا يوجد جدول إشراف بعد',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
            const SizedBox(height: 6),
            Text(teacherView ? 'لم يتم تعيينك في إشراف بعد' : 'أضف مشرفين أو استورد من Excel',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 13)),
          ],
        ),
      );
    }

    // للمعلم: أظهر فقط الأيام التي فيها إشراف له، مع جميع المشرفين في نفس اليوم
    // للإدارة: أظهر جميع الأيام
    final daysToShow = teacherView
        ? _kDays.where((day) => assignments.any((a) => a.day == day)).toList()
        : _kDays;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          // بانر للمعلم يوضح أيام إشرافه
          if (teacherView) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _kPrimary.withOpacity(0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _kPrimary.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(Icons.calendar_today_rounded, color: _kPrimary, size: 16),
                const SizedBox(width: 8),
                Text(
                  'أيام إشرافك: ${daysToShow.join(' • ')}',
                  style: TextStyle(color: _kPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ]),
            ),
          ],
          ...daysToShow.map((day) {
            final dayAssignments = assignments.where((a) => a.day == day).toList();
            return _DaySupervisionCard(
              day: day,
              assignments: dayAssignments,
              onDelete: (id) => onDelete(day, id),
              canDelete: canDelete,
            );
          }).toList(),
        ],
      ),
    );
  }
}

class _DaySupervisionCard extends StatelessWidget {
  final String day;
  final List<SupervisionAssignment> assignments;
  final void Function(String id) onDelete;
  final bool canDelete;

  const _DaySupervisionCard({
    required this.day,
    required this.assignments,
    required this.onDelete,
    this.canDelete = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(10),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text(
                  day,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${assignments.length} مشرف',
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          if (assignments.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text(
                'لا يوجد مشرفون لهذا اليوم',
                style: TextStyle(color: Colors.grey),
              ),
            )
          else
            ...assignments.map(
              (a) => ListTile(
                dense: true,
                leading: CircleAvatar(
                  backgroundColor: _kAccent.withOpacity(0.15),
                  child: Icon(Icons.person, color: _kAccent, size: 18),
                ),
                title: Text(
                  a.teacherName,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.location_on,
                            size: 13, color: Colors.grey),
                        const SizedBox(width: 3),
                        Text(a.location,
                            style: const TextStyle(fontSize: 12)),
                      ],
                    ),
                    if (a.supervisorChief != null &&
                        a.supervisorChief!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.star,
                              size: 13, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            'مشرف المشرفين: ${a.supervisorChief}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.amber,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                trailing: canDelete ? IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () => onDelete(a.id),
                ) : null,
              ),
            ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Add Supervision Dialog
// ─────────────────────────────────────────────
class _AddSupervisionDialog extends ConsumerStatefulWidget {
  final List<Map<String, dynamic>> teachers;
  final String schoolId;
  const _AddSupervisionDialog({required this.teachers, required this.schoolId});

  @override
  ConsumerState<_AddSupervisionDialog> createState() => _AddSupervisionDialogState();
}

class _AddSupervisionDialogState extends ConsumerState<_AddSupervisionDialog> {
  String? _selectedDay;
  Map<String, dynamic>? _selectedTeacher;
  Map<String, dynamic>? _selectedChief; // مشرف المشرفين من الإدارة
  final _locationCtrl = TextEditingController();

  @override
  void dispose() {
    _locationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Row(children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: _kPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.person_add, color: _kPrimary, size: 20)),
        const SizedBox(width: 10),
        const Text('إضافة مشرف', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
      ]),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // اليوم
              DropdownButtonFormField<String>(
                value: _selectedDay,
                decoration: const InputDecoration(labelText: 'اليوم *', border: OutlineInputBorder()),
                items: _kDays.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                onChanged: (v) => setState(() => _selectedDay = v),
              ),
              const SizedBox(height: 12),
              // المشرف
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedTeacher,
                decoration: const InputDecoration(labelText: 'المشرف *', border: OutlineInputBorder()),
                items: widget.teachers.map((t) => DropdownMenuItem(value: t, child: Text(t['name']?.toString() ?? ''))).toList(),
                onChanged: (v) => setState(() => _selectedTeacher = v),
              ),
              const SizedBox(height: 12),
              // الموقع
              TextField(
                controller: _locationCtrl,
                decoration: const InputDecoration(labelText: 'الموقع *', border: OutlineInputBorder(), hintText: 'مثال: الفناء الشمالي'),
              ),
              const SizedBox(height: 16),
              // مشرف المشرفين — من الإدارة فقط
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.manage_accounts_rounded, color: Colors.amber, size: 18),
                    const SizedBox(width: 6),
                    const Text('مشرف المشرفين', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                    const SizedBox(width: 6),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(6)),
                      child: const Text('اختياري', style: TextStyle(fontSize: 10, color: Colors.amber))),
                  ]),
                  const SizedBox(height: 4),
                  const Text('من الإدارة: وكيل / إداري / مدير', style: TextStyle(fontSize: 11, color: Colors.grey)),
                  const SizedBox(height: 10),
                  // جلب الإداريين من provider
                  ref.watch(_adminStaffProvider(widget.schoolId)).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('خطأ: $e', style: const TextStyle(color: Colors.red, fontSize: 12)),
                    data: (adminList) => DropdownButtonFormField<Map<String, dynamic>>(
                      value: _selectedChief,
                      decoration: const InputDecoration(
                        labelText: 'اختر مشرف المشرفين',
                        border: OutlineInputBorder(),
                        filled: true, fillColor: Colors.white,
                      ),
                      items: [
                        const DropdownMenuItem<Map<String, dynamic>>(
                          value: null,
                          child: Text('— بدون مشرف مشرفين —'),
                        ),
                        ...adminList.map((u) {
                          final label = _roleLabel(u['role'], u['deputyType']);
                          final name = u['name']?.toString() ?? '';
                          return DropdownMenuItem<Map<String, dynamic>>(
                            value: u,
                            child: Row(children: [
                              const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                              const SizedBox(width: 6),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(name, style: const TextStyle(fontSize: 13)),
                                  Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                ],
                              )),
                            ]),
                          );
                        }),
                      ],
                      onChanged: (v) => setState(() => _selectedChief = v),
                    ),
                  ),
                  if (_selectedChief != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(color: Colors.amber.shade100, borderRadius: BorderRadius.circular(8)),
                      child: Row(children: [
                        const Icon(Icons.verified_rounded, color: Colors.amber, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedChief!['name']} — ${_roleLabel(_selectedChief!['role'], _selectedChief!['deputyType'])}',
                          style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ],
                ]),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
          onPressed: () {
            if (_selectedDay == null || _selectedTeacher == null || _locationCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('يرجى تعبئة جميع الحقول المطلوبة')));
              return;
            }
            final assignment = SupervisionAssignment(
              id: const Uuid().v4(),
              docId: _selectedDay!, // docId = day name (used as Firestore doc ID)
              day: _selectedDay!,
              teacherId: _selectedTeacher!['id']?.toString() ?? '',
              teacherName: _selectedTeacher!['name']?.toString() ?? '',
              location: _locationCtrl.text.trim(),
              supervisorChief: _selectedChief?['name']?.toString(),
            );
            Navigator.pop(context, assignment);
          },
          child: const Text('إضافة', style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Duty Tab
// ─────────────────────────────────────────────
class _DutyTab extends ConsumerStatefulWidget {
  final String schoolId;
  final bool canEdit;
  const _DutyTab({required this.schoolId, required this.canEdit});

  @override
  ConsumerState<_DutyTab> createState() => _DutyTabState();
}

class _DutyTabState extends ConsumerState<_DutyTab> {
  bool _loading = false;

  // Duration options: 1 week / 16 weeks / 32 weeks
  static const List<_DurationOption> _durationOptions = [
    _DurationOption(label: 'أسبوع واحد', weeks: 1),
    _DurationOption(label: 'فصل دراسي (16 أسبوع)', weeks: 16),
    _DurationOption(label: 'سنة دراسية (32 أسبوع)', weeks: 32),
  ];

  Future<void> _generateDutySchedule(
    List<Map<String, dynamic>> teachers,
    _DurationOption option,
  ) async {
    if (teachers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لا يوجد معلمون لتوزيع المناوبة')),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('توليد جدول المناوبة'),
        content: Text(
          'سيتم توليد جدول مناوبة لـ ${option.label} '
          'بالتناوب بين ${teachers.length} معلم.\n\n'
          'هل تريد المتابعة؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _kPrimary),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('توليد', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final uuid = const Uuid();
      final now = DateTime.now();
      // Find the nearest Sunday as week start
      final daysToSunday = now.weekday == 7 ? 0 : now.weekday;
      final firstSunday = now.subtract(Duration(days: daysToSunday));
      final weekStart = DateTime(
        firstSunday.year,
        firstSunday.month,
        firstSunday.day,
      );

      final batch = FirebaseFirestore.instance.batch();
      int teacherIndex = 0;

      for (int w = 0; w < option.weeks; w++) {
        final wStart = weekStart.add(Duration(days: w * 7));
        final wEnd = wStart.add(const Duration(days: 4)); // Sun–Thu

        final List<DutyAssignment> weekAssignments = [];
        for (final day in _kDays) {
          final teacher = teachers[teacherIndex % teachers.length];
          weekAssignments.add(
            DutyAssignment(
              id: uuid.v4(),
              day: day,
              teacherId: teacher['id']?.toString() ?? '',
              teacherName: teacher['name']?.toString() ?? '',
            ),
          );
          teacherIndex++;
        }

        final week = DutyWeek(
          id: uuid.v4(),
          weekStart: wStart,
          weekEnd: wEnd,
          weekIndex: w + 1,
          totalWeeks: option.weeks,
          durationLabel: option.label,
          assignments: weekAssignments,
        );

        final docRef = FirebaseFirestore.instance
            .collection('Schools')
            .doc(widget.schoolId)
            .collection('DutySchedule')
            .doc(week.id);

        batch.set(docRef, week.toMap());
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم توليد جدول المناوبة لـ ${option.weeks} أسبوع بنجاح',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearDutySchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('مسح جدول المناوبة'),
        content: const Text(
          'هل تريد مسح جميع بيانات المناوبة؟ لا يمكن التراجع عن هذا الإجراء.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .collection('DutySchedule')
          .get();

      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم مسح جدول المناوبة')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _importDutyFromExcel(
    List<Map<String, dynamic>> teachers,
  ) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx', 'xls'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    final bytes = result.files.first.bytes;
    if (bytes == null) return;

    setState(() => _loading = true);
    try {
      final excel = xl.Excel.decodeBytes(bytes);
      final sheet = excel.tables.values.first;
      final rows = sheet.rows;
      if (rows.length < 2) throw Exception('الملف فارغ');

      final uuid = const Uuid();
      final Map<String, DutyWeek> weekMap = {};

      for (int i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.length < 3) continue;

        final weekStartStr = row[0]?.value?.toString().trim() ?? '';
        final day = row[1]?.value?.toString().trim() ?? '';
        final teacherName = row[2]?.value?.toString().trim() ?? '';

        if (weekStartStr.isEmpty || day.isEmpty || teacherName.isEmpty) {
          continue;
        }
        if (!_kDays.contains(day)) continue;

        final weekStart = DateTime.tryParse(weekStartStr);
        if (weekStart == null) continue;

        final weekKey = DateFormat('yyyy-MM-dd').format(weekStart);
        final teacher = teachers.firstWhere(
          (t) => (t['name'] ?? '').toString() == teacherName,
          orElse: () => {'id': uuid.v4(), 'name': teacherName},
        );

        if (!weekMap.containsKey(weekKey)) {
          weekMap[weekKey] = DutyWeek(
            id: uuid.v4(),
            weekStart: weekStart,
            weekEnd: weekStart.add(const Duration(days: 4)),
            assignments: [],
          );
        }

        weekMap[weekKey]!.assignments.add(
          DutyAssignment(
            id: uuid.v4(),
            day: day,
            teacherId: teacher['id']?.toString() ?? '',
            teacherName: teacherName,
          ),
        );
      }

      final batch = FirebaseFirestore.instance.batch();
      for (final week in weekMap.values) {
        final docRef = FirebaseFirestore.instance
            .collection('Schools')
            .doc(widget.schoolId)
            .collection('DutySchedule')
            .doc(week.id);
        batch.set(docRef, week.toMap());
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تم استيراد ${weekMap.length} أسبوع من المناوبة',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في الاستيراد: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showDutyManagementSheet(
    BuildContext context,
    List<Map<String, dynamic>> teachers,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, scrollCtrl) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(children: [
            // Handle
            Container(
              margin: const EdgeInsets.only(top: 10, bottom: 6),
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Row(children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _kPrimary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.settings_rounded, color: _kPrimary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('إدارة جدول المناوبة',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ]),
            ),
            const Divider(height: 1),
            // Content
            Expanded(child: ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.all(16),
              children: [
                // ── التوليد التلقائي ──
                _SectionHeader(
                  icon: Icons.auto_awesome,
                  title: 'توليد تلقائي بالتناوب',
                  subtitle: 'يوزع المعلمين تلقائياً على الأيام',
                  color: _kPrimary,
                ),
                const SizedBox(height: 10),
                ..._durationOptions.asMap().entries.map((e) {
                  final colors = [_kPrimary, Colors.green.shade700, Colors.orange.shade700];
                  final icons = [Icons.looks_one_rounded, Icons.calendar_view_month_rounded, Icons.auto_stories_rounded];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        _generateDutySchedule(teachers, e.value);
                      },
                      icon: Icon(icons[e.key], size: 18),
                      label: Text(e.value.label),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colors[e.key],
                        foregroundColor: Colors.white,
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // ── الإدخال اليدوي ──
                _SectionHeader(
                  icon: Icons.edit_note_rounded,
                  title: 'إدخال يدوي',
                  subtitle: 'اختر معلم المناوبة لكل يوم بنفسك',
                  color: Colors.purple.shade700,
                ),
                const SizedBox(height: 10),
                ..._durationOptions.asMap().entries.map((e) {
                  final icons = [Icons.looks_one_rounded, Icons.calendar_view_month_rounded, Icons.auto_stories_rounded];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        showDialog(
                          context: context,
                          builder: (_) => _ManualDutyInputDialog(
                            schoolId: widget.schoolId,
                            teachers: teachers,
                            option: e.value,
                          ),
                        );
                      },
                      icon: Icon(icons[e.key], size: 18),
                      label: Text(e.value.label),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.purple.shade700,
                        side: BorderSide(color: Colors.purple.shade400),
                        alignment: Alignment.centerRight,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                // ── أدوات أخرى ──
                _SectionHeader(
                  icon: Icons.more_horiz_rounded,
                  title: 'أدوات أخرى',
                  subtitle: '',
                  color: Colors.grey.shade700,
                ),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _ToolbarButton(
                    icon: Icons.upload_file,
                    label: 'استيراد Excel',
                    color: Colors.teal.shade700,
                    onTap: () {
                      Navigator.pop(context);
                      _importDutyFromExcel(teachers);
                    },
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _ToolbarButton(
                    icon: Icons.delete_sweep,
                    label: 'مسح الجدول',
                    color: Colors.red.shade700,
                    onTap: () {
                      Navigator.pop(context);
                      _clearDutySchedule();
                    },
                  )),
                ]),
                const SizedBox(height: 8),
              ],
            )),
          ]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final teachersAsync = ref.watch(_teachersProvider(widget.schoolId));
    final dutyAsync = ref.watch(_dutyScheduleProvider(widget.schoolId));

    return Stack(
      children: [
        Column(
          children: [
            // شريط أدوات مضغوط — للإدارة فقط
            if (widget.canEdit) Container(
              color: const Color(0xFFF0F4FF),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(children: [
                const Icon(Icons.swap_horiz_rounded, color: _kPrimary, size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text('جدول المناوبة',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: _kPrimary)),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final teachers = teachersAsync.value ?? [];
                    _showDutyManagementSheet(context, teachers);
                  },
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('إدارة', style: TextStyle(fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                ),
              ]),
            ),
            if (!widget.canEdit) _ReadOnlyBanner(),
            const Divider(height: 1),
            // Duty schedule list
            Expanded(
              child: dutyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('خطأ: $e')),
                data: (weeks) {
                  // للمعلم: أظهر فقط الأسابيع التي فيها مناوبة له
                  if (!widget.canEdit) {
                    final myId = ref.read(authStateProvider).value?.id ?? '';
                    final myWeeks = weeks.map((w) {
                      final myAssignments = w.assignments
                          .where((a) => a.teacherId == myId)
                          .toList();
                      if (myAssignments.isEmpty) return null;
                      return DutyWeek(
                        id: w.id,
                        weekStart: w.weekStart,
                        weekEnd: w.weekEnd,
                        weekIndex: w.weekIndex,
                        totalWeeks: w.totalWeeks,
                        durationLabel: w.durationLabel,
                        assignments: myAssignments,
                      );
                    }).whereType<DutyWeek>().toList();

                    if (myWeeks.isEmpty) {
                      return Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.swap_horiz_rounded, size: 56, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text('لا توجد مناوبات مُعيَّنة لك حالياً',
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
                        const SizedBox(height: 6),
                        Text('سيظهر هنا جدول مناوباتك عند تعيينه من الإدارة',
                            style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                      ]));
                    }
                    return _DutyWeekList(weeks: myWeeks);
                  }
                  return _DutyWeekList(weeks: weeks);
                },
              ),
            ),
          ],
        ),
        if (_loading)
          const Positioned.fill(
            child: ColoredBox(
              color: Color(0x55000000),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Duration Option Model & Button
// ─────────────────────────────────────────────
class _DurationOption {
  final String label;
  final int weeks;
  const _DurationOption({required this.label, required this.weeks});
}

class _DurationOptionButton extends StatelessWidget {
  final _DurationOption option;
  final VoidCallback onTap;

  const _DurationOptionButton({required this.option, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.auto_awesome, size: 15),
      label: Text(option.label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kPrimary,
        side: const BorderSide(color: _kPrimary),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
// ─────────────────────────────────────────────
// Section Header — مساعد لـ BottomSheet
// ─────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 17),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: color)),
          if (subtitle.isNotEmpty)
            Text(subtitle, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        ],
      )),
    ]);
  }
}

// ─────────────────────────────────────────────
// Duty Week List
// ─────────────────────────────────────────────
class _DutyWeekList extends StatelessWidget {
  final List<DutyWeek> weeks;
  const _DutyWeekList({required this.weeks});

  @override
  Widget build(BuildContext context) {
    if (weeks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.swap_horiz, size: 64, color: Colors.grey.shade300),
            const SizedBox(height: 12),
            Text(
              'لا يوجد جدول مناوبة بعد',
              style: TextStyle(color: Colors.grey.shade500, fontSize: 16),
            ),
            const SizedBox(height: 6),
            Text(
              'اختر مدة التوزيع أو استورد من Excel',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    final fmt = DateFormat('dd/MM/yyyy', 'ar');

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: weeks.length,
      itemBuilder: (context, index) {
        final week = weeks[index];
        final weekLabel = week.weekIndex != null && week.totalWeeks != null
            ? 'الأسبوع ${week.weekIndex} من ${week.totalWeeks}'
            : 'الأسبوع ${index + 1}';
        final dateRange =
            '${fmt.format(week.weekStart)} – ${fmt.format(week.weekEnd)}';

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          elevation: 1,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 4,
            ),
            leading: CircleAvatar(
              backgroundColor: _kAccent,
              radius: 18,
              child: Text(
                '${week.weekIndex ?? index + 1}',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
            title: Text(
              weekLabel,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateRange,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
                if (week.durationLabel != null)
                  Text(
                    week.durationLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      color: _kPrimary.withOpacity(0.7),
                    ),
                  ),
              ],
            ),
            children: week.assignments.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text(
                        'لا توجد تعيينات',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ]
                : week.assignments.map((a) => _DutyAssignmentTile(a)).toList(),
          ),
        );
      },
    );
  }
}

class _DutyAssignmentTile extends StatelessWidget {
  final DutyAssignment assignment;
  const _DutyAssignmentTile(this.assignment);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      leading: Container(
        width: 70,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: _kPrimary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          assignment.day,
          style: TextStyle(
            fontSize: 12,
            color: _kPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      title: Text(
        assignment.teacherName,
        style: const TextStyle(fontSize: 13),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Manual Duty Input Dialog — إدخال يدوي للمناوبة
// ─────────────────────────────────────────────
class _ManualDutyInputDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final List<Map<String, dynamic>> teachers;
  final _DurationOption option;

  const _ManualDutyInputDialog({
    required this.schoolId,
    required this.teachers,
    required this.option,
  });

  @override
  ConsumerState<_ManualDutyInputDialog> createState() =>
      _ManualDutyInputDialogState();
}

class _ManualDutyInputDialogState
    extends ConsumerState<_ManualDutyInputDialog> {
  // weekIndex -> dayName -> teacherId
  late final Map<int, Map<String, String?>> _selections;
  bool _saving = false;
  late final DateTime _weekStart;
  late final int _totalWeeks;

  @override
  void initState() {
    super.initState();
    _totalWeeks = widget.option.weeks;
    final now = DateTime.now();
    final daysToSunday = now.weekday % 7;
    final sunday = now.subtract(Duration(days: daysToSunday));
    _weekStart = DateTime(sunday.year, sunday.month, sunday.day);

    // تهيئة الخريطة: كل أسبوع × كل يوم = null
    _selections = {
      for (int w = 0; w < _totalWeeks; w++)
        w: {for (final d in _kDays) d: null},
    };
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 640,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.88,
        ),
        child: Column(children: [
          // ── Header ──
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.purple.shade800, Colors.purple.shade600],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(children: [
              const Icon(Icons.edit_note_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('إدخال يدوي — ${widget.option.label}',
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('$_totalWeeks أسبوع × 5 أيام = ${_totalWeeks * 5} خلية',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
              ])),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: Colors.white70),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),

          // ── Content ──
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Column(children: [
              // تعليمات
              Container(
                padding: const EdgeInsets.all(10),
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.purple.shade200),
                ),
                child: Row(children: [
                  Icon(Icons.info_outline_rounded, color: Colors.purple.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(
                    'اختر معلم المناوبة لكل يوم في كل أسبوع. يمكنك ترك الخلية فارغة.',
                    style: TextStyle(color: Colors.purple.shade700, fontSize: 12),
                  )),
                ]),
              ),

              // الأسابيع
              ...List.generate(_totalWeeks, (w) {
                final wStart = _weekStart.add(Duration(days: w * 7));
                final wEnd = wStart.add(const Duration(days: 4));
                final fmt = DateFormat('dd/MM');
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE0E7EF)),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 6, offset: const Offset(0, 2))],
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    // رأس الأسبوع
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade700,
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                      ),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text('${w + 1}/$_totalWeeks',
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 10),
                        Text('الأسبوع ${w + 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700)),
                        const Spacer(),
                        Text('${fmt.format(wStart)} — ${fmt.format(wEnd)}',
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11)),
                      ]),
                    ),
                    // الأيام
                    Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(children: _kDays.asMap().entries.map((e) {
                        final dayIdx = e.key;
                        final day = e.value;
                        final dayDate = wStart.add(Duration(days: dayIdx));
                        final selectedId = _selections[w]![day];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: selectedId != null ? Colors.purple.shade50 : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: selectedId != null ? Colors.purple.shade300 : const Color(0xFFE0E7EF),
                            ),
                          ),
                          child: Row(children: [
                            // اليوم والتاريخ
                            SizedBox(width: 90, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(day, style: TextStyle(
                                color: Colors.purple.shade700,
                                fontSize: 13, fontWeight: FontWeight.w700,
                              )),
                              Text(DateFormat('dd/MM').format(dayDate),
                                  style: const TextStyle(color: Colors.grey, fontSize: 10)),
                            ])),
                            const SizedBox(width: 10),
                            // Dropdown المعلم
                            Expanded(child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.purple.shade200),
                              ),
                              child: DropdownButtonHideUnderline(child: DropdownButton<String>(
                                value: selectedId,
                                isExpanded: true,
                                hint: Text('اختر المعلم',
                                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                items: [
                                  const DropdownMenuItem<String>(
                                    value: null,
                                    child: Text('— بدون مناوبة —', style: TextStyle(fontSize: 12)),
                                  ),
                                  ...widget.teachers.map((t) => DropdownMenuItem<String>(
                                    value: t['id']?.toString(),
                                    child: Text(t['name']?.toString() ?? '',
                                        style: const TextStyle(fontSize: 12)),
                                  )),
                                ],
                                onChanged: (v) => setState(() => _selections[w]![day] = v),
                              )),
                            )),
                            // مؤشر الاختيار
                            if (selectedId != null) ...[
                              const SizedBox(width: 8),
                              Icon(Icons.check_circle_rounded, color: Colors.purple.shade600, size: 18),
                            ],
                          ]),
                        );
                      }).toList()),
                    ),
                  ]),
                );
              }),
            ]),
          )),

          // ── Actions ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(children: [
              // إحصاء الخلايا المملوءة
              Expanded(child: Text(
                '${_countFilled()} / ${_totalWeeks * 5} يوم مملوء',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              )),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('إلغاء'),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.save_rounded, size: 18),
                label: Text('حفظ ${_totalWeeks > 1 ? "$_totalWeeks أسابيع" : "الأسبوع"}'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  int _countFilled() {
    int count = 0;
    for (final week in _selections.values) {
      for (final v in week.values) {
        if (v != null) count++;
      }
    }
    return count;
  }

  Future<void> _save() async {
    if (_countFilled() == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ يرجى تحديد معلم لمناوبة يوم واحد على الأقل'),
            backgroundColor: Colors.orange));
      return;
    }

    setState(() => _saving = true);
    try {
      final uuid = const Uuid();
      final batch = FirebaseFirestore.instance.batch();
      final col = FirebaseFirestore.instance
          .collection('Schools')
          .doc(widget.schoolId)
          .collection('DutySchedule');

      for (int w = 0; w < _totalWeeks; w++) {
        final wStart = _weekStart.add(Duration(days: w * 7));
        final wEnd = wStart.add(const Duration(days: 4));
        final dayMap = _selections[w]!;

        final assignments = <Map<String, dynamic>>[];
        for (final day in _kDays) {
          final tid = dayMap[day];
          if (tid == null) continue;
          final teacher = widget.teachers.firstWhere(
            (t) => t['id']?.toString() == tid,
            orElse: () => {},
          );
          if (teacher.isEmpty) continue;
          assignments.add({
            'id': uuid.v4(),
            'day': day,
            'teacherId': tid,
            'teacherName': teacher['name']?.toString() ?? '',
            'weekIndex': w + 1,
          });
        }

        if (assignments.isEmpty) continue;

        batch.set(col.doc(), {
          'weekStart': DateFormat('yyyy-MM-dd').format(wStart),
          'weekEnd': DateFormat('yyyy-MM-dd').format(wEnd),
          'assignments': assignments,
          'weekIndex': w + 1,
          'totalWeeks': _totalWeeks,
          'durationLabel': widget.option.label,
          'inputMode': 'manual',
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();

      // جدولة إشعارات الأسبوع الأول
      final firstWeek = _selections[0]!;
      for (int i = 0; i < _kDays.length; i++) {
        final day = _kDays[i];
        final tid = firstWeek[day];
        if (tid == null) continue;
        final teacher = widget.teachers.firstWhere(
          (t) => t['id']?.toString() == tid, orElse: () => {});
        if (teacher.isEmpty) continue;
        final dutyDate = _weekStart.add(Duration(days: i));
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(widget.schoolId)
            .collection('ScheduledNotifications')
            .add({
          'userId': tid,
          'teacherName': teacher['name'],
          'title': '📋 تذكير: مناوبتك غداً',
          'body': 'مرحباً ${teacher['name']}، تذكير بأن غداً ($day) هو يوم مناوبتك.',
          'type': 'duty_reminder',
          'scheduledFor': Timestamp.fromDate(dutyDate.subtract(const Duration(days: 1))),
          'dutyDate': DateFormat('yyyy-MM-dd').format(dutyDate),
          'dutyDay': day,
          'isSent': false,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('✅ تم حفظ ${_countFilled()} يوم مناوبة يدوياً'),
          backgroundColor: Colors.purple.shade700,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ خطأ: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}
