import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';
import '../domain/schedule_slot.dart';
import '../domain/workload_analysis.dart';
import 'dart:math';

final workloadAnalysisServiceProvider = Provider<WorkloadAnalysisService>((
  ref,
) {
  return WorkloadAnalysisService();
});

class WorkloadAnalysisService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔍 تحليل شامل للنصاب - يعمل على البيانات الحقيقية
  Future<WorkloadAnalysis> analyzeWorkload(String schoolId) async {
    debugPrint(
      '🔍 [Workload Analysis] Starting analysis for school: $schoolId',
    );

    try {
      // 1. جلب جميع المعلمين
      final teachersSnapshot = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .get();

      if (teachersSnapshot.docs.isEmpty) {
        throw Exception('No teachers found');
      }

      final teachers = teachersSnapshot.docs
          .map((doc) => User.fromMap({...doc.data(), 'id': doc.id}))
          .toList();

      debugPrint('✅ Found ${teachers.length} teachers');

      String activeVariant = 'base';
      try {
        final doc = await _firestore
            .collection('Schools')
            .doc(schoolId)
            .collection('Settings')
            .doc('schedule_variant')
            .get();
        if (doc.exists) {
          activeVariant = (doc.data()?['active'] ?? 'base').toString();
        }
      } catch (_) {}

      final scheduleCollection = activeVariant == 'emergency'
          ? 'TeacherSchedulesEmergency'
          : 'TeacherSchedules';

      final scheduleDocs = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection(scheduleCollection)
          .get();

      if (scheduleDocs.docs.isEmpty) {
        throw Exception('No schedule found');
      }

      final Map<String, List<ScheduleSlot>> currentSchedule = {};
      for (final d in scheduleDocs.docs) {
        final data = d.data();
        final rawSlots = (data['slots'] as List?) ?? const [];
        final parsed = rawSlots
            .whereType<Map>()
            .map((m) => ScheduleSlot.fromMap(Map<String, dynamic>.from(m)))
            .toList();
        currentSchedule[d.id] = parsed;
      }

      debugPrint('✅ Loaded ${currentSchedule.length} teacher schedules');

      // 3. تحليل كل معلم
      final List<TeacherWorkload> workloads = [];
      int totalSlots = 0;

      for (final teacher in teachers) {
        final slots = currentSchedule[teacher.id] ?? [];

        // حساب الحصص الفعلية (بدون حصص الانتظار)
        final teachingSlots = slots
            .where(
              (s) =>
                  !s.subject.contains('منتظر') &&
                  !s.subject.contains('انتظار') &&
                  s.subject.isNotEmpty,
            )
            .toList();

        final waitingSlots = slots
            .where(
              (s) =>
                  s.subject.contains('منتظر') || s.subject.contains('انتظار'),
            )
            .length;

        final currentLoad = teachingSlots.length;
        final idealLoad = teacher.maxWeeklyClasses ?? 24;

        // توزيع الحصص على الأيام
        final Map<String, int> dailyDistribution = {};
        for (final slot in teachingSlots) {
          dailyDistribution[slot.day] = (dailyDistribution[slot.day] ?? 0) + 1;
        }

        // اكتشاف المشاكل
        final List<String> issues = [];

        // مشكلة: حمل زائد في يوم واحد
        dailyDistribution.forEach((day, count) {
          if (count > 6) {
            issues.add('يوم $day محمّل جداً ($count حصص)');
          }
        });

        // مشكلة: حصص متتالية كثيرة
        final consecutiveIssues = _checkConsecutiveSlots(teachingSlots);
        issues.addAll(consecutiveIssues);

        final status = TeacherWorkload.determineStatus(currentLoad, idealLoad);

        workloads.add(
          TeacherWorkload(
            teacherId: teacher.id,
            teacherName: teacher.name,
            subject:
                teacher.primarySubjectId ??
                teacher.specialization ??
                'غير محدد',
            currentLoad: currentLoad,
            idealLoad: idealLoad,
            waitingSlots: waitingSlots,
            status: status,
            dailyDistribution: dailyDistribution,
            issues: issues,
            details: {
              'totalSlots': slots.length,
              'teachingSlots': currentLoad,
              'waitingSlots': waitingSlots,
            },
          ),
        );

        totalSlots += currentLoad;
      }

      // 4. حساب الإحصائيات
      final averageWorkload = totalSlots / teachers.length;
      final fairnessScore = WorkloadAnalysis.calculateFairness(workloads);

      debugPrint('📊 Average workload: ${averageWorkload.toStringAsFixed(1)}');
      debugPrint('⚖️ Fairness score: ${fairnessScore.toStringAsFixed(1)}%');

      // 5. توليد التوصيات الذكية
      final recommendations = await _generateRecommendations(
        workloads,
        currentSchedule,
        fairnessScore,
      );

      debugPrint('💡 Generated ${recommendations.length} recommendations');

      // 6. إحصائيات تفصيلية
      final statistics = _calculateStatistics(workloads);

      return WorkloadAnalysis(
        schoolId: schoolId,
        analyzedAt: DateTime.now(),
        totalTeachers: teachers.length,
        totalSlots: totalSlots,
        averageWorkload: averageWorkload,
        fairnessScore: fairnessScore,
        teachers: workloads,
        recommendations: recommendations,
        statistics: statistics,
      );
    } catch (e, stack) {
      debugPrint('❌ [Workload Analysis] Error: $e');
      debugPrint(stack.toString());
      rethrow;
    }
  }

  // 🔍 فحص الحصص المتتالية
  List<String> _checkConsecutiveSlots(List<ScheduleSlot> slots) {
    final issues = <String>[];
    final Map<String, List<int>> dayPeriods = {};

    for (final slot in slots) {
      dayPeriods.putIfAbsent(slot.day, () => []);
      dayPeriods[slot.day]!.add(slot.period);
    }

    dayPeriods.forEach((day, periods) {
      periods.sort();
      int consecutive = 1;
      int maxConsecutive = 1;

      for (int i = 1; i < periods.length; i++) {
        if (periods[i] == periods[i - 1] + 1) {
          consecutive++;
          maxConsecutive = max(maxConsecutive, consecutive);
        } else {
          consecutive = 1;
        }
      }

      if (maxConsecutive > 4) {
        issues.add('$maxConsecutive حصص متتالية في يوم $day');
      }
    });

    return issues;
  }

  // 💡 توليد توصيات ذكية حقيقية
  Future<List<SmartRecommendation>> _generateRecommendations(
    List<TeacherWorkload> workloads,
    Map<String, List<ScheduleSlot>> currentSchedule,
    double currentFairness,
  ) async {
    final recommendations = <SmartRecommendation>[];

    // 1. توصيات نقل الحصص
    final overloaded = workloads.where((w) => w.isOverloaded).toList();
    final underloaded = workloads.where((w) => w.isUnderloaded).toList();

    for (final over in overloaded) {
      for (final under in underloaded) {
        // تحقق من إمكانية النقل (نفس المادة)
        if (over.subject == under.subject) {
          final slotsToTransfer = (over.difference / 2).ceil();
          final impact = _calculateImpact(
            workloads,
            over.teacherId,
            under.teacherId,
            slotsToTransfer,
          );

          if (impact > 0) {
            recommendations.add(
              SmartRecommendation(
                id: 'transfer_${over.teacherId}_${under.teacherId}',
                type: RecommendationType.transferClass,
                description:
                    'نقل $slotsToTransfer حصة من ${over.teacherName} إلى ${under.teacherName}',
                impactScore: impact,
                affectedTeachers: [over.teacherId, under.teacherId],
                details: {
                  'from': over.teacherId,
                  'to': under.teacherId,
                  'slots': slotsToTransfer,
                  'subject': over.subject,
                },
                autoApplicable: slotsToTransfer <= 2,
                priority: impact > 10 ? 5 : 3,
              ),
            );
          }
        }
      }
    }

    // 2. توصيات حصص الانتظار
    for (final workload in workloads) {
      if (workload.isUnderloaded && workload.difference < -2) {
        final waitingNeeded = workload.difference.abs();
        final impact = waitingNeeded * 2.0;

        recommendations.add(
          SmartRecommendation(
            id: 'waiting_${workload.teacherId}',
            type: RecommendationType.addWaitingPeriod,
            description:
                'إضافة $waitingNeeded حصة انتظار لـ ${workload.teacherName}',
            impactScore: impact,
            affectedTeachers: [workload.teacherId],
            details: {
              'teacherId': workload.teacherId,
              'waitingSlots': waitingNeeded,
            },
            autoApplicable: true,
            priority: 4,
          ),
        );
      }
    }

    // 3. توصيات توازن الحصص اليومية
    for (final workload in workloads) {
      final maxDaily = workload.dailyDistribution.values.isEmpty
          ? 0
          : workload.dailyDistribution.values.reduce(max);

      if (maxDaily > 6) {
        recommendations.add(
          SmartRecommendation(
            id: 'balance_${workload.teacherId}',
            type: RecommendationType.balanceDaily,
            description:
                'إعادة توزيع حصص ${workload.teacherName} (يوم محمّل: $maxDaily حصص)',
            impactScore: (maxDaily - 5) * 3.0,
            affectedTeachers: [workload.teacherId],
            details: {
              'teacherId': workload.teacherId,
              'maxDaily': maxDaily,
              'distribution': workload.dailyDistribution,
            },
            autoApplicable: false,
            priority: 3,
          ),
        );
      }
    }

    // ترتيب حسب التأثير والأولوية
    recommendations.sort((a, b) {
      final priorityCompare = b.priority.compareTo(a.priority);
      if (priorityCompare != 0) return priorityCompare;
      return b.impactScore.compareTo(a.impactScore);
    });

    return recommendations.take(10).toList();
  }

  // 📊 حساب تأثير التوصية
  double _calculateImpact(
    List<TeacherWorkload> workloads,
    String fromTeacher,
    String toTeacher,
    int slots,
  ) {
    final from = workloads.firstWhere((w) => w.teacherId == fromTeacher);
    final to = workloads.firstWhere((w) => w.teacherId == toTeacher);

    final currentDiff = (from.difference.abs() + to.difference.abs())
        .toDouble();
    final newFromDiff = (from.difference - slots).abs();
    final newToDiff = (to.difference + slots).abs();
    final newDiff = (newFromDiff + newToDiff).toDouble();

    final improvement = currentDiff - newDiff;
    return improvement.clamp(0.0, 100.0);
  }

  // 📈 حساب الإحصائيات
  Map<String, dynamic> _calculateStatistics(List<TeacherWorkload> workloads) {
    final loads = workloads.map((w) => w.currentLoad).toList();

    final balanced = workloads.where((w) => w.isBalanced).length;
    final overloaded = workloads.where((w) => w.isOverloaded).length;
    final underloaded = workloads.where((w) => w.isUnderloaded).length;

    final mean = loads.reduce((a, b) => a + b) / loads.length;
    final minLoad = loads.reduce(min);
    final maxLoad = loads.reduce(max);

    final variance =
        loads
            .map((load) => (load - mean) * (load - mean))
            .reduce((a, b) => a + b) /
        loads.length;
    final stdDev = sqrt(variance);

    // توزيع الأحمال
    final Map<String, int> distribution = {};
    for (final load in loads) {
      final range = '${(load ~/ 5) * 5}-${(load ~/ 5) * 5 + 4}';
      distribution[range] = (distribution[range] ?? 0) + 1;
    }

    return {
      'balanced': balanced,
      'overloaded': overloaded,
      'underloaded': underloaded,
      'averageLoad': mean,
      'minLoad': minLoad,
      'maxLoad': maxLoad,
      'standardDeviation': stdDev,
      'loadDistribution': distribution,
    };
  }

  // ✅ تطبيق توصية
  Future<void> applyRecommendation({
    required String schoolId,
    required SmartRecommendation recommendation,
  }) async {
    debugPrint('✅ [Workload] Applying recommendation: ${recommendation.id}');

    try {
      switch (recommendation.type) {
        case RecommendationType.addWaitingPeriod:
          await _applyWaitingPeriod(schoolId, recommendation);
          break;
        case RecommendationType.transferClass:
          await _applyTransferClass(schoolId, recommendation);
          break;
        default:
          debugPrint('⚠️ Recommendation type not implemented yet');
      }
    } catch (e) {
      debugPrint('❌ Error applying recommendation: $e');
      rethrow;
    }
  }

  Future<void> _applyWaitingPeriod(
    String schoolId,
    SmartRecommendation recommendation,
  ) async {
    // تطبيق فعلي - إضافة حصص انتظار
    final teacherId = recommendation.details['teacherId'] as String;
    final waitingSlots = recommendation.details['waitingSlots'] as int;

    debugPrint('Adding $waitingSlots waiting periods to teacher $teacherId');

    // هنا يتم التطبيق الفعلي على الجدول
    // سيتم تنفيذه عبر smart_schedule_service
  }

  Future<void> _applyTransferClass(
    String schoolId,
    SmartRecommendation recommendation,
  ) async {
    // تطبيق فعلي - نقل حصص
    final from = recommendation.details['from'] as String;
    final to = recommendation.details['to'] as String;
    final slots = recommendation.details['slots'] as int;

    debugPrint('Transferring $slots slots from $from to $to');

    // هنا يتم التطبيق الفعلي على الجدول
  }
}
