/// Country Profile — نموذج بيانات الدولة
/// يحدد كيفية عمل النظام في كل دولة
/// قابل للتوسع لأي دولة في العالم

// ─── Behavior System ──────────────────────────────────────────────────────────

/// نظام السلوك المستخدم في الدولة
enum BehaviorSystem {
  /// نظام الدرجات (السعودية) — درجة أولى / ثانية / ثالثة
  levels,

  /// نظام النقاط (قطر) — خصم نقاط من رصيد الطالب
  points,

  /// نظام الإرشاد (الإمارات) — ملاحظات وخطط تحسين
  guidance,

  /// نظام مرن (الكويت / البحرين / عمان / دول أخرى)
  custom,

  /// نظام GPA (أمريكا / كندا / أستراليا)
  gpa,

  /// نظام الإنذارات (فرنسا / إسبانيا)
  warnings,
}

// ─── Grading System ───────────────────────────────────────────────────────────

/// نظام التقييم الأكاديمي
enum GradingSystem {
  /// نظام النسبة المئوية (0-100) — الخليج
  percentage,

  /// نظام GPA (0.0-4.0) — أمريكا / كندا
  gpa4,

  /// نظام GPA (0.0-5.0) — بعض الدول
  gpa5,

  /// نظام الحروف (A-F) — أمريكا / بريطانيا
  letters,

  /// نظام 1-20 — فرنسا
  french20,

  /// نظام 1-10 — إسبانيا / هولندا
  scale10,

  /// نظام مخصص
  custom,
}

// ─── Calendar System ──────────────────────────────────────────────────────────

/// نظام التقويم المدرسي
enum CalendarSystem {
  /// فصلان دراسيان (الخليج)
  twoSemesters,

  /// ثلاثة فصول (بريطانيا / أستراليا)
  threeTerms,

  /// أربعة أرباع (أمريكا)
  fourQuarters,

  /// نظام مخصص
  custom,
}

// ─── Language Direction ───────────────────────────────────────────────────────

/// اتجاه الكتابة
enum TextDirection {
  rtl, // عربي / عبري
  ltr, // إنجليزي / فرنسي / إسباني
}

// ─── Country Profile ──────────────────────────────────────────────────────────

/// ملف تعريف الدولة الكامل
class CountryProfile {
  /// رمز الدولة ISO 3166-1 alpha-2 (مثال: SA, AE, QA, US, FR)
  final String countryCode;

  /// اسم الدولة بالعربية
  final String nameAr;

  /// اسم الدولة بالإنجليزية
  final String nameEn;

  /// العلم (emoji)
  final String flag;

  /// المنطقة الجغرافية
  final String region; // 'gulf', 'arab', 'europe', 'americas', 'asia', 'africa'

  /// اللغة الرسمية الأساسية
  final String primaryLanguage; // 'ar', 'en', 'fr', 'es'

  /// اتجاه الكتابة
  final TextDirection textDirection;

  /// العملة
  final String currency;

  /// المنطقة الزمنية
  final String timezone;

  // ─── Academic System ────────────────────────────────────────────────────────

  /// نظام السلوك
  final BehaviorSystem behaviorSystem;

  /// نظام التقييم
  final GradingSystem gradingSystem;

  /// نظام التقويم المدرسي
  final CalendarSystem calendarSystem;

  /// هل المسارات الدراسية مفعّلة؟
  final bool tracksEnabled;

  /// المسارات الافتراضية للدولة
  final List<String> defaultTracks;

  /// المراحل الدراسية
  final List<SchoolStageConfig> stages;

  // ─── Communication ──────────────────────────────────────────────────────────

  /// هل SMS مهم في هذه الدولة؟
  final bool smsImportant;

  /// هل البريد الإلكتروني هو الوسيلة الأساسية؟
  final bool emailPrimary;

  /// هل تطبيقات المراسلة (واتساب) شائعة؟
  final bool messagingAppsCommon;

  // ─── Behavior Config ────────────────────────────────────────────────────────

  /// نقاط السلوك الابتدائية (للنظام النقطي)
  final int? initialBehaviorPoints;

  /// الحد الأدنى للنقاط قبل التدخل
  final int? behaviorPointsThreshold;

  /// مستويات السلوك (للنظام الدرجي)
  final List<BehaviorLevelConfig>? behaviorLevels;

  // ─── Features ───────────────────────────────────────────────────────────────

  /// الميزات المفعّلة في هذه الدولة
  final CountryFeatures features;

  // ─── Customization ──────────────────────────────────────────────────────────

  /// هل يمكن للمدرسة تخصيص الإعدادات؟
  final bool allowSchoolCustomization;

  /// الإعدادات الإضافية الخاصة بالدولة
  final Map<String, dynamic> extra;

  const CountryProfile({
    required this.countryCode,
    required this.nameAr,
    required this.nameEn,
    required this.flag,
    required this.region,
    required this.primaryLanguage,
    required this.textDirection,
    required this.currency,
    required this.timezone,
    required this.behaviorSystem,
    required this.gradingSystem,
    required this.calendarSystem,
    required this.tracksEnabled,
    required this.defaultTracks,
    required this.stages,
    required this.smsImportant,
    required this.emailPrimary,
    required this.messagingAppsCommon,
    required this.features,
    required this.allowSchoolCustomization,
    this.initialBehaviorPoints,
    this.behaviorPointsThreshold,
    this.behaviorLevels,
    this.extra = const {},
  });

  factory CountryProfile.fromMap(Map<String, dynamic> map) {
    return CountryProfile(
      countryCode: map['countryCode'] ?? '',
      nameAr: map['nameAr'] ?? '',
      nameEn: map['nameEn'] ?? '',
      flag: map['flag'] ?? '',
      region: map['region'] ?? 'other',
      primaryLanguage: map['primaryLanguage'] ?? 'ar',
      textDirection: map['textDirection'] == 'ltr'
          ? TextDirection.ltr
          : TextDirection.rtl,
      currency: map['currency'] ?? '',
      timezone: map['timezone'] ?? 'UTC',
      behaviorSystem: _parseBehaviorSystem(map['behaviorSystem']),
      gradingSystem: _parseGradingSystem(map['gradingSystem']),
      calendarSystem: _parseCalendarSystem(map['calendarSystem']),
      tracksEnabled: map['tracksEnabled'] ?? false,
      defaultTracks: List<String>.from(map['defaultTracks'] ?? []),
      stages: (map['stages'] as List<dynamic>? ?? [])
          .map((s) => SchoolStageConfig.fromMap(s as Map<String, dynamic>))
          .toList(),
      smsImportant: map['smsImportant'] ?? false,
      emailPrimary: map['emailPrimary'] ?? true,
      messagingAppsCommon: map['messagingAppsCommon'] ?? false,
      features: CountryFeatures.fromMap(
          map['features'] as Map<String, dynamic>? ?? {}),
      allowSchoolCustomization: map['allowSchoolCustomization'] ?? true,
      initialBehaviorPoints: map['initialBehaviorPoints'],
      behaviorPointsThreshold: map['behaviorPointsThreshold'],
      behaviorLevels: (map['behaviorLevels'] as List<dynamic>?)
          ?.map((l) => BehaviorLevelConfig.fromMap(l as Map<String, dynamic>))
          .toList(),
      extra: Map<String, dynamic>.from(map['extra'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() => {
        'countryCode': countryCode,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'flag': flag,
        'region': region,
        'primaryLanguage': primaryLanguage,
        'textDirection': textDirection == TextDirection.ltr ? 'ltr' : 'rtl',
        'currency': currency,
        'timezone': timezone,
        'behaviorSystem': behaviorSystem.name,
        'gradingSystem': gradingSystem.name,
        'calendarSystem': calendarSystem.name,
        'tracksEnabled': tracksEnabled,
        'defaultTracks': defaultTracks,
        'stages': stages.map((s) => s.toMap()).toList(),
        'smsImportant': smsImportant,
        'emailPrimary': emailPrimary,
        'messagingAppsCommon': messagingAppsCommon,
        'features': features.toMap(),
        'allowSchoolCustomization': allowSchoolCustomization,
        'initialBehaviorPoints': initialBehaviorPoints,
        'behaviorPointsThreshold': behaviorPointsThreshold,
        'behaviorLevels': behaviorLevels?.map((l) => l.toMap()).toList(),
        'extra': extra,
      };

  static BehaviorSystem _parseBehaviorSystem(String? v) {
    return BehaviorSystem.values.firstWhere(
      (e) => e.name == v,
      orElse: () => BehaviorSystem.custom,
    );
  }

  static GradingSystem _parseGradingSystem(String? v) {
    return GradingSystem.values.firstWhere(
      (e) => e.name == v,
      orElse: () => GradingSystem.percentage,
    );
  }

  static CalendarSystem _parseCalendarSystem(String? v) {
    return CalendarSystem.values.firstWhere(
      (e) => e.name == v,
      orElse: () => CalendarSystem.twoSemesters,
    );
  }
}

// ─── School Stage Config ──────────────────────────────────────────────────────

/// إعداد مرحلة دراسية
class SchoolStageConfig {
  final String key; // 'primary', 'middle', 'secondary', 'kindergarten'
  final String nameAr;
  final String nameEn;
  final int fromGrade;
  final int toGrade;
  final int fromAge;
  final int toAge;

  const SchoolStageConfig({
    required this.key,
    required this.nameAr,
    required this.nameEn,
    required this.fromGrade,
    required this.toGrade,
    required this.fromAge,
    required this.toAge,
  });

  factory SchoolStageConfig.fromMap(Map<String, dynamic> map) =>
      SchoolStageConfig(
        key: map['key'] ?? '',
        nameAr: map['nameAr'] ?? '',
        nameEn: map['nameEn'] ?? '',
        fromGrade: map['fromGrade'] ?? 1,
        toGrade: map['toGrade'] ?? 6,
        fromAge: map['fromAge'] ?? 6,
        toAge: map['toAge'] ?? 12,
      );

  Map<String, dynamic> toMap() => {
        'key': key,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'fromGrade': fromGrade,
        'toGrade': toGrade,
        'fromAge': fromAge,
        'toAge': toAge,
      };
}

// ─── Behavior Level Config ────────────────────────────────────────────────────

/// إعداد مستوى سلوكي (للنظام الدرجي)
class BehaviorLevelConfig {
  final int level;
  final String nameAr;
  final String nameEn;
  final String color; // hex color
  final String action; // الإجراء المطلوب

  const BehaviorLevelConfig({
    required this.level,
    required this.nameAr,
    required this.nameEn,
    required this.color,
    required this.action,
  });

  factory BehaviorLevelConfig.fromMap(Map<String, dynamic> map) =>
      BehaviorLevelConfig(
        level: map['level'] ?? 1,
        nameAr: map['nameAr'] ?? '',
        nameEn: map['nameEn'] ?? '',
        color: map['color'] ?? '#FF9800',
        action: map['action'] ?? '',
      );

  Map<String, dynamic> toMap() => {
        'level': level,
        'nameAr': nameAr,
        'nameEn': nameEn,
        'color': color,
        'action': action,
      };
}

// ─── Country Features ─────────────────────────────────────────────────────────

/// الميزات المفعّلة في الدولة
class CountryFeatures {
  /// نظام الحضور والغياب
  final bool attendance;

  /// نظام السلوك
  final bool behavior;

  /// نظام الجدول الذكي
  final bool smartSchedule;

  /// نظام المسارات الدراسية
  final bool tracks;

  /// التواصل مع أولياء الأمور
  final bool parentCommunication;

  /// SMS لأولياء الأمور
  final bool parentSms;

  /// تقارير الأداء
  final bool performanceReports;

  /// نظام الاشتراكات
  final bool subscriptions;

  /// الجدول الدراسي
  final bool timetable;

  /// نظام الاختبارات
  final bool exams;

  /// نظام الواجبات
  final bool assignments;

  /// الإرشاد الطلابي
  final bool counseling;

  /// الصحة المدرسية
  final bool healthTracking;

  /// نظام الإذاعة المدرسية
  final bool schoolBroadcast;

  /// نظام الاستئذان
  final bool leaveRequests;

  const CountryFeatures({
    this.attendance = true,
    this.behavior = true,
    this.smartSchedule = true,
    this.tracks = false,
    this.parentCommunication = true,
    this.parentSms = false,
    this.performanceReports = true,
    this.subscriptions = true,
    this.timetable = true,
    this.exams = true,
    this.assignments = true,
    this.counseling = true,
    this.healthTracking = true,
    this.schoolBroadcast = false,
    this.leaveRequests = true,
  });

  factory CountryFeatures.fromMap(Map<String, dynamic> map) => CountryFeatures(
        attendance: map['attendance'] ?? true,
        behavior: map['behavior'] ?? true,
        smartSchedule: map['smartSchedule'] ?? true,
        tracks: map['tracks'] ?? false,
        parentCommunication: map['parentCommunication'] ?? true,
        parentSms: map['parentSms'] ?? false,
        performanceReports: map['performanceReports'] ?? true,
        subscriptions: map['subscriptions'] ?? true,
        timetable: map['timetable'] ?? true,
        exams: map['exams'] ?? true,
        assignments: map['assignments'] ?? true,
        counseling: map['counseling'] ?? true,
        healthTracking: map['healthTracking'] ?? true,
        schoolBroadcast: map['schoolBroadcast'] ?? false,
        leaveRequests: map['leaveRequests'] ?? true,
      );

  Map<String, dynamic> toMap() => {
        'attendance': attendance,
        'behavior': behavior,
        'smartSchedule': smartSchedule,
        'tracks': tracks,
        'parentCommunication': parentCommunication,
        'parentSms': parentSms,
        'performanceReports': performanceReports,
        'subscriptions': subscriptions,
        'timetable': timetable,
        'exams': exams,
        'assignments': assignments,
        'counseling': counseling,
        'healthTracking': healthTracking,
        'schoolBroadcast': schoolBroadcast,
        'leaveRequests': leaveRequests,
      };

  /// دمج مع إعدادات مخصصة من المدرسة
  CountryFeatures mergeWith(Map<String, dynamic> overrides) {
    return CountryFeatures.fromMap({...toMap(), ...overrides});
  }
}
