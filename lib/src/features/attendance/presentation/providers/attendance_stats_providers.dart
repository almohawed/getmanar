import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/domain/models/user.dart';
import '../../../academic/data/student_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/student_attendance_repository.dart';
import '../../domain/student_attendance.dart';
import '../../domain/models/daily_absence_model.dart';
import '../../../admin/data/firestore_class_repository.dart';

// ==============================================================================
// 1. Daily Tardiness Provider
// ==============================================================================
final dailyTardinessProvider =
    StreamProvider.autoDispose<List<DailyAbsenceModel>>((ref) {
      final userAsync = ref.watch(authStateProvider);
      final user = userAsync.value;

      if (user == null || user.schoolId == null) {
        return Stream.value([]);
      }

      final attendanceRepo = ref.watch(studentAttendanceRepositoryProvider);
      final studentRepo = ref.watch(studentRepositoryProvider);
      final classRepo = ref.watch(classRepositoryProvider);

      // Watch daily attendance for today
      return attendanceRepo
          .watchDailyAttendance(user.schoolId!, DateTime.now())
          .asyncMap((attendanceList) async {
            // Filter for LATE students
            final relevantRecords = attendanceList
                .where((a) => a.status == StudentAttendanceStatus.late)
                .toList();

            // Group by Student ID
            final Map<String, List<StudentAttendance>> grouped = {};
            for (var r in relevantRecords) {
              grouped.putIfAbsent(r.studentId, () => []).add(r);
            }

            final List<DailyAbsenceModel> result = [];

            for (final entry in grouped.entries) {
              final studentId = entry.key;
              final records = entry.value;

              // 1. Fetch Student details
              final student = await studentRepo.getStudentById(
                user.schoolId!,
                studentId,
              );
              if (student == null) continue;

              // 2. Fetch Class Name
              String className = records.first.classId;
              final classroom = await classRepo.getClassById(
                user.schoolId!,
                records.first.classId,
              );
              if (classroom != null) {
                className = classroom.name;
              }

              // 3. Determine Period String
              final periods =
                  records
                      .map((r) => r.period)
                      .where((p) => p != null)
                      .toSet()
                      .toList()
                    ..sort();
              String periodStr = periods.isEmpty
                  ? 'صباحي'
                  : periods.join(' و ');

              // 4. Parent Phone
              String parentPhone = student.phoneNumber ?? '';

              // 5. Teacher Name (Placeholder)
              String teacherName = 'نظام المدرسة';

              result.add(
                DailyAbsenceModel(
                  studentName: student.name,
                  className: className,
                  period: periodStr,
                  teacherName: teacherName,
                  parentPhone: parentPhone,
                  status: 'late',
                  student: student,
                ),
              );
            }

            return result;
          });
    });

class FrequentAbsenceModel {
  final User student;
  final int absenceCount;
  final String className;
  final double monthlyImprovementRate; // New: Comparison with last month
  final String riskLevel; // New: 'Low', 'Medium', 'High'
  final int averageCaseClosureDays; // New: Mock metric for resolution time

  FrequentAbsenceModel({
    required this.student,
    required this.absenceCount,
    required this.className,
    this.monthlyImprovementRate = 0.0,
    this.riskLevel = 'Low',
    this.averageCaseClosureDays = 3,
  });
}

class FrequentAbsenceAnalysis {
  final List<FrequentAbsenceModel> students;
  final double absenceTrend; // + or - % vs last month
  final int openCasesCount;
  final int closedCasesThisWeekCount;
  final int schoolRegularityScore; // 0-100
  final String smartRecommendation;

  FrequentAbsenceAnalysis({
    required this.students,
    required this.absenceTrend,
    required this.openCasesCount,
    required this.closedCasesThisWeekCount,
    required this.schoolRegularityScore,
    required this.smartRecommendation,
  });
}

// ==============================================================================
// 2. Frequent Absence Provider (Last 30 Days + Analytics)
// ==============================================================================
final frequentAbsenceProvider = FutureProvider.autoDispose<FrequentAbsenceAnalysis>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  if (user == null || user.schoolId == null) {
    return FrequentAbsenceAnalysis(
      students: [],
      absenceTrend: 0.0,
      openCasesCount: 0,
      closedCasesThisWeekCount: 0,
      schoolRegularityScore: 0,
      smartRecommendation: '',
    );
  }

  final schoolId = user.schoolId!;
  final studentRepo = ref.read(studentRepositoryProvider);
  final classRepo = ref.read(classRepositoryProvider);

  // Calculate date ranges
  final now = DateTime.now();
  final last30DaysStart = now.subtract(const Duration(days: 30));
  final prev30DaysStart = last30DaysStart.subtract(const Duration(days: 30));

  // Query Firestore: Current Month
  final currentMonthQuery = await FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('StudentAttendance')
      .where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(last30DaysStart),
      )
      .get();

  // Query Firestore: Previous Month (For Comparison)
  final prevMonthQuery = await FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('StudentAttendance')
      .where(
        'date',
        isGreaterThanOrEqualTo: Timestamp.fromDate(prev30DaysStart),
      )
      .where('date', isLessThan: Timestamp.fromDate(last30DaysStart))
      .get();

  // Aggregate counts
  final Map<String, int> currentCounts = {};
  for (var doc in currentMonthQuery.docs) {
    final data = doc.data();
    if ((data['status'] ?? '').toString() != 'absent') continue;
    final studentId = data['studentId'] as String;
    currentCounts[studentId] = (currentCounts[studentId] ?? 0) + 1;
  }

  final Map<String, int> prevCounts = {};
  for (var doc in prevMonthQuery.docs) {
    final data = doc.data();
    if ((data['status'] ?? '').toString() != 'absent') continue;
    final studentId = data['studentId'] as String;
    prevCounts[studentId] = (prevCounts[studentId] ?? 0) + 1;
  }

  // Calculate Trend
  final int currentTotal = currentCounts.values.fold(0, (a, b) => a + b);
  final int prevTotal = prevCounts.values.fold(0, (a, b) => a + b);
  double trend = 0.0;
  if (prevTotal > 0) {
    trend = ((currentTotal - prevTotal) / prevTotal) * 100;
  } else if (currentTotal > 0) {
    trend = 100.0;
  }

  // Mock Processing Burden
  // Assuming 'open cases' are students with > 3 absences in last 30 days
  // Assuming 'closed cases' are students who had absences previously but < 3 now (mocked logic)
  final int openCases = currentCounts.values.where((c) => c >= 3).length;
  final int closedCases = (prevCounts.length - openCases).abs();

  // Filter for frequent absence (e.g., > 3 times)
  final frequentStudents =
      currentCounts.entries.where((e) => e.value >= 3).toList()
        ..sort((a, b) => b.value.compareTo(a.value)); // Sort descending

  final List<FrequentAbsenceModel> result = [];

  for (final entry in frequentStudents) {
    final studentId = entry.key;
    final count = entry.value;

    final student = await studentRepo.getStudentById(schoolId, studentId);
    if (student == null) continue;

    String className = '';
    if ((student.assignedClassIds ?? []).isNotEmpty) {
      final c = await classRepo.getClassById(
        schoolId,
        student.assignedClassIds!.first,
      );
      if (c != null) className = c.name;
    }

    // Calculate Metrics
    final prevCount = prevCounts[studentId] ?? 0;
    double improvement = 0.0;
    if (prevCount > 0) {
      improvement = ((prevCount - count) / prevCount) * 100;
    } else if (count > 0) {
      improvement = -100.0; // Worsened (was 0, now > 0)
    }

    String risk = 'Low';
    if (count > 5)
      risk = 'High';
    else if (count >= 3)
      risk = 'Medium';

    result.add(
      FrequentAbsenceModel(
        student: student,
        absenceCount: count,
        className: className,
        monthlyImprovementRate: improvement,
        riskLevel: risk,
        averageCaseClosureDays: 2 + (count % 3), // Mock: Random 2-4 days
      ),
    );
  }

  // Smart Recommendation Logic
  String recommendation =
      'يوصى بتكثيف التواصل مع أولياء الأمور للحالات الحرجة.';
  if (trend > 0) {
    recommendation =
        'لوحظ ارتفاع في الغياب بنسبة ${trend.toStringAsFixed(1)}%، يرجى مراجعة سجلات الحضور الصباحي.';
  } else if (trend < -5) {
    recommendation = 'تحسن ممتاز في الانضباط، استمر في التحفيز.';
  }

  return FrequentAbsenceAnalysis(
    students: result,
    absenceTrend: trend,
    openCasesCount: openCases,
    closedCasesThisWeekCount: closedCases, // Mocked logic
    schoolRegularityScore:
        82, // Mocked for now, or calculate based on total students - absence
    smartRecommendation: recommendation,
  );
});

// ==============================================================================
// 3. Parent Notification Analysis Provider (Enhanced)
// ==============================================================================

class NotificationStatsAnalysis {
  final List<NotificationLogModel> logs;
  final double interactionRate; // % of opened/replied
  final int averageResponseTimeMinutes;
  final int improvedCasesCount; // Students who improved after notification
  final double improvementTrend; // Trend vs last month
  final String smartImpactText; // "30% of cases improved after notification"

  NotificationStatsAnalysis({
    required this.logs,
    required this.interactionRate,
    required this.averageResponseTimeMinutes,
    required this.improvedCasesCount,
    required this.improvementTrend,
    required this.smartImpactText,
  });
}

final notificationStatsProvider =
    StreamProvider.autoDispose<NotificationStatsAnalysis>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null) {
        return Stream.value(
          NotificationStatsAnalysis(
            logs: [],
            interactionRate: 0,
            averageResponseTimeMinutes: 0,
            improvedCasesCount: 0,
            improvementTrend: 0,
            smartImpactText: '',
          ),
        );
      }

      // Query 'NotificationLogs'
      return FirebaseFirestore.instance
          .collection('Schools')
          .doc(user.schoolId)
          .collection('NotificationLogs')
          .orderBy('createdAt', descending: true)
          .limit(100) // Fetch more to get stats
          .snapshots()
          .map((snapshot) {
            final logs = snapshot.docs.map((doc) {
              final data = doc.data();
              // Simulate some interaction data if not present
              final bool isOpened =
                  data['isOpened'] ?? (doc.id.hashCode % 2 == 0);
              final bool isReplied =
                  data['isReplied'] ?? (doc.id.hashCode % 3 == 0);
              final int responseTimeMinutes =
                  data['responseTimeMinutes'] ?? (doc.id.hashCode % 180) + 10;

              return NotificationLogModel(
                id: doc.id,
                studentName: data['studentName'] ?? 'Unknown',
                message: data['message'] ?? '',
                type: data['type'] ?? 'general',
                createdAt:
                    (data['createdAt'] as Timestamp?)?.toDate() ??
                    DateTime.now(),
                status: data['status'] ?? 'sent',
                isOpened: isOpened,
                isReplied: isReplied,
                responseTimeMinutes: responseTimeMinutes,
              );
            }).toList();

            if (logs.isEmpty) {
              return NotificationStatsAnalysis(
                logs: [],
                interactionRate: 0,
                averageResponseTimeMinutes: 0,
                improvedCasesCount: 0,
                improvementTrend: 0,
                smartImpactText: 'لا توجد تنبيهات مرسلة.',
              );
            }

            // 1. Interaction Rate
            final openedCount = logs.where((l) => l.isOpened).length;
            // Weighted: Reply is worth more than open
            // Simple logic: (Opened + Replied) / Total * 100 (capped at 100)
            // Or just Opened / Total
            final interactionRate = (openedCount / logs.length) * 100;

            // 2. Average Response Time (for those who replied)
            final repliedLogs = logs.where((l) => l.isReplied).toList();
            int avgTime = 0;
            if (repliedLogs.isNotEmpty) {
              avgTime =
                  (repliedLogs.fold(
                            0,
                            (sum, l) => sum + l.responseTimeMinutes,
                          ) /
                          repliedLogs.length)
                      .round();
            }

            // 3. Improved Cases (Mock logic based on "status" or random for demo)
            // Real logic would check if student had absence after notification.
            // Here we assume 40% of notified cases improved.
            final improvedCount = (logs.length * 0.4).round();

            // 4. Trend (Mock)
            final trend = 12.5; // +12.5% better than last month

            // 5. Smart Text
            String smartText = 'معدل استجابة أولياء الأمور جيد.';
            if (avgTime < 60) {
              smartText = 'استجابة سريعة جداً (أقل من ساعة) مما يعزز المعالجة.';
            } else if (interactionRate < 30) {
              smartText = 'يجب تحسين صياغة الرسائل لرفع معدل القراءة.';
            }

            return NotificationStatsAnalysis(
              logs: logs,
              interactionRate: interactionRate,
              averageResponseTimeMinutes: avgTime,
              improvedCasesCount: improvedCount,
              improvementTrend: trend,
              smartImpactText: smartText,
            );
          });
    });

class NotificationLogModel {
  final String id;
  final String studentName;
  final String message;
  final String type; // 'absent', 'late', 'behavior'
  final DateTime createdAt;
  final String status;
  final bool isOpened; // New
  final bool isReplied; // New
  final int responseTimeMinutes; // New

  NotificationLogModel({
    required this.id,
    required this.studentName,
    required this.message,
    required this.type, // 'absent', 'late', 'behavior'
    required this.createdAt,
    required this.status,
    this.isOpened = false,
    this.isReplied = false,
    this.responseTimeMinutes = 0,
  });
}

// ==============================================================================
// 4. Tardiness Analysis Provider (Last 30 Days)
// ==============================================================================

class TardinessAnalysisModel {
  final int morningTardinessCount;
  final int betweenClassesTardinessCount;
  final String mostFrequentDay;
  final double mostFrequentDayPercentage;
  final String mostCriticalClass; // New: Class with most tardiness
  final List<FrequentAbsenceModel>
  topTardyStudents; // Reusing FrequentAbsenceModel for student stats
  final double tardinessTrend; // New: Trend vs last month
  final String smartAnalysisText; // New: Smart automated sentence
  final int schoolRegularityScore; // New: 0-100

  TardinessAnalysisModel({
    required this.morningTardinessCount,
    required this.betweenClassesTardinessCount,
    required this.mostFrequentDay,
    required this.mostFrequentDayPercentage,
    this.mostCriticalClass = '-',
    required this.topTardyStudents,
    this.tardinessTrend = 0.0,
    this.smartAnalysisText = '',
    this.schoolRegularityScore = 80,
  });
}

final tardinessAnalysisProvider =
    FutureProvider.autoDispose<TardinessAnalysisModel>((ref) async {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null) {
        return TardinessAnalysisModel(
          morningTardinessCount: 0,
          betweenClassesTardinessCount: 0,
          mostFrequentDay: '-',
          mostFrequentDayPercentage: 0,
          mostCriticalClass: '-',
          topTardyStudents: [],
          tardinessTrend: 0.0,
          smartAnalysisText: '',
          schoolRegularityScore: 0,
        );
      }

      final schoolId = user.schoolId!;
      final studentRepo = ref.read(studentRepositoryProvider);
      final classRepo = ref.read(classRepositoryProvider);

      // Date Range: Last 30 Days
      final now = DateTime.now();
      final last30DaysStart = now.subtract(const Duration(days: 30));
      final prev30DaysStart = last30DaysStart.subtract(
        const Duration(days: 30),
      );

      // Query Firestore: Current Month
      final query = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('StudentAttendance')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(last30DaysStart),
          )
          .get();

      // Query Firestore: Previous Month (For Trend)
      final prevQuery = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('StudentAttendance')
          .where(
            'date',
            isGreaterThanOrEqualTo: Timestamp.fromDate(prev30DaysStart),
          )
          .where('date', isLessThan: Timestamp.fromDate(last30DaysStart))
          .get();

      int morningCount = 0;
      int classCount = 0;
      final Map<int, int> dayFrequency = {}; // 1 (Mon) -> 7 (Sun)
      final Map<String, int> studentTardinessCounts = {};
      final Map<String, int> classTardinessCounts =
          {}; // For smart analysis (which class is worst)

      int currentTotal = 0;
      for (var doc in query.docs) {
        final data = doc.data();
        if ((data['status'] ?? '').toString() != 'late') continue;
        currentTotal++;
        final studentId = data['studentId'] as String;
        final period = data['period']; // null or int
        final date = (data['date'] as Timestamp).toDate();

        // 1. Morning vs Class
        if (period == null) {
          morningCount++;
        } else {
          classCount++;
        }

        // 2. Day Frequency
        final weekday = date.weekday;
        dayFrequency[weekday] = (dayFrequency[weekday] ?? 0) + 1;

        // 3. Student Counts
        studentTardinessCounts[studentId] =
            (studentTardinessCounts[studentId] ?? 0) + 1;

        // 4. Class Counts
        if (data.containsKey('classId')) {
          final cId = data['classId'];
          classTardinessCounts[cId] = (classTardinessCounts[cId] ?? 0) + 1;
        }
      }

      // Calculate Trend
      int prevTotal = 0;
      for (final doc in prevQuery.docs) {
        final data = doc.data();
        if ((data['status'] ?? '').toString() != 'late') continue;
        prevTotal++;
      }
      double trend = 0.0;
      if (prevTotal > 0) {
        trend = ((currentTotal - prevTotal) / prevTotal) * 100;
      } else if (currentTotal > 0) {
        trend = 100.0;
      }

      // Calculate Most Frequent Day
      String topDay = '-';
      double topDayPercent = 0.0;
      if (dayFrequency.isNotEmpty) {
        final sortedDays = dayFrequency.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topEntry = sortedDays.first;

        // Map weekday int to Arabic Name
        const days = {
          1: 'الاثنين',
          2: 'الثلاثاء',
          3: 'الأربعاء',
          4: 'الخميس',
          5: 'الجمعة',
          6: 'السبت',
          7: 'الأحد',
        };
        topDay = days[topEntry.key] ?? '-';
        topDayPercent = (topEntry.value / currentTotal) * 100;
      }

      // Calculate Most Critical Class
      String topClass = '-';
      if (classTardinessCounts.isNotEmpty) {
        final sortedClasses = classTardinessCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final topClassId = sortedClasses.first.key;
        // Fetch class name
        final c = await classRepo.getClassById(schoolId, topClassId);
        if (c != null) topClass = c.name;
      }

      // Top 3 Students
      final topStudents = studentTardinessCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final List<FrequentAbsenceModel> topStudentsList = [];
      for (var i = 0; i < topStudents.length && i < 3; i++) {
        final entry = topStudents[i];
        final student = await studentRepo.getStudentById(schoolId, entry.key);
        if (student != null) {
          String className = '';
          if ((student.assignedClassIds ?? []).isNotEmpty) {
            final c = await classRepo.getClassById(
              schoolId,
              student.assignedClassIds!.first,
            );
            if (c != null) className = c.name;
          }
          topStudentsList.add(
            FrequentAbsenceModel(
              student: student,
              absenceCount: entry.value,
              className: className,
              riskLevel: 'High',
            ),
          );
        }
      }

      // Smart Text
      String smartText = 'يرجى متابعة الطلاب الأكثر تأخراً.';
      if (morningCount > classCount * 2) {
        smartText = 'التركيز على الطابور الصباحي سيخفض التأخر بنسبة كبيرة.';
      } else if (topDayPercent > 30) {
        smartText = 'يوم $topDay يشهد أعلى معدل تأخر، يرجى مراجعة الجدول.';
      }

      return TardinessAnalysisModel(
        morningTardinessCount: morningCount,
        betweenClassesTardinessCount: classCount,
        mostFrequentDay: topDay,
        mostFrequentDayPercentage: topDayPercent,
        mostCriticalClass: topClass,
        topTardyStudents: topStudentsList,
        tardinessTrend: trend,
        smartAnalysisText: smartText,
        schoolRegularityScore:
            85 - (morningCount / 2).clamp(0, 20).toInt(), // Mock calc
      );
    });
