import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/sms_message.dart';

class FirestoreSmsRepository {
  final FirebaseFirestore _firestore;

  FirestoreSmsRepository(this._firestore);

  // Check if SMS is enabled in Settings
  Future<bool> isSmsEnabled(String schoolId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('sms')
        .get();

    if (!doc.exists) return false; // Default disabled if not configured
    return doc.data()?['enabled'] == true;
  }

  // Check Rate Limit
  Future<void> checkRateLimit(String schoolId, String userId) async {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final oneDayAgo = now.subtract(const Duration(days: 1));

    // Simple check: Count messages in last hour
    // Note: Firestore COUNT aggregation is cheaper/better if available, 
    // but for now we'll query and limit or use count() aggregation.
    
    final hourlyCountQuery = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SmsOutbox')
        .where('createdBy', isEqualTo: userId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(oneHourAgo))
        .count()
        .get();
        
    final hourlyCount = hourlyCountQuery.count ?? 0;
    if (hourlyCount >= 50) { // Limit 50 per hour
      throw Exception('تم تجاوز حد الإرسال المسموح (50 رسالة/ساعة). حاول لاحقاً.');
    }

    final dailyCountQuery = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SmsOutbox')
        .where('createdBy', isEqualTo: userId)
        .where('createdAt', isGreaterThan: Timestamp.fromDate(oneDayAgo))
        .count()
        .get();
        
    final dailyCount = dailyCountQuery.count ?? 0;
    if (dailyCount >= 200) { // Limit 200 per day
      throw Exception('تم تجاوز حد الإرسال اليومي (200 رسالة/يوم).');
    }
  }

  // Queue Messages
  Future<void> queueMessages(String schoolId, List<SmsMessage> messages) async {
    final batch = _firestore.batch();
    final collection = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SmsOutbox');

    for (var msg in messages) {
      final docRef = collection.doc(msg.id);
      batch.set(docRef, msg.toMap());
    }

    await batch.commit();
  }

  // Get Message Log
  Stream<List<SmsMessage>> getMessageLog(String schoolId, {int limit = 50}) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SmsOutbox')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) => snap.docs
            .map((d) => SmsMessage.fromMap(d.data(), d.id))
            .toList());
  }
}

final smsRepositoryProvider = Provider<FirestoreSmsRepository>((ref) {
  return FirestoreSmsRepository(FirebaseFirestore.instance);
});

final smsLogProvider = StreamProvider.family<List<SmsMessage>, String>((ref, schoolId) {
  final repo = ref.watch(smsRepositoryProvider);
  return repo.getMessageLog(schoolId);
});
