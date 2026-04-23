import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(FirebaseFirestore.instance, ref);
});

class AuditService {
  final FirebaseFirestore _firestore;
  final Ref _ref;

  AuditService(this._firestore, this._ref);

  Future<void> logAction({
    required String action,
    required String description,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      final user = _ref.read(authStateProvider).value;
      if (user == null) return;

      await _firestore.collection('Schools')
          .doc(user.schoolId)
          .collection('AuditLogs')
          .add({
        'action': action,
        'description': description,
        'userId': user.id,
        'userName': user.name,
        'userRole': user.role.name,
        'timestamp': FieldValue.serverTimestamp(),
        'metadata': metadata,
      });
    } catch (e) {
      // Fail silently to not disrupt user experience
      print('Audit Log Failed: $e');
    }
  }
}
