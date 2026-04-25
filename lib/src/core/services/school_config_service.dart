import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─── Grading System ───────────────────────────────────────────────────────────

class GradeLevel {
  final String label;
  final double min;
  final double max;
  final String color;
  const GradeLevel({required this.label, required this.min, required this.max, required this.color});

  factory GradeLevel.fromMap(Map<String, dynamic> m) => GradeLevel(
        label: m['label'] ?? '',
        min: (m['min'] as num?)?.toDouble() ?? 0,
        max: (m['max'] as num?)?.toDouble() ?? 100,
        color: m['color'] ?? '#9E9E9E',
      );

  Map<String, dynamic> toMap() => {'label': label, 'min': min, 'max': max, 'color': color};
}

class GradingSystemConfig {
  final String type;
  final double min;
  final double max;
  final double passMark;
  final String displayFormat;
  final List<GradeLevel> grades;

  const GradingSystemConfig({
    required this.type,
    required this.min,
    required this.max,
    required this.passMark,
    required this.displayFormat,
    required this.grades,
  });

  factory GradingSystemConfig.fromMap(Map<String, dynamic> m) => GradingSystemConfig(
        type: m['type'] ?? 'percentage',
        min: (m['min'] as num?)?.toDouble() ?? 0,
        max: (m['max'] as num?)?.toDouble() ?? 100,
        passMark: (m['passMark'] as num?)?.toDouble() ?? 50,
        displayFormat: m['displayFormat'] ?? '{score}%',
        grades: (m['grades'] as List<dynamic>? ?? [])
            .map((g) => GradeLevel.fromMap(g as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toMap() => {
        'type': type, 'min': min, 'max': max, 'passMark': passMark,
        'displayFormat': displayFormat,
        'grades': grades.map((g) => g.toMap()).toList(),
      };

  String format(double score) => displayFormat.replaceAll('{score}', score.toStringAsFixed(1));

  GradeLevel? getGradeLevel(double score) {
    for (final g in grades) {
      if (score >= g.min && score <= g.max) return g;
    }
    return null;
  }

  bool isPassing(double score) => score >= passMark;

  static GradingSystemConfig get defaultPercentage => GradingSystemConfig(
        type: 'percentage', min: 0, max: 100, passMark: 50,
        displayFormat: '{score}%',
        grades: const [
          GradeLevel(label: 'ممتاز',    min: 90, max: 100, color: '#4CAF50'),
          GradeLevel(label: 'جيد جداً', min: 80, max: 89,  color: '#8BC34A'),
          GradeLevel(label: 'جيد',      min: 70, max: 79,  color: '#FFC107'),
          GradeLevel(label: 'مقبول',    min: 60, max: 69,  color: '#FF9800'),
          GradeLevel(label: 'راسب',     min: 0,  max: 59,  color: '#F44336'),
        ],
      );
}

// ─── Feature Flags ────────────────────────────────────────────────────────────

class SchoolFeatures {
  final bool attendance;
  final bool behavior;
  final bool behaviorTracking;
  final bool smartSchedule;
  final bool tracks;
  final bool parentCommunication;
  final bool parentSms;
  final bool performanceReports;
  final bool timetable;
  final bool exams;
  final bool assignments;
  final bool counseling;
  final bool healthTracking;
  final bool schoolBroadcast;
  final bool leaveRequests;

  const SchoolFeatures({
    this.attendance = true,
    this.behavior = true,
    this.behaviorTracking = true,
    this.smartSchedule = true,
    this.tracks = false,
    this.parentCommunication = true,
    this.parentSms = false,
    this.performanceReports = true,
    this.timetable = true,
    this.exams = true,
    this.assignments = true,
    this.counseling = true,
    this.healthTracking = true,
    this.schoolBroadcast = false,
    this.leaveRequests = true,
  });

  factory SchoolFeatures.fromMap(Map<String, dynamic> m) => SchoolFeatures(
        attendance:           m['attendance']           ?? true,
        behavior:             m['behavior']             ?? true,
        behaviorTracking:     m['behaviorTracking']     ?? true,
        smartSchedule:        m['smartSchedule']        ?? true,
        tracks:               m['tracks']               ?? false,
        parentCommunication:  m['parentCommunication']  ?? true,
        parentSms:            m['parentSms']            ?? false,
        performanceReports:   m['performanceReports']   ?? true,
        timetable:            m['timetable']            ?? true,
        exams:                m['exams']                ?? true,
        assignments:          m['assignments']          ?? true,
        counseling:           m['counseling']           ?? true,
        healthTracking:       m['healthTracking']       ?? true,
        schoolBroadcast:      m['schoolBroadcast']      ?? false,
        leaveRequests:        m['leaveRequests']        ?? true,
      );

  Map<String, dynamic> toMap() => {
        'attendance': attendance, 'behavior': behavior,
        'behaviorTracking': behaviorTracking, 'smartSchedule': smartSchedule,
        'tracks': tracks, 'parentCommunication': parentCommunication,
        'parentSms': parentSms, 'performanceReports': performanceReports,
        'timetable': timetable, 'exams': exams, 'assignments': assignments,
        'counseling': counseling, 'healthTracking': healthTracking,
        'schoolBroadcast': schoolBroadcast, 'leaveRequests': leaveRequests,
      };

  static const SchoolFeatures defaults = SchoolFeatures();
}

// ─── School Config ────────────────────────────────────────────────────────────

class SchoolConfig {
  final String schoolId;
  final String countryCode;
  final SchoolFeatures features;
  final GradingSystemConfig gradingSystem;
  final String behaviorSystem;
  final String calendarSystem;
  final bool tracksEnabled;
  final List<String> enabledTracks;
  final List<String> weekDays;
  final List<String> weekend;
  final bool hasSchoolOverrides;
  final int profileVersion;
  final String source;
  final DateTime? cachedAt;

  const SchoolConfig({
    required this.schoolId,
    required this.countryCode,
    required this.features,
    required this.gradingSystem,
    required this.behaviorSystem,
    required this.calendarSystem,
    required this.tracksEnabled,
    required this.enabledTracks,
    required this.weekDays,
    required this.weekend,
    this.hasSchoolOverrides = false,
    this.profileVersion = 0,
    this.source = 'local',
    this.cachedAt,
  });

  factory SchoolConfig.fromMap(Map<String, dynamic> m, String schoolId) {
    final featuresMap = m['features'] as Map<String, dynamic>? ?? {};
    final gradingRaw  = m['gradingSystem'];
    return SchoolConfig(
      schoolId:         schoolId,
      countryCode:      m['countryCode'] ?? 'SA',
      features:         SchoolFeatures.fromMap(featuresMap),
      gradingSystem:    gradingRaw is Map<String, dynamic>
                            ? GradingSystemConfig.fromMap(gradingRaw)
                            : GradingSystemConfig.defaultPercentage,
      behaviorSystem:   m['behaviorSystem'] ?? 'custom',
      calendarSystem:   m['calendarSystem'] ?? 'twoSemesters',
      tracksEnabled:    m['tracksEnabled'] ?? false,
      enabledTracks:    List<String>.from(m['enabledTracks'] ?? []),
      weekDays:         List<String>.from(m['weekDays'] ?? []),
      weekend:          List<String>.from(m['weekend'] ?? []),
      hasSchoolOverrides: m['hasSchoolOverrides'] ?? false,
      profileVersion:   m['countryProfileVersion'] ?? m['profileVersion'] ?? 0,
      source:           m['source'] ?? 'local',
      cachedAt:         m['cachedAt'] != null
                            ? DateTime.tryParse(m['cachedAt'] as String)
                            : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'schoolId': schoolId,
        'countryCode': countryCode,
        'features': features.toMap(),
        'gradingSystem': gradingSystem.toMap(),
        'behaviorSystem': behaviorSystem,
        'calendarSystem': calendarSystem,
        'tracksEnabled': tracksEnabled,
        'enabledTracks': enabledTracks,
        'weekDays': weekDays,
        'weekend': weekend,
        'hasSchoolOverrides': hasSchoolOverrides,
        'profileVersion': profileVersion,
        'source': source,
        'cachedAt': cachedAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
      };

  static SchoolConfig defaultSA(String schoolId) => SchoolConfig(
        schoolId: schoolId,
        countryCode: 'SA',
        features: const SchoolFeatures(parentSms: true, schoolBroadcast: true),
        gradingSystem: GradingSystemConfig.defaultPercentage,
        behaviorSystem: 'levels',
        calendarSystem: 'twoSemesters',
        tracksEnabled: false,
        enabledTracks: const [],
        weekDays: const ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'],
        weekend: const ['الجمعة', 'السبت'],
        source: 'local',
        cachedAt: DateTime.now(),
      );
}

// ─── School Config Service — with TTL Cache + Persistent Cache ────────────────

class SchoolConfigService {
  static final SchoolConfigService _instance = SchoolConfigService._internal();
  factory SchoolConfigService() => _instance;
  SchoolConfigService._internal();

  // Memory cache: schoolId → (config, timestamp)
  final Map<String, (SchoolConfig, DateTime)> _memCache = {};

  // TTL: 30 دقيقة في الذاكرة، 24 ساعة في SharedPreferences
  static const Duration _memTTL   = Duration(minutes: 30);
  static const Duration _diskTTL  = Duration(hours: 24);
  static const int _currentVersion = 2; // يجب أن يطابق COUNTRY_PROFILE_VERSION في functions

  static String _prefKey(String schoolId) => 'school_config_$schoolId';

  // ─── Load ──────────────────────────────────────────────────────────────────

  Future<SchoolConfig> loadConfig(String schoolId) async {
    if (schoolId.isEmpty) return SchoolConfig.defaultSA(schoolId);

    // 1. Memory cache (أسرع)
    final memEntry = _memCache[schoolId];
    if (memEntry != null) {
      final age = DateTime.now().difference(memEntry.$2);
      if (age < _memTTL && memEntry.$1.profileVersion >= _currentVersion) {
        return memEntry.$1;
      }
    }

    // 2. Disk cache (SharedPreferences)
    final diskConfig = await _loadFromDisk(schoolId);
    if (diskConfig != null) {
      _memCache[schoolId] = (diskConfig, DateTime.now());
      // إذا الـ disk cache حديث وبنسخة صحيحة، أرجعه مباشرة
      if (diskConfig.profileVersion >= _currentVersion &&
          diskConfig.cachedAt != null &&
          DateTime.now().difference(diskConfig.cachedAt!) < _diskTTL) {
        return diskConfig;
      }
    }

    // 3. Firestore (مباشر — أسرع من Cloud Function)
    try {
      final doc = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        if (data['features'] != null &&
            data['gradingSystem'] != null &&
            (data['countryProfileVersion'] ?? 0) >= _currentVersion) {
          final config = SchoolConfig.fromMap({...data, 'source': 'firestore'}, schoolId);
          await _saveToCache(schoolId, config);
          return config;
        }
      }
    } catch (e) {
      debugPrint('[SchoolConfig] Firestore read failed: $e');
    }

    // 4. Cloud Function (يحسب الإعدادات ويحفظها)
    try {
      final result = await FirebaseFunctions.instance
          .httpsCallable('getSchoolConfig')
          .call({'schoolId': schoolId});
      final config = SchoolConfig.fromMap(
        Map<String, dynamic>.from(result.data as Map),
        schoolId,
      );
      await _saveToCache(schoolId, config);
      return config;
    } catch (e) {
      debugPrint('[SchoolConfig] Cloud Function failed: $e');
    }

    // 5. Fallback: disk cache القديم أو default
    if (diskConfig != null) return diskConfig;
    return SchoolConfig.defaultSA(schoolId);
  }

  // ─── Cache Management ──────────────────────────────────────────────────────

  Future<void> _saveToCache(String schoolId, SchoolConfig config) async {
    _memCache[schoolId] = (config, DateTime.now());
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKey(schoolId), jsonEncode(config.toMap()));
    } catch (e) {
      debugPrint('[SchoolConfig] Disk cache write failed: $e');
    }
  }

  Future<SchoolConfig?> _loadFromDisk(String schoolId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKey(schoolId));
      if (raw == null) return null;
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return SchoolConfig.fromMap(map, schoolId);
    } catch (e) {
      debugPrint('[SchoolConfig] Disk cache read failed: $e');
      return null;
    }
  }

  /// مسح cache مدرسة (بعد تحديث الإعدادات)
  Future<void> invalidate(String schoolId) async {
    _memCache.remove(schoolId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_prefKey(schoolId));
    } catch (_) {}
  }

  /// مسح كل الـ cache
  Future<void> clearAll() async {
    _memCache.clear();
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys().where((k) => k.startsWith('school_config_'));
      for (final k in keys) await prefs.remove(k);
    } catch (_) {}
  }

  // ─── School Override ───────────────────────────────────────────────────────

  /// تحديث School Overrides — المدرسة تعدّل فوق إعدادات الدولة
  Future<void> updateOverrides(String schoolId, Map<String, dynamic> overrides) async {
    await FirebaseFunctions.instance
        .httpsCallable('updateSchoolOverrides')
        .call({'schoolId': schoolId, 'overrides': overrides});
    await invalidate(schoolId);
  }
}

// ─── Riverpod Providers ───────────────────────────────────────────────────────

final schoolConfigServiceProvider = Provider<SchoolConfigService>((ref) {
  return SchoolConfigService();
});

/// الإعدادات الكاملة للمدرسة — مع TTL cache تلقائي
final schoolConfigProvider = FutureProvider.family<SchoolConfig, String>((ref, schoolId) async {
  if (schoolId.isEmpty) return SchoolConfig.defaultSA(schoolId);
  return ref.read(schoolConfigServiceProvider).loadConfig(schoolId);
});

/// Feature Flags فقط
final schoolFeaturesProvider = FutureProvider.family<SchoolFeatures, String>((ref, schoolId) async {
  final config = await ref.watch(schoolConfigProvider(schoolId).future);
  return config.features;
});

/// نظام التقييم
final gradingSystemProvider = FutureProvider.family<GradingSystemConfig, String>((ref, schoolId) async {
  final config = await ref.watch(schoolConfigProvider(schoolId).future);
  return config.gradingSystem;
});

/// نظام السلوك
final behaviorSystemProvider = FutureProvider.family<String, String>((ref, schoolId) async {
  final config = await ref.watch(schoolConfigProvider(schoolId).future);
  return config.behaviorSystem;
});

/// المسارات الدراسية
final schoolTracksProvider = FutureProvider.family<List<String>, String>((ref, schoolId) async {
  final config = await ref.watch(schoolConfigProvider(schoolId).future);
  return config.tracksEnabled ? config.enabledTracks : [];
});

/// هل Feature معينة مفعّلة؟ — للاستخدام المباشر في الشاشات
final featureEnabledProvider = FutureProvider.family<bool, ({String schoolId, String feature})>((ref, args) async {
  final features = await ref.watch(schoolFeaturesProvider(args.schoolId).future);
  return switch (args.feature) {
    'attendance'          => features.attendance,
    'behavior'            => features.behavior,
    'behaviorTracking'    => features.behaviorTracking,
    'smartSchedule'       => features.smartSchedule,
    'tracks'              => features.tracks,
    'parentCommunication' => features.parentCommunication,
    'parentSms'           => features.parentSms,
    'performanceReports'  => features.performanceReports,
    'timetable'           => features.timetable,
    'exams'               => features.exams,
    'assignments'         => features.assignments,
    'counseling'          => features.counseling,
    'healthTracking'      => features.healthTracking,
    'schoolBroadcast'     => features.schoolBroadcast,
    'leaveRequests'       => features.leaveRequests,
    _                     => false,
  };
});
