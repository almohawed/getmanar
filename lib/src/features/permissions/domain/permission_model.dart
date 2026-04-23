enum UserRole {
  admin,
  manager,
  teacher,
  custodian,
  student,
  parent,
  other
}

enum PermissionLevel {
  full,
  medium,
  limited
}

enum Department {
  schoolManagement,
  administrativeAffairs,
  studentAffairs,
  academicAffairs,
  other
}

class PermissionUser {
  final String id;
  final String name;
  final UserRole role;
  final Department department;
  final PermissionLevel permissionLevel;
  final DateTime lastLogin;
  final bool isActive;
  final DateTime assignedAt;

  PermissionUser({
    required this.id,
    required this.name,
    required this.role,
    required this.department,
    required this.permissionLevel,
    required this.lastLogin,
    required this.isActive,
    required this.assignedAt,
  });

  String get roleLabel {
    switch (role) {
      case UserRole.admin: return 'مدير نظام';
      case UserRole.manager: return 'إداري';
      case UserRole.teacher: return 'معلم';
      case UserRole.custodian: return 'موظف عهدة';
      case UserRole.student: return 'طالب';
      case UserRole.parent: return 'ولي أمر';
      case UserRole.other: return 'آخر';
    }
  }

  String get departmentLabel {
    switch (department) {
      case Department.schoolManagement: return 'إدارة المدرسة';
      case Department.administrativeAffairs: return 'الشؤون الإدارية';
      case Department.studentAffairs: return 'شؤون الطلاب';
      case Department.academicAffairs: return 'الشؤون التعليمية';
      case Department.other: return 'أخرى';
    }
  }

  String get permissionLevelLabel {
    switch (permissionLevel) {
      case PermissionLevel.full: return 'كاملة';
      case PermissionLevel.medium: return 'متوسطة';
      case PermissionLevel.limited: return 'محدودة';
    }
  }
}

class PermissionLog {
  final String id;
  final String action; // e.g., "تم منح صلاحية إداري"
  final String targetUser;
  final String performedBy;
  final DateTime timestamp;

  PermissionLog({
    required this.id,
    required this.action,
    required this.targetUser,
    required this.performedBy,
    required this.timestamp,
  });
}
