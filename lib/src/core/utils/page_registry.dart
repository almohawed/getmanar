/// Registry to track the progress of page migration.
class PageRegistryItem {
  final String routeName;
  final String screenClassName;
  final String module; // Academic, School, Student
  final String stage; // UIOnly, Wired, Connected, Done
  final String priority; // P0, P1, P2

  const PageRegistryItem({
    required this.routeName,
    required this.screenClassName,
    required this.module,
    required this.stage,
    required this.priority,
  });
}

class PageRegistry {
  static const List<PageRegistryItem> items = [
    // --- Academic Affairs (P0) ---
    PageRegistryItem(
      routeName: '/curriculum-progress',
      screenClassName: 'AcademicProgressModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/lesson-prep',
      screenClassName: 'AcademicProgressModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/plan-delay',
      screenClassName: 'AcademicProgressModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/create-schedule',
      screenClassName: 'TimetableModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/resolve-conflicts',
      screenClassName: 'TimetableModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/exam-schedule',
      screenClassName: 'ExamsModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/grade-entry',
      screenClassName: 'ExamsModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/subject-analysis',
      screenClassName: 'AcademicAnalyticsModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/low-achievers',
      screenClassName: 'AcademicAnalyticsModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/success-rates',
      screenClassName: 'AcademicReportsModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/export-academic-reports',
      screenClassName: 'AcademicReportsModuleScreen',
      module: 'Academic',
      stage: 'UIOnly',
      priority: 'P0',
    ),

    // --- Student Affairs (P0) ---
    PageRegistryItem(
      routeName: '/attendance',
      screenClassName: 'StudentDisciplineModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/tardiness',
      screenClassName: 'StudentDisciplineModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/frequent-absence',
      screenClassName: 'StudentDisciplineModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/notify-parents',
      screenClassName: 'StudentDisciplineModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/escalation',
      screenClassName: 'StudentBehaviorModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/student-profile',
      screenClassName: 'StudentCaseModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/immediate-report',
      screenClassName: 'StudentSupervisionModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/behavior-report',
      screenClassName: 'StudentReportsModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/attendance-report',
      screenClassName: 'StudentReportsModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/export-records',
      screenClassName: 'StudentReportsModuleScreen',
      module: 'Student',
      stage: 'UIOnly',
      priority: 'P0',
    ),

    // --- School Affairs (P0) ---
    PageRegistryItem(
      routeName: '/mail-management',
      screenClassName: 'SchoolAdminModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/staff-attendance',
      screenClassName: 'StaffAttendanceModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/maintenance-priority',
      screenClassName: 'MaintenanceModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/maintenance-status',
      screenClassName: 'MaintenanceModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/evacuation-plan',
      screenClassName: 'SafetyModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/extinguishers-check',
      screenClassName: 'SafetyModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/electronic-inventory',
      screenClassName: 'InventoryModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/building-readiness',
      screenClassName: 'MaintenanceModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/export-school-reports',
      screenClassName: 'SchoolAdminModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/health-rules',
      screenClassName: 'ServicesModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
    PageRegistryItem(
      routeName: '/observations-log',
      screenClassName: 'ServicesModuleScreen',
      module: 'School',
      stage: 'UIOnly',
      priority: 'P0',
    ),
  ];
}
