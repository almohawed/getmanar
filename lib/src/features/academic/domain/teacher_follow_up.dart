class TeacherFollowUp {
  final String teacherId;
  final String status;
  final String note;
  final DateTime? nextReviewAt;
  final DateTime? updatedAt;
  final String updatedByUid;
  final String updatedByName;

  const TeacherFollowUp({
    required this.teacherId,
    required this.status,
    required this.note,
    required this.nextReviewAt,
    required this.updatedAt,
    required this.updatedByUid,
    required this.updatedByName,
  });

  factory TeacherFollowUp.empty(String teacherId) {
    return TeacherFollowUp(
      teacherId: teacherId,
      status: 'none',
      note: '',
      nextReviewAt: null,
      updatedAt: null,
      updatedByUid: '',
      updatedByName: '',
    );
  }

  factory TeacherFollowUp.fromMap(Map<String, dynamic> m) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
      try {
        if (v.toDate != null) return v.toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    return TeacherFollowUp(
      teacherId: (m['teacherId'] ?? m['id'] ?? '').toString(),
      status: (m['status'] ?? 'none').toString(),
      note: (m['note'] ?? '').toString(),
      nextReviewAt: parseDate(m['nextReviewAt']),
      updatedAt: parseDate(m['updatedAt']),
      updatedByUid: (m['updatedByUid'] ?? '').toString(),
      updatedByName: (m['updatedByName'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'status': status,
      'note': note,
      if (nextReviewAt != null) 'nextReviewAt': nextReviewAt!.toIso8601String(),
      if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
      if (updatedByUid.isNotEmpty) 'updatedByUid': updatedByUid,
      if (updatedByName.isNotEmpty) 'updatedByName': updatedByName,
    };
  }
}

