import 'package:cloud_firestore/cloud_firestore.dart';

class StaffAssignment {
  final String id;
  final String schoolId;
  final String assignedUserId;
  final String assignedUserName;
  final String assignedUserRole;
  final String assignmentTitle;
  final String assignmentType;
  final String? description;
  final String createdBy;
  final String createdByName;
  final DateTime createdAt;
  final bool isActive;
  final String? dashboardRoute;

  StaffAssignment({
    required this.id,
    required this.schoolId,
    required this.assignedUserId,
    required this.assignedUserName,
    required this.assignedUserRole,
    required this.assignmentTitle,
    required this.assignmentType,
    this.description,
    required this.createdBy,
    required this.createdByName,
    required this.createdAt,
    this.isActive = true,
    this.dashboardRoute,
  });

  factory StaffAssignment.fromJson(Map<String, dynamic> json) {
    return StaffAssignment(
      id: json['id'] as String,
      schoolId: json['schoolId'] as String,
      assignedUserId: json['assignedUserId'] as String,
      assignedUserName: json['assignedUserName'] as String,
      assignedUserRole: json['assignedUserRole'] as String,
      assignmentTitle: json['assignmentTitle'] as String,
      assignmentType: json['assignmentType'] as String,
      description: json['description'] as String?,
      createdBy: json['createdBy'] as String,
      createdByName: json['createdByName'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool? ?? true,
      dashboardRoute: json['dashboardRoute'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'schoolId': schoolId,
      'assignedUserId': assignedUserId,
      'assignedUserName': assignedUserName,
      'assignedUserRole': assignedUserRole,
      'assignmentTitle': assignmentTitle,
      'assignmentType': assignmentType,
      'description': description,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'isActive': isActive,
      'dashboardRoute': dashboardRoute,
    };
  }
}

class AssignmentType {
  static const String gradeDeputy = 'grade_deputy';
  static const String securitySafety = 'security_safety';
  static const String healthCounselor = 'health_counselor';
  static const String floorSupervisor = 'floor_supervisor';
  static const String custom = 'custom';

  static String getDisplayName(String type) {
    switch (type) {
      case gradeDeputy:
        return 'وكيل مرحلة';
      case securitySafety:
        return 'مسؤول الأمن والسلامة';
      case healthCounselor:
        return 'المرشد الصحي';
      case floorSupervisor:
        return 'مشرف دور';
      case custom:
        return 'مهام أخرى';
      default:
        return type;
    }
  }

  static List<String> getAllTypes() {
    return [gradeDeputy, securitySafety, healthCounselor, floorSupervisor, custom];
  }
}
