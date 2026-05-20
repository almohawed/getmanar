import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../../../core/utils/web_utils.dart';
import '../../../../core/domain/models/user.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../maintenance/data/firestore_maintenance_repository.dart';
import '../../../maintenance/domain/models/maintenance_report.dart';
import '../../../maintenance/presentation/maintenance_widgets.dart';
import '../../../safety/data/firestore_safety_repository.dart';

String _dateKey(DateTime dt) => DateFormat('yyyy-MM-dd').format(dt);

DateTime? _asDateTime(dynamic v) {
  if (v == null) return null;
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  return null;
}

String _asString(dynamic v) => (v ?? '').toString().trim();

int _asInt(dynamic v) {
  if (v == null) return 0;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString()) ?? 0;
}

bool _asBool(dynamic v) {
  if (v == null) return false;
  if (v is bool) return v;
  final s = v.toString().trim().toLowerCase();
  return s == 'true' || s == '1' || s == 'yes' || s == 'نعم';
}

CollectionReference<Map<String, dynamic>> _schoolSubCollection(
  String schoolId,
  String name,
) {
  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection(name);
}

Stream<List<Map<String, dynamic>>> _watchCollection(
  String schoolId,
  String name, {
  int limit = 200,
}) {
  return _schoolSubCollection(
    schoolId,
    name,
  ).orderBy('createdAt', descending: true).limit(limit).snapshots().map((snap) {
    return snap.docs.map((d) {
      final data = d.data();
      return {...data, 'id': d.id};
    }).toList();
  });
}

final schoolMailItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'MailItems');
});

final schoolCircularsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'Circulars');
});

final schoolSignaturesStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'SignaturesLog');
});

final staffAttendanceTodayStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  final today = _dateKey(DateTime.now());
  return _schoolSubCollection(schoolId, 'StaffAttendance')
      .where('dateKey', isEqualTo: today)
      .orderBy('createdAt', descending: true)
      .limit(300)
      .snapshots()
      .map((snap) {
    return snap.docs.map((d) {
      final data = d.data();
      return {...data, 'id': d.id};
    }).toList();
  });
});

final schoolTeachersStreamProvider =
    StreamProvider.autoDispose<List<User>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();

  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Teachers')
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .map((doc) {
          try {
            final data = doc.data();
            data['id'] = doc.id;
            data['schoolId'] =
                (data['schoolId'] ?? '').toString().trim().isEmpty
                    ? schoolId
                    : data['schoolId'];
            return User.fromMap(data);
          } catch (e) {
            return null;
          }
        })
        .where((u) => u != null)
        .cast<User>()
        .toList();
  });
});

final safetyDrillsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'SafetyDrills');
});

final safetyExtinguishersStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'Extinguishers');
});

final safetyEmergencyExitsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'EmergencyExits');
});

final mailOpenCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(schoolMailItemsStreamProvider).value ?? const [];
  return items.where((m) => _asString(m['status']) != 'closed').length;
});

final unsignedCircularsCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(schoolCircularsStreamProvider).value ?? const [];
  return items.where((c) => !_asBool(c['isSigned'])).length;
});

final staffAttendanceIssuesCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(staffAttendanceTodayStreamProvider).value ?? const [];
  return items.where((r) {
    final s = _asString(r['status']).toLowerCase();
    return s == 'absent' || s == 'late' || s == 'غائب' || s == 'متأخر';
  }).length;
});

final safetyDrillsOverdueFlagProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(safetyDrillsStreamProvider).value ?? const [];
  final dates = items
      .map(
        (d) => _asDateTime(d['drillDate'] ?? d['date'] ?? d['createdAt']),
      )
      .whereType<DateTime>()
      .toList()
    ..sort((a, b) => b.compareTo(a));
  if (dates.isEmpty) return 1;
  final last = dates.first;
  final days = DateTime.now().difference(last).inDays;
  return days > 90 ? 1 : 0;
});

final expiredExtinguishersCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(safetyExtinguishersStreamProvider).value ?? const [];
  final now = DateTime.now();
  return items.where((e) {
    final exp = _asDateTime(e['expiryDate']);
    if (exp == null) return false;
    return exp.isBefore(now);
  }).length;
});

final blockedExitsCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(safetyEmergencyExitsStreamProvider).value ?? const [];
  return items.where((e) {
    final s = _asString(e['status']).toLowerCase();
    return s == 'blocked' || s == 'محجوب' || s == 'مغلق';
  }).length;
});

final evacuationPlanMissingFlagProvider = Provider.autoDispose<int>((ref) {
  final settings = ref.watch(safetySettingsProvider).value;
  final ok = (settings?.meetingPoint.trim().isNotEmpty ?? false) &&
      (settings?.evacuationOfficer.trim().isNotEmpty ?? false);
  return ok ? 0 : 1;
});

final healthRulesChecksStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'HealthRulesChecks', limit: 400);
});

final canteenChecksStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'CanteenChecks', limit: 400);
});

final observationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'Observations', limit: 400);
});

final healthIssuesCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(healthRulesChecksStreamProvider).value ?? const [];
  return items
      .where((r) => _asString(r['status']).toLowerCase() == 'issue')
      .length;
});

final openObservationsCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(observationsStreamProvider).value ?? const [];
  return items
      .where((o) => _asString(o['status']).toLowerCase() != 'closed')
      .length;
});

final inventoryItemsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'InventoryItems', limit: 800);
});

final materialRequestsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'MaterialRequests', limit: 400);
});

final damageReportsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'DamageReports', limit: 400);
});

final handoverLogsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return _watchCollection(schoolId, 'HandoverLogs', limit: 400);
});

final lowStockCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(inventoryItemsStreamProvider).value ?? const [];
  return items.where((i) {
    final qty = _asInt(i['quantity']);
    final min = _asInt(i['minQuantity']);
    if (min <= 0) return false;
    return qty <= min;
  }).length;
});

final openMaterialRequestsCountProvider = Provider.autoDispose<int>((ref) {
  final items = ref.watch(materialRequestsStreamProvider).value ?? const [];
  return items.where((r) {
    final s = _asString(r['status']).toLowerCase();
    return s != 'closed' && s != 'received' && s != 'rejected';
  }).length;
});

// ==============================================================================
// 1. School Admin Module
// ==============================================================================
class SchoolAdminModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const SchoolAdminModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final now = DateTime.now();
    bool isThisMonth(DateTime? dt) =>
        dt != null && dt.year == now.year && dt.month == now.month;

    final mailItems =
        ref.watch(schoolMailItemsStreamProvider).value ?? const [];
    final circulars =
        ref.watch(schoolCircularsStreamProvider).value ?? const [];
    final signatures =
        ref.watch(schoolSignaturesStreamProvider).value ?? const [];

    String title;
    String description;
    IconData icon;
    MaterialColor color;
    switch (initialIndex) {
      case 1:
        title = 'أرشفة التعاميم';
        description =
            'تنظيم التعاميم الواردة والصادرة وأرشفتها في سجل إلكتروني منظم.';
        icon = Icons.folder;
        color = Colors.indigo;
        break;
      case 2:
        title = 'سجل التوقيعات';
        description =
            'متابعة توقيعات استلام التعاميم والخطابات والقرارات الإدارية.';
        icon = Icons.draw;
        color = Colors.teal;
        break;
      case 3:
        title = 'تصدير التقارير';
        description =
            'تجهيز تقارير رسمية يمكن مشاركتها مع إدارة التعليم أو الجهات الرقابية.';
        icon = Icons.picture_as_pdf;
        color = Colors.blueGrey;
        break;
      case 0:
      default:
        title = 'الصادر والوارد';
        description =
            'إدارة البريد الإداري للمدرسة: ما يصدر منها وما يرد إليها من معاملات.';
        icon = Icons.email;
        color = Colors.teal;
        break;
    }

    final unsignedCircularsCount =
        circulars.where((c) => !_asBool(c['isSigned'])).length;
    final signedCircularsCount =
        circulars.where((c) => _asBool(c['isSigned'])).length;

    final mailInThisMonth = mailItems.where((m) {
      final dt = _asDateTime(m['date']) ?? _asDateTime(m['createdAt']);
      return isThisMonth(dt) && _asString(m['direction']) != 'out';
    }).length;
    final mailOutThisMonth = mailItems.where((m) {
      final dt = _asDateTime(m['date']) ?? _asDateTime(m['createdAt']);
      return isThisMonth(dt) && _asString(m['direction']) == 'out';
    }).length;
    final mailOpenCount = mailItems
        .where((m) => _asString(m['status']).toLowerCase() != 'closed')
        .length;

    final signaturesThisMonth = signatures.where((s) {
      final dt = _asDateTime(s['signedAt']) ?? _asDateTime(s['createdAt']);
      return isThisMonth(dt);
    }).length;

    Future<void> addMailItem() async {
      if (schoolId.isEmpty) return;
      final direction = ValueNotifier<String>('in');
      final status = ValueNotifier<String>('open');
      DateTime selectedDate = DateTime.now();
      final subjectCtrl = TextEditingController();
      final refNoCtrl = TextEditingController();
      final fromToCtrl = TextEditingController();
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('إضافة معاملة'),
                content: SizedBox(
                  width: 420.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: direction.value,
                          items: const [
                            DropdownMenuItem(value: 'in', child: Text('وارد')),
                            DropdownMenuItem(value: 'out', child: Text('صادر')),
                          ],
                          onChanged: (v) => setState(() {
                            direction.value = v ?? 'in';
                          }),
                          decoration: const InputDecoration(labelText: 'النوع'),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: subjectCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموضوع',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: refNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رقم المعاملة (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: fromToCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الجهة (وارد من / صادر إلى)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: status.value,
                          items: const [
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('مفتوحة'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('مغلقة'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            status.value = v ?? 'open';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ المعاملة'),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                          ),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;

      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'MailItems').doc(id).set({
        'direction': direction.value,
        'subject': subjectCtrl.text.trim(),
        'refNo': refNoCtrl.text.trim(),
        'counterparty': fromToCtrl.text.trim(),
        'status': status.value,
        'date': Timestamp.fromDate(selectedDate),
        'dateKey': _dateKey(selectedDate),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
        'notes': notesCtrl.text.trim(),
      });
    }

    Future<void> addCircular() async {
      if (schoolId.isEmpty) return;
      DateTime selectedDate = DateTime.now();
      final titleCtrl = TextEditingController();
      final refNoCtrl = TextEditingController();
      final sourceCtrl = TextEditingController();
      final requiresSignature = ValueNotifier<bool>(true);

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('إضافة تعميم'),
                content: SizedBox(
                  width: 420.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'عنوان التعميم',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: refNoCtrl,
                          decoration: const InputDecoration(
                            labelText: 'رقم التعميم (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: sourceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الجهة المصدرة (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        SwitchListTile(
                          value: requiresSignature.value,
                          title: const Text('يتطلب توقيع/إقرار'),
                          onChanged: (v) =>
                              setState(() => requiresSignature.value = v),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ التعميم'),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(selectedDate),
                          ),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: selectedDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => selectedDate = picked);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;

      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'Circulars').doc(id).set({
        'title': titleCtrl.text.trim(),
        'refNo': refNoCtrl.text.trim(),
        'source': sourceCtrl.text.trim(),
        'date': Timestamp.fromDate(selectedDate),
        'dateKey': _dateKey(selectedDate),
        'requiresSignature': requiresSignature.value,
        'isSigned': false,
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> addSignatureRecord() async {
      if (schoolId.isEmpty) return;
      final nameCtrl = TextEditingController(text: user?.name ?? '');
      final typeCtrl = TextEditingController(text: 'تعميم');
      final refCtrl = TextEditingController();
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('تسجيل توقيع'),
            content: SizedBox(
              width: 420.w,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'اسم الموقّع',
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: typeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'نوع المستند',
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'مرجع/رقم المستند',
                      ),
                    ),
                    SizedBox(height: 8.h),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ملاحظات (اختياري)',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('إلغاء'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('حفظ'),
              ),
            ],
          );
        },
      );

      if (ok != true) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'SignaturesLog').doc(id).set({
        'signerName': nameCtrl.text.trim(),
        'signerId': user?.id,
        'documentType': typeCtrl.text.trim(),
        'documentRef': refCtrl.text.trim(),
        'notes': notesCtrl.text.trim(),
        'signedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> markCircularSigned(Map<String, dynamic> circular) async {
      if (schoolId.isEmpty) return;
      final cid = _asString(circular['id']);
      if (cid.isEmpty) return;
      await _schoolSubCollection(schoolId, 'Circulars').doc(cid).set({
        'isSigned': true,
        'signedAt': FieldValue.serverTimestamp(),
        'signedById': user?.id,
        'signedByName': user?.name,
      }, SetOptions(merge: true));

      final sigId = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'SignaturesLog').doc(sigId).set({
        'signerName': user?.name ?? '',
        'signerId': user?.id,
        'documentType': 'تعميم',
        'documentRef': _asString(circular['refNo']).isEmpty
            ? _asString(circular['title'])
            : _asString(circular['refNo']),
        'circularId': cid,
        'signedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    String toCsv(List<List<String>> rows) {
      String esc(String s) => '"${s.replaceAll('"', '""')}"';
      return rows.map((r) => r.map(esc).join(',')).join('\n');
    }

    Future<void> exportMailCsv() async {
      final rows = <List<String>>[
        ['التاريخ', 'النوع', 'رقم', 'الموضوع', 'الجهة', 'الحالة'],
      ];
      for (final m in mailItems) {
        final dt = _asDateTime(m['date']) ?? _asDateTime(m['createdAt']);
        final dateStr = dt == null ? '' : DateFormat('yyyy-MM-dd').format(dt);
        rows.add([
          dateStr,
          _asString(m['direction']) == 'out' ? 'صادر' : 'وارد',
          _asString(m['refNo']),
          _asString(m['subject']),
          _asString(m['counterparty']),
          _asString(m['status']) == 'closed' ? 'مغلقة' : 'مفتوحة',
        ]);
      }
      downloadWebTextFile(
        "mail_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv",
        toCsv(rows),
        mimeType: 'text/csv;charset=utf-8',
      );
    }

    Future<void> exportCircularsCsv() async {
      final rows = <List<String>>[
        ['التاريخ', 'رقم', 'العنوان', 'الجهة', 'يتطلب توقيع', 'تم التوقيع'],
      ];
      for (final c in circulars) {
        final dt = _asDateTime(c['date']) ?? _asDateTime(c['createdAt']);
        final dateStr = dt == null ? '' : DateFormat('yyyy-MM-dd').format(dt);
        rows.add([
          dateStr,
          _asString(c['refNo']),
          _asString(c['title']),
          _asString(c['source']),
          _asBool(c['requiresSignature']) ? 'نعم' : 'لا',
          _asBool(c['isSigned']) ? 'نعم' : 'لا',
        ]);
      }
      downloadWebTextFile(
        "circulars_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv",
        toCsv(rows),
        mimeType: 'text/csv;charset=utf-8',
      );
    }

    Future<void> exportSignaturesCsv() async {
      final rows = <List<String>>[
        ['التاريخ', 'الموقّع', 'نوع المستند', 'المرجع', 'ملاحظات'],
      ];
      for (final s in signatures) {
        final dt = _asDateTime(s['signedAt']) ?? _asDateTime(s['createdAt']);
        final dateStr = dt == null ? '' : DateFormat('yyyy-MM-dd').format(dt);
        rows.add([
          dateStr,
          _asString(s['signerName']),
          _asString(s['documentType']),
          _asString(s['documentRef']),
          _asString(s['notes']),
        ]);
      }
      downloadWebTextFile(
        "signatures_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.csv",
        toCsv(rows),
        mimeType: 'text/csv;charset=utf-8',
      );
    }

    final recs = <String>[
      if (initialIndex == 0 && mailOpenCount > 0)
        'راجع المعاملات المفتوحة أسبوعيًا لضمان سرعة الإنجاز وتوثيق الإغلاق.',
      if (initialIndex == 1 && unsignedCircularsCount > 0)
        'يوصى بإغلاق التعاميم التي تتطلب توقيع خلال 48 ساعة وتحويل غير المكتمل للمتابعة.',
      if (initialIndex == 2 && signaturesThisMonth == 0)
        'سجل التوقيعات لهذا الشهر فارغ؛ تأكد من توثيق التوقيعات للامتثال الرقابي.',
      if (initialIndex == 3)
        'صدّر التقارير بشكل دوري واحتفظ بنسخة شهرية ضمن أرشيف المدرسة.',
    ];

    Widget recommendationsCard() {
      if (recs.isEmpty) return const SizedBox.shrink();
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توصيات ذكية',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 8.h),
              ...recs.map(
                (t) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: color.shade700, size: 18),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade800,
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
      );
    }

    final fab = schoolId.isEmpty
        ? null
        : (initialIndex == 0
            ? FloatingActionButton.extended(
                onPressed: addMailItem,
                icon: const Icon(Icons.add),
                label: const Text('إضافة'),
              )
            : initialIndex == 1
                ? FloatingActionButton.extended(
                    onPressed: addCircular,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة'),
                  )
                : initialIndex == 2
                    ? FloatingActionButton.extended(
                        onPressed: addSignatureRecord,
                        icon: const Icon(Icons.add),
                        label: const Text('تسجيل'),
                      )
                    : null);
    return UnifiedPageScaffold(
      requiredDeputyType: 'school',
      showAppBar: false,
      title: title,
      floatingActionButton: fab,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SchoolModuleHeader(
                title: title,
                description: description,
                icon: icon,
                color: color,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _SchoolMetricCard(
                      label: initialIndex == 0
                          ? 'وارد هذا الشهر'
                          : initialIndex == 1
                              ? 'تعاميم هذا الشهر'
                              : initialIndex == 2
                                  ? 'توقيعات هذا الشهر'
                                  : 'الصادر والوارد',
                      value: initialIndex == 0
                          ? mailInThisMonth.toString()
                          : initialIndex == 1
                              ? circulars
                                  .where((c) {
                                    final dt = _asDateTime(c['date']) ??
                                        _asDateTime(c['createdAt']);
                                    return isThisMonth(dt);
                                  })
                                  .length
                                  .toString()
                              : initialIndex == 2
                                  ? signaturesThisMonth.toString()
                                  : mailItems.length.toString(),
                      icon: initialIndex == 0
                          ? Icons.inbox
                          : initialIndex == 1
                              ? Icons.folder
                              : initialIndex == 2
                                  ? Icons.draw
                                  : Icons.analytics,
                      color: color.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label: initialIndex == 0
                          ? 'صادر هذا الشهر'
                          : initialIndex == 1
                              ? 'بانتظار التوقيع'
                              : initialIndex == 2
                                  ? 'إجمالي التوقيعات'
                                  : 'التعاميم',
                      value: initialIndex == 0
                          ? mailOutThisMonth.toString()
                          : initialIndex == 1
                              ? unsignedCircularsCount.toString()
                              : initialIndex == 2
                                  ? signatures.length.toString()
                                  : circulars.length.toString(),
                      icon: initialIndex == 0
                          ? Icons.outbox
                          : initialIndex == 1
                              ? Icons.pending_actions
                              : initialIndex == 2
                                  ? Icons.rule
                                  : Icons.folder,
                      color: initialIndex == 1 && unsignedCircularsCount > 0
                          ? Colors.orange.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label: initialIndex == 0
                          ? 'معاملات مفتوحة'
                          : initialIndex == 1
                              ? 'موقعة'
                              : initialIndex == 2
                                  ? 'آخر توقيع'
                                  : 'سجل التوقيعات',
                      value: initialIndex == 0
                          ? mailOpenCount.toString()
                          : initialIndex == 1
                              ? signedCircularsCount.toString()
                              : initialIndex == 2
                                  ? (() {
                                      final dt = signatures.isEmpty
                                          ? null
                                          : (_asDateTime(
                                                signatures.first['signedAt'],
                                              ) ??
                                              _asDateTime(
                                                signatures.first['createdAt'],
                                              ));
                                      return dt == null
                                          ? '—'
                                          : DateFormat('MM/dd').format(dt);
                                    })()
                                  : signatures.length.toString(),
                      icon: initialIndex == 0
                          ? Icons.assignment_late
                          : initialIndex == 1
                              ? Icons.check_circle
                              : initialIndex == 2
                                  ? Icons.event_available
                                  : Icons.draw,
                      color: initialIndex == 0 && mailOpenCount > 0
                          ? Colors.orange.shade700
                          : Colors.blueGrey.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (recs.isNotEmpty) ...[
                recommendationsCard(),
                SizedBox(height: 16.h),
              ],
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Builder(
                      builder: (context) {
                        if (schoolId.isEmpty) {
                          return Center(
                            child: Text(
                              'لا يمكن عرض البيانات بدون مدرسة مرتبطة بالحساب.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        if (initialIndex == 3) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'تصدير سريع',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Wrap(
                                spacing: 12.w,
                                runSpacing: 12.h,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: mailItems.isEmpty
                                        ? null
                                        : exportMailCsv,
                                    icon: const Icon(Icons.download),
                                    label: const Text('الصادر والوارد CSV'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: circulars.isEmpty
                                        ? null
                                        : exportCircularsCsv,
                                    icon: const Icon(Icons.download),
                                    label: const Text('التعاميم CSV'),
                                  ),
                                  ElevatedButton.icon(
                                    onPressed: signatures.isEmpty
                                        ? null
                                        : exportSignaturesCsv,
                                    icon: const Icon(Icons.download),
                                    label: const Text('التوقيعات CSV'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16.h),
                              Expanded(
                                child: ListView(
                                  children: [
                                    ListTile(
                                      leading: const Icon(Icons.inbox),
                                      title: const Text('الصادر والوارد'),
                                      subtitle: Text(
                                        'إجمالي السجلات: ${mailItems.length}',
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.folder),
                                      title: const Text('التعاميم'),
                                      subtitle: Text(
                                        'بانتظار التوقيع: $unsignedCircularsCount',
                                      ),
                                    ),
                                    ListTile(
                                      leading: const Icon(Icons.draw),
                                      title: const Text('سجل التوقيعات'),
                                      subtitle: Text(
                                        'إجمالي التوقيعات: ${signatures.length}',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        final list = initialIndex == 0
                            ? mailItems
                            : initialIndex == 1
                                ? circulars
                                : signatures;
                        final emptyMsg = initialIndex == 0
                            ? 'لم يتم تسجيل معاملات حتى الآن.'
                            : initialIndex == 1
                                ? 'لا توجد تعاميم مؤرشفة حتى الآن.'
                                : 'لا توجد توقيعات مسجلة حتى الآن.';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              initialIndex == 0
                                  ? 'آخر المعاملات'
                                  : initialIndex == 1
                                      ? 'آخر التعاميم'
                                      : 'آخر التوقيعات',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Expanded(
                              child: list.isEmpty
                                  ? Center(
                                      child: Text(
                                        emptyMsg,
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: list.length.clamp(0, 40),
                                      separatorBuilder: (_, __) => Divider(
                                        height: 12.h,
                                        color: Colors.grey.shade200,
                                      ),
                                      itemBuilder: (context, index) {
                                        final item = list[index];

                                        if (initialIndex == 0) {
                                          final dt = _asDateTime(
                                                  item['date']) ??
                                              _asDateTime(item['createdAt']);
                                          final dateStr = dt == null
                                              ? ''
                                              : DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(dt);
                                          final direction =
                                              _asString(item['direction']) ==
                                                      'out'
                                                  ? 'صادر'
                                                  : 'وارد';
                                          final statusLabel =
                                              _asString(item['status']) ==
                                                      'closed'
                                                  ? 'مغلقة'
                                                  : 'مفتوحة';
                                          final statusColor =
                                              statusLabel == 'مفتوحة'
                                                  ? Colors.orange.shade700
                                                  : Colors.green.shade700;
                                          return Row(
                                            children: [
                                              Container(
                                                width: 36.w,
                                                height: 36.w,
                                                decoration: BoxDecoration(
                                                  color: color.shade50
                                                      .withValues(alpha: 0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12.r,
                                                  ),
                                                ),
                                                child: Icon(
                                                  direction == 'صادر'
                                                      ? Icons.outbox
                                                      : Icons.inbox,
                                                  color: color.shade800,
                                                  size: 20.sp,
                                                ),
                                              ),
                                              SizedBox(width: 12.w),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _asString(
                                                        item['subject'],
                                                      ).isEmpty
                                                          ? '—'
                                                          : _asString(
                                                              item['subject'],
                                                            ),
                                                      style: TextStyle(
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .grey.shade900,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      [
                                                        if (dateStr.isNotEmpty)
                                                          dateStr,
                                                        direction,
                                                        _asString(
                                                          item['counterparty'],
                                                        ),
                                                      ]
                                                          .where(
                                                            (s) => s.isNotEmpty,
                                                          )
                                                          .join(' • '),
                                                      style: TextStyle(
                                                        fontSize: 11.sp,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 8.w,
                                                  vertical: 4.h,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: statusColor.withValues(
                                                    alpha: 0.08,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    16.r,
                                                  ),
                                                ),
                                                child: Text(
                                                  statusLabel,
                                                  style: TextStyle(
                                                    fontSize: 11.sp,
                                                    color: statusColor,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          );
                                        }

                                        if (initialIndex == 1) {
                                          final dt = _asDateTime(
                                                  item['date']) ??
                                              _asDateTime(item['createdAt']);
                                          final dateStr = dt == null
                                              ? ''
                                              : DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(dt);
                                          final signed = _asBool(
                                            item['isSigned'],
                                          );
                                          final requires = _asBool(
                                            item['requiresSignature'],
                                          );
                                          return Row(
                                            children: [
                                              Container(
                                                width: 36.w,
                                                height: 36.w,
                                                decoration: BoxDecoration(
                                                  color: Colors.indigo.shade50
                                                      .withValues(alpha: 0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                    12.r,
                                                  ),
                                                ),
                                                child: Icon(
                                                  Icons.folder,
                                                  color: Colors.indigo.shade800,
                                                  size: 20.sp,
                                                ),
                                              ),
                                              SizedBox(width: 12.w),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      _asString(
                                                        item['title'],
                                                      ).isEmpty
                                                          ? '—'
                                                          : _asString(
                                                              item['title'],
                                                            ),
                                                      style: TextStyle(
                                                        fontSize: 13.sp,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: Colors
                                                            .grey.shade900,
                                                      ),
                                                    ),
                                                    SizedBox(height: 4.h),
                                                    Text(
                                                      [
                                                        if (_asString(
                                                          item['refNo'],
                                                        ).isNotEmpty)
                                                          _asString(
                                                            item['refNo'],
                                                          ),
                                                        if (dateStr.isNotEmpty)
                                                          dateStr,
                                                        if (_asString(
                                                          item['source'],
                                                        ).isNotEmpty)
                                                          _asString(
                                                            item['source'],
                                                          ),
                                                      ].join(' • '),
                                                      style: TextStyle(
                                                        fontSize: 11.sp,
                                                        color: Colors
                                                            .grey.shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              SizedBox(width: 8.w),
                                              if (!signed && requires)
                                                TextButton(
                                                  onPressed: () async {
                                                    await markCircularSigned(
                                                      item,
                                                    );
                                                  },
                                                  child: const Text(
                                                    'تم التوقيع',
                                                  ),
                                                )
                                              else
                                                Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8.w,
                                                    vertical: 4.h,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: (signed
                                                            ? Colors.green
                                                            : Colors.blueGrey)
                                                        .withValues(
                                                      alpha: 0.08,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                      16.r,
                                                    ),
                                                  ),
                                                  child: Text(
                                                    signed
                                                        ? 'موقّع'
                                                        : requires
                                                            ? 'بانتظار'
                                                            : 'لا يتطلب',
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color: signed
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors.blueGrey
                                                              .shade700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          );
                                        }

                                        final dt =
                                            _asDateTime(item['signedAt']) ??
                                                _asDateTime(item['createdAt']);
                                        final dateStr = dt == null
                                            ? ''
                                            : DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(dt);
                                        return Row(
                                          children: [
                                            Container(
                                              width: 36.w,
                                              height: 36.w,
                                              decoration: BoxDecoration(
                                                color: Colors.teal.shade50
                                                    .withValues(alpha: 0.9),
                                                borderRadius:
                                                    BorderRadius.circular(12.r),
                                              ),
                                              child: Icon(
                                                Icons.draw,
                                                color: Colors.teal.shade800,
                                                size: 20.sp,
                                              ),
                                            ),
                                            SizedBox(width: 12.w),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _asString(
                                                      item['signerName'],
                                                    ).isEmpty
                                                        ? '—'
                                                        : _asString(
                                                            item['signerName'],
                                                          ),
                                                    style: TextStyle(
                                                      fontSize: 13.sp,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color:
                                                          Colors.grey.shade900,
                                                    ),
                                                  ),
                                                  SizedBox(height: 4.h),
                                                  Text(
                                                    [
                                                      if (_asString(
                                                        item['documentType'],
                                                      ).isNotEmpty)
                                                        _asString(
                                                          item['documentType'],
                                                        ),
                                                      if (_asString(
                                                        item['documentRef'],
                                                      ).isNotEmpty)
                                                        _asString(
                                                          item['documentRef'],
                                                        ),
                                                      if (dateStr.isNotEmpty)
                                                        dateStr,
                                                    ].join(' • '),
                                                    style: TextStyle(
                                                      fontSize: 11.sp,
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
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

// ==============================================================================
// 6. Services Module (General Services)
// ==============================================================================
class ServicesModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const ServicesModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final now = DateTime.now();
    bool isThisMonth(DateTime? dt) =>
        dt != null && dt.year == now.year && dt.month == now.month;

    String title;
    String description;
    IconData icon;
    MaterialColor color;

    switch (initialIndex) {
      case 1:
        title = 'ملاحظات رقابية';
        description =
            'تسجيل الملاحظات الرقابية الواردة من الزيارات الإشرافية والجهات المختصة.';
        icon = Icons.policy;
        color = Colors.blue;
        break;
      case 2:
        title = 'المقصف المدرسي';
        description =
            'متابعة المقصف المدرسي، الأصناف المتوفرة، ومستوى الالتزام بالمعايير الصحية.';
        icon = Icons.restaurant;
        color = Colors.amber;
        break;
      case 0:
      default:
        title = 'اشتراطات الصحة';
        description =
            'متابعة تطبيق الاشتراطات الصحية داخل مبنى المدرسة ومعاملها ومرافقها.';
        icon = Icons.health_and_safety;
        color = Colors.green;
        break;
    }

    final healthChecks =
        ref.watch(healthRulesChecksStreamProvider).value ?? const [];
    final canteenChecks =
        ref.watch(canteenChecksStreamProvider).value ?? const [];
    final observations =
        ref.watch(observationsStreamProvider).value ?? const [];

    int issuesThisMonth(List<Map<String, dynamic>> list) {
      return list.where((r) {
        final status = _asString(r['status']).toLowerCase();
        if (status != 'issue') return false;
        final dt = _asDateTime(r['date'] ?? r['createdAt']);
        return isThisMonth(dt);
      }).length;
    }

    int checksThisMonth(List<Map<String, dynamic>> list) {
      return list.where((r) {
        final dt = _asDateTime(r['date'] ?? r['createdAt']);
        return isThisMonth(dt);
      }).length;
    }

    int openObsCount() {
      return observations
          .where((o) => _asString(o['status']).toLowerCase() != 'closed')
          .length;
    }

    Future<void> addHealthRuleCheck({required bool isCanteen}) async {
      if (schoolId.isEmpty) return;
      DateTime date = DateTime.now();
      final areaCtrl = TextEditingController();
      final titleCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      String status = 'ok';
      String severity = 'low';

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  isCanteen ? 'تسجيل متابعة المقصف' : 'تسجيل متابعة صحية',
                ),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('التاريخ'),
                          subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: areaCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموقع/المرفق',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'البند/الملاحظة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(value: 'ok', child: Text('سليم')),
                            DropdownMenuItem(
                              value: 'issue',
                              child: Text('يوجد ملاحظة'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            status = v ?? 'ok';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: severity,
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('منخفضة'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('متوسطة'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('عالية'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            severity = v ?? 'low';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الخطورة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تفاصيل/إجراء (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final id = const Uuid().v4();
      final col = isCanteen ? 'CanteenChecks' : 'HealthRulesChecks';
      await _schoolSubCollection(schoolId, col).doc(id).set({
        'date': Timestamp.fromDate(date),
        'dateKey': _dateKey(date),
        'area': areaCtrl.text.trim(),
        'title': titleCtrl.text.trim(),
        'status': status,
        'severity': severity,
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> addObservation() async {
      if (schoolId.isEmpty) return;
      DateTime date = DateTime.now();
      final sourceCtrl = TextEditingController();
      final titleCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      String severity = 'medium';
      String status = 'open';

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('إضافة ملاحظة رقابية'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ الزيارة/الملاحظة'),
                          subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: sourceCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الجهة/المصدر (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: titleCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الملاحظة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: severity,
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('منخفضة'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('متوسطة'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('عالية'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            severity = v ?? 'medium';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الخطورة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(
                              value: 'open',
                              child: Text('مفتوحة'),
                            ),
                            DropdownMenuItem(
                              value: 'closed',
                              child: Text('مغلقة'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            status = v ?? 'open';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'إجراء/ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'Observations').doc(id).set({
        'date': Timestamp.fromDate(date),
        'dateKey': _dateKey(date),
        'source': sourceCtrl.text.trim(),
        'title': titleCtrl.text.trim(),
        'severity': severity,
        'status': status,
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> closeObservation(Map<String, dynamic> obs) async {
      if (schoolId.isEmpty) return;
      final id = _asString(obs['id']);
      if (id.isEmpty) return;
      await _schoolSubCollection(schoolId, 'Observations').doc(id).set({
        'status': 'closed',
        'closedAt': FieldValue.serverTimestamp(),
        'closedById': user?.id,
        'closedByName': user?.name,
      }, SetOptions(merge: true));
    }

    final recs = <String>[
      if (initialIndex == 0 && ref.watch(healthIssuesCountProvider) > 0)
        'عالج الملاحظات الصحية المفتوحة فورًا مع توثيق الإجراء لتقليل المخاطر.',
      if (initialIndex == 1 && openObsCount() > 0)
        'أغلق الملاحظات الرقابية بعد تنفيذ الإجراء التصحيحي وتوثيق ما تم.',
      if (initialIndex == 2 && issuesThisMonth(canteenChecks) > 0)
        'تابع التزام المقصف بالاشتراطات الصحية وحدث سجل المتابعة أسبوعيًا.',
    ];

    Widget recommendationsCard() {
      if (recs.isEmpty) return const SizedBox.shrink();
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توصيات ذكية',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 8.h),
              ...recs.map(
                (t) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: color.shade700, size: 18),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade800,
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
      );
    }

    return UnifiedPageScaffold(
      requiredDeputyType: 'school',
      showAppBar: false,
      title: title,
      floatingActionButton: schoolId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: initialIndex == 1
                  ? addObservation
                  : () => addHealthRuleCheck(isCanteen: initialIndex == 2),
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SchoolModuleHeader(
                title: title,
                description: description,
                icon: icon,
                color: color,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _SchoolMetricCard(
                      label: initialIndex == 1 ? 'مفتوحة' : 'متابعات هذا الشهر',
                      value: initialIndex == 1
                          ? openObsCount().toString()
                          : (initialIndex == 2
                                  ? checksThisMonth(canteenChecks)
                                  : checksThisMonth(healthChecks))
                              .toString(),
                      icon: initialIndex == 1
                          ? Icons.pending_actions
                          : Icons.fact_check,
                      color: initialIndex == 1 && openObsCount() > 0
                          ? Colors.orange.shade700
                          : color.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label: initialIndex == 1
                          ? 'مغلقة هذا الشهر'
                          : 'ملاحظات هذا الشهر',
                      value: initialIndex == 1
                          ? observations
                              .where((o) {
                                final dt = _asDateTime(
                                  o['date'] ?? o['createdAt'],
                                );
                                return isThisMonth(dt) &&
                                    _asString(o['status']).toLowerCase() ==
                                        'closed';
                              })
                              .length
                              .toString()
                          : (initialIndex == 2
                                  ? issuesThisMonth(canteenChecks)
                                  : issuesThisMonth(healthChecks))
                              .toString(),
                      icon:
                          initialIndex == 1 ? Icons.check_circle : Icons.report,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label:
                          initialIndex == 1 ? 'عالية الخطورة' : 'إجمالي السجل',
                      value: initialIndex == 1
                          ? observations
                              .where(
                                (o) =>
                                    _asString(o['severity']).toLowerCase() ==
                                        'high' &&
                                    _asString(o['status']).toLowerCase() !=
                                        'closed',
                              )
                              .length
                              .toString()
                          : (initialIndex == 2
                                  ? canteenChecks.length
                                  : healthChecks.length)
                              .toString(),
                      icon: initialIndex == 1
                          ? Icons.priority_high
                          : Icons.list_alt,
                      color: initialIndex == 1 &&
                              observations
                                      .where(
                                        (o) =>
                                            _asString(
                                                  o['severity'],
                                                ).toLowerCase() ==
                                                'high' &&
                                            _asString(
                                                  o['status'],
                                                ).toLowerCase() !=
                                                'closed',
                                      )
                                      .length >
                                  0
                          ? Colors.red.shade700
                          : Colors.blueGrey.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (recs.isNotEmpty) ...[
                recommendationsCard(),
                SizedBox(height: 16.h),
              ],
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Builder(
                      builder: (context) {
                        if (schoolId.isEmpty) {
                          return Center(
                            child: Text(
                              'لا يمكن عرض البيانات بدون مدرسة مرتبطة بالحساب.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        if (initialIndex == 1) {
                          return observations.isEmpty
                              ? Center(
                                  child: Text(
                                    'لا توجد ملاحظات رقابية مسجلة.',
                                    style: TextStyle(
                                      fontSize: 13.sp,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                )
                              : ListView.separated(
                                  itemCount: observations.length.clamp(0, 120),
                                  separatorBuilder: (_, __) => Divider(
                                    height: 12.h,
                                    color: Colors.grey.shade200,
                                  ),
                                  itemBuilder: (context, index) {
                                    final o = observations[index];
                                    final dt = _asDateTime(
                                      o['date'] ?? o['createdAt'],
                                    );
                                    final dateStr = dt == null
                                        ? '—'
                                        : DateFormat('yyyy-MM-dd').format(dt);
                                    final st = _asString(
                                      o['status'],
                                    ).toLowerCase();
                                    final isClosed = st == 'closed';
                                    final sev = _asString(
                                      o['severity'],
                                    ).toLowerCase();
                                    final sevLabel = sev == 'high'
                                        ? 'عالية'
                                        : sev == 'medium'
                                            ? 'متوسطة'
                                            : 'منخفضة';
                                    final sevColor = sev == 'high'
                                        ? Colors.red
                                        : sev == 'medium'
                                            ? Colors.orange
                                            : Colors.green;
                                    return ListTile(
                                      leading: CircleAvatar(
                                        backgroundColor: sevColor.withValues(
                                          alpha: 0.12,
                                        ),
                                        child: Icon(
                                          Icons.policy,
                                          color: sevColor,
                                        ),
                                      ),
                                      title: Text(
                                        _asString(o['title']).isEmpty
                                            ? '—'
                                            : _asString(o['title']),
                                      ),
                                      subtitle: Text(
                                        [
                                          dateStr,
                                          if (_asString(o['source']).isNotEmpty)
                                            _asString(o['source']),
                                          'الخطورة: $sevLabel',
                                        ].join(' • '),
                                      ),
                                      trailing: isClosed
                                          ? Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 10.w,
                                                vertical: 4.h,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Colors.green.withValues(
                                                  alpha: 0.08,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                'مغلقة',
                                                style: TextStyle(
                                                  color: Colors.green.shade700,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            )
                                          : TextButton(
                                              onPressed: () async {
                                                await closeObservation(o);
                                              },
                                              child: const Text('إغلاق'),
                                            ),
                                    );
                                  },
                                );
                        }

                        final list =
                            initialIndex == 2 ? canteenChecks : healthChecks;
                        final emptyMsg = initialIndex == 2
                            ? 'لا توجد متابعات للمقصف مسجلة.'
                            : 'لا توجد متابعات صحية مسجلة.';

                        return list.isEmpty
                            ? Center(
                                child: Text(
                                  emptyMsg,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                itemCount: list.length.clamp(0, 120),
                                separatorBuilder: (_, __) => Divider(
                                  height: 12.h,
                                  color: Colors.grey.shade200,
                                ),
                                itemBuilder: (context, index) {
                                  final r = list[index];
                                  final dt = _asDateTime(
                                    r['date'] ?? r['createdAt'],
                                  );
                                  final dateStr = dt == null
                                      ? '—'
                                      : DateFormat('yyyy-MM-dd').format(dt);
                                  final area = _asString(r['area']);
                                  final status = _asString(
                                    r['status'],
                                  ).toLowerCase();
                                  final isIssue = status == 'issue';
                                  final sev = _asString(
                                    r['severity'],
                                  ).toLowerCase();
                                  final sevLabel = sev == 'high'
                                      ? 'عالية'
                                      : sev == 'medium'
                                          ? 'متوسطة'
                                          : 'منخفضة';
                                  final colorStatus = isIssue
                                      ? (sev == 'high'
                                          ? Colors.red
                                          : sev == 'medium'
                                              ? Colors.orange
                                              : Colors.amber)
                                      : Colors.green;
                                  return ListTile(
                                    leading: CircleAvatar(
                                      backgroundColor: colorStatus.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        initialIndex == 2
                                            ? Icons.restaurant
                                            : Icons.health_and_safety,
                                        color: colorStatus,
                                      ),
                                    ),
                                    title: Text(
                                      _asString(r['title']).isEmpty
                                          ? '—'
                                          : _asString(r['title']),
                                    ),
                                    subtitle: Text(
                                      [
                                        dateStr,
                                        if (area.isNotEmpty) area,
                                        isIssue ? 'ملاحظة: $sevLabel' : 'سليم',
                                      ].join(' • '),
                                    ),
                                  );
                                },
                              );
                      },
                    ),
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

// ==============================================================================
// 2. Staff Attendance Module
// ==============================================================================
class StaffAttendanceModuleScreen extends ConsumerStatefulWidget {
  final int initialIndex;

  const StaffAttendanceModuleScreen({super.key, this.initialIndex = 0});

  @override
  ConsumerState<StaffAttendanceModuleScreen> createState() =>
      _StaffAttendanceModuleScreenState();
}

class _StaffAttendanceModuleScreenState
    extends ConsumerState<StaffAttendanceModuleScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final teachersAsync = ref.watch(schoolTeachersStreamProvider);
    final records =
        ref.watch(staffAttendanceTodayStreamProvider).value ?? const [];

    String norm(String v) => v.trim().toLowerCase();

    String statusLabel(String raw) {
      final s = norm(raw);
      if (s == 'present' || s == 'حاضر') return 'حاضر';
      if (s == 'late' || s == 'متأخر') return 'متأخر';
      if (s == 'absent' || s == 'غائب') return 'غائب';
      return raw.trim().isEmpty ? 'غير محدد' : raw.trim();
    }

    Color statusColor(String raw) {
      final s = statusLabel(raw);
      if (s == 'حاضر') return const Color(0xFF2E7D32);
      if (s == 'متأخر') return const Color(0xFFFF9800);
      if (s == 'غائب') return const Color(0xFFC62828);
      return Colors.blueGrey;
    }

    final presentCount = records
        .where((r) => statusLabel(_asString(r['status'])) == 'حاضر')
        .length;
    final lateCount = records
        .where((r) => statusLabel(_asString(r['status'])) == 'متأخر')
        .length;
    final absentCount = records
        .where((r) => statusLabel(_asString(r['status'])) == 'غائب')
        .length;

    Future<void> markTeacherAttendance(User teacher) async {
      if (schoolId.isEmpty) return;
      String status = 'present';
      DateTime? checkIn;
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(
                  'تسجيل حضور ${teacher.name}',
                  style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
                ),
                content: SizedBox(
                  width: 420.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80.w,
                          height: 80.w,
                          decoration: BoxDecoration(
                            color: Colors.indigo.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.person,
                            size: 40.r,
                            color: Colors.indigo,
                          ),
                        ),
                        SizedBox(height: 16.h),
                        Text(
                          teacher.name,
                          style: GoogleFonts.cairo(
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        SizedBox(height: 24.h),
                        DropdownButtonFormField<String>(
                          value: status,
                          decoration: InputDecoration(
                            labelText: 'الحالة',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16.w,
                              vertical: 12.h,
                            ),
                          ),
                          items: [
                            DropdownMenuItem(
                              value: 'present',
                              child: Row(
                                children: [
                                  const Icon(Icons.check_circle,
                                      color: Color(0xFF2E7D32)),
                                  SizedBox(width: 8.w),
                                  Text('حاضر', style: GoogleFonts.cairo()),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'late',
                              child: Row(
                                children: [
                                  const Icon(Icons.access_time,
                                      color: Color(0xFFFF9800)),
                                  SizedBox(width: 8.w),
                                  Text('متأخر', style: GoogleFonts.cairo()),
                                ],
                              ),
                            ),
                            DropdownMenuItem(
                              value: 'absent',
                              child: Row(
                                children: [
                                  const Icon(Icons.close,
                                      color: Color(0xFFC62828)),
                                  SizedBox(width: 8.w),
                                  Text('غائب', style: GoogleFonts.cairo()),
                                ],
                              ),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            status = v ?? 'present';
                          }),
                        ),
                        SizedBox(height: 16.h),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                            side: BorderSide(color: Colors.grey.shade300),
                          ),
                          title: Text(
                            'وقت الحضور (اختياري)',
                            style: GoogleFonts.cairo(),
                          ),
                          subtitle: Text(
                            checkIn == null
                                ? '—'
                                : DateFormat('HH:mm').format(checkIn!),
                            style:
                                GoogleFonts.cairo(color: Colors.grey.shade600),
                          ),
                          trailing: const Icon(Icons.access_time),
                          onTap: () async {
                            final initial = TimeOfDay.fromDateTime(
                              checkIn ?? DateTime.now(),
                            );
                            final picked = await showTimePicker(
                              context: context,
                              initialTime: initial,
                            );
                            if (picked != null) {
                              final base = DateTime.now();
                              setState(() {
                                checkIn = DateTime(
                                  base.year,
                                  base.month,
                                  base.day,
                                  picked.hour,
                                  picked.minute,
                                );
                              });
                            }
                          },
                        ),
                        SizedBox(height: 16.h),
                        TextField(
                          controller: notesCtrl,
                          maxLines: 3,
                          decoration: InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: Text('إلغاء', style: GoogleFonts.cairo()),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                    ),
                    child: Text('حفظ', style: GoogleFonts.cairo()),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;

      final id = const Uuid().v4();
      final today = _dateKey(DateTime.now());
      await _schoolSubCollection(schoolId, 'StaffAttendance').doc(id).set({
        'staffName': teacher.name,
        'staffId': teacher.id,
        'status': status,
        'checkInAt': checkIn == null ? null : Timestamp.fromDate(checkIn!),
        'notes': notesCtrl.text.trim(),
        'dateKey': today,
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    return UnifiedPageScaffold(
      allowedRoles: [UserRole.deputy, UserRole.admin, UserRole.superAdmin],
      showAppBar: true,
      title: 'حضور المعلمين',
      floatingActionButton: null,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF1A237E),
                      const Color(0xFF3949AB),
                    ],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  borderRadius: BorderRadius.circular(20.r),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1A237E).withOpacity(0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(20.r),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat.yMMMMd('ar').format(DateTime.now()),
                                style: GoogleFonts.cairo(
                                  color: Colors.white70,
                                  fontSize: 14.sp,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                'حضور المعلمين',
                                style: GoogleFonts.cairo(
                                  color: Colors.white,
                                  fontSize: 24.sp,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: EdgeInsets.all(12.r),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.group_rounded,
                              color: Colors.white,
                              size: 32,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 20.h),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    presentCount.toString(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'حاضر',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white70,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    lateCount.toString(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'متأخر',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white70,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Container(
                              padding: EdgeInsets.all(12.r),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12.r),
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    absentCount.toString(),
                                    style: GoogleFonts.cairo(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                  SizedBox(height: 4.h),
                                  Text(
                                    'غائب',
                                    style: GoogleFonts.cairo(
                                      color: Colors.white70,
                                      fontSize: 13.sp,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20.h),
              Expanded(
                child: teachersAsync.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF1A237E),
                    ),
                  ),
                  error: (error, stack) => Center(
                    child: Text(
                      'خطأ في تحميل البيانات',
                      style: GoogleFonts.cairo(),
                    ),
                  ),
                  data: (teachers) {
                    if (teachers.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.group_off_rounded,
                              size: 64.r,
                              color: Colors.grey.shade300,
                            ),
                            SizedBox(height: 16.h),
                            Text(
                              'لا يوجد معلمين مسجلين',
                              style: GoogleFonts.cairo(
                                fontSize: 18.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    final Map<String, Map<String, dynamic>> attendanceMap = {};
                    for (final r in records) {
                      final staffId = _asString(r['staffId']);
                      if (staffId.isNotEmpty) {
                        attendanceMap[staffId] = r;
                      }
                    }

                    return GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: MediaQuery.of(context).size.width > 1200
                            ? 4
                            : MediaQuery.of(context).size.width > 900
                                ? 3
                                : MediaQuery.of(context).size.width > 600
                                    ? 2
                                    : 1,
                        crossAxisSpacing: 12.w,
                        mainAxisSpacing: 12.h,
                        childAspectRatio: 2.8,
                      ),
                      itemCount: teachers.length,
                      itemBuilder: (context, index) {
                        final teacher = teachers[index];
                        final attendance = attendanceMap[teacher.id];
                        final currentStatus = attendance != null
                            ? statusLabel(_asString(attendance['status']))
                            : 'لم يتم تسجيله';
                        final currentColor = attendance != null
                            ? statusColor(_asString(attendance['status']))
                            : Colors.grey.shade400;
                        final checkIn = attendance != null
                            ? _asDateTime(attendance['checkInAt'])
                            : null;

                        return Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16.r),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Material(
                            color: Colors.transparent,
                            borderRadius: BorderRadius.circular(16.r),
                            child: InkWell(
                              onTap: () => markTeacherAttendance(teacher),
                              borderRadius: BorderRadius.circular(16.r),
                              child: Padding(
                                padding: EdgeInsets.all(16.r),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 56.w,
                                      height: 56.w,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1A237E)
                                            .withOpacity(0.1),
                                        borderRadius:
                                            BorderRadius.circular(14.r),
                                      ),
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: const Color(0xFF1A237E),
                                        size: 28.r,
                                      ),
                                    ),
                                    SizedBox(width: 14.w),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            teacher.name,
                                            style: GoogleFonts.cairo(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 15.sp,
                                              color: Colors.grey.shade800,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: 4.h),
                                          if (checkIn != null)
                                            Text(
                                              'وقت الحضور: ${DateFormat('HH:mm').format(checkIn)}',
                                              style: GoogleFonts.cairo(
                                                fontSize: 12.sp,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(width: 12.w),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 14.w,
                                        vertical: 8.h,
                                      ),
                                      decoration: BoxDecoration(
                                        color: currentColor.withOpacity(0.12),
                                        borderRadius:
                                            BorderRadius.circular(12.r),
                                      ),
                                      child: Text(
                                        currentStatus,
                                        style: GoogleFonts.cairo(
                                          color: currentColor,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.sp,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==============================================================================
// 3. Maintenance Module
// ==============================================================================
class MaintenanceModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const MaintenanceModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    String title;
    String description;
    IconData icon;
    final reportsAsync = ref.watch(maintenanceReportsStreamProvider);
    final reports = reportsAsync.value ?? <MaintenanceReport>[];
    final openReports = reports
        .where(
          (r) =>
              r.status == MaintenanceStatus.pending ||
              r.status == MaintenanceStatus.inProgress ||
              r.status == MaintenanceStatus.overdue,
        )
        .toList();
    final overdueReports =
        reports.where((r) => r.status == MaintenanceStatus.overdue).toList();

    final now = DateTime.now();
    final completedThisMonth = reports.where((r) {
      if (r.status != MaintenanceStatus.completed) return false;
      return r.createdAt.year == now.year && r.createdAt.month == now.month;
    }).length;

    final openCount = openReports.length;
    final overdueCount = overdueReports.length;
    switch (initialIndex) {
      case 1:
        title = 'تتبع الحالة';
        description =
            'متابعة حالة بلاغات الصيانة من لحظة تسجيلها وحتى إغلاقها.';
        icon = Icons.track_changes;
        break;
      case 2:
        title = 'سجل الأعطال';
        description =
            'سجل لجميع الأعطال السابقة في المبنى المدرسي وخطط معالجتها.';
        icon = Icons.build;
        break;
      case 3:
        title = 'تقرير جاهزية المبنى';
        description =
            'تقييم جاهزية المبنى المدرسي من حيث السلامة والتجهيزات الأساسية.';
        icon = Icons.domain_verification;
        break;
      case 4:
        title = 'تقرير صيانة دوري';
        description =
            'خطة صيانة دورية للمبنى والمرافق لضمان الاستدامة والسلامة.';
        icon = Icons.calendar_today;
        break;
      case 0:
      default:
        title = 'تحديد الأولوية';
        description =
            'تصنيف بلاغات الصيانة حسب الأولوية (عاجلة، متوسطة، روتينية).';
        icon = Icons.priority_high;
        break;
    }
    return UnifiedPageScaffold(
      requiredDeputyType: 'school',
      showAppBar: false,
      title: title,
      floatingActionButton: _buildMaintenanceFAB(context, ref, initialIndex),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SchoolModuleHeader(
                title: title,
                description: description,
                icon: icon,
                color: Colors.orange,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _SchoolMetricCard(
                      label: 'بلاغات مفتوحة',
                      value: openCount.toString(),
                      icon: Icons.build_circle,
                      color: Colors.red.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label: 'مكتملة هذا الشهر',
                      value: completedThisMonth.toString(),
                      icon: Icons.check_circle,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label: 'متأخرة',
                      value: overdueCount.toString(),
                      icon: Icons.timer_off,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              Expanded(
                child: _buildMaintenanceContent(
                  context,
                  ref,
                  initialIndex,
                  reports,
                  openReports,
                  overdueReports,
                  completedThisMonth,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaintenanceContent(
    BuildContext context,
    WidgetRef ref,
    int initialIndex,
    List<MaintenanceReport> reports,
    List<MaintenanceReport> openReports,
    List<MaintenanceReport> overdueReports,
    int completedThisMonth,
  ) {
    switch (initialIndex) {
      case 0: // تحديد الأولوية
        return _buildPrioritySection(reports);
      case 1: // تتبع الحالة
        return _buildStatusTrackingSection(reports);
      case 2: // سجل الأعطال
        return _buildFaultLogSection(reports);
      case 3: // تقرير جاهزية المبنى
        return _buildBuildingReadinessSection(reports);
      case 4: // تقرير صيانة دوري
        return _buildPeriodicMaintenanceSection();
      default:
        return _buildPrioritySection(reports);
    }
  }

  Widget _buildPrioritySection(List<MaintenanceReport> reports) {
    final criticalReports = reports
        .where((r) => r.priority == MaintenancePriority.critical)
        .toList();
    final highReports =
        reports.where((r) => r.priority == MaintenancePriority.high).toList();
    final mediumReports =
        reports.where((r) => r.priority == MaintenancePriority.medium).toList();
    final lowReports =
        reports.where((r) => r.priority == MaintenancePriority.low).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // إحصائيات الأولوية
          Row(
            children: [
              Expanded(
                child: PriorityCard(
                  title: 'حرجة',
                  count: criticalReports.length,
                  color: Colors.purple,
                  icon: Icons.warning,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: PriorityCard(
                  title: 'عالية',
                  count: highReports.length,
                  color: Colors.red,
                  icon: Icons.priority_high,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: PriorityCard(
                  title: 'متوسطة',
                  count: mediumReports.length,
                  color: Colors.orange,
                  icon: Icons.remove,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: PriorityCard(
                  title: 'منخفضة',
                  count: lowReports.length,
                  color: Colors.green,
                  icon: Icons.low_priority,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // أقسام الأولوية
          if (criticalReports.isNotEmpty) ...[
            _buildPrioritySectionWidget(
                'بلاغات حرجة', criticalReports, Colors.purple),
            SizedBox(height: 12.h),
          ],
          if (highReports.isNotEmpty) ...[
            _buildPrioritySectionWidget(
                'بلاغات عالية الأولوية', highReports, Colors.red),
            SizedBox(height: 12.h),
          ],
          if (mediumReports.isNotEmpty) ...[
            _buildPrioritySectionWidget(
                'بلاغات متوسطة الأولوية', mediumReports, Colors.orange),
            SizedBox(height: 12.h),
          ],
          if (lowReports.isNotEmpty) ...[
            _buildPrioritySectionWidget(
                'بلاغات منخفضة الأولوية', lowReports, Colors.green),
          ],
          if (reports.isEmpty)
            Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  children: [
                    Icon(Icons.build_circle_outlined,
                        size: 64.sp, color: Colors.grey.shade400),
                    SizedBox(height: 16.h),
                    Text(
                      'لا توجد بلاغات صيانة',
                      style: TextStyle(
                          fontSize: 16.sp, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPrioritySectionWidget(
      String title, List<MaintenanceReport> reports, Color color) {
    return Builder(
      builder: (context) => Container(
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20.w,
                  height: 20.w,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4.r),
                  ),
                ),
                SizedBox(width: 8.w),
                Text(
                  '$title (${reports.length})',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            ...reports.take(3).map((report) => Padding(
                  padding: EdgeInsets.only(bottom: 4.h),
                  child: GestureDetector(
                    onTap: () => _showReportDetails(context, report),
                    child: Container(
                      padding:
                          EdgeInsets.symmetric(vertical: 4.h, horizontal: 8.w),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: Text(
                        '• ${report.title}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                )),
            if (reports.length > 3)
              Text(
                'و ${reports.length - 3} بلاغات أخرى...',
                style: TextStyle(
                  fontSize: 11.sp,
                  color: Colors.grey.shade500,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTrackingSection(List<MaintenanceReport> reports) {
    final pendingReports =
        reports.where((r) => r.status == MaintenanceStatus.pending).toList();
    final inProgressReports =
        reports.where((r) => r.status == MaintenanceStatus.inProgress).toList();
    final completedReports =
        reports.where((r) => r.status == MaintenanceStatus.completed).toList();
    final overdueReports =
        reports.where((r) => r.status == MaintenanceStatus.overdue).toList();

    return SingleChildScrollView(
      child: Column(
        children: [
          // إحصائيات الحالة
          Row(
            children: [
              Expanded(
                child: StatusCard(
                  title: 'قيد الانتظار',
                  count: pendingReports.length,
                  color: Colors.blue,
                  icon: Icons.hourglass_empty,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: StatusCard(
                  title: 'قيد التنفيذ',
                  count: inProgressReports.length,
                  color: Colors.orange,
                  icon: Icons.build,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: StatusCard(
                  title: 'مكتملة',
                  count: completedReports.length,
                  color: Colors.green,
                  icon: Icons.check_circle,
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: StatusCard(
                  title: 'متأخرة',
                  count: overdueReports.length,
                  color: Colors.red,
                  icon: Icons.timer_off,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          // الخط الزمني للبلاغات
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'الخط الزمني للبلاغات',
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
                SizedBox(height: 12.h),
                if (reports.isNotEmpty)
                  ...reports.take(10).map((report) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: Builder(
                          builder: (context) => GestureDetector(
                            onTap: () => _showReportDetails(context, report),
                            child: buildTimelineItem(report),
                          ),
                        ),
                      ))
                else
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24.w),
                      child: Text(
                        'لا توجد بلاغات للعرض',
                        style: TextStyle(
                            fontSize: 14.sp, color: Colors.grey.shade600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFaultLogSection(List<MaintenanceReport> reports) {
    // تجميع البلاغات حسب الموقع
    final Map<String, List<MaintenanceReport>> reportsByLocation = {};
    for (final report in reports) {
      final location =
          report.location.isNotEmpty ? report.location : 'موقع غير محدد';
      reportsByLocation[location] = (reportsByLocation[location] ?? [])
        ..add(report);
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'الأعطال مجمعة حسب الموقع',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 12.h),
          if (reportsByLocation.isNotEmpty)
            ...reportsByLocation.entries.map((entry) => Padding(
                  padding: EdgeInsets.only(bottom: 12.h),
                  child: Builder(
                    builder: (context) => GestureDetector(
                      onTap: () {
                        if (entry.value.isNotEmpty) {
                          _showReportDetails(context, entry.value.first);
                        }
                      },
                      child: buildLocationFaultCard(entry.key, entry.value),
                    ),
                  ),
                ))
          else
            Center(
              child: Padding(
                padding: EdgeInsets.all(32.w),
                child: Column(
                  children: [
                    Icon(Icons.location_off,
                        size: 64.sp, color: Colors.grey.shade400),
                    SizedBox(height: 16.h),
                    Text(
                      'لا توجد أعطال مسجلة',
                      style: TextStyle(
                          fontSize: 16.sp, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBuildingReadinessSection(List<MaintenanceReport> reports) {
    // حساب نسب الجاهزية بناءً على البلاغات
    final totalReports = reports.length;
    final completedReports =
        reports.where((r) => r.status == MaintenanceStatus.completed).length;
    final pendingReports =
        reports.where((r) => r.status == MaintenanceStatus.pending).length;
    final overdueReports =
        reports.where((r) => r.status == MaintenanceStatus.overdue).length;

    final overallReadiness = totalReports == 0
        ? 100
        : ((completedReports / totalReports) * 100).round();
    final safetyReadiness =
        overdueReports == 0 ? 95 : (95 - (overdueReports * 10)).clamp(0, 100);
    final maintenanceReadiness =
        pendingReports == 0 ? 90 : (90 - (pendingReports * 5)).clamp(0, 100);
    final facilitiesReadiness = 85; // قيمة افتراضية

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'تقييم جاهزية المبنى',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          buildReadinessItem('الجاهزية العامة', overallReadiness, Colors.blue),
          SizedBox(height: 12.h),
          buildReadinessItem('السلامة والأمان', safetyReadiness, Colors.green),
          SizedBox(height: 12.h),
          buildReadinessItem(
              'حالة الصيانة', maintenanceReadiness, Colors.orange),
          SizedBox(height: 12.h),
          buildReadinessItem(
              'التجهيزات والمرافق', facilitiesReadiness, Colors.purple),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info, color: Colors.blue.shade700, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'ملخص التقييم',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '• إجمالي البلاغات: $totalReports\n'
                  '• البلاغات المكتملة: $completedReports\n'
                  '• البلاغات المعلقة: $pendingReports\n'
                  '• البلاغات المتأخرة: $overdueReports',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.blue.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodicMaintenanceSection() {
    // بيانات وهمية للصيانة الدورية
    final maintenanceTasks = [
      {
        'title': 'فحص أنظمة التكييف',
        'dueDate': DateTime.now().add(const Duration(days: 7)),
        'status': 'قادم',
      },
      {
        'title': 'صيانة المصاعد',
        'dueDate': DateTime.now().add(const Duration(days: 3)),
        'status': 'عاجل',
      },
      {
        'title': 'فحص أنظمة الإنذار',
        'dueDate': DateTime.now().subtract(const Duration(days: 2)),
        'status': 'متأخر',
      },
      {
        'title': 'تنظيف خزانات المياه',
        'dueDate': DateTime.now().add(const Duration(days: 14)),
        'status': 'مجدول',
      },
      {
        'title': 'فحص الأسلاك الكهربائية',
        'dueDate': DateTime.now().add(const Duration(days: 21)),
        'status': 'مجدول',
      },
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'جدول الصيانة الدورية',
            style: TextStyle(
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(height: 16.h),
          ...maintenanceTasks.map((task) => Padding(
                padding: EdgeInsets.only(bottom: 12.h),
                child: buildMaintenanceTaskCard(task),
              )),
          SizedBox(height: 20.h),
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.schedule,
                        color: Colors.green.shade700, size: 20.sp),
                    SizedBox(width: 8.w),
                    Text(
                      'توصيات الصيانة الدورية',
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade700,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  '• قم بجدولة الصيانة الدورية كل 3 أشهر\n'
                  '• تأكد من توفر قطع الغيار الأساسية\n'
                  '• وثق جميع أعمال الصيانة في السجل\n'
                  '• راجع خطة الصيانة الطارئة بانتظام',
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildMaintenanceFAB(
      BuildContext context, WidgetRef ref, int initialIndex) {
    switch (initialIndex) {
      case 0: // تحديد الأولوية
        return FloatingActionButton.extended(
          onPressed: () {
            context.push('/report-maintenance');
          },
          icon: const Icon(Icons.add),
          label: const Text('بلاغ جديد'),
          backgroundColor: Colors.purple.shade700,
        );
      case 1: // تتبع الحالة
        return FloatingActionButton.extended(
          onPressed: () {
            _showStatusUpdateDialog(context);
          },
          icon: const Icon(Icons.update),
          label: const Text('تحديث حالة'),
          backgroundColor: Colors.blue.shade700,
        );
      case 2: // سجل الأعطال
        return FloatingActionButton.extended(
          onPressed: () {
            context.push('/report-maintenance');
          },
          icon: const Icon(Icons.report_problem),
          label: const Text('تسجيل عطل'),
          backgroundColor: Colors.orange.shade700,
        );
      case 3: // تقرير جاهزية المبنى
        return FloatingActionButton.extended(
          onPressed: () {
            _showReadinessAssessmentDialog(context, ref);
          },
          icon: const Icon(Icons.assessment),
          label: const Text('تقييم جاهزية'),
          backgroundColor: Colors.green.shade700,
        );
      case 4: // تقرير صيانة دوري
        return FloatingActionButton.extended(
          onPressed: () {
            _showScheduleMaintenanceDialog(context, ref);
          },
          icon: const Icon(Icons.schedule),
          label: const Text('جدولة صيانة'),
          backgroundColor: Colors.indigo.shade700,
        );
      default:
        return FloatingActionButton.extended(
          onPressed: () {
            context.push('/report-maintenance');
          },
          icon: const Icon(Icons.add),
          label: const Text('بلاغ جديد'),
          backgroundColor: Colors.orange.shade800,
        );
    }
  }

  void _showStatusUpdateDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تحديث حالة البلاغ'),
        content: const Text('اختر بلاغاً من القائمة أدناه لتحديث حالته'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              context.push('/maintenance-requests');
            },
            child: const Text('عرض البلاغات'),
          ),
        ],
      ),
    );
  }

  void _showReadinessAssessmentDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('تقييم جاهزية المبنى'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('هل تريد إجراء تقييم شامل لجاهزية المبنى؟'),
            SizedBox(height: 16.h),
            const Text('سيتم فحص جميع الأنظمة والمرافق'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _startReadinessAssessment(context, ref);
            },
            child: const Text('بدء التقييم'),
          ),
        ],
      ),
    );
  }

  void _showScheduleMaintenanceDialog(BuildContext context, WidgetRef ref) {
    final titleController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('جدولة صيانة دورية'),
          content: SizedBox(
            width: 300.w,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'نوع الصيانة',
                    hintText: 'مثال: فحص أنظمة التكييف',
                  ),
                ),
                SizedBox(height: 16.h),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ الاستحقاق'),
                  subtitle: Text(DateFormat('yyyy-MM-dd').format(selectedDate)),
                  trailing: const Icon(Icons.date_range),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setState(() => selectedDate = picked);
                    }
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _scheduleMaintenanceTask(
                    context, ref, titleController.text, selectedDate);
              },
              child: const Text('جدولة'),
            ),
          ],
        ),
      ),
    );
  }

  void _startReadinessAssessment(BuildContext context, WidgetRef ref) async {
    // إنشاء تقرير جاهزية في Firestore
    try {
      final user = ref.read(authStateProvider).value;
      if (user?.schoolId == null) return;

      final assessmentId = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(user!.schoolId)
          .collection('BuildingReadinessAssessments')
          .doc(assessmentId)
          .set({
        'id': assessmentId,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.id,
        'createdByName': user.name,
        'status': 'in_progress',
        'overallScore': 0,
        'notes': 'تقييم جاهزية شامل للمبنى',
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ تم بدء تقييم جاهزية المبنى بنجاح'),
            backgroundColor: Colors.green.shade600,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _scheduleMaintenanceTask(BuildContext context, WidgetRef ref,
      String title, DateTime dueDate) async {
    if (title.trim().isEmpty) return;

    try {
      final user = ref.read(authStateProvider).value;
      if (user?.schoolId == null) return;

      final taskId = const Uuid().v4();
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(user!.schoolId)
          .collection('PeriodicMaintenanceTasks')
          .doc(taskId)
          .set({
        'id': taskId,
        'title': title.trim(),
        'dueDate': Timestamp.fromDate(dueDate),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': user.id,
        'createdByName': user.name,
        'status': 'scheduled',
        'isRecurring': false,
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                '✅ تم جدولة: $title لتاريخ ${DateFormat('yyyy-MM-dd').format(dueDate)}'),
            backgroundColor: Colors.indigo.shade600,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  void _showReportDetails(BuildContext context, MaintenanceReport report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(report.title.isNotEmpty ? report.title : 'بلاغ صيانة'),
        content: SizedBox(
          width: 400.w,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailRow('الموقع',
                    report.location.isNotEmpty ? report.location : 'غير محدد'),
                _buildDetailRow('الأولوية', _getPriorityLabel(report.priority)),
                _buildDetailRow('الحالة', _getStatusLabel(report.status)),
                _buildDetailRow('تاريخ الإنشاء',
                    DateFormat('yyyy-MM-dd HH:mm').format(report.createdAt)),
                if (report.dueAt != null)
                  _buildDetailRow('تاريخ الاستحقاق',
                      DateFormat('yyyy-MM-dd').format(report.dueAt!)),
                if (report.assignedTo != null && report.assignedTo!.isNotEmpty)
                  _buildDetailRow('مُكلف بالصيانة', report.assignedTo!),
                if (report.description.isNotEmpty) ...[
                  SizedBox(height: 12.h),
                  Text(
                    'الوصف:',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: Text(
                      report.description,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('إغلاق'),
          ),
          if (report.status != MaintenanceStatus.completed)
            ElevatedButton(
              onPressed: () {
                Navigator.of(ctx).pop();
                _showUpdateStatusDialog(context, report);
              },
              child: const Text('تحديث الحالة'),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100.w,
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.sp,
                color: Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getPriorityLabel(MaintenancePriority priority) {
    switch (priority) {
      case MaintenancePriority.critical:
        return 'حرجة';
      case MaintenancePriority.high:
        return 'عالية';
      case MaintenancePriority.medium:
        return 'متوسطة';
      case MaintenancePriority.low:
        return 'منخفضة';
    }
  }

  String _getStatusLabel(MaintenanceStatus status) {
    switch (status) {
      case MaintenanceStatus.pending:
        return 'قيد الانتظار';
      case MaintenanceStatus.inProgress:
        return 'قيد التنفيذ';
      case MaintenanceStatus.completed:
        return 'مكتمل';
      case MaintenanceStatus.rejected:
        return 'مرفوض';
      case MaintenanceStatus.overdue:
        return 'متأخر';
    }
  }

  void _showUpdateStatusDialog(BuildContext context, MaintenanceReport report) {
    MaintenanceStatus selectedStatus = report.status;

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, child) {
          final user = ref.watch(authStateProvider).value;

          return StatefulBuilder(
            builder: (context, setState) => AlertDialog(
              title: const Text('تحديث حالة البلاغ'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('البلاغ: ${report.title}'),
                  SizedBox(height: 16.h),
                  DropdownButtonFormField<MaintenanceStatus>(
                    value: selectedStatus,
                    decoration: const InputDecoration(
                      labelText: 'الحالة الجديدة',
                    ),
                    items: MaintenanceStatus.values.map((status) {
                      return DropdownMenuItem(
                        value: status,
                        child: Text(_getStatusLabel(status)),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => selectedStatus = value);
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('إلغاء'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.of(ctx).pop();

                    // تحديث الحالة في Firestore
                    final schoolId = user?.schoolId ?? '';
                    if (schoolId.isEmpty || report.id.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('❌ خطأ: لا يمكن تحديث الحالة'),
                          backgroundColor: Colors.red.shade600,
                        ),
                      );
                      return;
                    }

                    try {
                      await FirebaseFirestore.instance
                          .collection('Schools')
                          .doc(schoolId)
                          .collection('MaintenanceReports')
                          .doc(report.id)
                          .update({
                        'status': selectedStatus.name,
                        'updatedAt': FieldValue.serverTimestamp(),
                        'updatedBy': user?.id,
                        'updatedByName': user?.name,
                      });

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '✅ تم تحديث حالة البلاغ إلى: ${_getStatusLabel(selectedStatus)}'),
                            backgroundColor: Colors.green.shade600,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('❌ خطأ في التحديث: $e'),
                            backgroundColor: Colors.red.shade600,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('تحديث'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

// ==============================================================================
// 4. Safety Module
// ==============================================================================
class SafetyModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const SafetyModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final settings = ref.watch(safetySettingsProvider).value;
    final guardsCount =
        (ref.watch(safetyGuardsProvider).value ?? const <SafetyGuard>[]).length;
    final drills = ref.watch(safetyDrillsStreamProvider).value ?? const [];
    final extinguishers =
        ref.watch(safetyExtinguishersStreamProvider).value ?? const [];
    final exits =
        ref.watch(safetyEmergencyExitsStreamProvider).value ?? const [];
    final expiredExtinguishers = ref.watch(expiredExtinguishersCountProvider);
    final blockedExits = ref.watch(blockedExitsCountProvider);
    final drillOverdueFlag = ref.watch(safetyDrillsOverdueFlagProvider);

    DateTime? lastDrillDate() {
      final dates = drills
          .map(
            (d) => _asDateTime(d['drillDate'] ?? d['date'] ?? d['createdAt']),
          )
          .whereType<DateTime>()
          .toList()
        ..sort((a, b) => b.compareTo(a));
      return dates.isEmpty ? null : dates.first;
    }

    final lastDrill = lastDrillDate();
    final lastDrillLabel = lastDrill == null
        ? 'غير مسجل'
        : DateFormat('yyyy-MM-dd').format(lastDrill);

    final camA = settings?.camerasActive;
    final camT = settings?.camerasTotal;
    final camerasValue = (camA == null && camT == null)
        ? 'غير مسجل'
        : '${camA ?? 0}/${camT ?? 0}';
    final alarmsValue = settings?.alarmsReady == null
        ? 'غير مسجل'
        : (settings!.alarmsReady! ? 'جاهز' : 'غير جاهز');
    final planValue = (settings?.meetingPoint.trim().isNotEmpty ?? false) ||
            (settings?.evacuationOfficer.trim().isNotEmpty ?? false)
        ? 'مسجلة'
        : 'غير مسجلة';

    final recs = <String>[
      if (planValue == 'غير مسجلة')
        'استكمل بيانات خطة الإخلاء (نقطة التجمع + مسؤول الإخلاء) لضمان جاهزية المدرسة.',
      if (drillOverdueFlag == 1)
        'يوصى بتنفيذ فرضية إخلاء مرة واحدة على الأقل كل فصل دراسي وتوثيق النتائج.',
      if (expiredExtinguishers > 0)
        'يوصى باستبدال/صيانة طفايات الحريق المنتهية لضمان الامتثال والسلامة.',
      if (blockedExits > 0)
        'يوصى بإزالة العوائق من مخارج الطوارئ فورًا وتوثيق إعادة الفتح.',
    ];

    Widget recommendationsCard() {
      if (recs.isEmpty) return const SizedBox.shrink();
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توصيات ذكية',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 8.h),
              ...recs.map(
                (t) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.red.shade700,
                        size: 18,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade800,
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
      );
    }

    Future<void> editPlan() async {
      if (schoolId.isEmpty) return;
      final meetingCtrl = TextEditingController(
        text: settings?.meetingPoint ?? '',
      );
      final officerCtrl = TextEditingController(
        text: settings?.evacuationOfficer ?? '',
      );
      final camActiveCtrl = TextEditingController(
        text: settings?.camerasActive?.toString() ?? '',
      );
      final camTotalCtrl = TextEditingController(
        text: settings?.camerasTotal?.toString() ?? '',
      );
      bool? alarmsReady = settings?.alarmsReady;

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('تحديث خطة الإخلاء'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: meetingCtrl,
                          decoration: const InputDecoration(
                            labelText: 'نقطة التجمع',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: officerCtrl,
                          decoration: const InputDecoration(
                            labelText: 'مسؤول الإخلاء',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: camActiveCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'كاميرات فعالة',
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: TextField(
                                controller: camTotalCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'إجمالي الكاميرات',
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        SwitchListTile(
                          value: alarmsReady ?? false,
                          title: const Text('أنظمة الإنذار جاهزة'),
                          onChanged: (v) => setState(() {
                            alarmsReady = v;
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final repo = ref.read(safetyRepositoryProvider);
      await repo.upsertSettings(
        schoolId,
        meetingPoint: meetingCtrl.text.trim(),
        evacuationOfficer: officerCtrl.text.trim(),
        camerasActive: int.tryParse(camActiveCtrl.text.trim()),
        camerasTotal: int.tryParse(camTotalCtrl.text.trim()),
        alarmsReady: alarmsReady,
      );
    }

    Future<void> addDrill() async {
      if (schoolId.isEmpty) return;
      DateTime date = DateTime.now();
      final durationCtrl = TextEditingController(text: '10');
      final participantsCtrl = TextEditingController(text: '0');
      String result = 'pass';
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('إضافة فرضية إخلاء'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('التاريخ'),
                          subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: durationCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'المدة (دقائق)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: participantsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'عدد المشاركين (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: result,
                          items: const [
                            DropdownMenuItem(
                              value: 'pass',
                              child: Text('ناجح'),
                            ),
                            DropdownMenuItem(
                              value: 'needs_improvement',
                              child: Text('بحاجة لتحسين'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            result = v ?? 'pass';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'التقييم',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'SafetyDrills').doc(id).set({
        'drillDate': Timestamp.fromDate(date),
        'durationMinutes': int.tryParse(durationCtrl.text.trim()) ?? 0,
        'participantsCount': int.tryParse(participantsCtrl.text.trim()) ?? 0,
        'result': result,
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> addExtinguisher() async {
      if (schoolId.isEmpty) return;
      DateTime expiry = DateTime.now().add(const Duration(days: 365));
      DateTime checked = DateTime.now();
      final locationCtrl = TextEditingController();
      final serialCtrl = TextEditingController();
      String status = 'ok';
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('إضافة طفاية'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموقع',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: serialCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الرقم التسلسلي (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(value: 'ok', child: Text('سليم')),
                            DropdownMenuItem(
                              value: 'needs_service',
                              child: Text('يحتاج صيانة'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            status = v ?? 'ok';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ الفحص'),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(checked),
                          ),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: checked,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null)
                              setState(() => checked = picked);
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ الانتهاء'),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(expiry),
                          ),
                          trailing: const Icon(Icons.event_busy),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: expiry,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => expiry = picked);
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'Extinguishers').doc(id).set({
        'location': locationCtrl.text.trim(),
        'serial': serialCtrl.text.trim(),
        'status': status,
        'lastCheckedAt': Timestamp.fromDate(checked),
        'expiryDate': Timestamp.fromDate(expiry),
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> addExitInspection() async {
      if (schoolId.isEmpty) return;
      DateTime inspected = DateTime.now();
      final locationCtrl = TextEditingController();
      String status = 'clear';
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('تسجيل فحص مخرج'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموقع',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: status,
                          items: const [
                            DropdownMenuItem(
                              value: 'clear',
                              child: Text('سالِك'),
                            ),
                            DropdownMenuItem(
                              value: 'blocked',
                              child: Text('محجوب/مغلق'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            status = v ?? 'clear';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('تاريخ الفحص'),
                          subtitle: Text(
                            DateFormat('yyyy-MM-dd').format(inspected),
                          ),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: inspected,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) {
                              setState(() => inspected = picked);
                            }
                          },
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'EmergencyExits').doc(id).set({
        'location': locationCtrl.text.trim(),
        'status': status,
        'lastInspectedAt': Timestamp.fromDate(inspected),
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    String title;
    String description;
    IconData icon;
    switch (initialIndex) {
      case 1:
        title = 'سجل التجارب';
        description =
            'متابعة تجارب الإخلاء والتدريب على حالات الطوارئ وتوثيق نتائجها.';
        icon = Icons.history_edu;
        break;
      case 2:
        title = 'فحص الطفايات';
        description =
            'تسجيل مواقع طفايات الحريق ومواعيد فحصها وصلاحية الاستخدام.';
        icon = Icons.fire_extinguisher;
        break;
      case 3:
        title = 'مخارج الطوارئ';
        description =
            'متابعة جاهزية مخارج الطوارئ وخلوها من العوائق في جميع الأوقات.';
        icon = Icons.exit_to_app;
        break;
      case 0:
      default:
        title = 'خطة الإخلاء';
        description =
            'تصميم ومتابعة خطة إخلاء المدرسة في حالات الطوارئ بشكل منظم.';
        icon = Icons.run_circle;
        break;
    }
    return UnifiedPageScaffold(
      requiredDeputyType: 'school',
      showAppBar: false,
      title: title,
      floatingActionButton: schoolId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: initialIndex == 0
                  ? editPlan
                  : initialIndex == 1
                      ? addDrill
                      : initialIndex == 2
                          ? addExtinguisher
                          : addExitInspection,
              icon: const Icon(Icons.add),
              label: Text(
                initialIndex == 0
                    ? 'تحديث'
                    : initialIndex == 1
                        ? 'إضافة'
                        : initialIndex == 2
                            ? 'إضافة'
                            : 'تسجيل',
              ),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SchoolModuleHeader(
                title: title,
                description: description,
                icon: icon,
                color: Colors.red,
              ),
              SizedBox(height: 16.h),
              LayoutBuilder(
                builder: (context, constraints) {
                  // على الجوال: عمودي، على الشاشات الكبيرة: أفقي
                  final isMobile = constraints.maxWidth < 600;

                  if (isMobile) {
                    // تنسيق عمودي للجوال
                    return Column(
                      children: [
                        _SchoolMetricCard(
                          label: 'كاميرات المراقبة',
                          value: camerasValue,
                          icon: Icons.visibility,
                          color: Colors.red.shade700,
                        ),
                        SizedBox(height: 12.h),
                        _SchoolMetricCard(
                          label: 'أنظمة الإنذار',
                          value: alarmsValue,
                          icon: Icons.notifications_active,
                          color: Colors.green.shade700,
                        ),
                        SizedBox(height: 12.h),
                        _SchoolMetricCard(
                          label: 'حراس الأمن',
                          value: guardsCount.toString(),
                          icon: Icons.person_search,
                          color: Colors.orange.shade700,
                        ),
                      ],
                    );
                  } else {
                    // تنسيق أفقي للشاشات الكبيرة
                    return Row(
                      children: [
                        Expanded(
                          child: _SchoolMetricCard(
                            label: 'كاميرات المراقبة',
                            value: camerasValue,
                            icon: Icons.visibility,
                            color: Colors.red.shade700,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _SchoolMetricCard(
                            label: 'أنظمة الإنذار',
                            value: alarmsValue,
                            icon: Icons.notifications_active,
                            color: Colors.green.shade700,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: _SchoolMetricCard(
                            label: 'حراس الأمن',
                            value: guardsCount.toString(),
                            icon: Icons.person_search,
                            color: Colors.orange.shade700,
                          ),
                        ),
                      ],
                    );
                  }
                },
              ),
              SizedBox(height: 16.h),
              if (recs.isNotEmpty) ...[
                recommendationsCard(),
                SizedBox(height: 16.h),
              ],
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Builder(
                      builder: (context) {
                        if (schoolId.isEmpty) {
                          return Center(
                            child: Text(
                              'لا يمكن عرض البيانات بدون مدرسة مرتبطة بالحساب.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }

                        if (initialIndex == 0) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'ملخص الخطة',
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.grey.shade800,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: editPlan,
                                    child: const Text('تعديل'),
                                  ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              ListTile(
                                leading: const Icon(Icons.place),
                                title: const Text('نقطة التجمع'),
                                subtitle: Text(
                                  (settings?.meetingPoint ?? '').trim().isEmpty
                                      ? 'غير مسجل'
                                      : settings!.meetingPoint,
                                ),
                              ),
                              ListTile(
                                leading: const Icon(Icons.person),
                                title: const Text('مسؤول الإخلاء'),
                                subtitle: Text(
                                  (settings?.evacuationOfficer ?? '')
                                          .trim()
                                          .isEmpty
                                      ? 'غير مسجل'
                                      : settings!.evacuationOfficer,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Expanded(
                                child: GridView.count(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 8.w,
                                  mainAxisSpacing: 8.h,
                                  childAspectRatio: 4.5,
                                  children: [
                                    _buildSafetyTile(
                                      'خطة الإخلاء',
                                      planValue,
                                      Icons.run_circle,
                                      planValue == 'غير مسجلة'
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    _buildSafetyTile(
                                      'آخر فرضية',
                                      lastDrillLabel,
                                      Icons.history_edu,
                                      drillOverdueFlag == 1
                                          ? Colors.orange
                                          : Colors.blue,
                                    ),
                                    _buildSafetyTile(
                                      'طفايات منتهية',
                                      expiredExtinguishers.toString(),
                                      Icons.fire_extinguisher,
                                      expiredExtinguishers > 0
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                    _buildSafetyTile(
                                      'مخارج محجوبة',
                                      blockedExits.toString(),
                                      Icons.meeting_room,
                                      blockedExits > 0
                                          ? Colors.red
                                          : Colors.teal,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        }

                        if (initialIndex == 1) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'سجل التجارب',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Expanded(
                                child: drills.isEmpty
                                    ? Center(
                                        child: Text(
                                          'لا توجد تجارب مسجلة.',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: drills.length.clamp(0, 80),
                                        separatorBuilder: (_, __) => Divider(
                                          height: 12.h,
                                          color: Colors.grey.shade200,
                                        ),
                                        itemBuilder: (context, index) {
                                          final d = drills[index];
                                          final dt = _asDateTime(
                                            d['drillDate'] ??
                                                d['date'] ??
                                                d['createdAt'],
                                          );
                                          final dateStr = dt == null
                                              ? '—'
                                              : DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(dt);
                                          final result = _asString(d['result']);
                                          final resultLabel = result == 'pass'
                                              ? 'ناجح'
                                              : result == 'needs_improvement'
                                                  ? 'بحاجة لتحسين'
                                                  : (result.isEmpty
                                                      ? '—'
                                                      : result);
                                          final resultColor = result == 'pass'
                                              ? Colors.green
                                              : Colors.orange;
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: resultColor
                                                  .withValues(alpha: 0.12),
                                              child: Icon(
                                                Icons.history_edu,
                                                color: resultColor,
                                              ),
                                            ),
                                            title: Text(
                                              'تجربة إخلاء - $dateStr',
                                            ),
                                            subtitle: Text(
                                              [
                                                'التقييم: $resultLabel',
                                                'المدة: ${_asInt(d['durationMinutes'])} دقيقة',
                                              ].join(' • '),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        }

                        if (initialIndex == 2) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'فحص الطفايات',
                                style: TextStyle(
                                  fontSize: 16.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                              SizedBox(height: 12.h),
                              Expanded(
                                child: extinguishers.isEmpty
                                    ? Center(
                                        child: Text(
                                          'لا توجد طفايات مسجلة.',
                                          style: TextStyle(
                                            fontSize: 13.sp,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        itemCount: extinguishers.length.clamp(
                                          0,
                                          120,
                                        ),
                                        separatorBuilder: (_, __) => Divider(
                                          height: 12.h,
                                          color: Colors.grey.shade200,
                                        ),
                                        itemBuilder: (context, index) {
                                          final e = extinguishers[index];
                                          final loc = _asString(e['location']);
                                          final exp = _asDateTime(
                                            e['expiryDate'],
                                          );
                                          final expStr = exp == null
                                              ? 'غير مسجل'
                                              : DateFormat(
                                                  'yyyy-MM-dd',
                                                ).format(exp);
                                          final isExpired = exp != null &&
                                              exp.isBefore(DateTime.now());
                                          final st = _asString(e['status']);
                                          final stLabel = st == 'ok'
                                              ? 'سليم'
                                              : st == 'needs_service'
                                                  ? 'يحتاج صيانة'
                                                  : (st.isEmpty ? '—' : st);
                                          final stColor = isExpired
                                              ? Colors.red
                                              : st == 'needs_service'
                                                  ? Colors.orange
                                                  : Colors.green;
                                          return ListTile(
                                            leading: CircleAvatar(
                                              backgroundColor: stColor
                                                  .withValues(alpha: 0.12),
                                              child: Icon(
                                                Icons.fire_extinguisher,
                                                color: stColor,
                                              ),
                                            ),
                                            title: Text(
                                              loc.isEmpty ? '—' : loc,
                                            ),
                                            subtitle: Text(
                                              'الانتهاء: $expStr • الحالة: $stLabel',
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'مخارج الطوارئ',
                              style: TextStyle(
                                fontSize: 16.sp,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey.shade800,
                              ),
                            ),
                            SizedBox(height: 12.h),
                            Expanded(
                              child: exits.isEmpty
                                  ? Center(
                                      child: Text(
                                        'لا توجد سجلات مخارج مسجلة.',
                                        style: TextStyle(
                                          fontSize: 13.sp,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    )
                                  : ListView.separated(
                                      itemCount: exits.length.clamp(0, 120),
                                      separatorBuilder: (_, __) => Divider(
                                        height: 12.h,
                                        color: Colors.grey.shade200,
                                      ),
                                      itemBuilder: (context, index) {
                                        final e = exits[index];
                                        final loc = _asString(e['location']);
                                        final st = _asString(e['status']);
                                        final isBlocked = st == 'blocked';
                                        final color = isBlocked
                                            ? Colors.red
                                            : Colors.green;
                                        final inspected = _asDateTime(
                                          e['lastInspectedAt'],
                                        );
                                        final insStr = inspected == null
                                            ? 'غير مسجل'
                                            : DateFormat(
                                                'yyyy-MM-dd',
                                              ).format(inspected);
                                        return ListTile(
                                          leading: CircleAvatar(
                                            backgroundColor: color.withValues(
                                              alpha: 0.12,
                                            ),
                                            child: Icon(
                                              Icons.meeting_room,
                                              color: color,
                                            ),
                                          ),
                                          title: Text(loc.isEmpty ? '—' : loc),
                                          subtitle: Text(
                                            'آخر فحص: $insStr • الحالة: ${isBlocked ? 'محجوب/مغلق' : 'سالِك'}',
                                          ),
                                        );
                                      },
                                    ),
                            ),
                          ],
                        );
                      },
                    ),
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

// ==============================================================================
// 5. Inventory Module
// ==============================================================================
class InventoryModuleScreen extends ConsumerWidget {
  final int initialIndex;

  const InventoryModuleScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();

    final inventoryItems =
        ref.watch(inventoryItemsStreamProvider).value ?? const [];
    final requests =
        ref.watch(materialRequestsStreamProvider).value ?? const [];
    final damages = ref.watch(damageReportsStreamProvider).value ?? const [];
    final handovers = ref.watch(handoverLogsStreamProvider).value ?? const [];

    String title;
    String description;
    IconData icon;
    MaterialColor color;
    switch (initialIndex) {
      case 1:
        title = 'تسجيل تلف/فقد';
        description =
            'تسجيل حالات تلف أو فقد للأصول المدرسية وربطها بمحاضر رسمية.';
        icon = Icons.broken_image;
        color = Colors.red;
        break;
      case 2:
        title = 'سجل استلام وتسليم';
        description =
            'متابعة حركة استلام وتسليم العهد المدرسية بين الموظفين والمعلمين.';
        icon = Icons.handshake;
        color = Colors.teal;
        break;
      case 3:
        title = 'طلب مواد';
        description =
            'رفع طلبات المواد والاحتياجات مع متابعة حالة الطلب واعتمادها.';
        icon = Icons.list_alt;
        color = Colors.brown;
        break;
      case 0:
      default:
        title = 'جرد إلكتروني';
        description =
            'إجراء جرد إلكتروني سريع للممتلكات المدرسية ومقارنتها بسجلات النظام.';
        icon = Icons.inventory;
        color = Colors.blue;
        break;
    }

    final lowStockCount = ref.watch(lowStockCountProvider);
    final openRequestsCount = ref.watch(openMaterialRequestsCountProvider);
    final damageOpenCount = damages
        .where((d) => _asString(d['status']).toLowerCase() != 'closed')
        .length;
    final handoversThisMonth = (() {
      final now = DateTime.now();
      return handovers.where((h) {
        final dt = _asDateTime(h['date'] ?? h['createdAt']);
        return dt != null && dt.year == now.year && dt.month == now.month;
      }).length;
    })();

    Future<void> addInventoryItem() async {
      if (schoolId.isEmpty) return;
      final nameCtrl = TextEditingController();
      final categoryCtrl = TextEditingController();
      final locationCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      final minCtrl = TextEditingController(text: '0');
      final notesCtrl = TextEditingController();
      String condition = 'good';

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('إضافة عهدة'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(
                            labelText: 'اسم العهدة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: categoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'التصنيف (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموقع (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: qtyCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'الكمية',
                                ),
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Expanded(
                              child: TextField(
                                controller: minCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  labelText: 'حد التنبيه (اختياري)',
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: condition,
                          items: const [
                            DropdownMenuItem(
                              value: 'good',
                              child: Text('سليم'),
                            ),
                            DropdownMenuItem(
                              value: 'needs_repair',
                              child: Text('يحتاج صيانة'),
                            ),
                            DropdownMenuItem(
                              value: 'damaged',
                              child: Text('تالف'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            condition = v ?? 'good';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الحالة',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final name = nameCtrl.text.trim();
      if (name.isEmpty) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'InventoryItems').doc(id).set({
        'name': name,
        'category': categoryCtrl.text.trim(),
        'location': locationCtrl.text.trim(),
        'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
        'minQuantity': int.tryParse(minCtrl.text.trim()) ?? 0,
        'condition': condition,
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> addMaterialRequest() async {
      if (schoolId.isEmpty) return;
      final itemCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      final notesCtrl = TextEditingController();
      String priority = 'medium';

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('طلب مواد'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: itemCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الصنف المطلوب',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: priority,
                          items: const [
                            DropdownMenuItem(
                              value: 'low',
                              child: Text('منخفضة'),
                            ),
                            DropdownMenuItem(
                              value: 'medium',
                              child: Text('متوسطة'),
                            ),
                            DropdownMenuItem(
                              value: 'high',
                              child: Text('عالية'),
                            ),
                            DropdownMenuItem(
                              value: 'urgent',
                              child: Text('عاجلة'),
                            ),
                          ],
                          onChanged: (v) => setState(() {
                            priority = v ?? 'medium';
                          }),
                          decoration: const InputDecoration(
                            labelText: 'الأولوية',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'مبررات/ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final item = itemCtrl.text.trim();
      if (item.isEmpty) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'MaterialRequests').doc(id).set({
        'item': item,
        'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
        'priority': priority,
        'status': 'requested',
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> markRequestReceived(Map<String, dynamic> req) async {
      if (schoolId.isEmpty) return;
      final id = _asString(req['id']);
      if (id.isEmpty) return;
      await _schoolSubCollection(schoolId, 'MaterialRequests').doc(id).set({
        'status': 'received',
        'receivedAt': FieldValue.serverTimestamp(),
        'receivedById': user?.id,
        'receivedByName': user?.name,
      }, SetOptions(merge: true));
    }

    Future<void> addDamageReport() async {
      if (schoolId.isEmpty) return;
      DateTime date = DateTime.now();
      final itemCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      final locationCtrl = TextEditingController();
      final notesCtrl = TextEditingController();
      String type = 'damage';

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('تسجيل تلف/فقد'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('التاريخ'),
                          subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                        ),
                        TextField(
                          controller: itemCtrl,
                          decoration: const InputDecoration(labelText: 'الصنف'),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: locationCtrl,
                          decoration: const InputDecoration(
                            labelText: 'الموقع (اختياري)',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        DropdownButtonFormField<String>(
                          value: type,
                          items: const [
                            DropdownMenuItem(
                              value: 'damage',
                              child: Text('تلف'),
                            ),
                            DropdownMenuItem(value: 'lost', child: Text('فقد')),
                          ],
                          onChanged: (v) => setState(() {
                            type = v ?? 'damage';
                          }),
                          decoration: const InputDecoration(labelText: 'النوع'),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'تفاصيل (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final item = itemCtrl.text.trim();
      if (item.isEmpty) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'DamageReports').doc(id).set({
        'date': Timestamp.fromDate(date),
        'dateKey': _dateKey(date),
        'item': item,
        'location': locationCtrl.text.trim(),
        'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
        'type': type,
        'status': 'open',
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    Future<void> addHandoverLog() async {
      if (schoolId.isEmpty) return;
      DateTime date = DateTime.now();
      final fromCtrl = TextEditingController();
      final toCtrl = TextEditingController();
      final itemCtrl = TextEditingController();
      final qtyCtrl = TextEditingController(text: '1');
      final notesCtrl = TextEditingController();

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: const Text('سجل استلام وتسليم'),
                content: SizedBox(
                  width: 440.w,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('التاريخ'),
                          subtitle: Text(DateFormat('yyyy-MM-dd').format(date)),
                          trailing: const Icon(Icons.date_range),
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: date,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2100),
                            );
                            if (picked != null) setState(() => date = picked);
                          },
                        ),
                        TextField(
                          controller: fromCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المستلم منه',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: toCtrl,
                          decoration: const InputDecoration(
                            labelText: 'المستلم إليه',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: itemCtrl,
                          decoration: const InputDecoration(labelText: 'الصنف'),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: qtyCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'الكمية',
                          ),
                        ),
                        SizedBox(height: 8.h),
                        TextField(
                          controller: notesCtrl,
                          decoration: const InputDecoration(
                            labelText: 'ملاحظات (اختياري)',
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('إلغاء'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('حفظ'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (ok != true) return;
      final from = fromCtrl.text.trim();
      final to = toCtrl.text.trim();
      final item = itemCtrl.text.trim();
      if (from.isEmpty || to.isEmpty || item.isEmpty) return;
      final id = const Uuid().v4();
      await _schoolSubCollection(schoolId, 'HandoverLogs').doc(id).set({
        'date': Timestamp.fromDate(date),
        'dateKey': _dateKey(date),
        'fromName': from,
        'toName': to,
        'item': item,
        'quantity': int.tryParse(qtyCtrl.text.trim()) ?? 0,
        'notes': notesCtrl.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'createdById': user?.id,
        'createdByName': user?.name,
      });
    }

    final recs = <String>[
      if (initialIndex == 0 && lowStockCount > 0)
        'يوصى برفع طلب مواد للأصناف التي وصلت حد التنبيه لضمان توفر الاحتياج.',
      if (initialIndex == 3 && openRequestsCount > 0)
        'راجع طلبات المواد المفتوحة واعتمد/استلم الطلبات مع توثيق الإغلاق.',
      if (initialIndex == 1 && damageOpenCount > 0)
        'وثّق حالات التلف/الفقد فورًا مع الإجراء المتخذ لتقليل الهدر.',
    ];

    Widget recommendationsCard() {
      if (recs.isEmpty) return const SizedBox.shrink();
      return Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توصيات ذكية',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade900,
                ),
              ),
              SizedBox(height: 8.h),
              ...recs.map(
                (t) => Padding(
                  padding: EdgeInsets.only(bottom: 6.h),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: color.shade700, size: 18),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          t,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey.shade800,
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
      );
    }

    return UnifiedPageScaffold(
      requiredDeputyType: 'school',
      showAppBar: false,
      title: title,
      floatingActionButton: schoolId.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: initialIndex == 0
                  ? addInventoryItem
                  : initialIndex == 1
                      ? addDamageReport
                      : initialIndex == 2
                          ? addHandoverLog
                          : addMaterialRequest,
              icon: const Icon(Icons.add),
              label: const Text('إضافة'),
            ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SchoolModuleHeader(
                title: title,
                description: description,
                icon: icon,
                color: color,
              ),
              SizedBox(height: 16.h),
              Row(
                children: [
                  Expanded(
                    child: _SchoolMetricCard(
                      label: 'العهد المسجلة',
                      value: inventoryItems.length.toString(),
                      icon: Icons.inventory_2,
                      color: Colors.blue.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label: 'محاضر التسليم',
                      value: handoversThisMonth.toString(),
                      icon: Icons.assignment_turned_in,
                      color: Colors.green.shade700,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: _SchoolMetricCard(
                      label:
                          initialIndex == 3 ? 'طلبات مفتوحة' : 'بلاغات تلف/فقد',
                      value: initialIndex == 3
                          ? openRequestsCount.toString()
                          : damageOpenCount.toString(),
                      icon: Icons.report_problem,
                      color: Colors.red.shade700,
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              if (recs.isNotEmpty) ...[
                recommendationsCard(),
                SizedBox(height: 16.h),
              ],
              Expanded(
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(16.w),
                    child: Builder(
                      builder: (context) {
                        if (schoolId.isEmpty) {
                          return Center(
                            child: Text(
                              'لا يمكن عرض البيانات بدون مدرسة مرتبطة بالحساب.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          );
                        }

                        if (initialIndex == 3) {
                          if (requests.isEmpty) {
                            return Center(
                              child: Text(
                                'لا توجد طلبات مواد.',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: requests.length.clamp(0, 120),
                            separatorBuilder: (_, __) => Divider(
                              height: 12.h,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final r = requests[index];
                              final item = _asString(r['item']);
                              final qty = _asInt(r['quantity']);
                              final st = _asString(r['status']).toLowerCase();
                              final isOpen = st != 'received' &&
                                  st != 'closed' &&
                                  st != 'rejected';
                              final pr = _asString(r['priority']).toLowerCase();
                              final prLabel = pr == 'urgent'
                                  ? 'عاجلة'
                                  : pr == 'high'
                                      ? 'عالية'
                                      : pr == 'low'
                                          ? 'منخفضة'
                                          : 'متوسطة';
                              final prColor = pr == 'urgent' || pr == 'high'
                                  ? Colors.red
                                  : pr == 'medium'
                                      ? Colors.orange
                                      : Colors.green;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: prColor.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: Icon(Icons.list_alt, color: prColor),
                                ),
                                title: Text(item.isEmpty ? '—' : item),
                                subtitle: Text(
                                  'الكمية: $qty • الأولوية: $prLabel',
                                ),
                                trailing: isOpen
                                    ? TextButton(
                                        onPressed: () async {
                                          await markRequestReceived(r);
                                        },
                                        child: const Text('تم الاستلام'),
                                      )
                                    : Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 4.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          st == 'rejected' ? 'مرفوض' : 'مستلم',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              );
                            },
                          );
                        }

                        if (initialIndex == 1) {
                          if (damages.isEmpty) {
                            return Center(
                              child: Text(
                                'لا توجد بلاغات تلف/فقد.',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: damages.length.clamp(0, 120),
                            separatorBuilder: (_, __) => Divider(
                              height: 12.h,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final d = damages[index];
                              final item = _asString(d['item']);
                              final qty = _asInt(d['quantity']);
                              final type = _asString(d['type']).toLowerCase();
                              final typeLabel = type == 'lost' ? 'فقد' : 'تلف';
                              final st = _asString(d['status']).toLowerCase();
                              final isOpen = st != 'closed';
                              final dt = _asDateTime(
                                d['date'] ?? d['createdAt'],
                              );
                              final dateStr = dt == null
                                  ? '—'
                                  : DateFormat('yyyy-MM-dd').format(dt);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.red.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: const Icon(
                                    Icons.report_problem,
                                    color: Colors.red,
                                  ),
                                ),
                                title: Text(item.isEmpty ? '—' : item),
                                subtitle: Text(
                                  '$dateStr • النوع: $typeLabel • الكمية: $qty',
                                ),
                                trailing: isOpen
                                    ? Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 4.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'مفتوح',
                                          style: TextStyle(
                                            color: Colors.orange.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      )
                                    : Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10.w,
                                          vertical: 4.h,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green.withValues(
                                            alpha: 0.08,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            999,
                                          ),
                                        ),
                                        child: Text(
                                          'مغلق',
                                          style: TextStyle(
                                            color: Colors.green.shade700,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                              );
                            },
                          );
                        }

                        if (initialIndex == 2) {
                          if (handovers.isEmpty) {
                            return Center(
                              child: Text(
                                'لا توجد محاضر استلام وتسليم.',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            );
                          }
                          return ListView.separated(
                            itemCount: handovers.length.clamp(0, 120),
                            separatorBuilder: (_, __) => Divider(
                              height: 12.h,
                              color: Colors.grey.shade200,
                            ),
                            itemBuilder: (context, index) {
                              final h = handovers[index];
                              final from = _asString(h['fromName']);
                              final to = _asString(h['toName']);
                              final item = _asString(h['item']);
                              final qty = _asInt(h['quantity']);
                              final dt = _asDateTime(
                                h['date'] ?? h['createdAt'],
                              );
                              final dateStr = dt == null
                                  ? '—'
                                  : DateFormat('yyyy-MM-dd').format(dt);
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.teal.withValues(
                                    alpha: 0.12,
                                  ),
                                  child: const Icon(
                                    Icons.handshake,
                                    color: Colors.teal,
                                  ),
                                ),
                                title: Text(item.isEmpty ? '—' : item),
                                subtitle: Text(
                                  '$dateStr • $from → $to • الكمية: $qty',
                                ),
                              );
                            },
                          );
                        }

                        final sorted = [...inventoryItems];
                        sorted.sort((a, b) {
                          final aLow = (() {
                            final qty = _asInt(a['quantity']);
                            final min = _asInt(a['minQuantity']);
                            return min > 0 && qty <= min;
                          })();
                          final bLow = (() {
                            final qty = _asInt(b['quantity']);
                            final min = _asInt(b['minQuantity']);
                            return min > 0 && qty <= min;
                          })();
                          if (aLow != bLow) return aLow ? -1 : 1;
                          return _asString(
                            a['name'],
                          ).compareTo(_asString(b['name']));
                        });

                        if (sorted.isEmpty) {
                          return Center(
                            child: Text(
                              'لا توجد عهد مسجلة.',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          itemCount: sorted.length.clamp(0, 200),
                          separatorBuilder: (_, __) => Divider(
                            height: 12.h,
                            color: Colors.grey.shade200,
                          ),
                          itemBuilder: (context, index) {
                            final i = sorted[index];
                            final name = _asString(i['name']);
                            final cat = _asString(i['category']);
                            final loc = _asString(i['location']);
                            final qty = _asInt(i['quantity']);
                            final min = _asInt(i['minQuantity']);
                            final low = min > 0 && qty <= min;
                            final cond = _asString(
                              i['condition'],
                            ).toLowerCase();
                            final condLabel = cond == 'needs_repair'
                                ? 'يحتاج صيانة'
                                : cond == 'damaged'
                                    ? 'تالف'
                                    : 'سليم';
                            final condColor = cond == 'damaged'
                                ? Colors.red
                                : cond == 'needs_repair'
                                    ? Colors.orange
                                    : Colors.green;
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    (low ? Colors.red : Colors.blue).withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  Icons.inventory_2,
                                  color: low ? Colors.red : Colors.blue,
                                ),
                              ),
                              title: Text(name.isEmpty ? '—' : name),
                              subtitle: Text(
                                [
                                  if (cat.isNotEmpty) cat,
                                  if (loc.isNotEmpty) loc,
                                  'الكمية: $qty${min > 0 ? ' (حد: $min)' : ''}',
                                  'الحالة: $condLabel',
                                ].join(' • '),
                              ),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 10.w,
                                  vertical: 4.h,
                                ),
                                decoration: BoxDecoration(
                                  color: condColor.withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  low ? 'تنبيه' : condLabel,
                                  style: TextStyle(
                                    color: low ? Colors.red : condColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
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

class _SchoolModuleHeader extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final MaterialColor color;

  const _SchoolModuleHeader({
    required this.title,
    required this.description,
    required this.icon,
    this.color = Colors.teal,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20.r),
        gradient: LinearGradient(
          colors: [color.shade700, color.shade400],
          begin: Alignment.topRight,
          end: Alignment.bottomLeft,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.25),
            blurRadius: 12.r,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48.w,
            height: 48.w,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Icon(icon, color: Colors.white, size: 28.sp),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 6.h),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 13.sp,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SchoolMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _SchoolMetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 1,
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            Container(
              width: 40.w,
              height: 40.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14.r),
              ),
              child: Icon(icon, color: color, size: 22.sp),
            ),
            SizedBox(width: 10.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.grey.shade700,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
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
}

Color _priorityColor(MaintenancePriority priority) {
  switch (priority) {
    case MaintenancePriority.critical:
      return Colors.red;
    case MaintenancePriority.high:
      return Colors.deepOrange;
    case MaintenancePriority.medium:
      return Colors.amber;
    case MaintenancePriority.low:
    default:
      return Colors.blueGrey;
  }
}

String _statusLabel(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.pending:
      return 'قيد التقييم';
    case MaintenanceStatus.inProgress:
      return 'قيد المعالجة';
    case MaintenanceStatus.completed:
      return 'مكتمل';
    case MaintenanceStatus.rejected:
      return 'مرفوض';
    case MaintenanceStatus.overdue:
      return 'متأخر';
  }
}

Color _statusColor(MaintenanceStatus status) {
  switch (status) {
    case MaintenanceStatus.pending:
      return Colors.blueGrey;
    case MaintenanceStatus.inProgress:
      return Colors.blue;
    case MaintenanceStatus.completed:
      return Colors.green;
    case MaintenanceStatus.rejected:
      return Colors.red.shade700;
    case MaintenanceStatus.overdue:
      return Colors.orange.shade800;
  }
}

Widget _buildSafetyTile(
  String title,
  String subtitle,
  IconData icon,
  Color color,
) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 6.h),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8.r),
      color: color.withValues(alpha: 0.05),
      border: Border.all(color: color.withValues(alpha: 0.15), width: 0.8),
    ),
    child: Row(
      children: [
        Container(
          width: 18.w,
          height: 18.w,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: 0.12),
          ),
          child: Icon(icon, color: color, size: 11.sp),
        ),
        SizedBox(width: 5.w),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade900,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 1.h),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 10.sp,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                  height: 1.2,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
