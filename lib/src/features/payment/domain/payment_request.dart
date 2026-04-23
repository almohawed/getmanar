class PaymentRequest {
  final String id;
  final String schoolId;
  final String schoolName;
  final String contactName;
  final String contactPhone;
  final String? notes;
  final String? desiredPlanId;
  final String? desiredBillingCycle;
  final String status;
  final DateTime createdAt;
  final String createdBy;

  PaymentRequest({
    required this.id,
    required this.schoolId,
    required this.schoolName,
    required this.contactName,
    required this.contactPhone,
    required this.status,
    required this.createdAt,
    required this.createdBy,
    this.notes,
    this.desiredPlanId,
    this.desiredBillingCycle,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'notes': notes,
      'desiredPlanId': desiredPlanId,
      'desiredBillingCycle': desiredBillingCycle,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  factory PaymentRequest.fromMap(Map<String, dynamic> map) {
    return PaymentRequest(
      id: map['id'] ?? '',
      schoolId: map['schoolId'] ?? '',
      schoolName: map['schoolName'] ?? '',
      contactName: map['contactName'] ?? '',
      contactPhone: map['contactPhone'] ?? '',
      notes: map['notes'],
      desiredPlanId: map['desiredPlanId'],
      desiredBillingCycle: map['desiredBillingCycle'],
      status: map['status'] ?? 'pending',
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      createdBy: map['createdBy'] ?? '',
    );
  }
}

