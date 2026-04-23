import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

class ActivityRecord {
  final String id;
  final String name;
  final String type;
  final DateTime? date;
  final String supervisor;
  final int? expectedCount;
  final String description;
  final String status;
  final DateTime? updatedAt;

  const ActivityRecord({
    required this.id,
    required this.name,
    required this.type,
    required this.date,
    required this.supervisor,
    required this.expectedCount,
    required this.description,
    required this.status,
    required this.updatedAt,
  });

  factory ActivityRecord.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime? asDateTime(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return ActivityRecord(
      id: doc.id,
      name: (data['name'] as String?)?.trim() ?? '',
      type: (data['type'] as String?)?.trim() ?? '',
      date: asDateTime(data['date']),
      supervisor: (data['supervisor'] as String?)?.trim() ?? '',
      expectedCount: asInt(data['expectedCount']),
      description: (data['description'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'planned',
      updatedAt: asDateTime(data['updatedAt']),
    );
  }
}

class ActivityParticipationRecord {
  final String id;
  final String activityId;
  final String studentId;
  final String studentName;
  final String role;
  final DateTime? createdAt;

  const ActivityParticipationRecord({
    required this.id,
    required this.activityId,
    required this.studentId,
    required this.studentName,
    required this.role,
    required this.createdAt,
  });

  factory ActivityParticipationRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : null;
    return ActivityParticipationRecord(
      id: doc.id,
      activityId: (data['activityId'] as String?)?.trim() ?? '',
      studentId: (data['studentId'] as String?)?.trim() ?? '',
      studentName: (data['studentName'] as String?)?.trim() ?? '',
      role: (data['role'] as String?)?.trim() ?? '',
      createdAt: createdAt,
    );
  }
}

class FirestoreActivityRepository {
  final FirebaseFirestore _firestore;

  FirestoreActivityRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _activities(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Activities');
  }

  CollectionReference<Map<String, dynamic>> _participations(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ActivityParticipations');
  }

  Stream<List<ActivityRecord>> watchActivities(String schoolId) {
    return _activities(schoolId)
        .orderBy('date', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(ActivityRecord.fromDoc).toList());
  }

  Stream<List<ActivityParticipationRecord>> watchParticipations(
    String schoolId,
  ) {
    return _participations(schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs.map(ActivityParticipationRecord.fromDoc).toList(),
        );
  }

  Future<String> addActivity(
    String schoolId, {
    String? activityId,
    required String name,
    required String type,
    required DateTime? date,
    required String supervisor,
    required int? expectedCount,
    required String description,
    String? createdBy,
  }) async {
    final docRef = _activities(schoolId).doc(
      (activityId == null || activityId.trim().isEmpty)
          ? _activities(schoolId).doc().id
          : activityId.trim(),
    );

    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(docRef);
      if (snap.exists) return;
      tx.set(docRef, {
        'name': name.trim(),
        'type': type.trim(),
        'date': date == null ? null : Timestamp.fromDate(date),
        'supervisor': supervisor.trim(),
        'expectedCount': expectedCount,
        'description': description.trim(),
        'status': 'planned',
        'createdBy': createdBy?.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });

    return docRef.id;
  }

  Future<void> updateActivity(
    String schoolId, {
    required String activityId,
    DateTime? date,
    String? notes,
  }) async {
    final data = <String, dynamic>{'updatedAt': FieldValue.serverTimestamp()};
    if (date != null) data['date'] = Timestamp.fromDate(date);
    if (notes != null) data['notes'] = notes.trim();
    await _activities(
      schoolId,
    ).doc(activityId).set(data, SetOptions(merge: true));
  }

  Future<void> endActivity(
    String schoolId, {
    required String activityId,
    required String status,
    String? notes,
    int? actualParticipants,
    String? finalReport,
  }) async {
    final data = <String, dynamic>{
      'status': status.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (notes != null) data['notes'] = notes.trim();
    if (actualParticipants != null)
      data['actualParticipants'] = actualParticipants;
    if (finalReport != null) data['finalReport'] = finalReport.trim();
    await _activities(
      schoolId,
    ).doc(activityId).set(data, SetOptions(merge: true));
  }

  Future<void> registerStudent(
    String schoolId, {
    required String activityId,
    required String studentId,
    required String studentName,
    required String role,
  }) async {
    await _participations(schoolId).add({
      'activityId': activityId.trim(),
      'studentId': studentId.trim(),
      'studentName': studentName.trim(),
      'role': role.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<Map<String, int>> deletePreviousActivities(
    String schoolId, {
    required DateTime beforeDate,
    bool onlyCompleted = true,
  }) async {
    final sid = schoolId.trim();
    if (sid.isEmpty) return const {'activities': 0, 'participations': 0};
    final cutoff = Timestamp.fromDate(beforeDate);

    int deletedActivities = 0;
    int deletedParticipations = 0;

    Future<int> deleteInBatches(
      Query<Map<String, dynamic>> baseQuery, {
      required bool Function(Map<String, dynamic> data) filter,
    }) async {
      int deleted = 0;
      DocumentSnapshot<Map<String, dynamic>>? lastDoc;
      while (true) {
        Query<Map<String, dynamic>> q = baseQuery.limit(400);
        if (lastDoc != null) q = q.startAfterDocument(lastDoc);
        final snap = await q.get();
        if (snap.docs.isEmpty) break;
        lastDoc = snap.docs.last;

        final batch = _firestore.batch();
        int batchOps = 0;
        for (final d in snap.docs) {
          final data = d.data();
          if (!filter(data)) continue;
          batch.delete(d.reference);
          batchOps += 1;
          deleted += 1;
        }
        if (batchOps > 0) {
          await batch.commit();
        }
      }
      return deleted;
    }

    deletedActivities += await deleteInBatches(
      _activities(sid)
          .where('date', isLessThan: cutoff)
          .orderBy('date', descending: false),
      filter: (data) {
        if (!onlyCompleted) return true;
        return (data['status'] ?? '').toString().trim() == 'completed';
      },
    );

    deletedActivities += await deleteInBatches(
      _activities(sid)
          .where('createdAt', isLessThan: cutoff)
          .orderBy('createdAt', descending: false),
      filter: (data) {
        if (!onlyCompleted) return true;
        return (data['status'] ?? '').toString().trim() == 'completed';
      },
    );

    deletedParticipations += await deleteInBatches(
      _participations(sid)
          .where('createdAt', isLessThan: cutoff)
          .orderBy('createdAt', descending: false),
      filter: (_) => true,
    );

    return {
      'activities': deletedActivities,
      'participations': deletedParticipations,
    };
  }
}

final activityRepositoryProvider = Provider<FirestoreActivityRepository>((ref) {
  return FirestoreActivityRepository(FirebaseFirestore.instance);
});

final schoolActivitiesProvider =
    StreamProvider.autoDispose<List<ActivityRecord>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const Stream.empty();
      return ref.watch(activityRepositoryProvider).watchActivities(schoolId);
    });

final activityParticipationsProvider =
    StreamProvider.autoDispose<List<ActivityParticipationRecord>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const Stream.empty();
      return ref
          .watch(activityRepositoryProvider)
          .watchParticipations(schoolId);
    });
