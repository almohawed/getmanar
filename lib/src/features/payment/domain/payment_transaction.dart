enum PaymentStatus {
  pending,
  verified,
  failed,
  cancelled,
}

enum PaymentPlatform {
  googlePlay,
  manualInvoice,
}

class PaymentTransaction {
  final String id;
  final String schoolId;
  final String planId;
  final double amount;
  final String currency;
  final PaymentStatus status;
  final PaymentPlatform platform;
  final String productId;
  final String basePlanId;
  final String? purchaseToken;
  final DateTime? expiresAt;
  final DateTime createdAt;
  final String userId;

  PaymentTransaction({
    required this.id,
    required this.schoolId,
    required this.planId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.platform,
    required this.productId,
    required this.basePlanId,
    required this.createdAt,
    required this.userId,
    this.purchaseToken,
    this.expiresAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'planId': planId,
      'amount': amount,
      'currency': currency,
      'status': status.name,
      'platform': platform.name,
      'productId': productId,
      'basePlanId': basePlanId,
      'purchaseToken': purchaseToken,
      'expiresAt': expiresAt?.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
      'userId': userId,
    };
  }

  factory PaymentTransaction.fromMap(Map<String, dynamic> map) {
    return PaymentTransaction(
      id: map['id'] ?? '',
      schoolId: map['schoolId'] ?? '',
      planId: map['planId'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      currency: map['currency'] ?? 'SAR',
      status: PaymentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => PaymentStatus.pending,
      ),
      platform: PaymentPlatform.values.firstWhere(
        (e) => e.name == map['platform'],
        orElse: () => PaymentPlatform.googlePlay,
      ),
      productId: map['productId'] ?? '',
      basePlanId: map['basePlanId'] ?? '',
      purchaseToken: map['purchaseToken'],
      expiresAt: map['expiresAt'] != null
          ? DateTime.tryParse(map['expiresAt']) ?? DateTime.now()
          : null,
      createdAt: DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
      userId: map['userId'] ?? '',
    );
  }
}
