class TeacherNote {
  final String id;
  final String teacherId;
  final String title;
  final String content;
  final DateTime createdAt;
  final String? schoolId;

  TeacherNote({
    required this.id,
    required this.teacherId,
    required this.title,
    required this.content,
    required this.createdAt,
    this.schoolId,
  });

  TeacherNote copyWith({
    String? id,
    String? teacherId,
    String? title,
    String? content,
    DateTime? createdAt,
    String? schoolId,
  }) {
    return TeacherNote(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      schoolId: schoolId ?? this.schoolId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'teacherId': teacherId,
      'title': title,
      'content': content,
      'createdAt': createdAt.toIso8601String(),
      'schoolId': schoolId,
    };
  }

  factory TeacherNote.fromMap(Map<String, dynamic> map) {
    return TeacherNote(
      id: map['id'] ?? '',
      teacherId: map['teacherId'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] ?? '',
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'])
          : DateTime.now(),
      schoolId: map['schoolId'],
    );
  }
}
