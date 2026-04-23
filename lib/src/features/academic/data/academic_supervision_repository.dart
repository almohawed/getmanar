import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';

class CurriculumProgress {
  final String classId;
  final String subjectId;
  final int coveredUnits;
  final int expectedUnits;
  final DateTime? updatedAt;
  final String? teacherId;
  final String? className;
  final String? subjectName;

  CurriculumProgress({
    required this.classId,
    required this.subjectId,
    required this.coveredUnits,
    required this.expectedUnits,
    this.updatedAt,
    this.teacherId,
    this.className,
    this.subjectName,
  });

  factory CurriculumProgress.fromMap(Map<String, dynamic> map) {
    return CurriculumProgress(
      classId: map['classId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      coveredUnits: (map['coveredUnits'] ?? 0) is num
          ? (map['coveredUnits'] as num).toInt()
          : int.tryParse(map['coveredUnits']?.toString() ?? '0') ?? 0,
      expectedUnits: (map['expectedUnits'] ?? 0) is num
          ? (map['expectedUnits'] as num).toInt()
          : int.tryParse(map['expectedUnits']?.toString() ?? '0') ?? 0,
      updatedAt: (map['updatedAt'] is Timestamp)
          ? (map['updatedAt'] as Timestamp).toDate()
          : (map['updatedAt'] is String
                ? DateTime.tryParse(map['updatedAt'])
                : null),
      teacherId: map['teacherId'],
      className: map['className'],
      subjectName: map['subjectName'],
    );
  }
}

class LessonPrepRecord {
  final String id;
  final String teacherId;
  final String classId;
  final String subjectId;
  final DateTime date;
  final bool prepared;
  final String? notes;

  LessonPrepRecord({
    required this.id,
    required this.teacherId,
    required this.classId,
    required this.subjectId,
    required this.date,
    required this.prepared,
    this.notes,
  });

  factory LessonPrepRecord.fromMap(Map<String, dynamic> map, String id) {
    return LessonPrepRecord(
      id: id,
      teacherId: map['teacherId'] ?? '',
      classId: map['classId'] ?? '',
      subjectId: map['subjectId'] ?? '',
      date: (map['date'] is Timestamp)
          ? (map['date'] as Timestamp).toDate()
          : (() {
              if (map['date'] is String) {
                final parsed = DateTime.tryParse(map['date']);
                return parsed ?? DateTime.now();
              }
              return DateTime.now();
            })(),
      prepared: map['prepared'] == true,
      notes: map['notes'],
    );
  }
}

class AcademicAlert {
  final String id;
  final String title;
  final String? description;
  final String severity;
  final String status;
  final DateTime createdAt;

  AcademicAlert({
    required this.id,
    required this.title,
    this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
  });

  factory AcademicAlert.fromMap(Map<String, dynamic> map, String id) {
    return AcademicAlert(
      id: id,
      title: map['title'] ?? '',
      description: map['description'],
      severity: map['severity'] ?? 'low',
      status: map['status'] ?? 'open',
      createdAt: (map['createdAt'] is Timestamp)
          ? (map['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }
}

class AcademicSupervisionRepository {
  final FirebaseFirestore _firestore;

  AcademicSupervisionRepository(this._firestore);

  Stream<List<CurriculumProgress>> watchCurriculumProgress(
    String schoolId, {
    String? classId,
    String? subjectId,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CurriculumProgress');
    if (classId != null && classId.isNotEmpty) {
      q = q.where('classId', isEqualTo: classId);
    }
    if (subjectId != null && subjectId.isNotEmpty) {
      q = q.where('subjectId', isEqualTo: subjectId);
    }
    return () async* {
      try {
        final initial = await q.get().timeout(const Duration(seconds: 12));
        yield initial.docs
            .map((d) => CurriculumProgress.fromMap(d.data()))
            .toList();
      } on TimeoutException {
        yield const <CurriculumProgress>[];
      }

      yield* q.snapshots().map(
        (snapshot) => snapshot.docs
            .map((d) => CurriculumProgress.fromMap(d.data()))
            .toList(),
      );
    }();
  }

  Stream<List<LessonPrepRecord>> watchLessonPrepRange(
    String schoolId, {
    required DateTime from,
    required DateTime to,
    String? teacherId,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('LessonPrepRecords')
        .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('date', isLessThanOrEqualTo: Timestamp.fromDate(to));
    if (teacherId != null && teacherId.isNotEmpty) {
      q = q.where('teacherId', isEqualTo: teacherId);
    }
    return q.snapshots().map(
      (snapshot) => snapshot.docs
          .map((d) => LessonPrepRecord.fromMap(d.data(), d.id))
          .toList(),
    );
  }

  Future<List<Map<String, dynamic>>> getPacingDelays(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CurriculumProgress')
        .get();
    final items = snapshot.docs
        .map((d) => CurriculumProgress.fromMap(d.data()))
        .map((p) {
          final int delay = (p.expectedUnits - p.coveredUnits);
          return {
            'classId': p.classId,
            'subjectId': p.subjectId,
            'covered': p.coveredUnits,
            'expected': p.expectedUnits,
            'delay': delay,
            'className': p.className ?? p.classId,
            'subjectName': p.subjectName ?? p.subjectId,
          };
        })
        .where((x) => (x['delay'] as int) > 0)
        .toList();
    items.sort((a, b) => (b['delay'] as int).compareTo(a['delay'] as int));
    return items;
  }

  Stream<List<AcademicAlert>> watchAcademicAlerts(
    String schoolId, {
    String? severity,
    String? status,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('AcademicAlerts')
        .orderBy('createdAt', descending: true);
    if (severity != null && severity.isNotEmpty) {
      q = q.where('severity', isEqualTo: severity);
    }
    if (status != null && status.isNotEmpty) {
      q = q.where('status', isEqualTo: status);
    }
    return q.snapshots().map(
      (s) => s.docs.map((d) => AcademicAlert.fromMap(d.data(), d.id)).toList(),
    );
  }
}
