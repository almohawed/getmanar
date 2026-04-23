enum AnnouncementStatus {
  active,
  scheduled,
  expired,
  cancelled
}

enum AnnouncementType {
  activity,   // نشاط مدرسي
  event,      // فعالية
  alert,      // تنبيه
  occasion,   // مناسبة
  general     // إعلان عام
}

enum TargetAudience {
  all,
  teachers,
  students,
  parents
}

class Announcement {
  final String id;
  final String title;
  final String content;
  final TargetAudience targetAudience;
  final AnnouncementType type;
  final AnnouncementStatus status;
  final DateTime publishDate;
  final int viewCount;
  final String? imageUrl;
  final String creatorName;

  Announcement({
    required this.id,
    required this.title,
    required this.content,
    required this.targetAudience,
    required this.type,
    required this.status,
    required this.publishDate,
    required this.viewCount,
    this.imageUrl,
    required this.creatorName,
  });

  // Helper to get Arabic label for Type
  static String getTypeLabel(AnnouncementType type) {
    switch (type) {
      case AnnouncementType.activity: return 'نشاط مدرسي';
      case AnnouncementType.event: return 'فعالية';
      case AnnouncementType.alert: return 'تنبيه';
      case AnnouncementType.occasion: return 'مناسبة';
      case AnnouncementType.general: return 'إعلان عام';
    }
  }

  // Helper to get Arabic label for Audience
  static String getAudienceLabel(TargetAudience audience) {
    switch (audience) {
      case TargetAudience.all: return 'الجميع';
      case TargetAudience.teachers: return 'المعلمون';
      case TargetAudience.students: return 'الطلاب';
      case TargetAudience.parents: return 'أولياء الأمور';
    }
  }
}
