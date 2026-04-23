import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/student_attendance.dart';
import 'student_attendance_repository.dart';

class FirestoreStudentAttendanceRepository
    implements StudentAttendanceRepository {
  final FirebaseFirestore _firestore;

  FirestoreStudentAttendanceRepository(this._firestore);

  String _dateKey(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  @override
  Future<List<StudentAttendance>> getStudentAttendance(
    String classId,
    DateTime date,
  ) async {
    final key = _dateKey(date);
    final query = await _firestore
        .collection('StudentAttendance')
        .where('dateKey', isEqualTo: key)
        .get();

    final list =
        query.docs.map((d) => StudentAttendance.fromMap(d.data())).toList();
    return list.where((r) => r.classId == classId).toList();
  }

  @override
  Future<void> saveStudentAttendance(
    List<StudentAttendance> attendanceList,
  ) async {
    final batch = _firestore.batch();
    for (var record in attendanceList) {
      final data = record.toMap();
      final docRef = _firestore.collection('StudentAttendance').doc(record.id);
      batch.set(docRef, data);

      final schoolId = record.schoolId.trim();
      if (schoolId.isNotEmpty) {
        final scopedRef = _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('StudentAttendance')
            .doc(record.id);
        batch.set(scopedRef, data);
      }
    }
    await batch.commit();
  }

  @override
  Future<List<StudentAttendance>> getStudentAttendanceHistory(
    String studentId,
    String schoolId,
  ) async {
    // We removed orderBy('date') to avoid needing a composite index.
    // We will sort client-side instead.
    final query = await _firestore
        .collection('StudentAttendance')
        .where('schoolId', isEqualTo: schoolId)
        .where('studentId', isEqualTo: studentId)
        .get();

    final list =
        query.docs.map((d) => StudentAttendance.fromMap(d.data())).toList();

    // Client-side sorting
    list.sort((a, b) => b.date.compareTo(a.date));

    return list;
  }

  @override
  Stream<List<StudentAttendance>> watchDailyAttendance(
    String schoolId,
    DateTime date,
  ) {
    final key = _dateKey(date);
    final schoolDateKey = '${schoolId}_$key';
    return _firestore
        .collection('StudentAttendance')
        .where('schoolDateKey', isEqualTo: schoolDateKey)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((d) => StudentAttendance.fromMap(d.data()))
                  .toList(),
        );
  }
}
