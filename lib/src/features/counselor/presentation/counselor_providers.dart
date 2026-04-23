import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_counselor_repository.dart';
import '../domain/models/student_case.dart';
import '../domain/models/counselor_session.dart';
import '../domain/models/behavior_plan.dart';
import '../../admin_tasks/domain/admin_task_entity.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../domain/models/counselor_dashboard_models.dart';

// Repository Provider
final counselorRepositoryProvider = Provider<FirestoreCounselorRepository>((
  ref,
) {
  return FirestoreCounselorRepository(FirebaseFirestore.instance);
});

// Active Cases Provider
final activeCasesProvider = StreamProvider<List<StudentCase>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  if (user == null || (schoolId == null || schoolId.isEmpty)) {
    return Stream.value([]);
  }

  final repository = ref.watch(counselorRepositoryProvider);
  return repository.watchActiveCases(schoolId).map((cases) {
    return cases.map((c) {
      // Governance: Mask description if assigned to another counselor
      if (c.assignedTo != null &&
          c.assignedTo!.isNotEmpty &&
          c.assignedTo != user.id) {
        return StudentCase(
          id: c.id,
          studentId: c.studentId,
          studentName: c.studentName,
          schoolId: c.schoolId,
          title: c.title,
          description: '*** محتوى سري - تابع لمرشد آخر ***',
          status: c.status,
          priority: c.priority,
          createdAt: c.createdAt,
          updatedAt: c.updatedAt,
          assignedTo: c.assignedTo,
          evidenceCount: c.evidenceCount,
        );
      }
      return c;
    }).toList();
  });
});

// Today's Sessions Provider
final todaySessionsProvider =
    StreamProvider<List<CounselorSession>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId;
      if (user == null || (schoolId == null || schoolId.isEmpty)) {
        return Stream.value([]);
      }

      final repository = ref.watch(counselorRepositoryProvider);
      return repository.watchTodaySessions(schoolId).map((sessions) {
        return sessions.map((session) {
          // Governance: Mask confidential sessions of other counselors
          if (session.isConfidential &&
              session.counselorId.isNotEmpty &&
              session.counselorId != user.id) {
            return CounselorSession(
              id: session.id,
              schoolId: session.schoolId,
              title: 'جلسة سرية',
              description: '*** محتوى سري ***',
              scheduledAt: session.scheduledAt,
              durationMinutes: session.durationMinutes,
              status: session.status,
              type: session.type,
              attendeeIds: [], // Mask student identity
              caseId: null, // Mask case link
              evidenceCount: session.evidenceCount,
              counselorId: session.counselorId,
              isConfidential: true,
              attachments: [], // Mask attachments
            );
          }
          return session;
        }).toList();
      });
    });

// Active Plans Provider - للاستخدام في لوحة المرشد وشاشة تقييم التقدم
final activePlansProvider = StreamProvider<List<BehaviorPlan>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  if (user == null || (schoolId == null || schoolId.isEmpty)) {
    return Stream.value([]);
  }

  // البحث عن الخطط في education_plans
  return FirebaseFirestore.instance
      .collection('education_plans')
      .where('schoolId', isEqualTo: schoolId)
      .where('status', isEqualTo: 'active')
      .snapshots()
      .map((snapshot) {
    final plans = snapshot.docs.map((doc) {
      final data = doc.data();
      return BehaviorPlan(
        id: doc.id,
        studentId: data['studentId'] ?? '',
        studentName: data['studentName'] ?? 'طالب',
        schoolId: schoolId,
        title: data['title'] ?? data['planName'] ?? '',
        goals: List<String>.from(data['goals'] ?? []),
        status: PlanStatus.active,
        startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
        endDate: (data['endDate'] as Timestamp?)?.toDate(),
        createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      );
    }).toList();
    
    return plans;
  });
});

// Counselor Tasks Provider
final counselorTasksProvider =
    StreamProvider<List<AdminTaskEntity>>((ref) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId;
      if (user == null || (schoolId == null || schoolId.isEmpty)) {
        return Stream.value([]);
      }

      final repository = ref.watch(counselorRepositoryProvider);
      return repository.watchCounselorTasks(schoolId);
    });

// Smart Alerts Provider
final smartAlertsProvider =
    Provider<AsyncValue<List<AdminTaskEntity>>>((ref) {
      final tasksAsync = ref.watch(counselorTasksProvider);

      return tasksAsync.when(
        data: (tasks) {
          final alerts = tasks.where((t) {
            final isImportant =
                t.priority == AdminTaskPriority.high ||
                t.priority == AdminTaskPriority.urgent;
            return isImportant || t.isOverdue;
          }).toList();

          // Sort by priority (urgent first) then date
          alerts.sort((a, b) {
            if (a.priority != b.priority) {
              // urgent > high > medium > low
              // enum index: low=0, medium=1, high=2, urgent=3
              // we want descending order
              return b.priority.index.compareTo(a.priority.index);
            }
            return a.dueDate.compareTo(b.dueDate);
          });

          return AsyncValue.data(alerts.take(5).toList());
        },
        loading: () => const AsyncValue.loading(),
        error: (e, s) => AsyncValue.error(e, s),
      );
    });

// New Providers for "Command Center"

// 1. Risk Triage Provider
final riskTriageProvider = FutureProvider<List<RiskCase>>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  if (user == null || schoolId == null || schoolId.isEmpty) return [];

  final behaviorRepo = ref.watch(behaviorRepositoryProvider);

  // 1. Repeated Violations (3 in 7 days)
  final since = DateTime.now().subtract(const Duration(days: 7));
  final recentBehavior = await behaviorRepo.getSchoolBehavior(
    schoolId,
    since: since,
  );

  final Map<String, int> violationCounts = {};
  final Map<String, String> studentNames = {};

  for (var record in recentBehavior) {
    if (record.type == BehaviorType.negative) {
      violationCounts[record.studentId] =
          (violationCounts[record.studentId] ?? 0) + 1;
      studentNames[record.studentId] = record.studentName ?? 'طالب';
    }
  }

  final List<RiskCase> risks = [];

  violationCounts.forEach((studentId, count) {
    if (count >= 3) {
      risks.add(
        RiskCase(
          studentId: studentId,
          studentName: studentNames[studentId] ?? 'طالب',
          reason: '$count مخالفات خلال أسبوع',
          severity: 'critical',
          detectedAt: DateTime.now(),
        ),
      );
    }
  });

  // 2. Plans without recent sessions
  final activePlans = await ref.watch(activePlansProvider.future);
  for (var plan in activePlans) {
    final lastUpdate = plan.updatedAt ?? plan.createdAt;
    if (DateTime.now().difference(lastUpdate).inDays > 10) {
      risks.add(
        RiskCase(
          studentId: plan.studentId,
          studentName: 'خطة #${plan.id.substring(0, 4)}',
          reason: 'خطة بدون متابعة منذ 10 أيام',
          severity: 'high',
          detectedAt: DateTime.now(),
        ),
      );
    }
  }

  return risks;
});

// 2. Counseling Load Provider
final counselingLoadProvider = FutureProvider<CounselingLoad>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  if (user == null || schoolId == null || schoolId.isEmpty) {
    return CounselingLoad(
      activeCases: 0,
      openPlans: 0,
      sessionsThisWeek: 0,
      avgClosureDays: 0,
      status: 'normal',
    );
  }

  final activeCases = await ref.watch(activeCasesProvider.future);
  final activePlans = await ref.watch(activePlansProvider.future);
  final todaySessions = await ref.watch(todaySessionsProvider.future);

  // Estimate weekly sessions (mock for now as we don't have getThisWeekSessions)
  final sessionsThisWeek = todaySessions.length * 5;

  String status = 'normal';
  if (activeCases.length > 20 || activePlans.length > 15)
    status = 'high';
  else if (activeCases.length > 10 || activePlans.length > 8)
    status = 'medium';

  return CounselingLoad(
    activeCases: activeCases.length,
    openPlans: activePlans.length,
    sessionsThisWeek: sessionsThisWeek,
    avgClosureDays: 4.5,
    status: status,
  );
});

// 3. Smart Recommendation Provider
final smartRecommendationProvider =
    FutureProvider<CounselingRecommendation>((ref) async {
      final user = ref.watch(authStateProvider).value;
      final schoolId = user?.schoolId;
      if (user == null || schoolId == null || schoolId.isEmpty) {
        return CounselingRecommendation(
          title: '',
          description: '',
          targetGroup: '',
          type: '',
        );
      }

      final behaviorRepo = ref.watch(behaviorRepositoryProvider);
      final since = DateTime.now().subtract(const Duration(days: 7));
      final recentBehavior = await behaviorRepo.getSchoolBehavior(
        schoolId,
        since: since,
      );

      final Map<String, int> classNegativeCounts = {};
      for (var record in recentBehavior) {
        if (record.type == BehaviorType.negative && record.classId != null) {
          classNegativeCounts[record.className ?? 'Unknown'] =
              (classNegativeCounts[record.className ?? 'Unknown'] ?? 0) + 1;
        }
      }

      if (classNegativeCounts.isEmpty) {
        return CounselingRecommendation(
          title: 'مراقبة عامة',
          description:
              'لا توجد بيانات سلبية كافية هذا الأسبوع. ركز على الجولات الميدانية.',
          targetGroup: 'المدرسة',
          type: 'general',
        );
      }

      var maxClass = '';
      var maxCount = 0;
      classNegativeCounts.forEach((cls, count) {
        if (count > maxCount) {
          maxCount = count;
          maxClass = cls;
        }
      });

      return CounselingRecommendation(
        title: 'تركيز أسبوعي',
        description:
            'لوحظ ارتفاع في السلوكيات السلبية ($maxCount مخالفة) في هذا الصف.',
        targetGroup: maxClass,
        type: 'behavior',
      );
    });

// 4. Connectivity Provider (for Offline Indicator)
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});
