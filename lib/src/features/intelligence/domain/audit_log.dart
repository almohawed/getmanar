enum AuditActionType {
  create,
  update,
  delete,
  approve,
  reject,
  escalate,
  systemAuto,
}

class AuditLog {
  final String id;
  final String actorId; // Who performed the action
  final String actorName;
  final String actorRole;
  final AuditActionType action;
  final String targetId; // ID of the object (Student, Behavior, etc.)
  final String targetType; // 'BehaviorRecord', 'User', 'Schedule'
  final String description;
  final Map<String, dynamic>? previousValue;
  final Map<String, dynamic>? newValue;
  final DateTime timestamp;

  AuditLog({
    required this.id,
    required this.actorId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.targetId,
    required this.targetType,
    required this.description,
    this.previousValue,
    this.newValue,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'actorId': actorId,
      'actorName': actorName,
      'actorRole': actorRole,
      'action': action.name,
      'targetId': targetId,
      'targetType': targetType,
      'description': description,
      'previousValue': previousValue,
      'newValue': newValue,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory AuditLog.fromMap(Map<String, dynamic> map) {
    return AuditLog(
      id: map['id'] ?? '',
      actorId: map['actorId'] ?? '',
      actorName: map['actorName'] ?? '',
      actorRole: map['actorRole'] ?? '',
      action: AuditActionType.values.firstWhere(
        (e) =>
            e.name == map['action'] ||
            (e == AuditActionType.systemAuto && map['action'] == 'system_auto'),
        orElse: () => AuditActionType.systemAuto,
      ),
      targetId: map['targetId'] ?? '',
      targetType: map['targetType'] ?? '',
      description: map['description'] ?? '',
      previousValue: map['previousValue'],
      newValue: map['newValue'],
      timestamp: DateTime.parse(map['timestamp']),
    );
  }
}
