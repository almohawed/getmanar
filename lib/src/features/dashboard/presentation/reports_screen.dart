import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../common/services/pdf_export_service.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../academic/presentation/students_provider.dart';
import '../../academic/data/school_repository.dart';
import '../../reports/presentation/pdf_reports_generator.dart';
import '../../counselor/presentation/counselor_providers.dart';
import '../../attendance/domain/student_attendance.dart';
import '../../attendance/data/student_attendance_repository.dart';
import '../../exams/data/firestore_exams_repository.dart';
import '../../violations/data/firestore_violations_repository.dart';
import '../../academic/data/student_repository.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  // Define Report Categories and Items
  final Map<String, List<Map<String, String>>> _teacherReportCategories = {
    '1️⃣ كشوفات الطلاب': [
      {'id': 'student_names', 'title': 'كشف أسماء الطلاب في الشعبة'},
      {'id': 'daily_attendance', 'title': 'كشف الحضور والغياب اليومي'},
      {'id': 'behavior_log', 'title': 'كشف السلوك والملاحظات التربوية'},
      {'id': 'student_followup', 'title': 'سجل متابعة الطلاب (سلوك وواجبات)'},
      {'id': 'academic_delay', 'title': 'كشف الطلاب المتأخرين دراسياً'},
    ],
    '2️⃣ كشوفات التقويم والدرجات': [
      {'id': 'quarterly_grades', 'title': 'كشف درجات الأعمال الفصلية'},
      {'id': 'monthly_tests', 'title': 'كشف درجات الاختبارات الشهرية'},
      {'id': 'midterm_grades', 'title': 'كشف درجات منتصف الفصل'},
      {'id': 'final_grades', 'title': 'كشف درجات نهاية الفصل'},
      {'id': 'final_record', 'title': 'كشف الرصد النهائي'},
      {'id': 'struggling_students', 'title': 'كشف الطلاب المتعثرين دراسياً'},
    ],
    '3️⃣ كشوفات التخطيط والمتابعة': [
      {'id': 'preparation_log', 'title': 'كشف التحضير اليومي / الأسبوعي'},
      {'id': 'curriculum_log', 'title': 'خطة توزيع المنهج'},
      {'id': 'lesson_execution', 'title': 'كشف تنفيذ الدروس'},
      {'id': 'class_activities', 'title': 'كشف الأنشطة الصفية'},
      {'id': 'extracurricular', 'title': 'كشف الأنشطة اللاصفية'},
      {'id': 'waiting_classes', 'title': 'كشف حصص الانتظار'},
    ],
    '4️⃣ كشوفات التواصل والإرشاد': [
      {'id': 'parent_communication', 'title': 'كشف التواصل مع أولياء الأمور'},
      {'id': 'parent_meetings', 'title': 'كشف الاجتماعات مع ولي الأمر'},
      {'id': 'special_cases', 'title': 'كشف الحالات الخاصة'},
    ],
  };

  final Map<String, List<Map<String, String>>> _deputyReportCategories = {
    '1️⃣ كشوفات المعلمين (الضرورية)': [
      {'id': 'teacher_attendance_log', 'title': 'كشف حضور وانصراف المعلمين'},
      {'id': 'schedule_log', 'title': 'كشف جدول الحصص'},
      {'id': 'deputy_waiting_classes_log', 'title': 'كشف حصص الانتظار'},
    ],
    '2️⃣ كشوفات الطلاب (إشراف عام)': [
      {
        'id': 'general_daily_absence',
        'title': 'كشف الغياب اليومي العام للطلاب',
      },
      {'id': 'morning_lateness', 'title': 'كشف الطلاب المتأخرين صباحًا'},
      {'id': 'behavioral_violations', 'title': 'كشف المخالفات السلوكية'},
    ],
    '3️⃣ كشوفات التنظيم المدرسي': [
      {'id': 'daily_supervision', 'title': 'كشف الإشراف اليومي'},
      {'id': 'morning_assembly', 'title': 'كشف الطابور الصباحي'},
    ],
    '4️⃣ كشوفات الاختبارات (الأساسية)': [
      {'id': 'exam_committees', 'title': 'كشف لجان الاختبارات'},
      {'id': 'exam_absence', 'title': 'كشف الغياب في الاختبارات'},
    ],
    '5️⃣ كشوفات التواصل والإدارة': [
      {'id': 'administrative_meetings', 'title': 'كشف الاجتماعات الإدارية'},
      {'id': 'complaints_log', 'title': 'كشف الشكاوى والملاحظات'},
    ],
  };

  final Map<String, List<Map<String, String>>> _counselorReportCategories = {
    '1️⃣ تقارير المرشد': [
      {'id': 'counselor_active_cases', 'title': 'كشف الحالات النشطة'},
      {'id': 'counselor_sessions', 'title': 'كشف جلسات اليوم'},
      {'id': 'counselor_plans', 'title': 'كشف الخطط السلوكية النشطة'},
    ],
  };

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final isDeputy =
        user?.role == UserRole.deputy ||
        user?.role == UserRole.admin ||
        user?.role == UserRole.technicalSupport;
    final isCounselor = user?.role == UserRole.counselor;
    final reportCategories = isDeputy
        ? _deputyReportCategories
        : (isCounselor ? _counselorReportCategories : _teacherReportCategories);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF388E3C)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isDeputy ? 'كشوفات الوكيل' : 'التقارير والكشوفات',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp),
            ),
            Text(
              'طباعة وتصدير PDF',
              style: TextStyle(color: Colors.white70, fontSize: 11.sp),
            ),
          ],
        ),
        centerTitle: false,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: EdgeInsets.all(16.w),
        children: [
          // بطاقة إحصائية في الأعلى
          Container(
            margin: EdgeInsets.only(bottom: 20.h),
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF1B5E20), Color(0xFF388E3C)],
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
              ),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [BoxShadow(color: const Color(0xFF1B5E20).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(12.r)),
                  child: Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 28.sp),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${reportCategories.values.fold(0, (sum, list) => sum + list.length)} تقرير متاح',
                          style: TextStyle(color: Colors.white, fontSize: 18.sp, fontWeight: FontWeight.bold)),
                      Text('اختر التقرير المطلوب وصدّره بصيغة PDF',
                          style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ...reportCategories.entries.map((category) {
            return _buildCategoryCard(category.key, category.value);
          }),
        ],
      ),
    );
  }

  Widget _buildCategoryCard(String categoryTitle, List<Map<String, String>> reports) {
    // لون مختلف لكل فئة
    final colors = [
      const Color(0xFF1565C0),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFFE65100),
      const Color(0xFF880E4F),
    ];
    final idx = categoryTitle.codeUnitAt(0) % colors.length;
    final color = colors[idx];

    return Container(
      margin: EdgeInsets.only(bottom: 14.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: color.withOpacity(0.15)),
        boxShadow: [BoxShadow(color: color.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
          leading: Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10.r)),
            child: Icon(Icons.folder_special_rounded, color: Colors.white, size: 18.sp),
          ),
          title: Text(
            categoryTitle,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.sp, color: color),
          ),
          subtitle: Text('${reports.length} تقرير', style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade500)),
          children: [
            ...reports.map((report) {
              return InkWell(
                onTap: () => _handleReportSelection(report['id']!, report['title']!),
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
                  padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(color: color.withOpacity(0.1)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(6.w),
                        decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8.r)),
                        child: Icon(Icons.picture_as_pdf_rounded, color: Colors.red.shade700, size: 16.sp),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Text(report['title']!, style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                      ),
                      Icon(Icons.download_rounded, size: 16.sp, color: color.withOpacity(0.6)),
                    ],
                  ),
                ),
              );
            }),
            SizedBox(height: 8.h),
          ],
        ),
      ),
    );
  }

  void _handleReportSelection(String reportId, String title) {
    // Determine if the report requires Class Selection (Student-based)
    final bool requiresClass = [
      'student_names',
      'daily_attendance',
      'behavior_log',
      'student_followup',
      'academic_delay',
      'quarterly_grades',
      'monthly_tests',
      'midterm_grades',
      'final_grades',
      'final_record',
      'struggling_students',
    ].contains(reportId);

    if (requiresClass) {
      _showClassSelectionDialog(reportId, title);
    } else {
      _showExportOptionsDialog(reportId, title, null);
    }
  }

  Future<void> _showClassSelectionDialog(String reportId, String title) async {
    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final allClasses = await ref.read(classesProvider.future);
      final user = ref.read(authStateProvider).value;

      if (!mounted) return;
      Navigator.pop(context); // Remove loading

      // Filter classes
      var displayClasses = allClasses;
      if (user != null && user.role == UserRole.teacher) {
        final assignedIds = user.assignedClassIds ?? [];
        displayClasses = allClasses
            .where((c) => assignedIds.contains(c.id))
            .toList();
      }

      if (displayClasses.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('لا توجد فصول مسندة لهذا المعلم')),
          );
        }
        return;
      }

      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('اختيار الفصل'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: displayClasses.length,
                itemBuilder: (context, index) {
                  final c = displayClasses[index];
                  return ListTile(
                    title: Text(c.name),
                    onTap: () {
                      Navigator.pop(context);
                      _showExportOptionsDialog(reportId, title, c.name);
                    },
                  );
                },
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Remove loading
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ في تحميل الفصول: $e')));
      }
    }
  }

  void _showExportOptionsDialog(
    String reportId,
    String title,
    String? className,
  ) {
    const reportsWithDateSelection = {
      'general_daily_absence',
      'morning_lateness',
      'exam_absence',
      'daily_attendance',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: const Text('اختر نوع القالب:'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _generateReport(reportId, className, false);
            },
            child: const Text('قالب فارغ (PDF)'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              DateTime? selectedDate;
              if (reportsWithDateSelection.contains(reportId)) {
                final now = DateTime.now();
                selectedDate = await showDatePicker(
                  context: context,
                  initialDate: now,
                  firstDate: DateTime(now.year - 1, 1, 1),
                  lastDate: DateTime(now.year + 1, 12, 31),
                );
                if (selectedDate == null) {
                  return;
                }
              }
              _generateReport(
                reportId,
                className,
                true,
                selectedDate: selectedDate,
              );
            },
            child: const Text('سجل مرصود (PDF)'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateReport(
    String reportId,
    String? className,
    bool filled, {
    DateTime? selectedDate,
  }) async {
    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final user = ref.read(authStateProvider).value;

      // Fetch school name and settings
      String schoolName = '';
      String schoolStartTime = '06:30';
      if (user?.schoolId != null) {
        try {
          final school = await ref
              .read(schoolRepositoryProvider)
              .getSchool(user!.schoolId!);
          if (school != null) {
            schoolName = school.name;
            schoolStartTime = school.startTime;
          }
        } catch (_) {}
      }

      final isDeputy =
          user?.role == UserRole.deputy ||
          user?.role == UserRole.admin ||
          user?.role == UserRole.technicalSupport;

      String signerTitle = 'المعلم';
      bool managerOnlyFooter = false;
      if (user != null) {
        switch (user.role) {
          case UserRole.deputy:
            if (user.deputyType == 'student') {
              signerTitle = 'وكيل شؤون الطلاب';
            } else if (user.deputyType == 'academic') {
              signerTitle = 'وكيل الشؤون التعليمية';
            } else if (user.deputyType == 'school') {
              signerTitle = 'وكيل المدرسة';
            } else {
              signerTitle = 'الوكيل';
            }
            break;
          case UserRole.counselor:
            signerTitle = 'المرشد الطلابي';
            break;
          case UserRole.admin:
            signerTitle = '';
            managerOnlyFooter = true;
            break;
          case UserRole.teacher:
            signerTitle = 'المعلم';
            break;
          default:
            signerTitle = 'الموظف';
        }
      }

      final service = PdfExportService(
        teacherName: user?.name ?? '________________',
        schoolName: schoolName,
        principalName: user?.role == UserRole.admin
            ? (user?.name ?? '')
            : '________________',
        defaultShowClassInfo: !isDeputy,
        signerTitle: signerTitle,
        managerOnlyFooter: managerOnlyFooter,
      );

      // Get students filtered by class if className is provided
      List<User> students = [];
      if (className != null) {
        final classes = await ref.read(classesProvider.future);
        try {
          final targetClass = classes.firstWhere((c) => c.name == className);
          final allStudents = await ref.read(studentsProvider.future);
          students = allStudents
              .where((s) => targetClass.studentIds.contains(s.id))
              .toList();
        } catch (_) {
          // Handle case where class is not found
        }
      }

      switch (reportId) {
        // 1. Student Reports
        case 'student_names':
          await service.printStudentNamesLog(students, className!);
          break;
        case 'daily_attendance':
          List<StudentAttendance>? attendanceRecords;
          if (filled && className != null && user?.schoolId != null) {
            final classes = await ref.read(classesProvider.future);
            try {
              final targetClass = classes.firstWhere(
                (c) => c.name == className,
              );
              final attendanceRepo = ref.read(
                studentAttendanceRepositoryProvider,
              );
              final targetDate = selectedDate ?? DateTime.now();
              attendanceRecords = await attendanceRepo.getStudentAttendance(
                targetClass.id,
                targetDate,
              );
            } catch (_) {}
          }
          await service.printDailyAttendanceLog(
            students,
            className!,
            attendanceRecords: attendanceRecords,
          );
          break;
        case 'behavior_log':
          List<BehaviorRecord>? records;
          if (filled) {
            final repo = ref.read(behaviorRepositoryProvider);
            records = await repo.getClassBehavior(className ?? '');
          }
          await service.printBehaviorLog(
            students,
            className!,
            filled: filled,
            records: records,
          );
          break;
        case 'student_followup':
          List<BehaviorRecord> followupRecords = const [];
          Map<String, int> absenceDays = {};
          Map<String, int> tardinessCount = {};
          Map<String, int> excellenceScores = {};
          if (filled && user?.schoolId != null) {
            final repo = ref.read(behaviorRepositoryProvider);
            followupRecords = await repo.getClassBehavior(className ?? '');
            final attendanceRepo = ref.read(
              studentAttendanceRepositoryProvider,
            );
            final schoolId = user!.schoolId!;
            final futures = students.map((s) {
              return attendanceRepo.getStudentAttendanceHistory(s.id, schoolId);
            }).toList();
            final histories = await Future.wait(futures);
            for (var i = 0; i < students.length; i++) {
              final student = students[i];
              final history = histories[i];
              final abs = history
                  .where((a) => a.status == StudentAttendanceStatus.absent)
                  .length;
              final late = history
                  .where((a) => a.status == StudentAttendanceStatus.late)
                  .length;
              absenceDays[student.id] = abs;
              tardinessCount[student.id] = late;
              excellenceScores[student.id] = student.excellenceScore;
            }
          }
          await service.printStudentFollowupLog(
            students,
            className!,
            records: followupRecords,
            filled: filled,
            absenceDays: absenceDays.isEmpty ? null : absenceDays,
            tardinessCount: tardinessCount.isEmpty ? null : tardinessCount,
            excellenceScores: excellenceScores.isEmpty
                ? null
                : excellenceScores,
          );
          break;
        case 'academic_delay':
          await service.printAcademicDelayLog(students, className!);
          break;

        // 2. Evaluation
        case 'quarterly_grades':
          await service.printQuarterlyGradesLog(students, className!);
          break;
        case 'monthly_tests':
          Map<String, double>? month1Scores;
          Map<String, double>? month2Scores;
          if (filled && className != null && user?.schoolId != null) {
            final classes = await ref.read(classesProvider.future);
            try {
              final targetClass = classes.firstWhere(
                (c) => c.name == className,
              );
              final examsRepo = ref.read(examsRepositoryProvider);
              final List<ExamGradesTrack> tracks = await examsRepo
                  .getClassTracks(user!.schoolId!, targetClass.id, user.id);
              if (tracks.isNotEmpty) {
                final byTerm = <String, List<ExamGradesTrack>>{};
                for (final t in tracks) {
                  byTerm.putIfAbsent(t.termId, () => []).add(t);
                }
                final sortedTerms = byTerm.entries.toList()
                  ..sort(
                    (a, b) =>
                        b.value.first.dueDate.compareTo(a.value.first.dueDate),
                  );
                final activeTermTracks = sortedTerms.first.value
                  ..sort(
                    (ExamGradesTrack a, ExamGradesTrack b) =>
                        a.dueDate.compareTo(b.dueDate),
                  );
                final firstTrack = activeTermTracks.isNotEmpty
                    ? activeTermTracks.first
                    : null;
                final secondTrack = activeTermTracks.length > 1
                    ? activeTermTracks[1]
                    : null;
                if (firstTrack != null) {
                  month1Scores = await examsRepo.getTrackScores(
                    user.schoolId!,
                    firstTrack.id,
                  );
                }
                if (secondTrack != null) {
                  month2Scores = await examsRepo.getTrackScores(
                    user.schoolId!,
                    secondTrack.id,
                  );
                }
              }
            } catch (_) {}
          }
          await service.printMonthlyTestsLog(
            students,
            className!,
            month1Scores: month1Scores,
            month2Scores: month2Scores,
          );
          break;
        case 'midterm_grades':
          await service.printMidtermGradesLog(students, className!);
          break;
        case 'final_grades':
          await service.printFinalGradesLog(students, className!);
          break;
        case 'final_record':
          await service.printFinalRecordLog(students, className!);
          break;
        case 'struggling_students':
          await service.printStrugglingStudentsLog(students, className!);
          break;

        // 3. Planning
        case 'preparation_log':
          await service.printPreparationLog();
          break;
        case 'curriculum_log':
          await service.printCurriculumDistributionLog();
          break;
        case 'lesson_execution':
          await service.printLessonExecutionLog();
          break;
        case 'class_activities':
          await service.printClassActivitiesLog();
          break;
        case 'extracurricular':
          await service.printExtracurricularActivitiesLog();
          break;
        case 'waiting_classes':
          await service.printWaitingClassesLog();
          break;

        // 4. Communication
        case 'parent_communication':
          await service.printParentCommunicationLog();
          break;
        case 'parent_meetings':
          await service.printParentMeetingsLog();
          break;
        case 'special_cases':
          await service.printSpecialCasesLog();
          break;

        // 5. Deputy Reports
        case 'teacher_attendance_log':
          await service.printTeacherAttendanceDepartureLog();
          break;
        case 'schedule_log':
          await service.printScheduleLog();
          break;
        case 'deputy_waiting_classes_log':
          await service.printWaitingClassesLog();
          break;
        case 'general_daily_absence':
          if (filled && user?.schoolId != null) {
            final attendanceRepo = ref.read(
              studentAttendanceRepositoryProvider,
            );
            final targetDate = selectedDate ?? DateTime.now();
            final records = await attendanceRepo
                .watchDailyAttendance(user!.schoolId!, targetDate)
                .first;
            final classes = await ref.read(classesProvider.future);
            final classNames = <String, String>{
              for (final c in classes) c.id: c.name,
            };
            await service.printGeneralDailyAbsenceLog(
              attendanceRecords: records,
              classNames: classNames,
            );
          } else {
            await service.printGeneralDailyAbsenceLog();
          }
          break;
        case 'morning_lateness':
          if (filled && user?.schoolId != null) {
            final attendanceRepo = ref.read(
              studentAttendanceRepositoryProvider,
            );
            final targetDate = selectedDate ?? DateTime.now();
            final records = await attendanceRepo
                .watchDailyAttendance(user!.schoolId!, targetDate)
                .first;
            final classes = await ref.read(classesProvider.future);
            final classNames = <String, String>{
              for (final c in classes) c.id: c.name,
            };
            await service.printMorningLatenessLog(
              records: records,
              classNames: classNames,
              schoolStartTime: schoolStartTime,
            );
          } else {
            await service.printMorningLatenessLog();
          }
          break;
        case 'behavioral_violations':
          if (filled && user?.schoolId != null) {
            final repo = ref.read(violationsRepositoryProvider);
            final violations = await repo.getViolationsBySchool(
              user!.schoolId!,
            );
            await service.printBehavioralViolationsLog(violations: violations);
          } else {
            await service.printBehavioralViolationsLog();
          }
          break;
        case 'daily_supervision':
          await service.printDailySupervisionLog();
          break;
        case 'morning_assembly':
          await service.printMorningAssemblyLog();
          break;
        case 'exam_committees':
          if (filled && user?.schoolId != null) {
            final examsRepo = ref.read(examsRepositoryProvider);
            final committees = await examsRepo
                .watchCommittees(user!.schoolId!)
                .first;
            final rows = committees.asMap().entries.map((e) {
              final index = e.key + 1;
              final c = e.value;
              final committeeName = 'لجنة ${c.roomId}';
              final room = c.roomId;
              final supervisor = c.supervisorId;
              final backup = c.backupSupervisorId ?? '';
              final classes = c.assignedClassIds.join(', ');
              return [
                index.toString(),
                committeeName,
                room,
                supervisor,
                backup,
                classes,
              ];
            }).toList();
            await service.printExamCommitteesLog(rows: rows);
          } else {
            await service.printExamCommitteesLog();
          }
          break;
        case 'exam_absence':
          if (filled && user?.schoolId != null) {
            final examsRepo = ref.read(examsRepositoryProvider);
            final studentRepo = ref.read(studentRepositoryProvider);
            final schoolId = user!.schoolId!;
            final targetDate = selectedDate ?? DateTime.now();
            final records = await examsRepo
                .watchExamAttendance(schoolId, date: targetDate)
                .first;
            final byStudent = <String, User>{};
            final uniqueStudentIds = records
                .map((r) => r.studentId)
                .where((id) => id.isNotEmpty)
                .toSet()
                .toList();
            for (final sid in uniqueStudentIds) {
              try {
                final s = await studentRepo.getStudentById(schoolId, sid);
                if (s != null) {
                  byStudent[sid] = s;
                }
              } catch (_) {}
            }
            final classes = await ref.read(classesProvider.future);
            final classNames = <String, String>{
              for (final c in classes) c.id: c.name,
            };
            final rows = records.asMap().entries.map((e) {
              final index = e.key + 1;
              final r = e.value;
              final student = byStudent[r.studentId];
              final studentName = student?.name ?? r.studentId;
              final classLabel = classNames[r.classId] ?? '';
              final subject = r.subjectId;
              final dateLabel = intl.DateFormat(
                'yyyy-MM-dd',
              ).format(r.recordedAt);
              final reason = r.status.contains('excused')
                  ? 'غائب بعذر'
                  : 'غائب بدون عذر';
              return [
                index.toString(),
                studentName,
                classLabel,
                subject,
                dateLabel,
                reason,
              ];
            }).toList();
            await service.printExamAbsenceLog(rows: rows);
          } else {
            await service.printExamAbsenceLog();
          }
          break;
        case 'administrative_meetings':
          await service.printAdministrativeMeetingsLog();
          break;
        case 'complaints_log':
          await service.printComplaintsLog();
          break;

        case 'counselor_active_cases':
          final cases = await ref.read(activeCasesProvider.future);
          final bytes = await PdfReportsGenerator.generateCounselorActiveCases(
            schoolName: schoolName,
            cases: cases,
          );
          await Printing.layoutPdf(
            onLayout: (format) async => bytes,
            name: 'counselor_active_cases.pdf',
          );
          break;
        case 'counselor_sessions':
          final sessions = await ref.read(todaySessionsProvider.future);
          final bytes =
              await PdfReportsGenerator.generateCounselorTodaySessions(
                schoolName: schoolName,
                sessions: sessions,
              );
          await Printing.layoutPdf(
            onLayout: (format) async => bytes,
            name: 'counselor_sessions.pdf',
          );
          break;
        case 'counselor_plans':
          final plans = await ref.read(activePlansProvider.future);
          final bytes = await PdfReportsGenerator.generateCounselorActivePlans(
            schoolName: schoolName,
            plans: plans,
          );
          await Printing.layoutPdf(
            onLayout: (format) async => bytes,
            name: 'counselor_plans.pdf',
          );
          break;
      }
      
      // Success message
      if (mounted && Navigator.canPop(context)) {
        Navigator.pop(context); // Close loading
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('✅ تم تصدير التقرير بنجاح')),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      print('❌ خطأ في التصدير: $e');
      if (mounted) {
        if (Navigator.canPop(context)) {
          Navigator.pop(context); // Close loading
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'فشل التصدير: ${e.toString()}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
            action: SnackBarAction(
              label: 'تفاصيل',
              textColor: Colors.white,
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: Text('تفاصيل الخطأ'),
                    content: SingleChildScrollView(
                      child: Text(e.toString()),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text('حسناً'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      }
    }
  }
}
