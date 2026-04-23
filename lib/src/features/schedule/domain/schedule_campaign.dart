// 📊 الجدول التشاركي - نموذج الحملة
class ScheduleCampaign {
  final String id;
  final String schoolId;
  final DateTime startDate;
  final DateTime endDate;
  final Duration responseTime;
  final String? message;
  final CampaignStatus status;
  final Map<String, dynamic> settings;
  final DateTime createdAt;
  final String createdBy;

  // Statistics
  final int totalTeachers;
  final int respondedYes;
  final int respondedNo;
  final int notResponded;

  ScheduleCampaign({
    required this.id,
    required this.schoolId,
    required this.startDate,
    required this.endDate,
    required this.responseTime,
    this.message,
    required this.status,
    required this.settings,
    required this.createdAt,
    required this.createdBy,
    this.totalTeachers = 0,
    this.respondedYes = 0,
    this.respondedNo = 0,
    this.notResponded = 0,
  });

  factory ScheduleCampaign.fromMap(Map<String, dynamic> map) {
    return ScheduleCampaign(
      id: map['id'] as String,
      schoolId: map['schoolId'] as String,
      startDate: DateTime.parse(map['startDate'] as String),
      endDate: DateTime.parse(map['endDate'] as String),
      responseTime: Duration(hours: map['responseTimeHours'] as int),
      message: map['message'] as String?,
      status: CampaignStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => CampaignStatus.draft,
      ),
      settings: Map<String, dynamic>.from(map['settings'] ?? {}),
      createdAt: DateTime.parse(map['createdAt'] as String),
      createdBy: map['createdBy'] as String,
      totalTeachers: map['totalTeachers'] as int? ?? 0,
      respondedYes: map['respondedYes'] as int? ?? 0,
      respondedNo: map['respondedNo'] as int? ?? 0,
      notResponded: map['notResponded'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
      'responseTimeHours': responseTime.inHours,
      'message': message,
      'status': status.name,
      'settings': settings,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
      'totalTeachers': totalTeachers,
      'respondedYes': respondedYes,
      'respondedNo': respondedNo,
      'notResponded': notResponded,
    };
  }

  ScheduleCampaign copyWith({
    String? id,
    String? schoolId,
    DateTime? startDate,
    DateTime? endDate,
    Duration? responseTime,
    String? message,
    CampaignStatus? status,
    Map<String, dynamic>? settings,
    DateTime? createdAt,
    String? createdBy,
    int? totalTeachers,
    int? respondedYes,
    int? respondedNo,
    int? notResponded,
  }) {
    return ScheduleCampaign(
      id: id ?? this.id,
      schoolId: schoolId ?? this.schoolId,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      responseTime: responseTime ?? this.responseTime,
      message: message ?? this.message,
      status: status ?? this.status,
      settings: settings ?? this.settings,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
      totalTeachers: totalTeachers ?? this.totalTeachers,
      respondedYes: respondedYes ?? this.respondedYes,
      respondedNo: respondedNo ?? this.respondedNo,
      notResponded: notResponded ?? this.notResponded,
    );
  }

  // Helper methods
  bool get isActive => status == CampaignStatus.active;
  bool get isClosed => status == CampaignStatus.closed;
  bool get isExpired => status == CampaignStatus.expired || DateTime.now().isAfter(endDate);
  
  double get responseRate {
    if (totalTeachers == 0) return 0.0;
    return ((respondedYes + respondedNo) / totalTeachers) * 100;
  }

  Duration get timeRemaining {
    if (isExpired) return Duration.zero;
    return endDate.difference(DateTime.now());
  }
}

enum CampaignStatus {
  draft,    // مسودة
  active,   // نشط
  closed,   // مغلق
  expired,  // منتهي
}
