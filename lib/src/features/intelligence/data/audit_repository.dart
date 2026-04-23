import '../domain/audit_log.dart';

abstract class AuditRepository {
  Future<void> log(AuditLog log);
  Future<List<AuditLog>> getLogs({String? targetId, String? actorId, int limit = 50});
}

class MockAuditRepository implements AuditRepository {
  final List<AuditLog> _logs = [];

  @override
  Future<void> log(AuditLog log) async {
    _logs.add(log);
    // In a real app, this would write to Firestore
    // ignore: avoid_print
    print('AUDIT LOG: ${log.action.name} by ${log.actorName} on ${log.targetType}:${log.targetId}');
  }

  @override
  Future<List<AuditLog>> getLogs({String? targetId, String? actorId, int limit = 50}) async {
    // Sort by timestamp descending
    _logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    
    return _logs.where((l) {
      if (targetId != null && l.targetId != targetId) return false;
      if (actorId != null && l.actorId != actorId) return false;
      return true;
    }).take(limit).toList();
  }
}
