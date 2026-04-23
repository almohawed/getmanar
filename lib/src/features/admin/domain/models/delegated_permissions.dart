enum AdminSection {
  leadership, // القيادة والمؤشرات
  classes, // الفصول
  students, // الطلاب
  teachers, // المعلمين
  administrative, // التكاليف الإدارية
  schedule, // الجداول
  exams, // الاختبارات
  roles, // الصلاحيات والأدوار (Sensitive)
  reports, // التقارير
  settings, // إعدادات المدرسة (Sensitive)
}

enum AdminPermission {
  view,
  create,
  edit,
  delete,
  approve,
  export,
}

class DelegatedPermissions {
  final Map<String, List<String>> permissions;

  DelegatedPermissions({required this.permissions});

  factory DelegatedPermissions.empty() {
    return DelegatedPermissions(permissions: {});
  }

  factory DelegatedPermissions.fromMap(Map<String, dynamic> map) {
    final converted = <String, List<String>>{};
    map.forEach((key, value) {
      if (value is List) {
        converted[key] = value.map((e) => e.toString()).toList();
      }
    });
    return DelegatedPermissions(permissions: converted);
  }

  Map<String, dynamic> toMap() {
    return permissions;
  }

  bool hasPermission(AdminSection section, AdminPermission permission) {
    final sectionKey = section.name;
    final allowedActions = permissions[sectionKey] ?? [];
    return allowedActions.contains(permission.name);
  }
}
