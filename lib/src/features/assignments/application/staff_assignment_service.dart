import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/staff_assignment.dart';

class StaffAssignmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> createAssignment({
    required String schoolId,
    required String assignedUserId,
    required String assignedUserName,
    required String assignedUserRole,
    required String assignmentTitle,
    required String assignmentType,
    String? description,
    required String createdBy,
    required String createdByName,
    String? dashboardRoute,
  }) async {
    final docRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffAssignments')
        .doc();

    final assignment = StaffAssignment(
      id: docRef.id,
      schoolId: schoolId,
      assignedUserId: assignedUserId,
      assignedUserName: assignedUserName,
      assignedUserRole: assignedUserRole,
      assignmentTitle: assignmentTitle,
      assignmentType: assignmentType,
      description: description,
      createdBy: createdBy,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      isActive: true,
      dashboardRoute: dashboardRoute,
    );

    await docRef.set(assignment.toJson());
    return docRef.id;
  }

  Stream<List<StaffAssignment>> getAssignmentsBySchool(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffAssignments')
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffAssignment.fromJson(doc.data()))
            .toList());
  }

  Stream<List<StaffAssignment>> getAssignmentsByUser(String schoolId, String userId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffAssignments')
        .where('assignedUserId', isEqualTo: userId)
        .where('isActive', isEqualTo: true)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => StaffAssignment.fromJson(doc.data()))
            .toList());
  }

  Future<void> deactivateAssignment(String schoolId, String assignmentId) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffAssignments')
        .doc(assignmentId)
        .update({'isActive': false});
  }

  Future<void> updateAssignment(String schoolId, String assignmentId, Map<String, dynamic> updates) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffAssignments')
        .doc(assignmentId)
        .update(updates);
  }
}
