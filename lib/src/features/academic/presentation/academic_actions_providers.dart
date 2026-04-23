import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

Future<String?> _repairSchoolId() async {
  try {
    final res = await FirebaseFunctions.instance
        .httpsCallable('repairCurrentUserLink')
        .call({});
    final d = res.data;
    if (d is Map && d['schoolId'] != null) {
      final sid = d['schoolId'].toString().trim();
      return sid.isEmpty ? null : sid;
    }
  } catch (_) {}
  return null;
}

class AcademicAction {
  final String id;
  final String type;
  final String title;
  final String description;
  final String status;
  final String? classId;
  final String? subjectId;
  final String? studentId;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const AcademicAction({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.status,
    this.classId,
    this.subjectId,
    this.studentId,
    this.createdAt,
    this.updatedAt,
  });

  factory AcademicAction.fromMap(String id, Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is Timestamp) return v.toDate();
      if (v is Map) {
        final sec = v['_seconds'] ?? v['seconds'];
        final nanos = v['_nanoseconds'] ?? v['nanoseconds'] ?? 0;
        final s = sec is num ? sec.toInt() : int.tryParse(sec.toString());
        final n = nanos is num ? nanos.toInt() : int.tryParse(nanos.toString());
        if (s != null) {
          return DateTime.fromMillisecondsSinceEpoch(
            (s * 1000) + (((n ?? 0) / 1000000).round()),
          );
        }
      }
      if (v is num) return DateTime.fromMillisecondsSinceEpoch(v.toInt());
      if (v is String) return DateTime.tryParse(v);
      return null;
    }

    String? optString(dynamic v) {
      final s = (v ?? '').toString().trim();
      return s.isEmpty ? null : s;
    }

    return AcademicAction(
      id: id,
      type: (m['type'] ?? '').toString(),
      title: (m['title'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      status: (m['status'] ?? 'open').toString(),
      classId: optString(m['classId']),
      subjectId: optString(m['subjectId']),
      studentId: optString(m['studentId']),
      createdAt: parseDate(m['createdAt']),
      updatedAt: parseDate(m['updatedAt']),
    );
  }
}

class AcademicActionsFilters {
  final String? type;
  final String? status;

  const AcademicActionsFilters({this.type, this.status});

  @override
  bool operator ==(Object other) {
    return other is AcademicActionsFilters &&
        other.type == type &&
        other.status == status;
  }

  @override
  int get hashCode => Object.hash(type, status);
}

class UpsertAcademicActionParams {
  final String? id;
  final String type;
  final String title;
  final String description;
  final String status;
  final String? classId;
  final String? subjectId;
  final String? studentId;

  const UpsertAcademicActionParams({
    this.id,
    required this.type,
    required this.title,
    required this.description,
    this.status = 'open',
    this.classId,
    this.subjectId,
    this.studentId,
  });
}

final academicActionsProvider = FutureProvider.family
    .autoDispose<List<AcademicAction>, AcademicActionsFilters>((
      ref,
      filters,
    ) async {
      final user = ref.watch(authStateProvider).value;
      var schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        final repaired = await _repairSchoolId();
        schoolId = (repaired ?? '').trim();
      }
      if (schoolId.isEmpty) throw Exception('School ID مفقود');

      final callable = FirebaseFunctions.instance.httpsCallable(
        'listAcademicActionsForSchool',
      );
      final res = await callable
          .call({
            'schoolId': schoolId,
            if (filters.type?.isNotEmpty == true) 'type': filters.type,
            if (filters.status?.isNotEmpty == true) 'status': filters.status,
          })
          .timeout(const Duration(seconds: 15));
      final data = res.data;
      if (data is Map && data['items'] is List) {
        final list = (data['items'] as List).whereType<Map>().map((m) {
          final mm = Map<String, dynamic>.from(m);
          final id = (mm['id'] ?? '').toString();
          mm.remove('id');
          return AcademicAction.fromMap(id, mm);
        }).toList();
        list.sort((a, b) {
          final ad =
              a.updatedAt ??
              a.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          final bd =
              b.updatedAt ??
              b.createdAt ??
              DateTime.fromMillisecondsSinceEpoch(0);
          return bd.compareTo(ad);
        });
        return list;
      }
      return const <AcademicAction>[];
    });

final upsertAcademicActionProvider = FutureProvider.family
    .autoDispose<void, UpsertAcademicActionParams>((ref, p) async {
      final user = ref.read(authStateProvider).value;
      var schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) {
        final repaired = await _repairSchoolId();
        schoolId = (repaired ?? '').trim();
      }
      if (schoolId.isEmpty) throw Exception('School ID مفقود');
      final callable = FirebaseFunctions.instance.httpsCallable(
        'upsertAcademicAction',
      );
      await callable.call({
        'schoolId': schoolId,
        if (p.id?.isNotEmpty == true) 'id': p.id,
        'type': p.type,
        'title': p.title,
        'description': p.description,
        'status': p.status,
        if (p.classId?.isNotEmpty == true) 'classId': p.classId,
        if (p.subjectId?.isNotEmpty == true) 'subjectId': p.subjectId,
        if (p.studentId?.isNotEmpty == true) 'studentId': p.studentId,
      });
    });
