import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/transaction.dart' as domain;

class InboxService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // الحصول على جميع المعاملات للمدرسة
  Stream<List<domain.Transaction>> getTransactions(String schoolId) {
    final controller = StreamController<List<domain.Transaction>>();

    controller.add(const []);

    _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .orderBy('receivedAt', descending: true)
        .snapshots()
        .listen((snapshot) {
          final transactions = snapshot.docs
              .map((doc) => domain.Transaction.fromMap(doc.data(), doc.id))
              .toList();
          controller.add(transactions);
        }, onError: (_) {});

    return controller.stream;
  }

  // الحصول على إحصائيات الوارد
  Future<domain.InboxStatistics> getStatistics(String schoolId) async {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .get();

    var transactions = snapshot.docs
        .map((doc) => domain.Transaction.fromMap(doc.data(), doc.id))
        .toList();

    final todayTransactions = transactions
        .where((t) => t.receivedAt.isAfter(startOfDay))
        .toList();

    final unrouted = transactions
        .where(
          (t) => t.status == domain.TransactionStatus.awaitingDirectorRouting,
        )
        .length;

    final delayed = transactions.where((t) => t.isDelayed).length;

    final critical = transactions
        .where((t) => t.priority == domain.TransactionPriority.critical)
        .length;

    // حساب متوسط زمن المعالجة
    final closedTransactions = transactions
        .where((t) => t.status == domain.TransactionStatus.closed)
        .toList();

    double averageProcessingTime = 0;
    if (closedTransactions.isNotEmpty) {
      final totalHours = closedTransactions.fold<double>(
        0,
        (sum, t) => sum + t.durationInCurrentStatus.inHours,
      );
      averageProcessingTime = totalHours / closedTransactions.length;
    }

    // تحديد حالة التدفق
    String flowStatus = 'مستقر';
    if (unrouted > 10 || delayed > 5) {
      flowStatus = 'ضغط مرتفع';
    } else if (unrouted > 5 || delayed > 2) {
      flowStatus = 'ضغط متوسط';
    }

    return domain.InboxStatistics(
      totalToday: todayTransactions.length,
      unrouted: unrouted,
      delayed: delayed,
      averageProcessingTime: averageProcessingTime,
      critical: critical,
      flowStatus: flowStatus,
    );
  }

  // الحصول على التحليل الإداري
  Future<domain.AdministrativeAnalysis> getAnalysis(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .get();

    var transactions = snapshot.docs
        .map((doc) => domain.Transaction.fromMap(doc.data(), doc.id))
        .toList();

    // أكثر جهة ترسل معاملات
    final senderCounts = <String, int>{};
    for (var t in transactions) {
      senderCounts[t.senderEntity] = (senderCounts[t.senderEntity] ?? 0) + 1;
    }
    final topSender = senderCounts.entries.isNotEmpty
        ? senderCounts.entries.reduce((a, b) => a.value > b.value ? a : b)
        : MapEntry('غير محدد', 0);

    // أكثر نوع معاملة يتأخر
    final delayedByType = <domain.TransactionType, int>{};
    for (var t in transactions.where((t) => t.isDelayed)) {
      delayedByType[t.type] = (delayedByType[t.type] ?? 0) + 1;
    }
    final mostDelayedType = delayedByType.isNotEmpty
        ? delayedByType.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : domain.TransactionType.other;

    // أيام الذروة (آخر 7 أيام)
    final now = DateTime.now();
    final last7Days = List.generate(7, (i) => now.subtract(Duration(days: i)));
    final dayCounts = <String, int>{};
    for (var day in last7Days) {
      final dayName = _getDayName(day.weekday);
      final count = transactions
          .where(
            (t) =>
                t.receivedAt.year == day.year &&
                t.receivedAt.month == day.month &&
                t.receivedAt.day == day.day,
          )
          .length;
      dayCounts[dayName] = count;
    }
    final peakDays = dayCounts.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // تحليل سبب التأخير
    final delayReasons = <String, int>{
      'ضغط مهام': 0,
      'نقص متابعة': 0,
      'بطء استجابة': 0,
    };

    // ملخص مكتوب
    final summary = _generateSummary(
      topSender.key,
      topSender.value,
      transactions,
    );

    return domain.AdministrativeAnalysis(
      topSenderEntity: topSender.key,
      topSenderCount: topSender.value,
      mostDelayedType: mostDelayedType,
      peakDays: peakDays.take(3).map((e) => e.key).toList(),
      delayReasons: delayReasons,
      summary: summary,
    );
  }

  // الحصول على خريطة الضغط الإداري
  Future<domain.WorkloadMap> getWorkloadMap(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .get();

    final transactions = snapshot.docs
        .map((doc) => domain.Transaction.fromMap(doc.data(), doc.id))
        .toList();

    // الإدارات الأكثر ضغطاً (حسب عدد المعاملات الموجهة)
    final departmentLoad = <String, int>{};
    for (var t in transactions.where((t) => t.routedToUserName != null)) {
      final dept = t.routedToUserName!
          .split(' - ')
          .first; // افتراض: "الاسم - القسم"
      departmentLoad[dept] = (departmentLoad[dept] ?? 0) + 1;
    }

    // الموظف الأكثر استلاماً
    final staffReceived = <String, int>{};
    for (var t in transactions.where((t) => t.routedToUserName != null)) {
      staffReceived[t.routedToUserName!] =
          (staffReceived[t.routedToUserName!] ?? 0) + 1;
    }
    final mostReceived = staffReceived.isNotEmpty
        ? staffReceived.entries.reduce((a, b) => a.value > b.value ? a : b)
        : MapEntry('لا يوجد', 0);

    // الموظف الأكثر تأخيراً
    final staffDelayed = <String, int>{};
    for (var t in transactions.where(
      (t) => t.isDelayed && t.routedToUserName != null,
    )) {
      staffDelayed[t.routedToUserName!] =
          (staffDelayed[t.routedToUserName!] ?? 0) + 1;
    }
    final mostDelayed = staffDelayed.isNotEmpty
        ? staffDelayed.entries.reduce((a, b) => a.value > b.value ? a : b)
        : MapEntry('لا يوجد', 0);

    return domain.WorkloadMap(
      departmentLoad: departmentLoad,
      mostReceivedStaff: mostReceived.key,
      mostReceivedCount: mostReceived.value,
      mostDelayedStaff: mostDelayed.key,
      mostDelayedCount: mostDelayed.value,
    );
  }

  // الحصول على مؤشر سلامة الدورة الإدارية
  Future<domain.CycleHealthIndicator> getCycleHealth(String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .get();

    final transactions = snapshot.docs
        .map((doc) => domain.Transaction.fromMap(doc.data(), doc.id))
        .toList();

    // سرعة التوجيه (نسبة المعاملات الموجهة خلال 24 ساعة)
    final routedWithin24h = transactions
        .where(
          (t) =>
              t.routedAt != null &&
              t.routedAt!.difference(t.receivedAt).inHours <= 24,
        )
        .length;
    final routingSpeed = transactions.isNotEmpty
        ? (routedWithin24h / transactions.length) * 100
        : 0.0;

    // سرعة الإغلاق (نسبة المعاملات المغلقة خلال 7 أيام)
    final closedWithin7d = transactions
        .where(
          (t) =>
              t.closedAt != null &&
              t.closedAt!.difference(t.receivedAt).inDays <= 7,
        )
        .length;
    final closingSpeed = transactions.isNotEmpty
        ? (closedWithin7d / transactions.length) * 100
        : 0.0;

    // نسبة التأخير
    final delayedCount = transactions.where((t) => t.isDelayed).length;
    final delayRate = transactions.isNotEmpty
        ? (delayedCount / transactions.length) * 100
        : 0.0;

    // تراكم المعاملات (نسبة المعاملات غير المغلقة)
    final openCount = transactions
        .where((t) => t.status != domain.TransactionStatus.closed)
        .length;
    final accumulationRate = transactions.isNotEmpty
        ? (openCount / transactions.length) * 100
        : 0.0;

    // الدرجة الإجمالية
    final overallScore =
        (routingSpeed * 0.3) +
        (closingSpeed * 0.3) +
        ((100 - delayRate) * 0.2) +
        ((100 - accumulationRate) * 0.2);

    String rating = 'يحتاج تدخل';
    if (overallScore >= 85) {
      rating = 'ممتاز';
    } else if (overallScore >= 70) {
      rating = 'جيد';
    }

    return domain.CycleHealthIndicator(
      routingSpeed: routingSpeed,
      closingSpeed: closingSpeed,
      delayRate: delayRate,
      accumulationRate: accumulationRate,
      overallScore: overallScore,
      rating: rating,
    );
  }

  // توجيه معاملة
  Future<void> routeTransaction({
    required String schoolId,
    required String transactionId,
    required String toUserId,
    required String toUserName,
    required String byUserId,
    required String byUserName,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .doc(transactionId)
        .update({
          'status': domain.TransactionStatus.routed.name,
          'routedAt': Timestamp.fromDate(now),
          'routedToUserId': toUserId,
          'routedToUserName': toUserName,
          'routedByUserId': byUserId,
          'routedByUserName': byUserName,
          'logs': FieldValue.arrayUnion([
            {
              'action': 'route',
              'userId': byUserId,
              'userName': byUserName,
              'notes': notes,
              'timestamp': Timestamp.fromDate(now),
            },
          ]),
          'updatedAt': Timestamp.fromDate(now),
        });
  }

  // إغلاق معاملة
  Future<void> closeTransaction({
    required String schoolId,
    required String transactionId,
    required String byUserId,
    required String byUserName,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .doc(transactionId)
        .update({
          'status': domain.TransactionStatus.closed.name,
          'closedAt': Timestamp.fromDate(now),
          'logs': FieldValue.arrayUnion([
            {
              'action': 'close',
              'userId': byUserId,
              'userName': byUserName,
              'notes': notes,
              'timestamp': Timestamp.fromDate(now),
            },
          ]),
          'updatedAt': Timestamp.fromDate(now),
        });
  }

  // تصعيد معاملة
  Future<void> escalateTransaction({
    required String schoolId,
    required String transactionId,
    required String byUserId,
    required String byUserName,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .doc(transactionId)
        .update({
          'priority': domain.TransactionPriority.critical.name,
          'logs': FieldValue.arrayUnion([
            {
              'action': 'escalate',
              'userId': byUserId,
              'userName': byUserName,
              'notes': notes,
              'timestamp': Timestamp.fromDate(now),
            },
          ]),
          'updatedAt': Timestamp.fromDate(now),
        });
  }

  // تحديث حالة المعاملة
  Future<void> updateTransactionStatus({
    required String schoolId,
    required String transactionId,
    required domain.TransactionStatus newStatus,
    required String byUserId,
    required String byUserName,
    String? notes,
  }) async {
    final now = DateTime.now();
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .doc(transactionId)
        .update({
          'status': newStatus.name,
          'logs': FieldValue.arrayUnion([
            {
              'action': 'status_change',
              'userId': byUserId,
              'userName': byUserName,
              'notes':
                  notes ?? 'تغيير الحالة إلى ${_getStatusArabic(newStatus)}',
              'timestamp': Timestamp.fromDate(now),
            },
          ]),
          'updatedAt': Timestamp.fromDate(now),
        });
  }

  // إضافة مشاهدة
  Future<void> markAsViewed({
    required String schoolId,
    required String transactionId,
    required String userId,
  }) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Transactions')
        .doc(transactionId)
        .update({
          'viewedBy': FieldValue.arrayUnion([userId]),
        });
  }

  // Helper methods
  String _getDayName(int weekday) {
    const days = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return days[weekday - 1];
  }

  String _generateSummary(
    String topSender,
    int count,
    List<domain.Transaction> transactions,
  ) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final fourteenDaysAgo = now.subtract(const Duration(days: 14));

    final lastWeekCount = transactions
        .where((t) => t.receivedAt.isAfter(sevenDaysAgo))
        .where((t) => t.senderEntity == topSender)
        .length;

    final previousWeekCount = transactions
        .where(
          (t) =>
              t.receivedAt.isBefore(sevenDaysAgo) &&
              t.receivedAt.isAfter(fourteenDaysAgo),
        )
        .where((t) => t.senderEntity == topSender)
        .length;

    final percentageChange = previousWeekCount > 0
        ? ((lastWeekCount - previousWeekCount) / previousWeekCount * 100)
              .round()
        : 0;

    if (percentageChange > 0) {
      return 'لوحظ ارتفاع في معاملات $topSender بنسبة $percentageChange% هذا الأسبوع.';
    } else if (percentageChange < 0) {
      return 'لوحظ انخفاض في معاملات $topSender بنسبة ${percentageChange.abs()}% هذا الأسبوع.';
    } else {
      return 'معاملات $topSender مستقرة هذا الأسبوع.';
    }
  }

  String _getStatusArabic(domain.TransactionStatus status) {
    switch (status) {
      case domain.TransactionStatus.awaitingDirectorRouting:
        return 'بانتظار توجيه المدير';
      case domain.TransactionStatus.routed:
        return 'تم التوجيه';
      case domain.TransactionStatus.needsFollowup:
        return 'تحتاج متابعة';
      case domain.TransactionStatus.delayed:
        return 'متأخرة';
      case domain.TransactionStatus.closed:
        return 'مغلقة';
    }
  }

  List<domain.Transaction> getDemoTransactions(String schoolId) {
    return [];
  }
}
