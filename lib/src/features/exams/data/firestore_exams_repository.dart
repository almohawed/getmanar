import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'dart:async';
import '../../attendance/data/student_attendance_repository.dart';
import '../../attendance/domain/student_attendance.dart';

class ExamSchedule {
  final String id;
  final String termId;
  final String stage;
  final String grade;
  final String classId;
  final String subjectId;
  final String teacherId;
  final String examType;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String roomId;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool noConflicts;
  final bool perDayLimitOk;
  final bool roomOk;
  final bool teacherOk;

  ExamSchedule({
    required this.id,
    required this.termId,
    required this.stage,
    required this.grade,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.examType,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    required this.noConflicts,
    required this.perDayLimitOk,
    required this.roomOk,
    required this.teacherOk,
  });

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'stage': stage,
      'grade': grade,
      'classId': classId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'examType': examType,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'startTime': startTime,
      'endTime': endTime,
      'roomId': roomId,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'validationFlags': {
        'noConflicts': noConflicts,
        'perDayLimitOk': perDayLimitOk,
        'roomOk': roomOk,
        'teacherOk': teacherOk,
      },
    };
  }

  factory ExamSchedule.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    final vf = (m['validationFlags'] as Map?) ?? {};
    return ExamSchedule(
      id: d.id,
      termId: m['termId'] ?? '',
      stage: m['stage'] ?? '',
      grade: m['grade'] ?? '',
      classId: m['classId'] ?? '',
      subjectId: m['subjectId'] ?? '',
      teacherId: m['teacherId'] ?? '',
      examType: m['examType'] ?? 'final',
      date: (m['date'] as Timestamp).toDate(),
      startTime: m['startTime'] ?? '08:00',
      endTime: m['endTime'] ?? '09:00',
      roomId: m['roomId'] ?? '',
      status: m['status'] ?? 'draft',
      createdBy: m['createdBy'] ?? '',
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp).toDate(),
      noConflicts: vf['noConflicts'] == true,
      perDayLimitOk: vf['perDayLimitOk'] == true,
      roomOk: vf['roomOk'] == true,
      teacherOk: vf['teacherOk'] == true,
    );
  }
}

class ExamCommittee {
  final String id;
  final String termId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String roomId;
  final String supervisorId;
  final String? backupSupervisorId;
  final List<String> assignedClassIds;
  final String status;
  final String createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  ExamCommittee({
    required this.id,
    required this.termId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.roomId,
    required this.supervisorId,
    required this.backupSupervisorId,
    required this.assignedClassIds,
    required this.status,
    required this.createdBy,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'date': Timestamp.fromDate(date),
      'startTime': startTime,
      'endTime': endTime,
      'roomId': roomId,
      'supervisorId': supervisorId,
      'backupSupervisorId': backupSupervisorId,
      'assignedClassIds': assignedClassIds,
      'status': status,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory ExamCommittee.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ExamCommittee(
      id: d.id,
      termId: m['termId'] ?? '',
      date: (m['date'] as Timestamp).toDate(),
      startTime: m['startTime'] ?? '08:00',
      endTime: m['endTime'] ?? '09:00',
      roomId: m['roomId'] ?? '',
      supervisorId: m['supervisorId'] ?? '',
      backupSupervisorId: m['backupSupervisorId'],
      assignedClassIds:
          (m['assignedClassIds'] as List?)?.map((e) => e.toString()).toList() ??
          [],
      status: m['status'] ?? 'active',
      createdBy: m['createdBy'] ?? '',
      createdAt: (m['createdAt'] as Timestamp).toDate(),
      updatedAt: (m['updatedAt'] as Timestamp).toDate(),
    );
  }
}

class ExamGradesTrack {
  final String id;
  final String termId;
  final String classId;
  final String subjectId;
  final String teacherId;
  final int expectedCount;
  final int enteredCount;
  final double completionRate;
  final String status;
  final int escalationLevel;
  final DateTime lastUpdateAt;
  final DateTime dueDate;

  ExamGradesTrack({
    required this.id,
    required this.termId,
    required this.classId,
    required this.subjectId,
    required this.teacherId,
    required this.expectedCount,
    required this.enteredCount,
    required this.completionRate,
    required this.status,
    required this.escalationLevel,
    required this.lastUpdateAt,
    required this.dueDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'classId': classId,
      'subjectId': subjectId,
      'teacherId': teacherId,
      'expectedCount': expectedCount,
      'enteredCount': enteredCount,
      'completionRate': completionRate,
      'status': status,
      'escalationLevel': escalationLevel,
      'lastUpdateAt': Timestamp.fromDate(lastUpdateAt),
      'dueDate': Timestamp.fromDate(dueDate),
    };
  }

  factory ExamGradesTrack.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ExamGradesTrack(
      id: d.id,
      termId: m['termId'] ?? '',
      classId: m['classId'] ?? '',
      subjectId: m['subjectId'] ?? '',
      teacherId: m['teacherId'] ?? '',
      expectedCount: (m['expectedCount'] ?? 0) is num
          ? (m['expectedCount'] as num).toInt()
          : int.tryParse(m['expectedCount']?.toString() ?? '0') ?? 0,
      enteredCount: (m['enteredCount'] ?? 0) is num
          ? (m['enteredCount'] as num).toInt()
          : int.tryParse(m['enteredCount']?.toString() ?? '0') ?? 0,
      completionRate: (m['completionRate'] ?? 0.0) is num
          ? (m['completionRate'] as num).toDouble()
          : double.tryParse(m['completionRate']?.toString() ?? '0') ?? 0.0,
      status: m['status'] ?? 'incomplete',
      escalationLevel: (m['escalationLevel'] ?? 0) is num
          ? (m['escalationLevel'] as num).toInt()
          : int.tryParse(m['escalationLevel']?.toString() ?? '0') ?? 0,
      lastUpdateAt: (m['lastUpdateAt'] as Timestamp).toDate(),
      dueDate: (m['dueDate'] as Timestamp).toDate(),
    );
  }

  factory ExamGradesTrack.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
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
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt;
        final n = int.tryParse(v);
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(n);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ExamGradesTrack(
      id: id,
      termId: (m['termId'] ?? '').toString(),
      classId: (m['classId'] ?? '').toString(),
      subjectId: (m['subjectId'] ?? '').toString(),
      teacherId: (m['teacherId'] ?? '').toString(),
      expectedCount: (m['expectedCount'] ?? 0) is num
          ? (m['expectedCount'] as num).toInt()
          : int.tryParse(m['expectedCount']?.toString() ?? '0') ?? 0,
      enteredCount: (m['enteredCount'] ?? 0) is num
          ? (m['enteredCount'] as num).toInt()
          : int.tryParse(m['enteredCount']?.toString() ?? '0') ?? 0,
      completionRate: (m['completionRate'] ?? 0.0) is num
          ? (m['completionRate'] as num).toDouble()
          : double.tryParse(m['completionRate']?.toString() ?? '0') ?? 0.0,
      status: (m['status'] ?? 'incomplete').toString(),
      escalationLevel: (m['escalationLevel'] ?? 0) is num
          ? (m['escalationLevel'] as num).toInt()
          : int.tryParse(m['escalationLevel']?.toString() ?? '0') ?? 0,
      lastUpdateAt: parseDate(m['lastUpdateAt']),
      dueDate: parseDate(m['dueDate']),
    );
  }
}

class ExamAttendanceRecord {
  final String id;
  final String termId;
  final String scheduleId;
  final String studentId;
  final String classId;
  final String subjectId;
  final String status;
  final String? excuseDocUrl;
  final String recordedBy;
  final DateTime recordedAt;

  ExamAttendanceRecord({
    required this.id,
    required this.termId,
    required this.scheduleId,
    required this.studentId,
    required this.classId,
    required this.subjectId,
    required this.status,
    required this.excuseDocUrl,
    required this.recordedBy,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'scheduleId': scheduleId,
      'studentId': studentId,
      'classId': classId,
      'subjectId': subjectId,
      'status': status,
      'excuseDocUrl': excuseDocUrl,
      'recordedBy': recordedBy,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  factory ExamAttendanceRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> d,
  ) {
    final m = d.data()!;
    return ExamAttendanceRecord(
      id: d.id,
      termId: m['termId'] ?? '',
      scheduleId: m['scheduleId'] ?? '',
      studentId: m['studentId'] ?? '',
      classId: m['classId'] ?? '',
      subjectId: m['subjectId'] ?? '',
      status: m['status'] ?? 'present',
      excuseDocUrl: m['excuseDocUrl'],
      recordedBy: m['recordedBy'] ?? '',
      recordedAt: (m['recordedAt'] as Timestamp).toDate(),
    );
  }

  factory ExamAttendanceRecord.fromMap(String id, Map<String, dynamic> m) {
    DateTime parseDate(dynamic v) {
      if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
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
      if (v is String) {
        final dt = DateTime.tryParse(v);
        if (dt != null) return dt;
        final n = int.tryParse(v);
        if (n != null) return DateTime.fromMillisecondsSinceEpoch(n);
      }
      return DateTime.fromMillisecondsSinceEpoch(0);
    }

    return ExamAttendanceRecord(
      id: id,
      termId: (m['termId'] ?? '').toString(),
      scheduleId: (m['scheduleId'] ?? '').toString(),
      studentId: (m['studentId'] ?? '').toString(),
      classId: (m['classId'] ?? '').toString(),
      subjectId: (m['subjectId'] ?? '').toString(),
      status: (m['status'] ?? 'present').toString(),
      excuseDocUrl: (m['excuseDocUrl'] ?? '').toString().trim().isEmpty
          ? null
          : (m['excuseDocUrl'] ?? '').toString(),
      recordedBy: (m['recordedBy'] ?? '').toString(),
      recordedAt: parseDate(m['recordedAt']),
    );
  }
}

class ExamViolation {
  final String id;
  final String termId;
  final String studentId;
  final String scheduleId;
  final String violationType;
  final String actionTaken;
  final String recordedBy;
  final DateTime recordedAt;

  ExamViolation({
    required this.id,
    required this.termId,
    required this.studentId,
    required this.scheduleId,
    required this.violationType,
    required this.actionTaken,
    required this.recordedBy,
    required this.recordedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'termId': termId,
      'studentId': studentId,
      'scheduleId': scheduleId,
      'violationType': violationType,
      'actionTaken': actionTaken,
      'recordedBy': recordedBy,
      'recordedAt': Timestamp.fromDate(recordedAt),
    };
  }

  factory ExamViolation.fromDoc(DocumentSnapshot<Map<String, dynamic>> d) {
    final m = d.data()!;
    return ExamViolation(
      id: d.id,
      termId: m['termId'] ?? '',
      studentId: m['studentId'] ?? '',
      scheduleId: m['scheduleId'] ?? '',
      violationType: m['violationType'] ?? '',
      actionTaken: m['actionTaken'] ?? '',
      recordedBy: m['recordedBy'] ?? '',
      recordedAt: (m['recordedAt'] as Timestamp).toDate(),
    );
  }
}

class ExamsValidationResult {
  final bool ok;
  final List<String> errors;
  final bool roomOk;
  final bool teacherOk;
  final bool perDayLimitOk;

  ExamsValidationResult({
    required this.ok,
    required this.errors,
    required this.roomOk,
    required this.teacherOk,
    required this.perDayLimitOk,
  });
}

class FirestoreExamsRepository {
  final FirebaseFirestore _firestore;
  final StudentAttendanceRepository _attendanceRepo;
  FirestoreExamsRepository(this._firestore, this._attendanceRepo);

  Stream<List<ExamSchedule>> watchSchedules(
    String schoolId, {
    String? termId,
    String? classId,
    String? subjectId,
    DateTime? date,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules');
    if (termId != null && termId.isNotEmpty)
      q = q.where('termId', isEqualTo: termId);
    if (classId != null && classId.isNotEmpty)
      q = q.where('classId', isEqualTo: classId);
    if (subjectId != null && subjectId.isNotEmpty) {
      q = q.where('subjectId', isEqualTo: subjectId);
    }
    if (date != null) {
      final d = DateTime(date.year, date.month, date.day);
      q = q.where('date', isEqualTo: Timestamp.fromDate(d));
    }
    return q
        .orderBy('date')
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(ExamSchedule.fromDoc).toList());
  }

  Stream<List<ExamCommittee>> watchCommittees(
    String schoolId, {
    String? termId,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamCommittees');
    if (termId != null && termId.isNotEmpty) {
      q = q.where('termId', isEqualTo: termId);
    }
    return q
        .orderBy('date')
        .orderBy('startTime')
        .snapshots()
        .map((s) => s.docs.map(ExamCommittee.fromDoc).toList());
  }

  Stream<List<ExamGradesTrack>> watchGradesTracking(
    String schoolId, {
    String? termId,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking');
    if (termId != null && termId.isNotEmpty) {
      q = q.where('termId', isEqualTo: termId);
    }
    q = q.orderBy('completionRate');
    return () async* {
      try {
        final initial = await q.get().timeout(const Duration(seconds: 12));
        yield initial.docs.map(ExamGradesTrack.fromDoc).toList();
      } on TimeoutException {
        yield const <ExamGradesTrack>[];
      }
      yield* q.snapshots().map(
        (s) => s.docs.map(ExamGradesTrack.fromDoc).toList(),
      );
    }();
  }

  Future<void> recalcGradesTracking(String schoolId, String trackId) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .doc(trackId);
    final snap = await doc.get();
    final m = snap.data() ?? {};
    final classId = m['classId'] ?? '';
    final subjectId = m['subjectId'] ?? '';
    final termId = m['termId'] ?? '';
    final studentsSnap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .where('classId', isEqualTo: classId)
        .get();
    final expected = studentsSnap.docs.length;
    final entriesSnap = await doc
        .collection('Entries')
        .where('termId', isEqualTo: termId)
        .where('subjectId', isEqualTo: subjectId)
        .get();
    final entered = entriesSnap.docs.length;
    final rate = expected == 0 ? 0.0 : (entered * 100.0) / expected;
    final status = rate >= 100.0
        ? 'complete'
        : DateTime.now().isAfter((m['dueDate'] as Timestamp).toDate())
        ? 'late'
        : 'incomplete';
    await doc.update({
      'expectedCount': expected,
      'enteredCount': entered,
      'completionRate': rate,
      'status': status,
      'lastUpdateAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  Future<String> createSchedule(
    String schoolId, {
    required Map<String, dynamic> payload,
    required String createdBy,
    int maxPerDayPerClass = 2,
    bool preventTwoCoreSameDay = false,
  }) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .doc();
    final id = doc.id;
    final now = DateTime.now();
    final data = {
      ...payload,
      'id': id,
      'status': 'draft',
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
      'validationFlags': {
        'noConflicts': true,
        'perDayLimitOk': true,
        'roomOk': true,
        'teacherOk': true,
      },
    };
    await doc.set(data);
    return id;
  }

  Future<void> publishSchedule(String schoolId, String scheduleId) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .doc(scheduleId)
        .update({'status': 'published'});
  }

  Future<void> amendSchedule(
    String schoolId,
    String scheduleId, {
    required Map<String, dynamic> changes,
    required String reason,
    required String actorId,
  }) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .doc(scheduleId);
    await doc.update({
      ...changes,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'lastAmendment': {
        'reason': reason,
        'actorId': actorId,
        'at': Timestamp.fromDate(DateTime.now()),
      },
    });
  }

  Future<void> deleteSchedule(String schoolId, String scheduleId) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .doc(scheduleId)
        .delete();
  }

  Future<List<ExamSchedule>> getRoomConflicts(
    String schoolId,
    String roomId,
    DateTime date,
  ) async {
    final d = DateTime(date.year, date.month, date.day);
    final start = Timestamp.fromDate(d);
    final end = Timestamp.fromDate(d.add(const Duration(days: 1)));
    final snap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .where('roomId', isEqualTo: roomId)
        .where('date', isGreaterThanOrEqualTo: start)
        .where('date', isLessThan: end)
        .get();
    return snap.docs.map(ExamSchedule.fromDoc).toList();
  }

  Stream<List<ExamSchedule>> watchSchedulesForStudent(
    String schoolId,
    String studentId,
  ) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .where('status', isEqualTo: 'published')
        .snapshots()
        .map((s) => s.docs.map(ExamSchedule.fromDoc).toList());
  }

  Stream<List<ExamSchedule>> watchSchedulesForTeacher(
    String schoolId,
    String teacherId,
  ) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamSchedules')
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((s) => s.docs.map(ExamSchedule.fromDoc).toList());
  }

  Future<String> createCommittee(
    String schoolId, {
    required Map<String, dynamic> payload,
    required String createdBy,
  }) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamCommittees')
        .doc();
    final id = doc.id;
    final now = DateTime.now();
    final data = {
      ...payload,
      'id': id,
      'status': 'active',
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(now),
      'updatedAt': Timestamp.fromDate(now),
    };
    await doc.set(data);
    return id;
  }

  Stream<List<ExamAttendanceRecord>> watchExamAttendance(
    String schoolId, {
    String? termId,
    String? classId,
    String? subjectId,
    DateTime? date,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamAttendance');
    if (termId != null && termId.isNotEmpty)
      q = q.where('termId', isEqualTo: termId);
    if (classId != null && classId.isNotEmpty)
      q = q.where('classId', isEqualTo: classId);
    if (subjectId != null && subjectId.isNotEmpty) {
      q = q.where('subjectId', isEqualTo: subjectId);
    }
    if (date != null) {
      final d = DateTime(date.year, date.month, date.day);
      final start = Timestamp.fromDate(d);
      final end = Timestamp.fromDate(d.add(const Duration(days: 1)));
      q = q
          .where('recordedAt', isGreaterThanOrEqualTo: start)
          .where('recordedAt', isLessThan: end);
    }
    return q
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ExamAttendanceRecord.fromDoc).toList());
  }

  Future<void> recordExamAttendance(
    String schoolId, {
    required ExamAttendanceRecord record,
  }) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamAttendance')
        .doc(record.id);
    await doc.set(record.toMap());
    if (record.status == 'absent_unexcused') {
      final sa = StudentAttendance(
        id: const Uuid().v4(),
        schoolId: schoolId,
        studentId: record.studentId,
        studentName: record.studentId,
        classId: record.classId,
        date: record.recordedAt,
        status: StudentAttendanceStatus.absent,
        recordedBy: record.recordedBy,
      );
      await _attendanceRepo.saveStudentAttendance([sa]);
    }
  }

  Future<void> addGradeEntry(
    String schoolId,
    String trackId, {
    required String studentId,
    required String subjectId,
    required String termId,
    required String teacherId,
    required double score,
  }) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .doc(trackId)
        .collection('Entries')
        .doc(studentId);
    await doc.set({
      'studentId': studentId,
      'subjectId': subjectId,
      'termId': termId,
      'teacherId': teacherId,
      'score': score,
      'createdAt': Timestamp.fromDate(DateTime.now()),
    });
    await recalcGradesTracking(schoolId, trackId);
  }

  Stream<List<ExamViolation>> watchExamViolations(
    String schoolId, {
    String? termId,
  }) {
    Query<Map<String, dynamic>> q = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamViolations');
    if (termId != null && termId.isNotEmpty)
      q = q.where('termId', isEqualTo: termId);
    return q
        .orderBy('recordedAt', descending: true)
        .snapshots()
        .map((s) => s.docs.map(ExamViolation.fromDoc).toList());
  }

  Future<void> recordExamViolation(String schoolId, ExamViolation v) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamViolations')
        .doc(v.id)
        .set(v.toMap());
  }

  Future<List<ExamGradesTrack>> getClassTracks(
    String schoolId,
    String classId,
    String teacherId,
  ) async {
    final snap = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .where('classId', isEqualTo: classId)
        .where('teacherId', isEqualTo: teacherId)
        .get();
    return snap.docs.map(ExamGradesTrack.fromDoc).toList();
  }

  Future<Map<String, double>> getTrackScores(
    String schoolId,
    String trackId,
  ) async {
    final doc = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ExamGradesTracking')
        .doc(trackId);
    final snap = await doc.collection('Entries').get();
    final result = <String, double>{};
    for (final e in snap.docs) {
      final m = e.data();
      final studentId = m['studentId']?.toString() ?? e.id;
      final rawScore = m['score'];
      double score = 0.0;
      if (rawScore is num) {
        score = rawScore.toDouble();
      } else if (rawScore is String) {
        score = double.tryParse(rawScore) ?? 0.0;
      }
      result[studentId] = score;
    }
    return result;
  }

  int _parseHm(String hm) {
    final parts = hm.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
    return h * 60 + m;
  }
}

final examsRepositoryProvider = Provider<FirestoreExamsRepository>((ref) {
  final firestore = FirebaseFirestore.instance;
  final attendanceRepo = ref.read(studentAttendanceRepositoryProvider);
  return FirestoreExamsRepository(firestore, attendanceRepo);
});
