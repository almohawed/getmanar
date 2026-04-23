import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../domain/audit_log.dart';
import '../data/audit_repository.dart';

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return MockAuditRepository();
});

final auditServiceProvider = Provider<AuditService>((ref) {
  return AuditService(ref.read(auditRepositoryProvider));
});

class AuditService {
  final AuditRepository _repository;
  final _uuid = const Uuid();

  AuditService(this._repository);

  Future<void> logAction({
    required User actor,
    required AuditActionType action,
    required String targetId,
    required String targetType,
    required String description,
    Map<String, dynamic>? previousValue,
    Map<String, dynamic>? newValue,
  }) async {
    final log = AuditLog(
      id: _uuid.v4(),
      actorId: actor.id,
      actorName: actor.name,
      actorRole: actor.role.name,
      action: action,
      targetId: targetId,
      targetType: targetType,
      description: description,
      previousValue: previousValue,
      newValue: newValue,
      timestamp: DateTime.now(),
    );

    await _repository.log(log);
  }
  
  Future<List<AuditLog>> getLogs({String? targetId, String? actorId}) {
    return _repository.getLogs(targetId: targetId, actorId: actorId);
  }
}
