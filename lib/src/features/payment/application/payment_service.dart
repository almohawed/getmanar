import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/payment_transaction.dart';
import '../domain/subscription_plan.dart';

class PaymentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<PaymentTransaction> processPayment({
    required String schoolId,
    required String userId,
    required SubscriptionPlan plan,
  }) async {
    final transactionId = const Uuid().v4();
    final transaction = PaymentTransaction(
      id: transactionId,
      schoolId: schoolId,
      planId: plan.id,
      amount: plan.price,
      currency: plan.currency,
      status: PaymentStatus.pending,
      platform: PaymentPlatform.manualInvoice,
      productId: plan.id,
      basePlanId: 'default',
      createdAt: DateTime.now(),
      userId: userId,
    );

    await _firestore
        .collection('payment_transactions')
        .doc(transactionId)
        .set(transaction.toMap());

    try {
      await Future.delayed(const Duration(seconds: 2));

      final completedTransaction = PaymentTransaction(
        id: transaction.id,
        schoolId: transaction.schoolId,
        planId: transaction.planId,
        amount: transaction.amount,
        currency: transaction.currency,
        status: PaymentStatus.verified,
        platform: transaction.platform,
        productId: transaction.productId,
        basePlanId: transaction.basePlanId,
        createdAt: DateTime.now(),
        userId: transaction.userId,
        purchaseToken: transaction.purchaseToken,
        expiresAt: transaction.expiresAt,
      );

      await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .update(completedTransaction.toMap());

      await _updateSchoolSubscription(schoolId, plan);

      return completedTransaction;
    } catch (e) {
      final failedTransaction = PaymentTransaction(
        id: transaction.id,
        schoolId: transaction.schoolId,
        planId: transaction.planId,
        amount: transaction.amount,
        currency: transaction.currency,
        status: PaymentStatus.failed,
        platform: transaction.platform,
        productId: transaction.productId,
        basePlanId: transaction.basePlanId,
        createdAt: DateTime.now(),
        userId: transaction.userId,
        purchaseToken: transaction.purchaseToken,
        expiresAt: transaction.expiresAt,
      );

      await _firestore
          .collection('payment_transactions')
          .doc(transactionId)
          .update(failedTransaction.toMap());

      rethrow;
    }
  }

  Future<void> _updateSchoolSubscription(String schoolId, SubscriptionPlan plan) async {
    final now = DateTime.now();
    final expiryDate = now.add(Duration(days: plan.durationMonths * 30)); // Approx

    await _firestore.collection('Schools').doc(schoolId).update({
      'subscriptionPlan': plan.id,
      'subscriptionEndsAt': expiryDate.toIso8601String(), // Need to add this field to School model if not present, but Firestore is flexible
      // We might want to clear trialEndsAt or keep it for record
    });
  }
}

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return PaymentService();
});
