import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'day_index_mapper.dart';

/// مدير الـ Cache للجداول
/// يتعامل مع تنظيف وتحديث الـ cache عند توليد جدول جديد
class ScheduleCacheManager {
  static final ScheduleCacheManager _instance = ScheduleCacheManager._internal();

  factory ScheduleCacheManager() {
    return _instance;
  }

  ScheduleCacheManager._internal();

  /// 🔥 Static cache reference - will be set by _PeriodViewTabState
  static Map<String, dynamic>? _periodViewCache;
  
  /// Set the cache reference from _PeriodViewTabState
  static void setPeriodViewCache(Map<String, dynamic> cache) {
    _periodViewCache = cache;
  }

  /// تنظيف الـ cache لمدرسة معينة
  /// يجب استدعاء هذه الدالة بعد التوليد الناجح
  static void clearCacheForSchool(String schoolId) {
    debugPrint('🧹 ScheduleCacheManager: Clearing cache for school: $schoolId');
    if (_periodViewCache != null) {
      _periodViewCache!.remove(schoolId);
      debugPrint('✅ Cache cleared. Remaining: ${_periodViewCache!.keys.toList()}');
    } else {
      debugPrint('⚠️ Cache reference not set yet');
    }
  }

  /// تنظيف جميع الـ cache
  static void clearAllCache() {
    debugPrint('🧹 ScheduleCacheManager: Clearing all cache');
    if (_periodViewCache != null) {
      _periodViewCache!.clear();
      debugPrint('✅ All cache cleared');
    }
  }

  /// الحصول على آخر جدول تم توليده
  static Future<Map<String, dynamic>?> getLatestSchedule(String schoolId) async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Schools/$schoolId/Schedules')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        debugPrint('⚠️ No schedules found for school: $schoolId');
        return null;
      }

      final doc = snapshot.docs.first;
      final data = doc.data();
      
      // 🔧 Normalize dayIndex for all lessons
      final lessons = data['lessons'] as List?;
      if (lessons != null) {
        data['lessons'] = DayIndexMapper.normalizeLessons(lessons);
      }
      
      debugPrint('✅ Latest schedule found:');
      debugPrint('   ID: ${doc.id}');
      debugPrint('   Created: ${data['createdAt']}');
      debugPrint('   Lessons count: ${(data['lessons'] as List?)?.length ?? 0}');
      debugPrint('   Status: ${data['status']}');
      debugPrint('   Version: ${data['version']}');

      return {
        'id': doc.id,
        'data': data,
      };
    } catch (e) {
      debugPrint('❌ Error getting latest schedule: $e');
      return null;
    }
  }

  /// التحقق من أن الجدول يحتوي على أيام مختلفة (ليس مكرراً)
  static bool validateScheduleDiversity(List<dynamic> lessons) {
    if (lessons.isEmpty) return false;

    // تجميع الحصص حسب اليوم
    final dayLessons = <String, List<Map<String, dynamic>>>{};
    
    for (final lesson in lessons) {
      if (lesson is! Map<String, dynamic>) continue;
      
      final day = lesson['day'] as String?;
      if (day == null) continue;

      dayLessons.putIfAbsent(day, () => []);
      dayLessons[day]!.add(lesson);
    }

    // التحقق من أن كل يوم له حصص مختلفة
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    
    for (int i = 0; i < days.length - 1; i++) {
      final day1 = days[i];
      final day2 = days[i + 1];

      final lessons1 = dayLessons[day1] ?? [];
      final lessons2 = dayLessons[day2] ?? [];

      if (lessons1.isEmpty || lessons2.isEmpty) continue;

      // مقارنة الحصص بين اليومين
      final subjects1 = lessons1.map((l) => l['subject']).toSet();
      final subjects2 = lessons2.map((l) => l['subject']).toSet();

      // إذا كانت المواد متطابقة تماماً، هناك تكرار
      if (subjects1.length == subjects2.length && 
          subjects1.every((s) => subjects2.contains(s))) {
        debugPrint('⚠️ WARNING: Days $day1 and $day2 have identical subjects!');
        debugPrint('   $day1 subjects: $subjects1');
        debugPrint('   $day2 subjects: $subjects2');
        return false;
      }
    }

    debugPrint('✅ Schedule diversity check passed');
    return true;
  }

  /// طباعة تفاصيل الجدول للتشخيص
  static void printScheduleDetails(String schoolId, Map<String, dynamic> schedule) {
    debugPrint('\n📊 Schedule Details:');
    debugPrint('   School ID: $schoolId');
    debugPrint('   Schedule ID: ${schedule['id']}');
    
    final data = schedule['data'] as Map<String, dynamic>;
    final lessons = data['lessons'] as List<dynamic>?;
    
    if (lessons == null) {
      debugPrint('   ❌ No lessons found');
      return;
    }

    debugPrint('   Total lessons: ${lessons.length}');

    // تجميع الحصص حسب اليوم والفصل
    final byDay = <String, Map<String, int>>{};
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

    for (final lesson in lessons) {
      if (lesson is! Map<String, dynamic>) continue;

      final day = lesson['day'] as String?;
      final className = lesson['className'] as String?;
      
      if (day == null || className == null) continue;

      byDay.putIfAbsent(day, () => {});
      byDay[day]![className] = (byDay[day]![className] ?? 0) + 1;
    }

    // طباعة التفاصيل
    for (final day in days) {
      if (!byDay.containsKey(day)) {
        debugPrint('   $day: (no lessons)');
        continue;
      }

      final classes = byDay[day]!;
      final classesStr = classes.entries
          .map((e) => '${e.key}(${e.value})')
          .join(', ');
      
      debugPrint('   $day: $classesStr');
    }

    debugPrint('');
  }

  /// التحقق من أن الجدول الجديد مختلف عن السابق
  static bool isScheduleDifferent(
    Map<String, dynamic>? oldSchedule,
    Map<String, dynamic>? newSchedule,
  ) {
    if (oldSchedule == null || newSchedule == null) return true;

    final oldLessons = (oldSchedule['data'] as Map?)?['lessons'] as List?;
    final newLessons = (newSchedule['data'] as Map?)?['lessons'] as List?;

    if (oldLessons == null || newLessons == null) return true;
    if (oldLessons.length != newLessons.length) return true;

    // مقارنة المواد والمعلمين
    final oldSubjects = oldLessons
        .whereType<Map<String, dynamic>>()
        .map((l) => '${l['day']}_${l['period']}_${l['subject']}')
        .toSet();

    final newSubjects = newLessons
        .whereType<Map<String, dynamic>>()
        .map((l) => '${l['day']}_${l['period']}_${l['subject']}')
        .toSet();

    return oldSubjects != newSubjects;
  }
}
