import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SubscriptionRepository {
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  SubscriptionRepository(this._firestore)
      : _functions = FirebaseFunctions.instance;

  Future<Map<String, Map<String, double>>> getSubscriptionPrices() async {
    try {
      final doc = await _firestore
          .collection('SystemSettings')
          .doc('SubscriptionPrices')
          .get();

      if (!doc.exists) {
        return {
          'starter': {'monthly': 49.0, 'yearly': 490.0},
          'smart': {'monthly': 99.0, 'yearly': 990.0},
          'elite': {'monthly': 199.0, 'yearly': 1990.0},
        };
      }

      final data = doc.data()!;
      return {
        'starter': {
          'monthly': (data['starter']?['monthly'] ?? 49).toDouble(),
          'yearly': (data['starter']?['yearly'] ?? 490).toDouble(),
        },
        'smart': {
          'monthly': (data['smart']?['monthly'] ?? 99).toDouble(),
          'yearly': (data['smart']?['yearly'] ?? 990).toDouble(),
        },
        'elite': {
          'monthly': (data['elite']?['monthly'] ?? 199).toDouble(),
          'yearly': (data['elite']?['yearly'] ?? 1990).toDouble(),
        },
      };
    } catch (e) {
      return {
        'starter': {'monthly': 49.0, 'yearly': 490.0},
        'smart': {'monthly': 99.0, 'yearly': 990.0},
        'elite': {'monthly': 199.0, 'yearly': 1990.0},
      };
    }
  }

  Future<void> updateSubscriptionPrices({
    required String planId,
    required double monthly,
    required double yearly,
  }) async {
    await _firestore.collection('SystemSettings').doc('SubscriptionPrices').set(
      {
        planId: {
          'monthly': monthly,
          'yearly': yearly,
        }
      },
      SetOptions(merge: true),
    );
  }

  Future<Map<String, dynamic>?> getSchoolSubscription(String schoolId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Subscription')
        .doc('current')
        .get();
    if (!doc.exists) return null;
    return doc.data();
  }

  Future<Map<String, dynamic>> createSubscriptionCheckout({
    required String schoolId,
    required String planId,
    required String billingCycle,
  }) async {
    final callable = _functions.httpsCallable('createSubscriptionCheckout');
    final result = await callable.call({
      'schoolId': schoolId,
      'planId': planId,
      'billingCycle': billingCycle,
    });
    final data = result.data as Map<dynamic, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  Future<Map<String, dynamic>> confirmSubscriptionPayment({
    required String schoolId,
    required String transactionId,
  }) async {
    final callable = _functions.httpsCallable('confirmSubscriptionPayment');
    final result = await callable.call({
      'schoolId': schoolId,
      'transactionId': transactionId,
    });
    final data = result.data as Map<dynamic, dynamic>;
    return Map<String, dynamic>.from(data);
  }

  Future<void> createPaymentRequest({
    required String schoolId,
    required String schoolName,
    required String contactName,
    required String contactPhone,
    required String notes,
    required String userId,
  }) async {
    final doc = _firestore.collection('PaymentRequests').doc();
    await doc.set({
      'id': doc.id,
      'schoolId': schoolId,
      'schoolName': schoolName,
      'contactName': contactName,
      'contactPhone': contactPhone,
      'notes': notes,
      'status': 'pending',
      'createdBy': userId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(FirebaseFirestore.instance);
});

final subscriptionPricesProvider =
    FutureProvider<Map<String, Map<String, double>>>((ref) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getSubscriptionPrices();
});

final schoolSubscriptionProvider =
    FutureProvider.family<Map<String, dynamic>?, String>((ref, schoolId) async {
  final repo = ref.watch(subscriptionRepositoryProvider);
  return repo.getSchoolSubscription(schoolId);
});
