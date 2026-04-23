import 'dart:async';
import 'dart:developer' as developer;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../domain/behavior_repository.dart';
import 'offline_behavior_service.dart';

class FirestoreBehaviorRepository implements BehaviorRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OfflineBehaviorService? _offlineService;
  static const String _collection = 'behavior_records';

  FirestoreBehaviorRepository({OfflineBehaviorService? offlineService})
    : _offlineService = offlineService;

  @override
  Future<void> addBehaviorRecord(BehaviorRecord record) async {
    // Offline Check
    final offlineService = _offlineService;
    if (offlineService != null && !(await offlineService.isOnline())) {
      await offlineService.queueAddBehavior(record);
      return;
    }

    await _firestore.collection(_collection).doc(record.id).set(record.toMap());
  }

  @override
  Future<List<BehaviorRecord>> getStudentBehavior(
    String studentId, {
    String? schoolId,
  }) async {
    // Offline Check
    final offlineService = _offlineService;
    if (offlineService != null && !(await offlineService.isOnline())) {
      return offlineService.getCachedRecordsForStudent(studentId);
    }

    Query query = _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId);

    if (schoolId != null && schoolId.isNotEmpty) {
      query = query.where('schoolId', isEqualTo: schoolId);
    }

    final snapshot = await query.get();

    final records = snapshot.docs
        .map(
          (doc) => BehaviorRecord.fromMap(doc.data() as Map<String, dynamic>),
        )
        .toList();

    // Sort client-side to avoid Firestore Index requirement
    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Cache fetched records
    if (offlineService != null) {
      await offlineService.cacheBehaviorRecords(records);
    }

    return records;
  }

  @override
  Future<List<BehaviorRecord>> getClassBehavior(String classId) async {
    // Offline Check
    final offlineService = _offlineService;
    if (offlineService != null && !(await offlineService.isOnline())) {
      return offlineService.getCachedRecordsForClass(classId);
    }

    final snapshot = await _firestore
        .collection(_collection)
        .where('classId', isEqualTo: classId)
        .get();

    final records = snapshot.docs
        .map((doc) => BehaviorRecord.fromMap(doc.data()))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    // Cache
    if (offlineService != null) {
      await offlineService.cacheBehaviorRecords(records);
    }

    return records;
  }

  @override
  Future<void> updateBehaviorRecord(BehaviorRecord record) async {
    await _firestore
        .collection(_collection)
        .doc(record.id)
        .update(record.toMap());
  }

  @override
  Future<BehaviorRecord?> getActiveBathroomTrip(String studentId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('studentId', isEqualTo: studentId)
        .where('type', isEqualTo: BehaviorType.bathroom.name)
        .where('bathroomReturnTime', isNull: true)
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      return BehaviorRecord.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  @override
  Future<List<BehaviorRecord>> getPendingViolations({String? schoolId}) async {
    Query query = _firestore
        .collection(_collection)
        .where('status', isEqualTo: BehaviorStatus.pending.name);

    if (schoolId != null) {
      query = query.where('schoolId', isEqualTo: schoolId);
    }

    final snapshot = await query.get();
    final records = snapshot.docs
        .map(
          (doc) => BehaviorRecord.fromMap(doc.data() as Map<String, dynamic>),
        )
        .toList();

    records.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return records;
  }

  @override
  Future<List<BehaviorRecord>> getRejectedViolations(String teacherId) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('teacherId', isEqualTo: teacherId)
        .where('status', isEqualTo: BehaviorStatus.rejected.name)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => BehaviorRecord.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<List<BehaviorRecord>> getTeacherDrafts(String teacherId) async {
    try {
      // Direct fetch without complex offline/timeout logic for stability
      final snapshot = await _firestore
          .collection(_collection)
          .where('teacherId', isEqualTo: teacherId)
          .where('status', isEqualTo: BehaviorStatus.draft.name)
          .get();

      final records = snapshot.docs
          .map((doc) => BehaviorRecord.fromMap(doc.data()))
          .toList();

      // Sort client-side
      records.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Cache if possible, but don't block
      final offlineService = _offlineService;
      if (offlineService != null) {
        offlineService.cacheBehaviorRecords(records).ignore();
      }

      return records;
    } catch (e) {
      debugPrint('Error fetching teacher drafts: $e');
      // On error, try to return cached data if available, otherwise empty
      final offlineService = _offlineService;
      if (offlineService != null) {
        return offlineService
            .getCachedRecordsForTeacher(teacherId)
            .where((r) => r.status == BehaviorStatus.draft)
            .toList();
      }
      return [];
    }
  }

  @override
  Future<List<BehaviorRecord>> getTeacherRecords(String teacherId) async {
    final offlineService = _offlineService;

    try {
      final snapshot = await _firestore
          .collection(_collection)
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get()
          .timeout(const Duration(seconds: 10));

      final records = snapshot.docs
          .map((doc) => BehaviorRecord.fromMap(doc.data()))
          .toList();

      if (offlineService != null) {
        await offlineService.cacheBehaviorRecords(records);
      }

      return records;
    } catch (e) {
      debugPrint('Error fetching teacher records: $e');
      if (offlineService != null) {
        return offlineService.getCachedRecordsForTeacher(teacherId);
      }
      return [];
    }
  }

  @override
  Future<void> deleteBehaviorRecord(String recordId) async {
    await _firestore.collection(_collection).doc(recordId).delete();
  }

  @override
  Future<List<BehaviorRecord>> getRecordsByType(BehaviorType type) async {
    final snapshot = await _firestore
        .collection(_collection)
        .where('type', isEqualTo: type.name)
        .orderBy('timestamp', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => BehaviorRecord.fromMap(doc.data()))
        .toList();
  }

  @override
  Future<String?> getParentIdForStudent(String studentId) async {
    // Assuming parents are in Schools/{schoolId}/Parents and have a 'childrenIds' array
    // Since we don't have schoolId here, we use collectionGroup query
    try {
      final snapshot = await _firestore
          .collectionGroup('Parents')
          .where('childrenIds', arrayContains: studentId)
          .limit(1)
          .get();

      if (snapshot.docs.isNotEmpty) {
        return snapshot.docs.first.id;
      }
    } catch (e) {
      developer.log('Error finding parent for student $studentId', error: e);
    }
    return null;
  }

  @override
  Future<List<BehaviorRecord>> getSchoolBehavior(
    String schoolId, {
    DateTime? since,
  }) async {
    final offlineService = _offlineService;

    // Check if offline
    if (offlineService != null && !(await offlineService.isOnline())) {
      final allRecords = offlineService.getCachedBehaviorRecords();
      return allRecords.where((r) {
        if (r.schoolId != schoolId) return false;
        if (since != null && !r.timestamp.isAfter(since)) return false;
        return true;
      }).toList();
    }

    Query query = _firestore
        .collection(_collection)
        .where('schoolId', isEqualTo: schoolId);

    if (since != null) {
      query = query.where(
        'timestamp',
        isGreaterThan: Timestamp.fromDate(since),
      );
    }

    query = query.orderBy('timestamp', descending: true);

    try {
      final snapshot = await query.get();

      final records = snapshot.docs
          .map(
            (doc) => BehaviorRecord.fromMap(doc.data() as Map<String, dynamic>),
          )
          .toList();

      // Cache fetched records
      if (offlineService != null) {
        await offlineService.cacheBehaviorRecords(records);
      }

      return records;
    } catch (e) {
      // Fallback to cache on error
      if (offlineService != null) {
        final allRecords = offlineService.getCachedBehaviorRecords();
        return allRecords.where((r) {
          if (r.schoolId != schoolId) return false;
          if (since != null && !r.timestamp.isAfter(since)) return false;
          return true;
        }).toList();
      }
      rethrow;
    }
  }
}
