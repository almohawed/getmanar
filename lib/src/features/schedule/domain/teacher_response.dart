// 📝 رد المعلم على الحملة
class TeacherResponse {
  final String id;
  final String campaignId;
  final String teacherId;
  final String teacherName;
  final ResponseType response;
  final List<BlockedSlot> blockedSlots;
  final DateTime? respondedAt;
  final String? notes;

  TeacherResponse({
    required this.id,
    required this.campaignId,
    required this.teacherId,
    required this.teacherName,
    required this.response,
    required this.blockedSlots,
    this.respondedAt,
    this.notes,
  });

  factory TeacherResponse.fromMap(Map<String, dynamic> map) {
    return TeacherResponse(
      id: map['id'] as String,
      campaignId: map['campaignId'] as String,
      teacherId: map['teacherId'] as String,
      teacherName: map['teacherName'] as String,
      response: ResponseType.values.firstWhere(
        (e) => e.name == map['response'],
        orElse: () => ResponseType.noResponse,
      ),
      blockedSlots: (map['blockedSlots'] as List<dynamic>?)
              ?.map((e) => BlockedSlot.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      respondedAt: map['respondedAt'] != null
          ? DateTime.parse(map['respondedAt'] as String)
          : null,
      notes: map['notes'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'campaignId': campaignId,
      'teacherId': teacherId,
      'teacherName': teacherName,
      'response': response.name,
      'blockedSlots': blockedSlots.map((e) => e.toMap()).toList(),
      'respondedAt': respondedAt?.toIso8601String(),
      'notes': notes,
    };
  }

  bool get hasResponded => response != ResponseType.noResponse;
  bool get wantsToBlock => response == ResponseType.yes;
  int get blockedSlotsCount => blockedSlots.length;
}

enum ResponseType {
  yes,        // نعم، لدي رغبة
  no,         // لا، شكراً
  noResponse, // لم يرد
}

// 🚫 حصة محظورة
class BlockedSlot {
  final String day;
  final int period;
  final String? reason;

  BlockedSlot({
    required this.day,
    required this.period,
    this.reason,
  });

  factory BlockedSlot.fromMap(Map<String, dynamic> map) {
    return BlockedSlot(
      day: map['day'] as String,
      period: map['period'] as int,
      reason: map['reason'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'period': period,
      'reason': reason,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BlockedSlot && other.day == day && other.period == period;
  }

  @override
  int get hashCode => day.hashCode ^ period.hashCode;
}
