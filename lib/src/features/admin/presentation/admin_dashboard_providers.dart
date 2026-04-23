import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../../maintenance/data/firestore_maintenance_repository.dart';
import '../../requests/data/permission_repository.dart';
import '../../auth/presentation/auth_controller.dart';

// --- Domain Models ---

class SchoolStatusMetrics {
  final int incomingToday;
  final int outgoingToday;
  final int pendingTransactions;
  final int delayedTransactions;
  final int openMaintenanceReports;
  final int requestsAwaitingApproval;

  SchoolStatusMetrics({
    this.incomingToday = 0,
    this.outgoingToday = 0,
    this.pendingTransactions = 0,
    this.delayedTransactions = 0,
    this.openMaintenanceReports = 0,
    this.requestsAwaitingApproval = 0,
  });
}

class ActionNeededItem {
  final String id;
  final String title;
  final String subtitle;
  final String
  type; // 'transaction', 'circular', 'permission', 'letter', 'maintenance'
  final DateTime date;
  final int priorityLevel; // 1: High, 2: Medium

  String get timeAgo {
    final diff = DateTime.now().difference(date);
    if (diff.inDays > 0) return 'منذ ${diff.inDays} يوم';
    if (diff.inHours > 0) return 'منذ ${diff.inHours} ساعة';
    if (diff.inMinutes > 0) return 'منذ ${diff.inMinutes} دقيقة';
    return 'الآن';
  }

  ActionNeededItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.type,
    required this.date,
    required this.priorityLevel,
  });
}

class AdminDisciplineIndex {
  final int score; // 0-100
  final String status; // 'Stable', 'Medium Pressure', 'High Pressure'
  final double avgProcessingTimeHours;
  final int delayedCount;
  final double closureRate24h;

  double get beneficiarySatisfaction => 0.0;

  AdminDisciplineIndex({
    required this.score,
    required this.status,
    required this.avgProcessingTimeHours,
    required this.delayedCount,
    required this.closureRate24h,
  });
}

// --- Providers ---

final schoolStatusProvider = StreamProvider.autoDispose<SchoolStatusMetrics>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) {
    return Stream.value(SchoolStatusMetrics());
  }

  final firestore = FirebaseFirestore.instance;
  final schoolRef = firestore.collection('Schools').doc(user.schoolId);

  // 1. Maintenance Stream (Open/Pending/InProgress/Overdue)
  final maintenanceStream = schoolRef
      .collection('MaintenanceTickets')
      .where('status', whereIn: ['open', 'in_progress', 'pending', 'overdue'])
      .snapshots()
      .map((s) => s.docs.length)
      .startWith(0);

  // 2. Permissions Stream (Pending)
  final permissionsPendingStream = schoolRef
      .collection('Permissions')
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.length)
      .startWith(0);

  final startOfDay = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  // 3. Incoming Transactions (Today)
  final inboxTodayStream = schoolRef
      .collection('Transactions')
      .where(
        'receivedAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      )
      .snapshots()
      .map((s) => s.docs.length)
      .startWith(0);

  // 4. Outgoing Transactions (Today)
  final outboxTodayStream = schoolRef
      .collection('OutgoingTransactions')
      .where(
        'createdAt',
        isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
      )
      .snapshots()
      .map((s) => s.docs.length)
      .startWith(0);

  // 5. Pending / Delayed Incoming Transactions
  final pendingTxStream = schoolRef
      .collection('Transactions')
      .where(
        'status',
        whereIn: ['awaitingDirectorRouting', 'routed', 'needsFollowup'],
      )
      .snapshots()
      .map((s) => s.docs.length)
      .startWith(0);

  final delayedTxStream = schoolRef
      .collection('Transactions')
      .where('status', isEqualTo: 'delayed')
      .snapshots()
      .map((s) => s.docs.length)
      .startWith(0);

  return Rx.combineLatest6(
    maintenanceStream,
    permissionsPendingStream,
    inboxTodayStream,
    outboxTodayStream,
    pendingTxStream,
    delayedTxStream,
    (maintenance, pendingPerm, inboxToday, outboxToday, pendingTx, delayedTx) =>
        SchoolStatusMetrics(
          incomingToday: inboxToday,
          outgoingToday: outboxToday,
          pendingTransactions: pendingTx,
          delayedTransactions: delayedTx,
          openMaintenanceReports: maintenance,
          requestsAwaitingApproval: pendingPerm,
        ),
  );
});

final actionNeededProvider = StreamProvider.autoDispose<List<ActionNeededItem>>(
  (ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null || user.schoolId == null) {
      return Stream.value([]);
    }

    final firestore = FirebaseFirestore.instance;
    final schoolRef = firestore.collection('Schools').doc(user.schoolId);

    // 1. Overdue Admin Tasks
    final tasksStream = schoolRef
        .collection('AdminTasks')
        .where('status', whereIn: ['open', 'in_progress'])
        .where('dueDate', isLessThan: Timestamp.now())
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            return ActionNeededItem(
              id: d.id,
              title: data['title'] ?? 'مهمة إدارية',
              subtitle: 'متأخرة عن موعدها',
              type: 'transaction',
              date: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
              priorityLevel: 1,
            );
          }).toList(),
        )
        .startWith([]);

    // 2. Pending Permissions
    final permissionsStream = schoolRef
        .collection('Permissions')
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            return ActionNeededItem(
              id: d.id,
              title: 'استئذان: ${data['studentName'] ?? 'طالب'}',
              subtitle: 'بانتظار الموافقة',
              type: 'permission',
              date:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              priorityLevel: 2,
            );
          }).toList(),
        )
        .startWith([]);

    // 3. Maintenance Reports (Pending/Overdue)
    final maintenanceStream = schoolRef
        .collection('MaintenanceTickets')
        .where('status', whereIn: ['open', 'pending', 'overdue'])
        .snapshots()
        .map(
          (s) => s.docs.map((d) {
            final data = d.data();
            final isOverdue = data['status'] == 'overdue';
            return ActionNeededItem(
              id: d.id,
              title: data['title'] ?? 'بلاغ صيانة',
              subtitle: isOverdue ? 'متأخر' : 'جديد',
              type: 'maintenance',
              date:
                  (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              priorityLevel: isOverdue ? 1 : 2,
            );
          }).toList(),
        )
        .startWith([]);

    return Rx.combineLatest3(
      tasksStream,
      permissionsStream,
      maintenanceStream,
      (tasks, permissions, maintenance) {
        final allItems = [...tasks, ...permissions, ...maintenance];
        // Sort by priority (1 is high), then by date (newest first)
        allItems.sort((a, b) {
          if (a.priorityLevel != b.priorityLevel) {
            return a.priorityLevel.compareTo(
              b.priorityLevel,
            ); // 1 comes before 2
          }
          return b.date.compareTo(a.date);
        });
        return allItems;
      },
    );
  },
);

final adminDisciplineIndexProvider = Provider.autoDispose<AdminDisciplineIndex>(
  (ref) {
    final statusAsync = ref.watch(schoolStatusProvider);
    final status = statusAsync.value ?? SchoolStatusMetrics();

    final delayed = status.delayedTransactions;

    // Real calculation based on delayed transactions (Overdue Tasks)
    // Start at 100, deduct 10 points for each delayed transaction
    double score = 100.0 - (delayed * 10.0);
    if (score < 0) score = 0;

    String statusText;
    if (score >= 80) {
      statusText = 'مستقر';
    } else if (score >= 50) {
      statusText = 'ضغط متوسط';
    } else {
      statusText = 'ضغط عالي';
    }

    return AdminDisciplineIndex(
      score: score.toInt(),
      status: statusText,
      avgProcessingTimeHours: 0,
      delayedCount: delayed,
      closureRate24h: 0,
    );
  },
);
