import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/leave_request.dart';

class LeaveRequestRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference _col(String schoolId) => _db
      .collection('Schools')
      .doc(schoolId)
      .collection('LeaveRequests');

  // إضافة طلب جديد
  Future<void> addRequest(LeaveRequest req) async {
    await _col(req.schoolId).doc(req.id).set(req.toMap());
  }

  // تحديث حالة الطلب (قبول/رفض)
  Future<void> updateStatus({
    required String schoolId,
    required String requestId,
    required LeaveStatus status,
    String? deputyNote,
    required String reviewedBy,
  }) async {
    await _col(schoolId).doc(requestId).update({
      'status': status.name,
      'deputyNote': deputyNote,
      'reviewedAt': FieldValue.serverTimestamp(),
      'reviewedBy': reviewedBy,
    });
  }

  // طلبات معلم معين
  Stream<List<LeaveRequest>> streamTeacherRequests(String schoolId, String teacherId) {
    return _col(schoolId)
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => LeaveRequest.fromMap(d.data() as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => b.requestDate.compareTo(a.requestDate));
          return list;
        });
  }

  // جميع الطلبات للوكيل
  Stream<List<LeaveRequest>> streamAllRequests(String schoolId) {
    return _col(schoolId)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => LeaveRequest.fromMap(d.data() as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => b.requestDate.compareTo(a.requestDate));
          return list;
        });
  }

  // الطلبات المعلقة فقط
  Stream<List<LeaveRequest>> streamPendingRequests(String schoolId) {
    return _col(schoolId)
        .where('status', isEqualTo: LeaveStatus.pending.name)
        .snapshots()
        .map((s) {
          final list = s.docs
              .map((d) => LeaveRequest.fromMap(d.data() as Map<String, dynamic>))
              .toList();
          list.sort((a, b) => b.requestDate.compareTo(a.requestDate));
          return list;
        });
  }
}

final leaveRequestRepositoryProvider = Provider((_) => LeaveRequestRepository());
