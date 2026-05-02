import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  if (user == null || (user.schoolId ?? '').isEmpty) {
    return Stream.value(SchoolStatusMetrics());
  }

  final schoolId = user.schoolId!;
  final firestore = FirebaseFirestore.instance;
  final schoolRef = firestore.collection('Schools').doc(schoolId);

  // استخدام Future بدلاً من streams متعددة لتجنب خطأ Firestore INTERNAL ASSERTION
  return Stream.fromFuture(() async {
    try {
      final startOfDay = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );

      final results = await Future.wait([
        schoolRef.collection('MaintenanceTickets')
            .where('status', whereIn: ['open', 'in_progress', 'pending', 'overdue'])
            .get().then((s) => s.docs.length).catchError((_) => 0),
        schoolRef.collection('Permissions')
            .where('status', isEqualTo: 'pending')
            .get().then((s) => s.docs.length).catchError((_) => 0),
        schoolRef.collection('Transactions')
            .where('receivedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .get().then((s) => s.docs.length).catchError((_) => 0),
        schoolRef.collection('OutgoingTransactions')
            .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
            .get().then((s) => s.docs.length).catchError((_) => 0),
        schoolRef.collection('Transactions')
            .where('status', whereIn: ['awaitingDirectorRouting', 'routed', 'needsFollowup'])
            .get().then((s) => s.docs.length).catchError((_) => 0),
        schoolRef.collection('Transactions')
            .where('status', isEqualTo: 'delayed')
            .get().then((s) => s.docs.length).catchError((_) => 0),
      ]);

      return SchoolStatusMetrics(
        openMaintenanceReports: results[0],
        requestsAwaitingApproval: results[1],
        incomingToday: results[2],
        outgoingToday: results[3],
        pendingTransactions: results[4],
        delayedTransactions: results[5],
      );
    } catch (_) {
      return SchoolStatusMetrics();
    }
  }());
});

final actionNeededProvider = StreamProvider.autoDispose<List<ActionNeededItem>>(
  (ref) {
    final user = ref.watch(authStateProvider).value;
    if (user == null || (user.schoolId ?? '').isEmpty) {
      return Stream.value([]);
    }

    final schoolId = user.schoolId!;
    final firestore = FirebaseFirestore.instance;
    final schoolRef = firestore.collection('Schools').doc(schoolId);

    return Stream.fromFuture(() async {
      try {
        final results = await Future.wait([
          // 1. Overdue Admin Tasks
          schoolRef.collection('AdminTasks')
              .where('status', whereIn: ['open', 'in_progress'])
              .where('dueDate', isLessThan: Timestamp.now())
              .get().catchError((_) => null as dynamic),
          // 2. Pending Permissions
          schoolRef.collection('Permissions')
              .where('status', isEqualTo: 'pending')
              .get().catchError((_) => null as dynamic),
          // 3. Maintenance Reports
          schoolRef.collection('MaintenanceTickets')
              .where('status', whereIn: ['open', 'pending', 'overdue'])
              .get().catchError((_) => null as dynamic),
        ]);

        final allItems = <ActionNeededItem>[];

        // Tasks
        final tasksSnap = results[0];
        if (tasksSnap != null) {
          for (final d in tasksSnap.docs) {
            final data = d.data() as Map<String, dynamic>;
            allItems.add(ActionNeededItem(
              id: d.id,
              title: data['title'] ?? 'مهمة إدارية',
              subtitle: 'متأخرة عن موعدها',
              type: 'transaction',
              date: (data['dueDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
              priorityLevel: 1,
            ));
          }
        }

        // Permissions
        final permSnap = results[1];
        if (permSnap != null) {
          for (final d in permSnap.docs) {
            final data = d.data() as Map<String, dynamic>;
            allItems.add(ActionNeededItem(
              id: d.id,
              title: 'استئذان: ${data['studentName'] ?? 'طالب'}',
              subtitle: 'بانتظار الموافقة',
              type: 'permission',
              date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              priorityLevel: 2,
            ));
          }
        }

        // Maintenance
        final maintSnap = results[2];
        if (maintSnap != null) {
          for (final d in maintSnap.docs) {
            final data = d.data() as Map<String, dynamic>;
            final isOverdue = data['status'] == 'overdue';
            allItems.add(ActionNeededItem(
              id: d.id,
              title: data['title'] ?? 'بلاغ صيانة',
              subtitle: isOverdue ? 'متأخر' : 'جديد',
              type: 'maintenance',
              date: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
              priorityLevel: isOverdue ? 1 : 2,
            ));
          }
        }

        allItems.sort((a, b) {
          if (a.priorityLevel != b.priorityLevel) {
            return a.priorityLevel.compareTo(b.priorityLevel);
          }
          return b.date.compareTo(a.date);
        });
        return allItems;
      } catch (_) {
        return <ActionNeededItem>[];
      }
    }());
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
