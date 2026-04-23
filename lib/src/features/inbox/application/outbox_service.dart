import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../domain/outgoing_transaction.dart';

class OutboxService {
  static final OutboxService _instance = OutboxService._internal();
  factory OutboxService() => _instance;

  OutboxService._internal() {
    _transactions = [];
  }

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  // ignore: unused_field
  final _uuid = const Uuid();

  List<OutgoingTransaction> _transactions = [];
  final StreamController<List<OutgoingTransaction>> _controller =
      StreamController<List<OutgoingTransaction>>.broadcast();

  // الحصول على المراسلات الصادرة للمدرسة
  Stream<List<OutgoingTransaction>> getOutgoingTransactions(String schoolId) {
    // Emit current local data immediately
    Future.microtask(() => _controller.add(_transactions));

    // Listen to Firestore
    _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('OutgoingTransactions')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final firestoreTransactions = snapshot.docs
              .map((doc) => OutgoingTransaction.fromMap(doc.data(), doc.id))
              .toList();
          _transactions = firestoreTransactions;
          _controller.add(_transactions);
        }, onError: (_) {});

    return _controller.stream;
  }

  // توليد رقم معاملة جديد (محاكاة للتسلسل)
  Future<String> generateNextTransactionNumber(String schoolId) async {
    final year = DateTime.now().year;
    final counterRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Counters')
        .doc('OutgoingTransactions');

    return _firestore.runTransaction((tx) async {
      final snap = await tx.get(counterRef);
      final data = snap.data() as Map<String, dynamic>?;
      final storedYear = (data?['year'] as num?)?.toInt();
      final storedSeq = (data?['seq'] as num?)?.toInt() ?? 0;
      final nextSeq = (storedYear == year) ? storedSeq + 1 : 1;
      tx.set(counterRef, {
        'year': year,
        'seq': nextSeq,
      }, SetOptions(merge: true));
      return 'OUT-$year-${nextSeq.toString().padLeft(3, '0')}';
    });
  }

  // إنشاء معاملة جديدة
  Future<void> createTransaction(OutgoingTransaction transaction) async {
    // 1. Optimistic update (Local)
    _transactions.insert(0, transaction);
    _controller.add(List.from(_transactions));

    // 2. Persist (Firestore)
    try {
      await _firestore
          .collection('Schools')
          .doc(transaction.schoolId)
          .collection('OutgoingTransactions')
          .doc(transaction.id)
          .set(transaction.toMap());
    } catch (e) {
      print('Error creating transaction: $e');
      // If failed, we could revert local change, but for demo we keep it
    }
  }

  // تحديث حالة المعاملة
  Future<void> updateTransactionStatus(
    String schoolId,
    String transactionId,
    OutgoingTransactionStatus newStatus,
    String userId,
    String userName, {
    String? notes,
  }) async {
    // 1. Optimistic update (Local)
    final index = _transactions.indexWhere((t) => t.id == transactionId);
    if (index != -1) {
      final oldTx = _transactions[index];

      // Create log entry
      final log = OutgoingLog(
        action: _getActionName(newStatus),
        userId: userId,
        userName: userName,
        timestamp: DateTime.now(),
        notes: notes,
      );

      final updatedTx = OutgoingTransaction(
        id: oldTx.id,
        schoolId: oldTx.schoolId,
        number: oldTx.number,
        recipientEntity: oldTx.recipientEntity,
        subject: oldTx.subject,
        createdAt: oldTx.createdAt,
        updatedAt: DateTime.now(),
        sentAt: newStatus == OutgoingTransactionStatus.sent
            ? DateTime.now()
            : oldTx.sentAt,
        status: newStatus,
        type: oldTx.type,
        priority: oldTx.priority,
        content: oldTx.content,
        attachments: oldTx.attachments,
        creatorId: oldTx.creatorId,
        creatorName: oldTx.creatorName,
        logs: [...oldTx.logs, log],
      );

      _transactions[index] = updatedTx;
      _controller.add(List.from(_transactions));

      // 2. Persist (Firestore)
      try {
        final docRef = _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('OutgoingTransactions')
            .doc(transactionId);

        final updateData = {
          'status': newStatus.name,
          'updatedAt': Timestamp.now(),
          'logs': FieldValue.arrayUnion([log.toMap()]),
        };

        if (newStatus == OutgoingTransactionStatus.sent) {
          updateData['sentAt'] = Timestamp.now();
        }

        await docRef.update(updateData);
      } catch (e) {
        print('Error updating transaction: $e');
      }
    }
  }

  String _getActionName(OutgoingTransactionStatus status) {
    switch (status) {
      case OutgoingTransactionStatus.draft:
        return 'تعديل المسودة';
      case OutgoingTransactionStatus.reviewing:
        return 'إرسال للمراجعة';
      case OutgoingTransactionStatus.awaitingApproval:
        return 'رفع للاعتماد';
      case OutgoingTransactionStatus.sent:
        return 'تم الإرسال';
      case OutgoingTransactionStatus.archived:
        return 'أرشفة';
    }
  }

  // إحصائيات الصادر
  Future<OutboxStatistics> getOutboxStatistics(String schoolId) async {
    final now = DateTime.now();
    final totalToday = _transactions
        .where(
          (t) =>
              t.createdAt.year == now.year &&
              t.createdAt.month == now.month &&
              t.createdAt.day == now.day,
        )
        .length;

    final inPrep = _transactions
        .where(
          (t) =>
              t.status == OutgoingTransactionStatus.draft ||
              t.status == OutgoingTransactionStatus.reviewing,
        )
        .length;

    final awaiting = _transactions
        .where((t) => t.status == OutgoingTransactionStatus.awaitingApproval)
        .length;

    final sent = _transactions
        .where((t) => t.status == OutgoingTransactionStatus.sent)
        .length;

    final sentDurations = _transactions
        .where((t) => t.sentAt != null)
        .map((t) => t.sentAt!.difference(t.createdAt).inMinutes / (60 * 24))
        .toList();

    final avg = sentDurations.isEmpty
        ? 0.0
        : (sentDurations.reduce((a, b) => a + b) / sentDurations.length);

    return OutboxStatistics(
      totalToday: totalToday,
      inPreparation: inPrep,
      awaitingApproval: awaiting,
      sent: sent,
      averageProcessingTime: avg,
    );
  }

  List<OutgoingTransaction> getDemoOutgoingTransactions(String schoolId) {
    return [];
  }
}
