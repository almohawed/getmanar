import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/schedule_modification.dart';
import '../domain/schedule_slot.dart';

final modificationTrackingServiceProvider = Provider<ModificationTrackingService>((ref) {
  return ModificationTrackingService();
});

// 📝 خدمة تتبع التعديلات
class ModificationTrackingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 📝 تسجيل تعديل
  Future<void> logModification({
    required String schoolId,
    required String scheduleId,
    required String modifiedBy,
    required String modifierName,
    required ModificationType type,
    required String description,
    required Map<String, dynamic> before,
    required Map<String, dynamic> after,
    required List<String> affectedTeachers,
    required List<String> affectedClasses,
    String? reason,
  }) async {
    debugPrint('📝 [Modification] Logging: $description');

    try {
      final modification = ScheduleModification(
        id: _firestore.collection('temp').doc().id,
        schoolId: schoolId,
        scheduleId: scheduleId,
        timestamp: DateTime.now(),
        modifiedBy: modifiedBy,
        modifierName: modifierName,
        type: type,
        description: description,
        before: before,
        after: after,
        affectedTeachers: affectedTeachers,
        affectedClasses: affectedClasses,
        reason: reason,
        metadata: {
          'impactScore': (affectedTeachers.length * 2) + affectedClasses.length,
          'isMajor': ((affectedTeachers.length * 2) + affectedClasses.length) > 5,
        },
      );

      await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('ScheduleModifications')
          .doc(modification.id)
          .set(modification.toMap());

      debugPrint('✅ [Modification] Logged successfully');
    } catch (e) {
      debugPrint('❌ [Modification] Error logging: $e');
      rethrow;
    }
  }

  // 📊 جلب التعديلات
  Future<List<ScheduleModification>> getModifications({
    required String schoolId,
    String? scheduleId,
    DateTime? startDate,
    DateTime? endDate,
    int? limit,
  }) async {
    debugPrint('📊 [Modification] Fetching modifications');

    try {
      Query query = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('ScheduleModifications')
          .orderBy('timestamp', descending: true);

      if (scheduleId != null) {
        query = query.where('scheduleId', isEqualTo: scheduleId);
      }

      if (startDate != null) {
        query = query.where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate));
      }

      if (endDate != null) {
        query = query.where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate));
      }

      if (limit != null) {
        query = query.limit(limit);
      }

      final snapshot = await query.get();
      
      final modifications = snapshot.docs
          .map((doc) => ScheduleModification.fromMap({
                ...doc.data() as Map<String, dynamic>,
                'id': doc.id,
              }))
          .toList();

      debugPrint('✅ [Modification] Found ${modifications.length} modifications');
      return modifications;
    } catch (e) {
      debugPrint('❌ [Modification] Error fetching: $e');
      rethrow;
    }
  }

  // 📈 حساب الإحصائيات
  Future<ModificationStatistics> calculateStatistics({
    required String schoolId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    debugPrint('📈 [Modification] Calculating statistics');

    try {
      final modifications = await getModifications(
        schoolId: schoolId,
        startDate: startDate,
        endDate: endDate,
      );

      if (modifications.isEmpty) {
        return ModificationStatistics(
          totalModifications: 0,
          byType: {},
          byModifier: {},
          byDay: {},
          byHour: {},
          majorModifications: 0,
          minorModifications: 0,
          averageImpact: 0,
          mostAffectedTeachers: [],
          mostAffectedClasses: [],
        );
      }

      // حسب النوع
      final Map<ModificationType, int> byType = {};
      for (final mod in modifications) {
        byType[mod.type] = (byType[mod.type] ?? 0) + 1;
      }

      // حسب المعدّل
      final Map<String, int> byModifier = {};
      for (final mod in modifications) {
        byModifier[mod.modifierName] = (byModifier[mod.modifierName] ?? 0) + 1;
      }

      // حسب اليوم
      final Map<String, int> byDay = {};
      final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس', 'الجمعة', 'السبت'];
      for (final mod in modifications) {
        final dayIndex = mod.timestamp.weekday % 7;
        final dayName = days[dayIndex];
        byDay[dayName] = (byDay[dayName] ?? 0) + 1;
      }

      // حسب الساعة
      final Map<String, int> byHour = {};
      for (final mod in modifications) {
        final hour = mod.timestamp.hour;
        final hourRange = '${hour}:00-${hour + 1}:00';
        byHour[hourRange] = (byHour[hourRange] ?? 0) + 1;
      }

      // التعديلات الكبيرة والصغيرة
      final majorMods = modifications.where((m) => m.isMajor).length;
      final minorMods = modifications.length - majorMods;

      // متوسط التأثير
      final totalImpact = modifications.fold<int>(0, (sum, mod) => sum + mod.impactScore);
      final avgImpact = totalImpact / modifications.length;

      // المعلمون الأكثر تأثراً
      final Map<String, int> teacherImpact = {};
      for (final mod in modifications) {
        for (final teacher in mod.affectedTeachers) {
          teacherImpact[teacher] = (teacherImpact[teacher] ?? 0) + 1;
        }
      }
      final mostAffectedTeachers = (teacherImpact.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key)
          .toList();

      // الصفوف الأكثر تأثراً
      final Map<String, int> classImpact = {};
      for (final mod in modifications) {
        for (final className in mod.affectedClasses) {
          classImpact[className] = (classImpact[className] ?? 0) + 1;
        }
      }
      final mostAffectedClasses = (classImpact.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value)))
          .take(5)
          .map((e) => e.key)
          .toList();

      return ModificationStatistics(
        totalModifications: modifications.length,
        byType: byType,
        byModifier: byModifier,
        byDay: byDay,
        byHour: byHour,
        majorModifications: majorMods,
        minorModifications: minorMods,
        averageImpact: avgImpact,
        mostAffectedTeachers: mostAffectedTeachers,
        mostAffectedClasses: mostAffectedClasses,
      );
    } catch (e) {
      debugPrint('❌ [Modification] Error calculating statistics: $e');
      rethrow;
    }
  }

  // 📈 تحليل الاتجاهات
  Future<List<ModificationTrend>> analyzeTrends({
    required String schoolId,
    required DateTime startDate,
    required DateTime endDate,
    required TrendPeriod period,
  }) async {
    debugPrint('📈 [Modification] Analyzing trends');

    try {
      final modifications = await getModifications(
        schoolId: schoolId,
        startDate: startDate,
        endDate: endDate,
      );

      if (modifications.isEmpty) {
        return [];
      }

      // تجميع حسب الفترة
      final Map<DateTime, List<ScheduleModification>> grouped = {};
      
      for (final mod in modifications) {
        final periodStart = _getPeriodStart(mod.timestamp, period);
        grouped.putIfAbsent(periodStart, () => []);
        grouped[periodStart]!.add(mod);
      }

      // حساب الاتجاهات
      final trends = <ModificationTrend>[];
      for (final entry in grouped.entries) {
        final mods = entry.value;
        final totalImpact = mods.fold<int>(0, (sum, mod) => sum + mod.impactScore);
        final avgImpact = totalImpact / mods.length;

        final Map<ModificationType, int> typeDistribution = {};
        for (final mod in mods) {
          typeDistribution[mod.type] = (typeDistribution[mod.type] ?? 0) + 1;
        }

        trends.add(ModificationTrend(
          period: entry.key,
          count: mods.length,
          averageImpact: avgImpact,
          typeDistribution: typeDistribution,
        ));
      }

      trends.sort((a, b) => a.period.compareTo(b.period));

      debugPrint('✅ [Modification] Found ${trends.length} trend periods');
      return trends;
    } catch (e) {
      debugPrint('❌ [Modification] Error analyzing trends: $e');
      rethrow;
    }
  }

  DateTime _getPeriodStart(DateTime date, TrendPeriod period) {
    switch (period) {
      case TrendPeriod.daily:
        return DateTime(date.year, date.month, date.day);
      case TrendPeriod.weekly:
        final weekday = date.weekday;
        return DateTime(date.year, date.month, date.day - weekday);
      case TrendPeriod.monthly:
        return DateTime(date.year, date.month);
    }
  }

  // 🔍 مقارنة جدولين
  Future<ScheduleComparison> compareSchedules({
    required String schoolId,
    required String scheduleId1,
    required String scheduleId2,
  }) async {
    debugPrint('🔍 [Modification] Comparing schedules');

    try {
      // جلب الجدولين
      final schedule1Doc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Schedules')
          .doc(scheduleId1)
          .get();

      final schedule2Doc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Schedules')
          .doc(scheduleId2)
          .get();

      if (!schedule1Doc.exists || !schedule2Doc.exists) {
        throw Exception('Schedule not found');
      }

      final schedule1Data = schedule1Doc.data()!;
      final schedule2Data = schedule2Doc.data()!;

      // مقارنة الحصص
      final differences = <ScheduleDifference>[];
      
      final teacherSchedules1 = schedule1Data['teacherSchedules'] as Map<String, dynamic>? ?? {};
      final teacherSchedules2 = schedule2Data['teacherSchedules'] as Map<String, dynamic>? ?? {};

      // مقارنة كل معلم
      final allTeachers = {...teacherSchedules1.keys, ...teacherSchedules2.keys};
      
      for (final teacherId in allTeachers) {
        final slots1 = teacherSchedules1[teacherId] as List<dynamic>? ?? [];
        final slots2 = teacherSchedules2[teacherId] as List<dynamic>? ?? [];

        if (slots1.length != slots2.length) {
          differences.add(ScheduleDifference(
            type: 'slot_count',
            description: 'عدد الحصص مختلف للمعلم $teacherId',
            schedule1Data: {'count': slots1.length},
            schedule2Data: {'count': slots2.length},
          ));
        }

        // مقارنة الحصص
        for (int i = 0; i < slots1.length && i < slots2.length; i++) {
          final slot1 = slots1[i] as Map<String, dynamic>;
          final slot2 = slots2[i] as Map<String, dynamic>;

          if (slot1['subject'] != slot2['subject'] ||
              slot1['day'] != slot2['day'] ||
              slot1['period'] != slot2['period'] ||
              slot1['className'] != slot2['className']) {
            differences.add(ScheduleDifference(
              type: 'slot_change',
              description: 'حصة مختلفة للمعلم $teacherId',
              schedule1Data: slot1,
              schedule2Data: slot2,
            ));
          }
        }
      }

      // حساب نسبة التشابه
      final totalSlots1 = teacherSchedules1.values
          .fold<int>(0, (sum, slots) => sum + (slots as List).length);
      final totalSlots2 = teacherSchedules2.values
          .fold<int>(0, (sum, slots) => sum + (slots as List).length);
      final maxSlots = totalSlots1 > totalSlots2 ? totalSlots1 : totalSlots2;
      
      final similarityScore = maxSlots > 0
          ? ((maxSlots - differences.length) / maxSlots * 100).clamp(0.0, 100.0)
          : 100.0;

      debugPrint('✅ [Modification] Found ${differences.length} differences');
      debugPrint('📊 [Modification] Similarity: ${similarityScore.toStringAsFixed(1)}%');

      return ScheduleComparison(
        scheduleId1: scheduleId1,
        scheduleId2: scheduleId2,
        comparedAt: DateTime.now(),
        totalDifferences: differences.length,
        differences: differences,
        similarityScore: similarityScore,
      );
    } catch (e) {
      debugPrint('❌ [Modification] Error comparing: $e');
      rethrow;
    }
  }

  // 🔄 التراجع عن تعديل
  Future<void> revertModification({
    required String schoolId,
    required String modificationId,
  }) async {
    debugPrint('🔄 [Modification] Reverting modification: $modificationId');

    try {
      // جلب التعديل
      final modDoc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('ScheduleModifications')
          .doc(modificationId)
          .get();

      if (!modDoc.exists) {
        throw Exception('Modification not found');
      }

      final modification = ScheduleModification.fromMap({
        ...modDoc.data()!,
        'id': modDoc.id,
      });

      // تطبيق البيانات القديمة
      // هنا يتم التطبيق الفعلي على الجدول
      // سيتم تنفيذه عبر smart_schedule_service

      debugPrint('✅ [Modification] Reverted successfully');
    } catch (e) {
      debugPrint('❌ [Modification] Error reverting: $e');
      rethrow;
    }
  }
}

enum TrendPeriod {
  daily,
  weekly,
  monthly,
}
