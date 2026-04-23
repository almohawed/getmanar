import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/incoming_transaction.dart';

class InboxTransactionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get all transactions for a school
  Stream<List<IncomingTransaction>> getSchoolTransactions(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('IncomingTransactions')
        .orderBy('receivedDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => IncomingTransaction.fromFirestore(doc))
            .toList());
  }

  // Get transactions by status
  List<IncomingTransaction> getTransactionsByStatus(
    List<IncomingTransaction> transactions,
    TransactionStatus status,
  ) {
    return transactions.where((t) => t.status == status).toList();
  }

  // Get sensitive transactions
  List<IncomingTransaction> getSensitiveTransactions(
    List<IncomingTransaction> transactions,
  ) {
    return transactions
        .where((t) =>
            t.isSensitive ||
            t.priority == TransactionPriority.urgent ||
            t.daysInCurrentStatus > 3)
        .toList();
  }

  // Update transaction status
  Future<void> updateTransactionStatus({
    required String schoolId,
    required String transactionId,
    required TransactionStatus newStatus,
    required String performedBy,
    String? notes,
  }) async {
    final docRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('IncomingTransactions')
        .doc(transactionId);

    final doc = await docRef.get();
    final transaction = IncomingTransaction.fromFirestore(doc);

    final newLog = TransactionLog(
      action: 'تغيير الحالة إلى ${_getStatusName(newStatus)}',
      timestamp: DateTime.now(),
      performedBy: performedBy,
      notes: notes,
    );

    await docRef.update({
      'status': newStatus.name,
      'logs': [...transaction.logs.map((e) => e.toMap()), newLog.toMap()],
      'daysInCurrentStatus': 0,
    });
  }

  // Assign transaction
  Future<void> assignTransaction({
    required String schoolId,
    required String transactionId,
    required String assignedTo,
    required String performedBy,
  }) async {
    final docRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('IncomingTransactions')
        .doc(transactionId);

    final doc = await docRef.get();
    final transaction = IncomingTransaction.fromFirestore(doc);

    final newLog = TransactionLog(
      action: 'تم التوجيه إلى $assignedTo',
      timestamp: DateTime.now(),
      performedBy: performedBy,
    );

    await docRef.update({
      'assignedTo': assignedTo,
      'status': TransactionStatus.inProgress.name,
      'logs': [...transaction.logs.map((e) => e.toMap()), newLog.toMap()],
    });
  }

  // Get statistics
  Map<String, dynamic> getStatistics(List<IncomingTransaction> transactions) {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);

    final todayTransactions = transactions
        .where((t) => t.receivedDate.isAfter(todayStart))
        .length;

    final notDirected = transactions
        .where((t) => t.status == TransactionStatus.waitingDirection)
        .length;

    final needsFollowUp = transactions
        .where((t) => t.status == TransactionStatus.needsFollowUp)
        .length;

    final delayed =
        transactions.where((t) => t.status == TransactionStatus.delayed).length;

    final avgProcessingTime = transactions.isEmpty
        ? 0.0
        : transactions
                .map((t) => t.daysInCurrentStatus)
                .reduce((a, b) => a + b) /
            transactions.length;

    return {
      'todayCount': todayTransactions,
      'notDirected': notDirected,
      'needsFollowUp': needsFollowUp,
      'delayed': delayed,
      'avgProcessingTime': avgProcessingTime.toStringAsFixed(1),
    };
  }

  // Get analytics
  Map<String, dynamic> getAnalytics(List<IncomingTransaction> transactions) {
    // Most sending entities
    final entityCounts = <String, int>{};
    for (var t in transactions) {
      entityCounts[t.senderEntity] = (entityCounts[t.senderEntity] ?? 0) + 1;
    }
    final topEntity = entityCounts.entries.isEmpty
        ? 'لا يوجد'
        : entityCounts.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key;

    // Most delayed type
    final delayedByType = <TransactionType, int>{};
    for (var t in transactions.where((t) => t.daysInCurrentStatus > 2)) {
      delayedByType[t.type] = (delayedByType[t.type] ?? 0) + 1;
    }
    final mostDelayedType = delayedByType.entries.isEmpty
        ? 'لا يوجد'
        : _getTypeName(delayedByType.entries
            .reduce((a, b) => a.value > b.value ? a : b)
            .key);

    return {
      'topSender': topEntity,
      'mostDelayedType': mostDelayedType,
      'totalTransactions': transactions.length,
    };
  }

  String _getStatusName(TransactionStatus status) {
    switch (status) {
      case TransactionStatus.waitingDirection:
        return 'بانتظار توجيه المدير';
      case TransactionStatus.inProgress:
        return 'قيد التنفيذ';
      case TransactionStatus.needsFollowUp:
        return 'تحتاج متابعة';
      case TransactionStatus.delayed:
        return 'متأخرة';
      case TransactionStatus.closed:
        return 'مغلقة';
    }
  }

  String _getTypeName(TransactionType type) {
    switch (type) {
      case TransactionType.circular:
        return 'تعميم';
      case TransactionType.administrative:
        return 'إداري';
      case TransactionType.student:
        return 'طلاب';
      case TransactionType.financial:
        return 'مالي';
      case TransactionType.complaint:
        return 'شكوى';
    }
  }
}
