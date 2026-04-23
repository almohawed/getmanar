import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// خدمة تحميل البيانات بشكل صاروخي
/// تستخدم Caching و Batch Queries لتحسين الأداء
class FastDataService {
  final FirebaseFirestore _firestore;
  
  // Cache للبيانات
  final Map<String, CachedData> _cache = {};
  
  // مدة صلاحية الـ Cache (30 ثانية)
  static const _cacheDuration = Duration(seconds: 30);
  
  FastDataService(this._firestore);
  
  /// جلب جميع إحصائيات لوحة وكيل شؤون الطلاب دفعة واحدة
  Future<StudentAffairsStats> getStudentAffairsStats(String schoolId) async {
    final cacheKey = 'student_affairs_$schoolId';
    
    // تحقق من الـ Cache
    if (_cache.containsKey(cacheKey)) {
      final cached = _cache[cacheKey]!;
      if (DateTime.now().difference(cached.timestamp) < _cacheDuration) {
        return cached.data as StudentAffairsStats;
      }
    }
    
    // جلب البيانات بالتوازي (Parallel)
    final results = await Future.wait([
      _getAttendanceStats(schoolId),
      _getBehaviorStats(schoolId),
      _getBathroomStats(schoolId),
      _getSmsStats(schoolId),
    ]);
    
    final stats = StudentAffairsStats(
      attendance: results[0] as AttendanceStats,
      behavior: results[1] as BehaviorStats,
      bathroom: results[2] as BathroomStats,
      sms: results[3] as SmsStats,
    );
    
    // حفظ في الـ Cache
    _cache[cacheKey] = CachedData(
      data: stats,
      timestamp: DateTime.now(),
    );
    
    return stats;
  }
  
  /// جلب إحصائيات الحضور (محسّن)
  Future<AttendanceStats> _getAttendanceStats(String schoolId) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    
    try {
      // استعلام واحد فقط مع limit صغير
      final snapshot = await _firestore
          .collection('StudentAttendance')
          .where('schoolId', isEqualTo: schoolId)
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .limit(500) // تقليل من غير محدود إلى 500
          .get(const GetOptions(source: Source.serverAndCache)); // استخدام Cache
      
      int present = 0;
      int absent = 0;
      int late = 0;
      
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'present':
          case 'excused':
            present++;
            break;
          case 'absent':
            absent++;
            break;
          case 'late':
            late++;
            break;
        }
      }
      
      return AttendanceStats(
        total: present + absent + late,
        present: present,
        absent: absent,
        late: late,
      );
    } catch (e) {
      // في حالة الخطأ، إرجاع قيم افتراضية
      return AttendanceStats(total: 0, present: 0, absent: 0, late: 0);
    }
  }
  
  /// جلب إحصائيات السلوك (محسّن)
  Future<BehaviorStats> _getBehaviorStats(String schoolId) async {
    try {
      // استعلام واحد فقط مع limit صغير
      final snapshot = await _firestore
          .collection('behavior_records')
          .where('schoolId', isEqualTo: schoolId)
          .where('status', whereIn: ['pending', 'warning', 'active'])
          .limit(200) // تقليل من 800 إلى 200
          .get(const GetOptions(source: Source.serverAndCache));
      
      int open = 0;
      int escalationDue = 0;
      final escalationThreshold = DateTime.now().subtract(const Duration(days: 7));
      
      for (final doc in snapshot.docs) {
        open++;
        
        final timestamp = _parseTimestamp(doc.data()['timestamp']);
        if (timestamp != null && timestamp.isBefore(escalationThreshold)) {
          escalationDue++;
        }
      }
      
      return BehaviorStats(
        open: open,
        escalationDue: escalationDue,
      );
    } catch (e) {
      return BehaviorStats(open: 0, escalationDue: 0);
    }
  }
  
  /// جلب إحصائيات الاستئذان (محسّن)
  Future<BathroomStats> _getBathroomStats(String schoolId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final snapshot = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('BathroomPasses')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .limit(100) // limit صغير
          .get(const GetOptions(source: Source.serverAndCache));
      
      int active = 0;
      int redCount = 0;
      
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final closedAt = data['closedAt'];
        
        if (closedAt == null) {
          active++;
          if (data['status'] == 'locked_red') {
            redCount++;
          }
        }
      }
      
      return BathroomStats(
        active: active,
        redCount: redCount,
      );
    } catch (e) {
      return BathroomStats(active: 0, redCount: 0);
    }
  }
  
  /// جلب إحصائيات الرسائل (محسّن)
  Future<SmsStats> _getSmsStats(String schoolId) async {
    try {
      final today = DateTime.now();
      final todayStart = DateTime(today.year, today.month, today.day);
      
      final snapshot = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('SmsOutbox')
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart))
          .limit(100)
          .get(const GetOptions(source: Source.serverAndCache));
      
      int queued = 0;
      int sent = 0;
      int failed = 0;
      
      for (final doc in snapshot.docs) {
        final status = doc.data()['status'] as String?;
        switch (status) {
          case 'queued':
            queued++;
            break;
          case 'sent':
            sent++;
            break;
          case 'failed':
            failed++;
            break;
        }
      }
      
      return SmsStats(
        queued: queued,
        sent: sent,
        failed: failed,
      );
    } catch (e) {
      return SmsStats(queued: 0, sent: 0, failed: 0);
    }
  }
  
  /// مساعد لتحويل Timestamp
  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
  
  /// مسح الـ Cache
  void clearCache() {
    _cache.clear();
  }
  
  /// مسح cache معين
  void clearCacheFor(String key) {
    _cache.remove(key);
  }
}

/// بيانات محفوظة في الـ Cache
class CachedData {
  final dynamic data;
  final DateTime timestamp;
  
  CachedData({
    required this.data,
    required this.timestamp,
  });
}

/// إحصائيات شاملة للوحة
class StudentAffairsStats {
  final AttendanceStats attendance;
  final BehaviorStats behavior;
  final BathroomStats bathroom;
  final SmsStats sms;
  
  StudentAffairsStats({
    required this.attendance,
    required this.behavior,
    required this.bathroom,
    required this.sms,
  });
}

/// إحصائيات الحضور
class AttendanceStats {
  final int total;
  final int present;
  final int absent;
  final int late;
  
  AttendanceStats({
    required this.total,
    required this.present,
    required this.absent,
    required this.late,
  });
}

/// إحصائيات السلوك
class BehaviorStats {
  final int open;
  final int escalationDue;
  
  BehaviorStats({
    required this.open,
    required this.escalationDue,
  });
}

/// إحصائيات الاستئذان
class BathroomStats {
  final int active;
  final int redCount;
  
  BathroomStats({
    required this.active,
    required this.redCount,
  });
}

/// إحصائيات الرسائل
class SmsStats {
  final int queued;
  final int sent;
  final int failed;
  
  SmsStats({
    required this.queued,
    required this.sent,
    required this.failed,
  });
}

/// Provider للخدمة
final fastDataServiceProvider = Provider<FastDataService>((ref) {
  return FastDataService(FirebaseFirestore.instance);
});

/// Provider للإحصائيات (مع Caching)
final studentAffairsStatsProvider = FutureProvider.autoDispose
    .family<StudentAffairsStats, String>((ref, schoolId) async {
  final service = ref.watch(fastDataServiceProvider);
  return service.getStudentAffairsStats(schoolId);
});
