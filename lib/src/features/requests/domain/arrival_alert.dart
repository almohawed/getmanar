class ArrivalAlert {
  final String id;
  final String parentId;
  final String parentName;
  final DateTime timestamp;
  final bool isRead;

  ArrivalAlert({
    required this.id,
    required this.parentId,
    required this.parentName,
    required this.timestamp,
    this.isRead = false,
  });
}
