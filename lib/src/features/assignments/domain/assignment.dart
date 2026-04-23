enum AssignmentStatus { pending, submitted, approved }

class Assignment {
  final String id;
  final String title;
  final String subject;
  final DateTime dueDate;
  final AssignmentStatus status;
  final String studentId;
  final String? description;
  final String? type; // 'assignment', 'activity', 'test'
  final bool? isRemote;
  final String? testLink;
  final String? pageFrom;
  final String? pageTo;
  final String? teacherId; // Added for teacher reference
  final String? classId; // Added for class reference
  final String? schoolId; // Added for school scoping and security
  final String? deliveryType; // 'book', 'worksheet', 'research'
  final String? batchId; // Group id for teacher-created batches
  final bool? published; // null/false = draft, true = sent to students

  Assignment({
    required this.id,
    required this.title,
    required this.subject,
    required this.dueDate,
    required this.status,
    required this.studentId,
    this.description,
    this.type,
    this.isRemote,
    this.testLink,
    this.pageFrom,
    this.pageTo,
    this.teacherId,
    this.classId,
    this.schoolId,
    this.deliveryType,
    this.batchId,
    this.published,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subject': subject,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'status': status.name,
      'studentId': studentId,
      'description': description,
      'type': type,
      'isRemote': isRemote,
      'testLink': testLink,
      'pageFrom': pageFrom,
      'pageTo': pageTo,
      'teacherId': teacherId,
      'classId': classId,
      'schoolId': schoolId,
      'deliveryType': deliveryType,
      'batchId': batchId,
      'published': published,
    };
  }

  factory Assignment.fromMap(Map<String, dynamic> map) {
    return Assignment(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      subject: map['subject'] ?? '',
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate'] ?? 0),
      status: AssignmentStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => AssignmentStatus.pending,
      ),
      studentId: map['studentId'] ?? '',
      description: map['description'],
      type: map['type'],
      isRemote: map['isRemote'],
      testLink: map['testLink'],
      pageFrom: map['pageFrom'],
      pageTo: map['pageTo'],
      teacherId: map['teacherId'],
      classId: map['classId'],
      schoolId: map['schoolId'],
      deliveryType: map['deliveryType'],
      batchId: map['batchId'],
      published: map['published'],
    );
  }

  Assignment copyWith({
    String? id,
    String? title,
    String? subject,
    DateTime? dueDate,
    AssignmentStatus? status,
    String? studentId,
    String? description,
    String? type,
    bool? isRemote,
    String? testLink,
    String? pageFrom,
    String? pageTo,
    String? teacherId,
    String? classId,
    String? schoolId,
    String? deliveryType,
    String? batchId,
    bool? published,
  }) {
    return Assignment(
      id: id ?? this.id,
      title: title ?? this.title,
      subject: subject ?? this.subject,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      studentId: studentId ?? this.studentId,
      description: description ?? this.description,
      type: type ?? this.type,
      isRemote: isRemote ?? this.isRemote,
      testLink: testLink ?? this.testLink,
      pageFrom: pageFrom ?? this.pageFrom,
      pageTo: pageTo ?? this.pageTo,
      teacherId: teacherId ?? this.teacherId,
      classId: classId ?? this.classId,
      schoolId: schoolId ?? this.schoolId,
      deliveryType: deliveryType ?? this.deliveryType,
      batchId: batchId ?? this.batchId,
      published: published ?? this.published,
    );
  }
}
