import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/maintenance_report.dart';

class FirestoreMaintenanceRepository {
  final FirebaseFirestore _firestore;

  FirestoreMaintenanceRepository(this._firestore);

  // Helper to get collection reference
  CollectionReference<Map<String, dynamic>> _reportsCollection(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('MaintenanceReports');
  }

  // Create Report
  Future<void> createReport(String schoolId, MaintenanceReport report) async {
    await _reportsCollection(schoolId).doc(report.id).set(report.toMap());
  }

  // Update Report
  Future<void> updateReport(String schoolId, MaintenanceReport report) async {
    await _reportsCollection(schoolId).doc(report.id).update(report.toMap());
  }
  
  // Delete Report (if needed)
  Future<void> deleteReport(String schoolId, String reportId) async {
    await _reportsCollection(schoolId).doc(reportId).delete();
  }

  // Add Evidence (Subcollection)
  Future<void> addEvidence(String schoolId, String reportId, Map<String, dynamic> evidenceData) async {
    await _reportsCollection(schoolId)
        .doc(reportId)
        .collection('Evidence')
        .add(evidenceData);
    // evidenceCount is updated via Cloud Function, but we can optimistically update local model if needed
    // For now, rely on stream updates
  }

  // Streams
  Stream<List<MaintenanceReport>> watchReports(String schoolId) {
    return _reportsCollection(schoolId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceReport.fromMap(doc.data()))
            .toList());
  }

  Stream<List<MaintenanceReport>> watchOverdueReports(String schoolId) {
    return _reportsCollection(schoolId)
        .where('status', isEqualTo: 'overdue')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceReport.fromMap(doc.data()))
            .toList());
  }
  
  Stream<List<MaintenanceReport>> watchCriticalOpenReports(String schoolId) {
    return _reportsCollection(schoolId)
        .where('priority', isEqualTo: 'critical')
        .where('status', whereIn: ['pending', 'inProgress', 'overdue'])
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => MaintenanceReport.fromMap(doc.data()))
            .toList());
  }
  
   Stream<int> watchOpenCriticalCount(String schoolId) {
    return _reportsCollection(schoolId)
        .where('priority', isEqualTo: 'critical')
        .where('status', whereIn: ['pending', 'inProgress', 'overdue'])
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Stream<int> watchOverdueCount(String schoolId) {
    return _reportsCollection(schoolId)
        .where('status', isEqualTo: 'overdue')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
}

final maintenanceRepositoryProvider = Provider<FirestoreMaintenanceRepository>((ref) {
  return FirestoreMaintenanceRepository(FirebaseFirestore.instance);
});

final maintenanceReportsStreamProvider = StreamProvider.autoDispose<List<MaintenanceReport>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null || user.schoolId!.isEmpty) {
    return const Stream.empty();
  }
  return ref.watch(maintenanceRepositoryProvider).watchReports(user.schoolId!);
});

final openCriticalCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null || user.schoolId!.isEmpty) {
    return const Stream.empty();
  }
  return ref.watch(maintenanceRepositoryProvider).watchOpenCriticalCount(user.schoolId!);
});

final overdueCountProvider = StreamProvider.autoDispose<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null || user.schoolId!.isEmpty) {
    return const Stream.empty();
  }
  return ref.watch(maintenanceRepositoryProvider).watchOverdueCount(user.schoolId!);
});
