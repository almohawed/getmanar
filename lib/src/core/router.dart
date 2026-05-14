import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../features/supervision/presentation/supervision_duty_screen.dart';
import '../features/broadcast/presentation/broadcast_screen.dart';
import '../features/broadcast/presentation/assign_broadcast_supervisor_screen.dart';
import '../features/admin/presentation/teacher_detail_screen.dart'; // Import this
import '../features/admin/presentation/core_rules_screen.dart'; // Import CoreRulesScreen
import '../features/academic/presentation/class_details_screen.dart'; // Import this
import '../features/academic/presentation/students_list_screen.dart'; // Import this
import '../features/auth/presentation/login_screen.dart';
import '../features/auth/presentation/splash_screen.dart'; // Import this
import '../features/dashboard/presentation/dashboard_screen.dart';

import '../features/dashboard/presentation/reports_screen.dart';
import '../features/dashboard/presentation/teacher_drafts_screen.dart';
import '../features/admin/presentation/add_teacher_screen.dart';
import '../features/admin/presentation/add_class_screen.dart'; // Import this
import '../features/admin/presentation/add_staff_screen.dart';
import '../features/academic/domain/classroom.dart'; // Import this
import '../features/admin/presentation/school_requests_list_screen.dart'; // Import this
import '../features/admin/presentation/admin_lists.dart'; // Import admin lists
import '../features/counselor/presentation/counselor_screens.dart'; // Import counselor screens
import '../features/counselor/presentation/health_cases_screen.dart'; // Import health cases screen
import '../features/counselor/presentation/active_cases_screen.dart'; // Import active cases screen
import '../features/counselor/presentation/closed_cases_screen.dart'; // Import closed cases screen
import '../features/counselor/presentation/search_cases_screen.dart'; // Import search cases screen
import '../features/counselor/presentation/sessions_calendar_screen.dart'; // Import sessions calendar screen
import '../features/counselor/presentation/sessions_reports_screen.dart'; // Import sessions reports screen
import '../features/counselor/presentation/comprehensive_report_screen.dart';
import '../features/counselor/presentation/cases_statistics_screen.dart';
import '../features/counselor/presentation/cases_timeline_screen.dart';
import '../features/counselor/presentation/print_reports_screen.dart';
import '../features/counselor/presentation/counselor_sms_screen.dart';
import '../features/admin/presentation/sms_settings_screen.dart';
import '../features/admin/presentation/school_location_screen.dart';
import '../features/sms/presentation/teacher_sms_screen.dart';
import '../features/sms/presentation/teacher_sms_limits_screen.dart';
// import '../features/counselor/presentation/progress_evaluation_screen.dart'; // Import progress evaluation screen
import '../features/counselor/presentation/add_followup_screen.dart'; // Import add followup screen
import '../features/counselor/presentation/create_modification_plan_screen.dart'; // Import create modification plan screen
import '../features/counselor/presentation/simple_pdf_export_screen.dart'; // Import simple PDF export screen
import '../features/academic/presentation/active_plans_screen_simple.dart'; // Import active plans screen
import '../features/academic/presentation/plan_recommendations_screen.dart'; // Import plan recommendations screen
import '../features/academic/presentation/plan_details_screen.dart'; // Import plan details screen
import '../features/academic/presentation/plan_edit_screen.dart'; // Import plan edit screen
import '../features/academic/presentation/plan_progress_screen.dart'; // Import plan progress screen
import '../features/assignments/presentation/assignments_list_screen.dart';
import '../features/tests/presentation/tests_list_screen.dart';
import '../features/wait_management/presentation/wait_management_screen.dart';
import '../features/schedule/presentation/schedule_management_screen.dart';
import '../features/schedule/presentation/smart_schedule_screen.dart';
import '../features/schedule/presentation/subject_assignment_screen.dart';
import '../features/schedule/presentation/teacher_constraints_screen.dart';
import '../features/schedule/presentation/assign_subjects_screen.dart';
import '../features/schedule/presentation/teacher_schedule_preferences_screen.dart';
import '../features/schedule/presentation/teacher_schedule_screen.dart';
import '../features/schedule/presentation/teacher_schedule_with_summary_screen.dart';
import '../features/schedule/presentation/student_schedule_screen.dart';
import '../features/schedule/presentation/current_schedule_screen.dart';
import '../features/schedule/presentation/schedule_import_screen.dart';
import '../features/schedule/presentation/subjects_management_screen.dart';
import '../features/behavior/presentation/behavioral_violations_screen.dart';
import '../features/violations/presentation/violations_list_screen.dart';
import '../features/behavior/presentation/violations_log_screen.dart';
import '../features/counselor/presentation/students_by_behavior_screen.dart';
import '../features/attendance/presentation/attendance_days_screen.dart';
import '../features/attendance/presentation/attendance_periods_screen.dart';
import '../features/attendance/presentation/teacher_attendance_screen.dart';
import '../features/attendance/presentation/period_attendance_screen.dart';
import 'domain/models/behavior_record.dart';
import 'domain/models/user.dart';
import '../features/notifications/presentation/notifications_screen.dart';
import '../features/notifications/presentation/send_announcement_screen.dart';
import '../features/circulars/presentation/circulars_inbox_screen.dart';
import '../features/circulars/presentation/circulars_management_screen.dart';
import '../features/circulars/presentation/create_circular_screen.dart';
import '../features/circulars/presentation/circular_details_screen.dart';
import '../features/circulars/presentation/circular_viewer_screen.dart';
import '../features/circulars/domain/circular.dart';
import '../features/students/presentation/student_scan_screen.dart';
import '../features/auth/presentation/privacy_policy_screen.dart';
import '../features/auth/presentation/terms_of_use_screen.dart';
import '../features/auth/presentation/forgot_password_screen.dart';
import '../features/auth/presentation/school_request_screen.dart';
import '../features/auth/presentation/school_request_success_screen.dart';
import '../features/requests/presentation/deputy_permission_requests_screen.dart';
import '../features/subscription/presentation/subscription_plans_screen.dart';
import '../features/subscription/presentation/subscription_invoice_screen.dart';
import '../features/super_admin/presentation/announcements_screen.dart';
import '../features/super_admin/presentation/add_school_screen.dart'; // Import this
import '../features/schedule/presentation/create_campaign_screen.dart';
import '../features/schedule/presentation/teacher_campaign_response_screen.dart';
import '../features/schedule/presentation/workload_analysis_screen.dart';
import '../features/schedule/presentation/modifications_log_screen.dart';
import '../features/super_admin/presentation/global_accounts_screen.dart'; // Import this
import '../features/super_admin/presentation/seed_omar_screen.dart';
import '../features/settings/presentation/settings_screen.dart'; // Import SettingsScreen
import '../features/settings/presentation/about_screen.dart'; // Import AboutScreen
import '../features/settings/presentation/masarat_tracks_screen.dart';
import '../features/setup/presentation/school_setup_wizard.dart';
import '../features/admin/presentation/smart_admin_dashboard.dart';
import '../features/admin/presentation/admin_dashboard_v2.dart';
import '../features/parent/presentation/parent_pin_setup_screen.dart';
import '../features/academic_calendar/presentation/academic_calendar_manage_screen.dart';
import '../features/auth/presentation/change_password_screen.dart'; // Import ChangePasswordScreen
import '../features/distinguished_students/presentation/distinguished_review_screen.dart';
import '../features/intelligence/presentation/school_intelligence_dashboard.dart';
import '../features/notifications/presentation/system_announcement_details_screen.dart';
import '../features/teacher_intelligence/presentation/teacher_intelligence_dashboard.dart';
import '../features/attendance/presentation/school_attendance_command_center_screen.dart'; // Import SchoolAttendanceCommandCenterScreen
import '../features/attendance/presentation/smart_attendance_dashboard.dart'; // Import SmartAttendanceDashboard
import '../features/behavior/presentation/behavior_dashboard_screen.dart';
import '../features/behavior/presentation/smart_behavior_dashboard.dart';
import '../features/behavior/presentation/behavior_analysis_screen.dart';
import '../features/behavior/presentation/behavior_reports_screen.dart';
import '../features/behavior/presentation/students_list_by_behavior_screen.dart';
import '../features/behavior/presentation/behavioral_cases_screen.dart';
import '../features/behavior/presentation/add_violation_quick_screen.dart';

import '../features/assignments/presentation/admin/assignments_management_screen.dart';
import '../features/assignments/presentation/dashboard/assignment_dashboard_screen.dart';
import '../features/assignments/domain/administrative_assignment.dart';

import '../features/dashboard/presentation/pages/student_violations_screen.dart';
import '../features/dashboard/presentation/pages/student_attendance_screen.dart';
import '../features/dashboard/presentation/pages/student_behavior_profile_screen.dart';
import '../features/dashboard/presentation/pages/classroom_behavior_indicators_screen.dart';
import '../features/academic/presentation/friends_list_screen.dart';
import '../features/dashboard/presentation/pages/safety_dashboard_screen.dart';
// import '../features/dashboard/presentation/pages/activity_dashboard_screen.dart';
import '../features/dashboard/presentation/pages/health_dashboard_screen.dart';
import '../features/dashboard/presentation/smart_health_dashboard.dart';
import '../features/dashboard/presentation/counselor_dashboard.dart';
import '../features/dashboard/presentation/smart_counselor_dashboard.dart';
import '../features/academic/presentation/screens/academic_modules.dart';
import '../features/student/presentation/screens/student_supervision_screen.dart';
import '../features/student/presentation/screens/student_modules.dart';
import '../features/student/presentation/screens/tardiness_registration_screen.dart';
import '../features/student/presentation/screens/frequent_absence_screen.dart';
import '../core/domain/models/user.dart'; // Use User model
import '../features/attendance/presentation/screens/student_absence_details_screen.dart'; // Import StudentAbsenceDetailsScreen
import '../features/school/presentation/screens/school_modules.dart';
import 'presentation/screens/dev_progress_screen.dart';
import '../features/behavior/presentation/add_violation_screen.dart'; // Import AddViolationScreen
import '../features/maintenance/presentation/report_maintenance_screen.dart'; // Import ReportMaintenanceScreen
import '../features/maintenance/presentation/maintenance_request_list_screen.dart'; // Import MaintenanceRequestListScreen
import '../features/school/presentation/school_guide_screen.dart'; // Import SchoolGuideScreen
import '../features/deputy/presentation/deputy_sms_screen.dart'; // Import DeputySmsScreen
import '../features/deputy/presentation/teacher_notes_inbox_screen.dart';
import '../features/deputy/presentation/teacher_migration_screen.dart'; // Import TeacherMigrationScreen
import '../features/leave_requests/presentation/teacher_leave_request_screen.dart';
import '../features/leave_requests/presentation/deputy_leave_dashboard_screen.dart';
import '../features/admin_tasks/presentation/admin_task_details_screen.dart'; // Import AdminTaskDetailsScreen
import '../features/counselor/presentation/case_details_screen.dart'; // Import CaseDetailsScreen
import '../features/admin_tasks/presentation/admin_tasks_list_screen.dart'; // Import AdminTasksListScreen
import '../features/dashboard/presentation/teacher_alerts_center_screen.dart'; // Import TeacherAlertsCenterScreen
// school_intelligence_dashboard.dart already imported above
import '../features/behavior/presentation/behavior_enhancement_dashboard_screen.dart';
import '../features/exams/presentation/exam_management_screen.dart'; // Import ExamManagementScreen
import '../features/exams/presentation/exam_seating_screen.dart';
import '../features/admin_tasks/presentation/create_admin_task_screen.dart'; // Import CreateAdminTaskScreen
import '../features/admin/presentation/code_management_screen.dart'; // Import CodeManagementScreen
import '../features/auth/presentation/pin_setup_screen.dart';
import '../features/auth/presentation/pin_login_screen.dart';

import '../features/admin/presentation/parents_list_screen.dart'; // Import ParentsListScreen
import '../features/admin/presentation/governance_framework_screen.dart'; // Import GovernanceFrameworkScreen
import '../features/admin/presentation/executive_dashboard_screen.dart'; // Import ExecutiveDashboardScreen
import '../features/assignments/presentation/staff_assignments_list_screen.dart';
import '../features/assignments/presentation/create_staff_assignment_screen.dart';
import '../features/admin/presentation/specialized_dashboards.dart'; // Import specialized dashboards
import '../features/admin/presentation/student_labels_screen.dart';
import '../features/inbox/presentation/inbox_dashboard_screen.dart'; // Import IncomingMailScreen
import '../features/inbox/presentation/outbox_dashboard_screen.dart';
import '../features/announcements/presentation/announcements_dashboard_screen.dart';
import '../features/permissions/presentation/permissions_dashboard_screen.dart';
import '../features/admin/presentation/development_plans_screen.dart';

import '../features/behavior/presentation/student_follow_up_screen.dart'; // Import StudentFollowUpScreen
import '../features/behavior/presentation/add_behavior_enhancement_screen.dart'; // Import AddBehaviorEnhancementScreen
import '../features/behavior/presentation/student_excellence_compensation_screen.dart'; // Import StudentExcellenceCompensationScreen
import '../features/behavior/presentation/add_behavior_warning_screen.dart'; // Import AddBehaviorWarningScreen

import '../features/counselor/presentation/add_student_case_screen.dart'; // Import AddStudentCaseScreen
import '../features/counselor/presentation/add_session_screen.dart'; // Import AddSessionScreen

// REMOVED: import '../features/counselor/presentation/add_case_followup_screen.dart';
// استخدم AddFollowupScreen بدلاً منها (مستوردة بالفعل في السطر 27)
import '../features/counselor/presentation/close_student_case_screen.dart'; // Import CloseStudentCaseScreen

import '../features/dashboard/presentation/activity_dashboard_screen.dart'; // Import ActivityDashboardScreen
import '../features/dashboard/presentation/smart_activity_dashboard.dart'; // Import SmartActivityDashboard
import '../features/activity/presentation/add_activity_screen.dart'; // Import AddActivityScreen
import '../features/activity/presentation/register_student_activity_screen.dart'; // Import RegisterStudentActivityScreen
import '../features/activity/presentation/update_activity_screen.dart'; // Import UpdateActivityScreen
import '../features/activity/presentation/end_activity_screen.dart'; // Import EndActivityScreen

import '../features/health/presentation/add_health_incident_screen.dart'; // Import AddHealthIncidentScreen
import '../features/health/presentation/add_health_case_screen.dart'; // Import AddHealthCaseScreen
import '../features/health/presentation/medication_tracking_screen.dart'; // Import MedicationTrackingScreen
import '../features/academic/presentation/create_remedial_plan_screen.dart'; // Import CreateRemedialPlanScreen
import '../features/academic/presentation/link_student_teacher_screen.dart';
import '../features/academic/presentation/plan_followup_screen.dart';
import '../features/academic/presentation/measure_improvement_screen.dart';
import '../features/academic/presentation/success_rates_report_screen.dart';
import '../features/academic/presentation/learning_gaps_report_screen.dart';
import '../features/academic/presentation/teacher_performance_report_tab.dart';
import '../features/academic/presentation/export_academic_reports_tab.dart';
import '../features/simple_schedule/presentation/simple_schedule_screen.dart';
import '../features/simple_schedule/presentation/my_schedule_screen.dart';
import '../features/requests/presentation/student_exit_permission_screen.dart';
import '../features/attendance/presentation/morning_assembly_attendance_screen.dart';
import '../features/schedule/presentation/teacher_schedule_edit_screen.dart';

final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/smart-placeholder',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final title = extra?['title'] as String? ?? 'قريباً';
        final color = extra?['color'] as Color? ?? Colors.grey;
        final icon = extra?['icon'] as IconData? ?? Icons.build;

        // --- Specialized Routing Logic ---
        if (title.contains('التقارير')) {
          return const AcademicDashboard(); // Using Academic for now as it fits data viz
        }
        if (title.contains('الخطط')) {
          return const DevelopmentPlansScreen();
        }
        if (title.contains('الاستراتيجية') || title.contains('المناعة')) {
          return const StrategicDashboard();
        }
        if (title.contains('الوارد')) {
          return InboxDashboardScreen(
            schoolId: extra?['schoolId'],
            userId: extra?['userId'],
            userName: extra?['userName'],
          );
        }
        if (title.contains('الصادر')) {
          return OutboxDashboardScreen(
            schoolId: (extra?['schoolId'] as String?) ?? '',
            userName: (extra?['userName'] as String?) ?? 'مستخدم',
            userRole: (extra?['userRole'] as String?) ?? '',
          );
        }
        if (title.contains('التعاميم')) {
          return const CircularsManagementScreen();
        }
        if (title.contains('الإعلانات')) {
          return const AnnouncementsDashboardScreen();
        }
        if (title.contains('الصلاحيات') || title.contains('الأمان')) {
          return const PermissionsDashboard();
        }
        if (title.contains('النقل')) {
          return const LogisticsDashboard();
        }
        if (title.contains('العهد') || title.contains('الممتلكات')) {
          return const AssetsDashboard();
        }
        if (title.contains('الاجتماعات') || title.contains('اللجان')) {
          return const MeetingsDashboard();
        }
        if (title.contains('صيانة') || title.contains('العمليات')) {
          return const MaintenanceDashboard();
        }
        if (title.contains('الأمن') || title.contains('السلامة')) {
          return const SafetyDashboard();
        }
        if (title.contains('أكاديم') ||
            title.contains('التميز') ||
            title.contains('التحصيل') ||
            title.contains('الاختبارات') ||
            title.contains('الجدول')) {
          return const AcademicDashboard();
        }
        if (title.contains('طلاب') ||
            title.contains('السلوك') ||
            title.contains('النشاط') ||
            title.contains('التوجيه') ||
            title.contains('الصحة') ||
            title.contains('الحضور')) {
          return const StudentLifeDashboard();
        }

        // --- NEW: Redirect to Executive Dashboard ---
        return ExecutiveDashboardScreen(title: title, color: color, icon: icon);
      },
    ),
    GoRoute(
      path: '/development-plans',
      builder: (context, state) => const DevelopmentPlansScreen(),
    ),
    GoRoute(
      path: '/student-follow-up',
      builder: (context, state) => const StudentFollowUpScreen(),
    ),
    GoRoute(
      path: '/add-behavior-enhancement',
      builder: (context, state) => const AddBehaviorEnhancementScreen(),
    ),
    GoRoute(
      path: '/student-excellence-compensation',
      builder: (context, state) {
        final tab = state.uri.queryParameters['tab'] ?? 'excellence';
        return StudentExcellenceCompensationScreen(initialTab: tab);
      },
    ),
    GoRoute(
      path: '/add-behavior-warning',
      builder: (context, state) => const AddBehaviorWarningScreen(),
    ),
    GoRoute(
      path: '/add-student-case',
      builder: (context, state) => const AddStudentCaseScreen(),
    ),
    GoRoute(
      path: '/add-counseling-session',
      builder: (context, state) => const AddSessionScreen(),
    ),
    GoRoute(
      path: '/add-case-followup',
      builder: (context, state) =>
          const AddFollowupScreen(), // استخدام الصفحة الجديدة الاحترافية
    ),
    GoRoute(
      path: '/counselor/active-cases',
      builder: (context, state) => const ActiveCasesScreen(),
    ),
    GoRoute(
      path: '/counselor/closed-cases',
      builder: (context, state) => const ClosedCasesScreen(),
    ),
    GoRoute(
      path: '/counselor/search-cases',
      builder: (context, state) => const SearchCasesScreen(),
    ),
    GoRoute(
      path: '/counselor/sessions-calendar',
      builder: (context, state) => const SessionsCalendarScreen(),
    ),
    GoRoute(
      path: '/counselor/sessions-reports',
      builder: (context, state) => const SessionsReportsScreen(),
    ),
    GoRoute(
        path: '/counselor/comprehensive-report',
        builder: (context, state) => const ComprehensiveReportScreen()),
    GoRoute(
        path: '/counselor/cases-statistics',
        builder: (context, state) => const CasesStatisticsScreen()),
    GoRoute(
        path: '/counselor/cases-timeline',
        builder: (context, state) => const CasesTimelineScreen()),
    GoRoute(
        path: '/counselor/print-reports',
        builder: (context, state) => const PrintReportsScreen()),
    GoRoute(
        path: '/counselor/sms',
        builder: (context, state) => const CounselorSmsScreen()),
    GoRoute(
        path: '/admin/sms-settings',
        builder: (context, state) => const SmsSettingsScreen()),
    GoRoute(
        path: '/teacher-sms',
        builder: (context, state) => const TeacherSmsScreen()),
    GoRoute(
        path: '/teacher-sms-limits',
        builder: (context, state) => const TeacherSmsLimitsScreen()),
    // GoRoute(
    //   path: '/counselor/progress-evaluation',
    //   builder: (context, state) => const ProgressEvaluationScreen(),
    // ),
    GoRoute(
      path: '/counselor/simple-pdf-export',
      builder: (context, state) => const SimplePdfExportScreen(),
    ),
    GoRoute(
      path: '/counselor/recommendations',
      builder: (context, state) => const AddFollowupScreen(),
    ),
    GoRoute(
      path: '/counselor/add-followup',
      builder: (context, state) => const AddFollowupScreen(),
    ),
    GoRoute(
      path: '/counselor/active-plans',
      builder: (context, state) {
        // سيتم الحصول على schoolId من المستخدم الحالي تلقائياً
        return ActivePlansScreen();
      },
    ),
    GoRoute(
      path: '/counselor/create-plan',
      builder: (context, state) => const CreateModificationPlanScreen(),
    ),
    GoRoute(
      path: '/create-plan',
      builder: (context, state) => const CreateModificationPlanScreen(),
    ),
    GoRoute(
      path: '/academic/active-plans',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        final schoolId = extra?['schoolId'] as String? ?? '';
        return ActivePlansScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/plan-progress/:planId',
      builder: (context, state) {
        final planId = state.pathParameters['planId'] ?? '';
        return PlanProgressScreen(planId: planId);
      },
    ),
    GoRoute(
      path: '/plan-recommendations/:planId',
      builder: (context, state) {
        final planId = state.pathParameters['planId'] ?? '';
        return PlanRecommendationsScreen(planId: planId);
      },
    ),
    GoRoute(
      path: '/close-student-case',
      builder: (context, state) => const CloseStudentCaseScreen(),
    ),
    GoRoute(
      path: '/activity-dashboard',
      builder: (context, state) => const SmartActivityDashboard(),
    ),
    GoRoute(
      path: '/add-activity',
      builder: (context, state) => const AddActivityScreen(),
    ),
    GoRoute(
      path: '/register-student-activity',
      builder: (context, state) => const RegisterStudentActivityScreen(),
    ),
    GoRoute(
      path: '/update-activity',
      builder: (context, state) => const UpdateActivityScreen(),
    ),
    GoRoute(
      path: '/end-activity',
      builder: (context, state) => const EndActivityScreen(),
    ),

    GoRoute(
      path: '/add-health-incident',
      builder: (context, state) => const AddHealthIncidentScreen(),
    ),
    GoRoute(
      path: '/add-health-case',
      builder: (context, state) => const AddHealthCaseScreen(),
    ),
    GoRoute(
      path: '/counselor/medications',
      builder: (context, state) => const MedicationTrackingScreen(),
    ),
    GoRoute(
      path: '/create-remedial-plan',
      builder: (context, state) => const CreateRemedialPlanScreen(),
    ),
    GoRoute(
      path: '/link-student-teacher',
      builder: (context, state) => const LinkStudentTeacherScreen(),
    ),
    GoRoute(
      path: '/plan-followup',
      builder: (context, state) => const PlanFollowupScreen(),
    ),
    GoRoute(
      path: '/measure-improvement',
      builder: (context, state) => const MeasureImprovementScreen(),
    ),
    GoRoute(
      path: '/success-rates',
      builder: (context, state) => const SuccessRatesReportScreen(),
    ),
    GoRoute(
      path: '/learning-gaps',
      builder: (context, state) => const LearningGapsReportScreen(),
    ),
    GoRoute(
      path: '/teacher-performance-report',
      builder: (context, state) => const TeacherPerformanceReportTab(),
    ),
    GoRoute(
      path: '/export-academic-reports',
      builder: (context, state) => const ExportAcademicReportsTab(),
    ),
    GoRoute(
      path: '/parents',
      builder: (context, state) => const ParentsListScreen(),
    ),
    GoRoute(
      path: '/school-attendance-dashboard',
      builder: (context, state) => const SchoolAttendanceCommandCenterScreen(),
    ),
    GoRoute(
      path: '/smart-attendance-dashboard',
      builder: (context, state) => const SmartAttendanceDashboard(),
    ),
    GoRoute(
      path: '/incoming-mail',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return InboxDashboardScreen(
          schoolId: extra?['schoolId'],
          userId: extra?['userId'],
          userName: extra?['userName'],
        );
      },
    ),
    GoRoute(
      path: '/governance-framework',
      builder: (context, state) => const GovernanceFrameworkScreen(),
    ),
    GoRoute(
      path: '/smart-exams',
      builder: (context, state) => const ExamManagementScreen(),
    ),
    GoRoute(
      path: '/exam-seating',
      builder: (context, state) => const ExamSeatingScreen(),
    ),
    GoRoute(
      path: '/admin-tasks',
      builder: (context, state) => const PermissionsDashboard(),
    ),
    GoRoute(
      path: '/create-admin-task',
      builder: (context, state) {
        final initialStaffId = state.uri.queryParameters['staffId'];
        return CreateAdminTaskScreen(initialStaffId: initialStaffId);
      },
    ),
    GoRoute(
      path: '/code-management',
      builder: (context, state) => const CodeManagementScreen(),
    ),
    GoRoute(
      path: '/admin-task/:taskId',
      builder: (context, state) {
        final taskId = state.pathParameters['taskId']!;
        return AdminTaskDetailsScreen(taskId: taskId);
      },
    ),
    GoRoute(
      path: '/admin-assignments',
      builder: (context, state) => const AssignmentsManagementScreen(),
    ),
    GoRoute(path: '/', builder: (context, state) => const SplashScreen()),
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(
      path: '/pin-setup',
      builder: (context, state) => const PinSetupScreen(),
    ),
    GoRoute(
      path: '/pin-login',
      builder: (context, state) => const PinLoginScreen(),
    ),
    GoRoute(
      path: '/student-violations',
      builder: (context, state) {
        final student = state.extra as User;
        return StudentViolationsScreen(student: student);
      },
    ),
    GoRoute(
      path: '/student-attendance',
      builder: (context, state) {
        final student = state.extra as User;
        return StudentAttendanceScreen(student: student);
      },
    ),
    GoRoute(
      path: '/student-behavior-profile',
      builder: (context, state) {
        final student = state.extra as User;
        return StudentBehaviorProfileScreen(student: student);
      },
    ),
    GoRoute(
      path: '/friends-list',
      builder: (context, state) {
        final student = state.extra as User;
        return FriendsListScreen(student: student);
      },
    ),
    GoRoute(
      path: '/assignments-management',
      builder: (context, state) => const AssignmentsManagementScreen(),
    ),
    GoRoute(
      path: '/assignment-dashboard',
      builder: (context, state) {
        final assignment = state.extra as AdministrativeAssignment;
        return AssignmentDashboardScreen(assignment: assignment);
      },
    ),
    GoRoute(
      path: '/forgot-password',
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: '/school-request',
      builder: (context, state) => const SchoolRequestScreen(),
    ),
    GoRoute(
      path: '/school-request-success',
      builder: (context, state) => const SchoolRequestSuccessScreen(),
    ),
    GoRoute(
      path: '/subscription-plans',
      builder: (context, state) => const SubscriptionPlansScreen(),
    ),
    GoRoute(
      path: '/permissions-dashboard',
      builder: (context, state) => const PermissionsDashboardScreen(),
    ),
    GoRoute(
      path: '/subscription-invoice',
      builder: (context, state) {
        final args = state.extra as SubscriptionInvoiceArgs;
        return SubscriptionInvoiceScreen(args: args);
      },
    ),
    GoRoute(
      path: '/privacy-policy',
      builder: (context, state) => const PrivacyPolicyScreen(),
    ),
    GoRoute(
      path: '/terms-of-use',
      builder: (context, state) => const TermsOfUseScreen(),
    ),
    GoRoute(
      path: '/notifications',
      builder: (context, state) => const NotificationsScreen(),
    ),
    GoRoute(
      path: '/system-announcement',
      builder: (context, state) {
        final args = state.extra as SystemAnnouncementDetailsArgs;
        return SystemAnnouncementDetailsScreen(args: args);
      },
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) =>
          const DashboardScreen(child: SizedBox.shrink()),
    ),
    GoRoute(
      path: '/safety-dashboard',
      builder: (context, state) => const SafetyDashboardScreen(),
    ),
    GoRoute(
      path: '/health-dashboard',
      builder: (context, state) => const SmartHealthDashboard(),
    ),
    GoRoute(
      path: '/health-cases',
      builder: (context, state) => const HealthCasesScreen(),
    ),
    GoRoute(
      path: '/counselor-dashboard',
      builder: (context, state) => const SmartCounselorDashboard(),
    ),
    GoRoute(
      path: '/attendance',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/behavior',
      builder: (context, state) => const SmartBehaviorDashboard(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
    GoRoute(
      path: '/about',
      builder: (context, state) => const AboutScreen(),
    ),
    GoRoute(
      path: '/school-location',
      builder: (context, state) => const SchoolLocationScreen(),
    ),
    GoRoute(
      path: '/seed-omar-school',
      builder: (context, state) => const SeedOmarSchoolScreen(),
    ),
    GoRoute(
      path: '/masarat-tracks',
      builder: (context, state) => const MasaratTracksScreen(),
    ),
    GoRoute(
      path: '/setup-wizard',
      builder: (context, state) {
        final schoolId = state.extra as String? ?? '';
        return SchoolSetupWizard(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/smart-admin-dashboard',
      builder: (context, state) => const SmartAdminDashboard(),
    ),
    GoRoute(
      path: '/admin-full-dashboard',
      builder: (context, state) => const AdminDashboardV2(),
    ),
    GoRoute(
      path: '/parent-pin-setup',
      builder: (context, state) => const ParentPinSetupScreen(),
    ),
    GoRoute(
      path: '/academic-calendar-manage',
      builder: (context, state) => const AcademicCalendarManageScreen(),
    ),

    // ==========================================
    // Academic Affairs Routes (Modules)
    // ==========================================
    // AcademicProgressModuleScreen:
    // 0: الجاهزية التعليمية والتخطيط التدريسي
    // 1: مستوى الالتزام بالخطة الدراسية
    // 2: مؤشرات تحسين الأداء التعليمي
    GoRoute(
      path: '/curriculum-progress',
      builder: (context, state) =>
          const AcademicProgressModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/lesson-prep',
      builder: (context, state) =>
          const AcademicProgressModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/plan-delay',
      builder: (context, state) =>
          const AcademicProgressModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/performance-alerts',
      builder: (context, state) =>
          const AcademicProgressModuleScreen(initialIndex: 2),
    ),

    GoRoute(
      path: '/create-schedule',
      builder: (context, state) => const TimetableModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/smart-schedule',
      builder: (context, state) {
        return const SmartScheduleScreen();
      },
    ),
    GoRoute(
      path: '/supervision-duty',
      builder: (context, state) {
        return const SupervisionDutyScreen();
      },
    ),
    GoRoute(
      path: '/morning-assembly',
      builder: (context, state) => const MorningAssemblyAttendanceScreen(),
    ),
    GoRoute(
      path: '/teacher-schedule-edit',
      builder: (context, state) {
        final teacherId = state.extra as String?;
        return TeacherScheduleEditScreen(teacherId: teacherId);
      },
    ),
    GoRoute(
      path: '/subject-assignment',
      builder: (context, state) {
        return const SubjectAssignmentScreen();
      },
    ),
    GoRoute(
      path: '/teacher-constraints',
      builder: (context, state) {
        return const TeacherConstraintsScreen();
      },
    ),
    GoRoute(
      path: '/assign-subjects',
      builder: (context, state) {
        return const AssignSubjectsScreen();
      },
    ),
    GoRoute(
      path: '/subjects-management',
      builder: (context, state) => const SubjectsManagementScreen(),
    ),
    GoRoute(
      path: '/schedule-import',
      builder: (context, state) => const ScheduleImportScreen(),
    ),
    GoRoute(
      path: '/schedule-management',
      builder: (context, state) {
        return const ScheduleManagementScreen();
      },
    ),
    GoRoute(
      path: '/collaborative-schedule',
      builder: (context, state) {
        final schoolId = state.uri.queryParameters['schoolId'] ?? '';
        final userId = state.uri.queryParameters['userId'] ?? '';
        return CreateCampaignScreen(schoolId: schoolId, userId: userId);
      },
    ),
    GoRoute(
      path: '/teacher-campaign-response',
      builder: (context, state) {
        final campaignId = state.uri.queryParameters['campaignId'] ?? '';
        final schoolId = state.uri.queryParameters['schoolId'] ?? '';
        return TeacherCampaignResponseScreen(
          campaignId: campaignId,
          schoolId: schoolId,
        );
      },
    ),
    GoRoute(
      path: '/resolve-conflicts',
      builder: (context, state) => const TimetableModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/teacher-load',
      builder: (context, state) {
        final schoolId = state.uri.queryParameters['schoolId'] ?? '';
        return WorkloadAnalysisScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/schedule-log',
      builder: (context, state) {
        final schoolId = state.uri.queryParameters['schoolId'] ?? '';
        return ModificationsLogScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/teacher-schedule-preferences/:runId',
      builder: (context, state) {
        final runId = state.pathParameters['runId']!;
        return TeacherSchedulePreferencesScreen(scheduleRunId: runId);
      },
    ),

    // ExamsModuleScreen: Tabs: (جدول اختبارات / إدارة لجان / رصد درجات / غياب اختبار)
    GoRoute(
      path: '/exam-schedule',
      builder: (context, state) => const ExamsModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/exam-committees',
      builder: (context, state) => const ExamsModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/grade-entry',
      builder: (context, state) => const ExamsModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/exam-absence',
      builder: (context, state) => const ExamsModuleScreen(initialIndex: 3),
    ),

    // AcademicAnalyticsModuleScreen: Tabs: (تحليل مادة / منخفضي التحصيل / مقارنة الفصول / توصيات)
    GoRoute(
      path: '/subject-analysis',
      builder: (context, state) =>
          const AcademicAnalyticsModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/low-achievers',
      builder: (context, state) =>
          const AcademicAnalyticsModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/class-comparison',
      builder: (context, state) =>
          const AcademicAnalyticsModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/improvement-recommendations',
      builder: (context, state) =>
          const AcademicAnalyticsModuleScreen(initialIndex: 3),
    ),

    // RemedialPlansModuleScreen: Tabs: (إنشاء خطة / ربط طالب-معلم / متابعة / قياس تحسن)
    GoRoute(
      path: '/create-remedial-plan',
      builder: (context, state) => const CreateRemedialPlanScreen(),
    ),
    GoRoute(
      path: '/link-student-teacher',
      builder: (context, state) => const LinkStudentTeacherScreen(),
    ),
    GoRoute(
      path: '/plan-followup',
      builder: (context, state) => const PlanFollowupScreen(),
    ),
    GoRoute(
      path: '/measure-improvement',
      builder: (context, state) => const MeasureImprovementScreen(),
    ),

    // AcademicReportsModuleScreen: Tabs: (نسب نجاح / فجوات / أداء معلم / تصدير PDF)
    GoRoute(
      path: '/school-health-index',
      builder: (context, state) =>
          const SchoolIntelligenceDashboard(titleOverride: 'مؤشر صحة المدرسة'),
    ),

    // ==========================================
    // School Affairs Routes (Modules)
    // ==========================================
    // SchoolAdminModuleScreen: Tabs: (صادر ووارد / أرشفة تعاميم / توقيعات / تصدير)
    GoRoute(
      path: '/mail-management',
      builder: (context, state) =>
          const SchoolAdminModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/circulars-archive',
      builder: (context, state) =>
          const SchoolAdminModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/signatures-log',
      builder: (context, state) =>
          const SchoolAdminModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/export-school-reports',
      builder: (context, state) =>
          const SchoolAdminModuleScreen(initialIndex: 3),
    ),

    // StaffAttendanceModuleScreen: Tabs: (حضور الموظفين)
    GoRoute(
      path: '/staff-attendance',
      builder: (context, state) =>
          const StaffAttendanceModuleScreen(initialIndex: 0),
    ),

    GoRoute(
      path: '/school-guide',
      builder: (context, state) => const SchoolGuideScreen(),
    ),

    // MaintenanceModuleScreen: Tabs: (تحديد أولوية / تتبع حالة / سجل أعطال / جاهزية / صيانة دورية)
    GoRoute(
      path: '/report-maintenance',
      builder: (context, state) => const ReportMaintenanceScreen(),
    ),
    GoRoute(
      path: '/maintenance-requests',
      builder: (context, state) => const MaintenanceRequestListScreen(),
    ),
    GoRoute(
      path: '/maintenance-priority',
      builder: (context, state) =>
          const MaintenanceModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/maintenance-status',
      builder: (context, state) =>
          const MaintenanceModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/fault-log',
      builder: (context, state) =>
          const MaintenanceModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/building-readiness',
      builder: (context, state) =>
          const MaintenanceModuleScreen(initialIndex: 3),
    ),
    GoRoute(
      path: '/periodic-maintenance',
      builder: (context, state) =>
          const MaintenanceModuleScreen(initialIndex: 4),
    ),

    // SafetyModuleScreen: Tabs: (خطة إخلاء / تجارب / طفايات / مخارج)
    GoRoute(
      path: '/evacuation-plan',
      builder: (context, state) => const SafetyModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/drills-log',
      builder: (context, state) => const SafetyModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/extinguishers-check',
      builder: (context, state) => const SafetyModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/emergency-exits',
      builder: (context, state) => const SafetyModuleScreen(initialIndex: 3),
    ),

    // ServicesModuleScreen: Tabs: (اشتراطات صحة / ملاحظات رقابية / مقصف إن وجد)
    GoRoute(
      path: '/health-rules',
      builder: (context, state) => const ServicesModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/observations-log',
      builder: (context, state) => const ServicesModuleScreen(initialIndex: 1),
    ),

    // InventoryModuleScreen: Tabs: (جرد إلكتروني / تلف/فقد / استلام وتسليم)
    GoRoute(
      path: '/electronic-inventory',
      builder: (context, state) => const InventoryModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/report-damage',
      builder: (context, state) => const InventoryModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/handover-log',
      builder: (context, state) => const InventoryModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/inventory-check',
      builder: (context, state) => const InventoryModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/material-request',
      builder: (context, state) => const InventoryModuleScreen(initialIndex: 3),
    ),

    // Monthly Safety -> Maintenance or Safety? Safety.
    GoRoute(
      path: '/monthly-safety',
      builder: (context, state) => const SafetyModuleScreen(
        initialIndex: 1,
      ), // Map to Drills for now or similar
    ),

    // ==========================================
    // Student Affairs Routes (Modules)
    // ==========================================
    // StudentDisciplineModuleScreen: Tabs: (حضور وغياب / تأخر / كثيري الغياب / تنبيه ولي أمر)
    GoRoute(
      path: '/tardiness',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 1),
    ),
    // Tardiness Classification -> Discipline Tab 1 (Tardiness) or new tab?
    // Prompt says "P1 (بعد P0) - تصنيف التأخر".
    // I will map it to Tardiness tab for now.
    GoRoute(
      path: '/tardiness-classification',
      builder: (context, state) => const StudentSupervisionModuleScreen(
        initialIndex: 2,
      ),
    ),
    GoRoute(
      path: '/frequent-absence',
      builder: (context, state) => const FrequentAbsenceScreen(),
    ),
    GoRoute(
      path: '/student-absence-details',
      builder: (context, state) {
        final student = state.extra as User;
        return StudentAbsenceDetailsScreen(student: student);
      },
    ),
    GoRoute(
      path: '/notify-parents',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 3),
    ),
    GoRoute(
      path: '/deputy-sms',
      builder: (context, state) => const DeputySmsScreen(),
    ),

    GoRoute(
      path: '/teacher-migration',
      builder: (context, state) => const TeacherMigrationScreen(),
    ),

    GoRoute(
      path: '/teacher-leave-request',
      builder: (context, state) => const TeacherLeaveRequestScreen(),
    ),

    GoRoute(
      path: '/broadcast',
      builder: (context, state) => const BroadcastScreen(),
    ),

    GoRoute(
      path: '/assign-broadcast-supervisor',
      builder: (context, state) => const AssignBroadcastSupervisorScreen(),
    ),

    GoRoute(
      path: '/deputy-leave-dashboard',
      builder: (context, state) => const DeputyLeaveDashboardScreen(),
    ),

    GoRoute(
      path: '/add-violation',
      builder: (context, state) => const AddViolationScreen(),
    ), // Keep existing
    // StudentBehaviorModuleScreen: Tabs: (لائحة سلوك / تصعيد / تعهدات / طباعة إشعار)
    GoRoute(
      path: '/behavior',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/behavior-rules',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/escalation',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/undertakings',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/print-notice',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 3),
    ),
    GoRoute(
      path: '/behavior-inbox',
      builder: (context, state) => const TeacherNotesInboxScreen(),
    ),

    // StudentCaseModuleScreen: Tabs: (ملف سلوكي / استدعاء ولي أمر / توثيق / تحويل مرشد / أرشيف)
    GoRoute(
      path: '/student-profile',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/call-parent',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/meeting-log',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/refer-counselor',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 3),
    ),
    GoRoute(
      path: '/archive',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 4),
    ),

    // StudentSupervisionModuleScreen: Tabs: (اصطفاف / فسحة / صلاة / انصراف / بلاغ فوري)
    GoRoute(
      path: '/assembly',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/recess',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/prayer',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/dismissal',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 3),
    ),
    GoRoute(
      path: '/immediate-report',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 4),
    ),

    // StudentReportsModuleScreen: Tabs: (سلوك / مواظبة / إحصائيات / تصدير)
    GoRoute(
      path: '/behavior-report',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 0),
    ),
    GoRoute(
      path: '/attendance-report',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 1),
    ),
    GoRoute(
      path: '/violation-stats',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 2),
    ),
    GoRoute(
      path: '/export-records',
      builder: (context, state) =>
          const StudentSupervisionModuleScreen(initialIndex: 3),
    ),

    // Counselor Routes
    GoRoute(
      path: '/deputy-requests',
      builder: (context, state) => const DeputyPermissionRequestsScreen(),
    ),
    GoRoute(
      path: '/distinguished-review',
      builder: (context, state) {
        final schoolId = state.extra as String;
        return DistinguishedReviewScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/counselor/sessions',
      builder: (context, state) => const CounselingSessionsScreen(),
    ),
    GoRoute(
      path: '/counselor/pledges',
      builder: (context, state) => const PledgesScreen(),
    ),
    GoRoute(
      path: '/counselor/plans',
      builder: (context, state) {
        // سيتم الحصول على schoolId من المستخدم الحالي تلقائياً
        return ActivePlansScreen();
      },
    ),
    GoRoute(
      path: '/plan-details/:id',
      builder: (context, state) {
        final planId = state.pathParameters['id'] ?? '';
        return PlanDetailsScreen(planId: planId);
      },
    ),
    GoRoute(
      path: '/plan-edit/:id',
      builder: (context, state) {
        final planId = state.pathParameters['id'] ?? '';
        return PlanEditScreen(planId: planId);
      },
    ),
    GoRoute(
      path: '/counselor/health-cases',
      builder: (context, state) => const HealthCasesScreen(),
    ),
    GoRoute(
      path: '/school-requests-list',
      builder: (context, state) => const SchoolRequestsListScreen(),
    ),
    GoRoute(
      path: '/add-school',
      builder: (context, state) => const AddSchoolScreen(),
    ),
    GoRoute(
      path: '/announcements',
      builder: (context, state) => const AnnouncementsScreen(),
    ),
    GoRoute(
      path: '/send-announcement',
      builder: (context, state) => const SendAnnouncementScreen(),
    ),
    GoRoute(
      path: '/circulars/inbox',
      builder: (context, state) => const CircularsInboxScreen(),
    ),
    GoRoute(
      path: '/circulars',
      builder: (context, state) => const CircularsManagementScreen(),
    ),
    GoRoute(
      path: '/circulars/create',
      builder: (context, state) => const CreateCircularScreen(),
    ),
    GoRoute(
      path: '/circulars/view',
      builder: (context, state) {
        final id = state.uri.queryParameters['id'] ?? '';
        final adminView = (state.uri.queryParameters['admin'] ?? '') == '1';
        if (id.trim().isEmpty) {
          return const CircularsInboxScreen();
        }
        return CircularViewerScreen(
          circularId: id.trim(),
          adminView: adminView,
        );
      },
    ),
    GoRoute(
      path: '/circulars/details',
      builder: (context, state) {
        final circular = state.extra as Circular;
        return CircularDetailsScreen(circular: circular);
      },
    ),
    GoRoute(
      path: '/add-teacher',
      builder: (context, state) {
        final teacherToEdit = state.extra as User?;
        return AddTeacherScreen(teacherToEdit: teacherToEdit);
      },
    ),
    GoRoute(
      path: '/core-rules',
      builder: (context, state) => const CoreRulesScreen(),
    ),
    GoRoute(
      path: '/add-class',
      builder: (context, state) {
        final classToEdit = state.extra as Classroom?;
        return AddClassScreen(classToEdit: classToEdit);
      },
    ),
    GoRoute(
      path: '/add-counselor',
      builder: (context, state) {
        final staffToEdit = state.extra as User?;
        return AddStaffScreen(
          role: UserRole.counselor,
          title: 'مرشد طلابي',
          staffToEdit: staffToEdit,
        );
      },
    ),
    GoRoute(
      path: '/add-admin-staff',
      builder: (context, state) {
        final staffToEdit = state.extra as User?;
        return AddStaffScreen(
          role: UserRole.administrative,
          title: 'موظف إداري',
          staffToEdit: staffToEdit,
        );
      },
    ),
    GoRoute(
      path: '/add-deputy',
      builder: (context, state) {
        final staffToEdit = state.extra as User?;
        return AddStaffScreen(
          role: UserRole.deputy,
          title: 'وكيل مدرسة',
          staffToEdit: staffToEdit,
        );
      },
    ),
    GoRoute(
      path: '/teachers-list',
      builder: (context, state) => const TeachersListScreen(),
    ),
    GoRoute(
      path: '/staff-list',
      builder: (context, state) => const StaffListScreen(),
    ),
    GoRoute(
      path: '/teacher-details',
      builder: (context, state) {
        final teacher = state.extra as User;
        return TeacherDetailScreen(teacher: teacher);
      },
    ),
    GoRoute(
      path: '/students-list',
      builder: (context, state) => StudentsListScreen(
        initialSearchQuery: state.uri.queryParameters['q'],
      ),
    ),
    GoRoute(
      path: '/student-barcodes',
      builder: (context, state) => const StudentLabelsScreen(),
    ),
    GoRoute(
      path: '/student-scan',
      builder: (context, state) => const StudentScanScreen(),
    ),
    GoRoute(
      path: '/current-schedule',
      builder: (context, state) => const CurrentScheduleScreen(),
    ),
    GoRoute(
      path: '/classes-list',
      builder: (context, state) => const ClassesListScreen(),
    ),
    GoRoute(
      path: '/class/:id',
      builder: (context, state) {
        final id = state.pathParameters['id']!;
        return ClassDetailsScreen(classId: id);
      },
    ),
    GoRoute(
      path: '/reports',
      builder: (context, state) => const ReportsScreen(),
    ),
    GoRoute(
      path: '/counselor/case-details',
      builder: (context, state) {
        final caseId = state.uri.queryParameters['caseId'];
        return CaseDetailsScreen(caseId: caseId);
      },
    ),
    GoRoute(
      path: '/teacher/alerts',
      builder: (context, state) => const TeacherAlertsCenterScreen(),
    ),
    GoRoute(
      path: '/classroom-behavior-indicators',
      builder: (context, state) => const ClassroomBehaviorIndicatorsScreen(),
    ),
    GoRoute(
      path: '/assignments',
      builder: (context, state) => const AssignmentsListScreen(),
    ),
    GoRoute(
      path: '/tests',
      builder: (context, state) => const TestsListScreen(),
    ),
    GoRoute(
      path: '/wait-management',
      builder: (context, state) {
        // Get schoolId from extra or from auth
        final extra = state.extra as Map<String, dynamic>?;
        final schoolId = extra?['schoolId'] as String?;
        return WaitManagementScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/teacher-schedule',
      builder: (context, state) {
        final teacherId = state.uri.queryParameters['teacherId'];
        return TeacherScheduleScreen(teacherId: teacherId);
      },
    ),
    GoRoute(
      path: '/teacher-schedule-summary',
      builder: (context, state) {
        final teacherId = state.uri.queryParameters['teacherId'] ?? '';
        final schoolId = state.uri.queryParameters['schoolId'] ?? '';
        return TeacherScheduleWithSummaryScreen(
          teacherId: teacherId,
          schoolId: schoolId,
        );
      },
    ),
    GoRoute(
      path: '/student-schedule',
      builder: (context, state) {
        final classId = state.uri.queryParameters['classId'];
        return StudentScheduleScreen(classId: classId);
      },
    ),
    GoRoute(
      path: '/deputy-violations',
      builder: (context, state) => const ViolationsListScreen(),
    ),
    GoRoute(
      path: '/attendance-days',
      builder: (context, state) => const AttendanceDaysScreen(),
    ),
    GoRoute(
      path: '/attendance-periods',
      builder: (context, state) {
        final day = state.extra as String;
        return AttendancePeriodsScreen(day: day);
      },
    ),
    GoRoute(
      path: '/teacher-attendance',
      builder: (context, state) => const TeacherAttendanceScreen(),
    ),
    GoRoute(
      path: '/period-attendance',
      builder: (context, state) => const PeriodAttendanceScreen(),
    ),
    GoRoute(
      path: '/behavioral-violations',
      builder: (context, state) => const BehavioralViolationsScreen(),
    ),
    GoRoute(
      path: '/violations-log',
      builder: (context, state) => const ViolationsLogScreen(),
    ),
    GoRoute(
      path: '/teacher-drafts',
      builder: (context, state) => const TeacherDraftsScreen(),
    ),
    GoRoute(
      path: '/global-accounts',
      builder: (context, state) => const GlobalAccountsScreen(),
    ),
    GoRoute(
      path: '/change-password',
      builder: (context, state) => const ChangePasswordScreen(),
    ),
    GoRoute(
      path: '/counselor/students-by-behavior/:type',
      builder: (context, state) {
        final typeStr = state.pathParameters['type']!;
        final type = BehaviorType.values.firstWhere(
          (e) => e.name == typeStr,
          orElse: () => BehaviorType.positive,
        );
        return StudentsByBehaviorScreen(behaviorType: type);
      },
    ),
    GoRoute(
      path: '/intelligence-dashboard',
      builder: (context, state) => const SchoolIntelligenceDashboard(),
    ),
    GoRoute(
      path: '/teacher-intelligence-dashboard',
      builder: (context, state) => const TeacherIntelligenceDashboard(),
    ),
    GoRoute(
      path: '/behavior-enhancement',
      builder: (context, state) => const BehaviorEnhancementDashboardScreen(),
    ),

    // New Behavior Management Routes
    GoRoute(
      path: '/behavior-dashboard',
      builder: (context, state) => const BehaviorDashboardScreen(),
    ),
    GoRoute(
      path: '/behavior-analysis',
      builder: (context, state) => const BehaviorAnalysisScreen(),
    ),
    GoRoute(
      path: '/behavior-reports',
      builder: (context, state) => const BehaviorReportsScreen(),
    ),
    GoRoute(
      path: '/students-by-behavior',
      builder: (context, state) => const StudentsListByBehaviorScreen(),
    ),
    GoRoute(
      path: '/behavioral-cases',
      builder: (context, state) => const BehavioralCasesScreen(),
    ),
    GoRoute(
      path: '/add-violation-quick',
      builder: (context, state) => const AddViolationQuickScreen(),
    ),

    // Dev Progress
    GoRoute(
      path: '/dev-progress',
      builder: (context, state) => const DevProgressScreen(),
    ),

    // Staff Assignments
    GoRoute(
      path: '/staff-assignments',
      builder: (context, state) {
        final schoolId = state.extra as String;
        return StaffAssignmentsListScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/create-staff-assignment',
      builder: (context, state) {
        final schoolId = state.extra as String;
        return CreateStaffAssignmentScreen(schoolId: schoolId);
      },
    ),
    // Simple Schedule System
    GoRoute(
      path: '/simple-schedule',
      builder: (context, state) {
        final schoolId = state.extra as String;
        return SimpleScheduleScreen(schoolId: schoolId);
      },
    ),
    GoRoute(
      path: '/my-schedule',
      builder: (context, state) {
        final params = state.extra as Map<String, String>;
        return MyScheduleScreen(
          userId: params['userId']!,
          userType: params['userType']!,
          schoolId: params['schoolId']!,
        );
      },
    ),
    GoRoute(
      path: '/student-exit-permission',
      builder: (context, state) => const StudentExitPermissionScreen(),
    ),
  ],
);
