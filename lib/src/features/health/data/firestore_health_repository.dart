import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

class HealthCaseRecord {
  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String conditionType;
  final String conditionName;
  final String medication;
  final DateTime createdAt;
  final String createdBy;

  const HealthCaseRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.conditionType,
    required this.conditionName,
    required this.medication,
    required this.createdAt,
    required this.createdBy,
  });

  factory HealthCaseRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String schoolId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return HealthCaseRecord(
      id: doc.id,
      schoolId: schoolId,
      studentId: (data['studentId'] as String?)?.trim() ?? '',
      studentName: (data['studentName'] as String?)?.trim() ?? '',
      conditionType: (data['conditionType'] as String?)?.trim() ?? '',
      conditionName: (data['conditionName'] as String?)?.trim() ?? '',
      medication: (data['medication'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      createdBy: (data['createdBy'] as String?)?.trim() ?? '',
    );
  }
}

class HealthIncidentRecord {
  final String id;
  final String schoolId;
  final String? studentId;
  final String? studentName;
  final String incidentType;
  final String location;
  final String description;
  final String actionTaken;
  final DateTime createdAt;
  final String createdBy;

  const HealthIncidentRecord({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.incidentType,
    required this.location,
    required this.description,
    required this.actionTaken,
    required this.createdAt,
    required this.createdBy,
  });

  factory HealthIncidentRecord.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String schoolId,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['createdAt'];
    final createdAt = ts is Timestamp ? ts.toDate() : DateTime.now();
    return HealthIncidentRecord(
      id: doc.id,
      schoolId: schoolId,
      studentId: (data['studentId'] as String?)?.trim(),
      studentName: (data['studentName'] as String?)?.trim(),
      incidentType: (data['incidentType'] as String?)?.trim() ?? '',
      location: (data['location'] as String?)?.trim() ?? '',
      description: (data['description'] as String?)?.trim() ?? '',
      actionTaken: (data['actionTaken'] as String?)?.trim() ?? '',
      createdAt: createdAt,
      createdBy: (data['createdBy'] as String?)?.trim() ?? '',
    );
  }
}

class FirestoreHealthRepository {
  final FirebaseFirestore _firestore;

  FirestoreHealthRepository(this._firestore);

  CollectionReference<Map<String, dynamic>> _cases(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('HealthCases');
  }

  CollectionReference<Map<String, dynamic>> _incidents(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('HealthIncidents');
  }

  Stream<List<HealthCaseRecord>> watchCases(String schoolId) {
    return _cases(schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => HealthCaseRecord.fromDoc(d, schoolId))
              .toList(),
        );
  }

  Stream<List<HealthIncidentRecord>> watchIncidents(String schoolId) {
    return _incidents(schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => HealthIncidentRecord.fromDoc(d, schoolId))
              .toList(),
        );
  }

  Future<void> addCase({
    required String schoolId,
    required String studentId,
    required String studentName,
    required String conditionType,
    required String conditionName,
    required String medication,
    required String createdBy,
  }) async {
    await _cases(schoolId).add({
      'studentId': studentId.trim(),
      'studentName': studentName.trim(),
      'conditionType': conditionType.trim(),
      'conditionName': conditionName.trim(),
      'medication': medication.trim(),
      'createdBy': createdBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> addIncident({
    required String schoolId,
    required String incidentType,
    required String location,
    required String description,
    required String actionTaken,
    required String createdBy,
    String? studentId,
    String? studentName,
  }) async {
    await _incidents(schoolId).add({
      'studentId': studentId?.trim(),
      'studentName': studentName?.trim(),
      'incidentType': incidentType.trim(),
      'location': location.trim(),
      'description': description.trim(),
      'actionTaken': actionTaken.trim(),
      'createdBy': createdBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final healthRepositoryProvider = Provider<FirestoreHealthRepository>((ref) {
  return FirestoreHealthRepository(FirebaseFirestore.instance);
});

final healthCasesProvider = StreamProvider.autoDispose<List<HealthCaseRecord>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return ref.watch(healthRepositoryProvider).watchCases(schoolId);
});

final healthIncidentsProvider =
    StreamProvider.autoDispose<List<HealthIncidentRecord>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) return const Stream.empty();
      return ref.watch(healthRepositoryProvider).watchIncidents(schoolId);
    });

