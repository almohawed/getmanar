import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../behavior/domain/bathroom_pass.dart';
import '../../../core/domain/models/user.dart';
import '../../behavior/presentation/behavior_controller.dart';
import '../../auth/presentation/auth_controller.dart';
import 'behavior_sheet.dart';
import 'students_provider.dart';
import 'students_list_screen.dart';
import '../../admin/data/mock_class_repository.dart';
import '../../academic/domain/classroom.dart';
import '../../common/services/pdf_export_service.dart';
import '../../attendance/presentation/student_attendance_sheet.dart';

class ClassDetailsScreen extends ConsumerWidget {
  final String classId;

  const ClassDetailsScreen({super.key, required this.classId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classesAsync = ref.watch(classesProvider);
    final studentsAsync = ref.watch(studentsProvider);

    return classesAsync.when(
      loading: () =>
          const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, s) => Scaffold(body: Center(child: Text('حدث خطأ: $e'))),
      data: (classes) {
        Classroom? classroom;
        for (final c in classes) {
          if (c.id == classId) {
            classroom = c;
            break;
          }
        }
        if (classroom == null) {
          return const Scaffold(
            body: Center(child: Text('لم يتم العثور على الفصل')),
          );
        }
        final cls = classroom;

        return studentsAsync.when(
          loading: () =>
              const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, s) => Scaffold(body: Center(child: Text('حدث خطأ: $e'))),
          data: (allStudents) {
            final classStudentIds = cls.studentIds.toSet();
            final students = allStudents.where((s) {
              final assigned = s.assignedClassIds ?? const <String>[];
              return classStudentIds.contains(s.id) || assigned.contains(cls.id);
            }).toList();

            final studentIds = students.map((s) => s.id).toList();
            // نجلب trips بشكل منفصل ولا نعلق عرض الطلاب عليها
            final activeTripsAsync = ref.watch(
              activeBathroomTripsProvider(studentIds),
            );
            final activeTrips = activeTripsAsync.value ?? {};

            return Scaffold(
              backgroundColor: const Color(0xFFF0F4FF),
              appBar: AppBar(
                flexibleSpace: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
                      begin: Alignment.topRight,
                      end: Alignment.bottomLeft,
                    ),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('الفصل ${cls.preferredLabel}',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18.sp)),
                    Text('${students.length} طالب', style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
                  ],
                ),
                centerTitle: false,
                foregroundColor: Colors.white,
                elevation: 0,
                actions: [
                  IconButton(
                    icon: const Icon(Icons.fact_check_outlined, color: Colors.white),
                    tooltip: 'تحضير الطلاب',
                    onPressed: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => StudentAttendanceSheet(
                          classId: classId,
                          students: students,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Colors.white),
                    onPressed: () {
                      context.push(
                        Uri(
                          path: '/student-schedule',
                          queryParameters: {'className': cls.name},
                        ).toString(),
                      );
                    },
                    tooltip: 'عرض الجدول',
                  ),
                ],
              ),
              body: students.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: EdgeInsets.all(24.w),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(colors: [const Color(0xFF1A237E).withOpacity(0.08), const Color(0xFF3949AB).withOpacity(0.04)]),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.people_outline, size: 64.sp, color: const Color(0xFF3949AB)),
                          ),
                          SizedBox(height: 16.h),
                          Text('لا يوجد طلاب في هذا الفصل',
                              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        // شريط إحصائيات سريع
                        Container(
                          color: const Color(0xFF1A237E),
                          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 14.h),
                          child: Row(
                            children: [
                              _buildStatChip(Icons.people, '${students.length}', 'طالب', Colors.blue.shade200),
                              SizedBox(width: 12.w),
                              _buildStatChip(Icons.wc, '${activeTrips.length}', 'خارج', Colors.orange.shade200),
                              SizedBox(width: 12.w),
                              _buildStatChip(Icons.check_circle_outline, '${students.length - activeTrips.length}', 'حاضر', Colors.green.shade200),
                            ],
                          ),
                        ),
                        Expanded(
                          child: ListView.builder(
                            padding: EdgeInsets.all(14.w),
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final activeTrip = activeTrips[student.id];
                              return _StudentCard(
                                student: student,
                                activeTrip: activeTrip,
                                index: index,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
            );
          },
        );
      },
    );
  }

  Widget _buildStatChip(IconData icon, String value, String label, Color color) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14.sp, color: color),
          SizedBox(width: 5.w),
          Text('$value $label', style: TextStyle(color: color, fontSize: 11.sp, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  void _showExportOptions(
    BuildContext context,
    WidgetRef ref,
    String className,
    List<User> students,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('طباعة سجل المتابعة'),
        content: const Text('اختر نوع السجل المطلوب تحميله:'),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await _exportLog(context, ref, className, students, false);
            },
            child: const Text('قالب فارغ'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _exportLog(context, ref, className, students, true);
            },
            child: const Text('سجل مرصود'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportLog(
    BuildContext context,
    WidgetRef ref,
    String className,
    List<User> students,
    bool filled,
  ) async {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      List<BehaviorRecord> allRecords = [];
      if (filled) {
        final repo = ref.read(behaviorRepositoryProvider);
        // جلب السجلات مع timeout لمنع التعليق
        try {
          final futures = students.map((s) => repo.getStudentBehavior(s.id));
          final results = await Future.wait(futures)
              .timeout(const Duration(seconds: 10));
          allRecords = results.expand((i) => i).toList();
        } catch (_) {
          // إذا فشل الجلب، نكمل بقالب فارغ
          allRecords = [];
        }
      }

      // Close loading قبل فتح نافذة الطباعة
      if (context.mounted) Navigator.pop(context);

      if (context.mounted) {
        // لا نستخدم await لأن layoutPdf يعلق حتى يغلق المستخدم نافذة الطباعة
        PdfExportService().printStudentLog(
          className: className,
          students: students,
          records: allRecords,
          filled: filled,
        ).catchError((_) {});
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ في التصدير: $e')),
        );
      }
    }
  }
}

class _StudentCard extends ConsumerWidget {
  final User student;
  final BathroomPass? activeTrip;
  final int index;

  const _StudentCard({required this.student, this.activeTrip, this.index = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOut = activeTrip != null;
    final userAsync = ref.watch(authStateProvider);
    final currentUser = userAsync.value;

    bool canSeeHealthStatus = false;
    if (currentUser != null) {
      canSeeHealthStatus = [
        UserRole.teacher, UserRole.admin, UserRole.deputy,
        UserRole.counselor, UserRole.administrative,
      ].contains(currentUser.role);
    }

    Color nameColor = Colors.grey.shade900;
    Color cardBorderColor = const Color(0xFF1A237E).withOpacity(0.12);
    Color avatarGradientStart = const Color(0xFF1A237E);
    Color avatarGradientEnd = const Color(0xFF3949AB);

    if (canSeeHealthStatus && student.healthStatus != null) {
      if (student.healthStatus == 'care') {
        nameColor = Colors.amber.shade800;
        cardBorderColor = Colors.amber.shade200;
        avatarGradientStart = Colors.amber.shade600;
        avatarGradientEnd = Colors.orange.shade500;
      } else if (student.healthStatus == 'bathroom') {
        nameColor = Colors.red.shade700;
        cardBorderColor = Colors.red.shade200;
        avatarGradientStart = Colors.red.shade600;
        avatarGradientEnd = Colors.red.shade400;
      }
    }

    if (isOut) {
      cardBorderColor = Colors.orange.shade300;
      avatarGradientStart = Colors.orange.shade600;
      avatarGradientEnd = Colors.amber.shade500;
    }

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: isOut ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: cardBorderColor),
        boxShadow: [
          BoxShadow(
            color: (isOut ? Colors.orange : const Color(0xFF1A237E)).withOpacity(0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16.r),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => BehaviorSheet(student: student, activeTrip: activeTrip),
          );
        },
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 12.h),
          child: Row(
            children: [
              // رقم الطالب
              Container(
                width: 28.w,
                height: 28.h,
                decoration: BoxDecoration(
                  color: const Color(0xFF1A237E).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: TextStyle(fontSize: 11.sp, fontWeight: FontWeight.bold, color: const Color(0xFF1A237E)),
                  ),
                ),
              ),
              SizedBox(width: 10.w),
              // أفاتار
              Container(
                width: 42.w,
                height: 42.h,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [avatarGradientStart, avatarGradientEnd],
                    begin: Alignment.topRight,
                    end: Alignment.bottomLeft,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: avatarGradientStart.withOpacity(0.3), blurRadius: 6, offset: const Offset(0, 2))],
                ),
                child: Center(
                  child: isOut
                      ? Icon(Icons.wc_rounded, color: Colors.white, size: 20.sp)
                      : Text(
                          student.name.isNotEmpty ? student.name[0] : '؟',
                          style: TextStyle(color: Colors.white, fontSize: 16.sp, fontWeight: FontWeight.bold),
                        ),
                ),
              ),
              SizedBox(width: 12.w),
              // معلومات الطالب
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.bold,
                        color: nameColor,
                      ),
                    ),
                    SizedBox(height: 3.h),
                    isOut
                        ? _BathroomTimer(startTime: activeTrip!.startTime)
                        : Row(
                            children: [
                              Icon(Icons.star_rounded, size: 12.sp, color: Colors.amber.shade600),
                              SizedBox(width: 3.w),
                              Text('نقاط السلوك: ${student.excellenceScore}',
                                  style: TextStyle(fontSize: 11.sp, color: Colors.grey.shade600)),
                            ],
                          ),
                  ],
                ),
              ),
              // أزرار الإجراءات
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isOut && currentUser != null)
                    Container(
                      margin: EdgeInsets.only(left: 6.w),
                      child: Material(
                        color: Colors.green.shade600,
                        borderRadius: BorderRadius.circular(10.r),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10.r),
                          onTap: () async {
                            try {
                              await ref.read(behaviorControllerProvider.notifier)
                                  .returnStudentFromBathroom(activeTrip!, currentUser);
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                                );
                              }
                            }
                          },
                          child: Padding(
                            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.login_rounded, size: 14.sp, color: Colors.white),
                                SizedBox(width: 4.w),
                                Text('عودة', style: TextStyle(color: Colors.white, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: currentUser?.role != UserRole.teacher
                        ? IconButton(
                            icon: Icon(Icons.edit_rounded, color: const Color(0xFF1A237E), size: 18.sp),
                            onPressed: () {
                              showDialog(
                                context: context,
                                builder: (context) => EditStudentDialog(student: student),
                              );
                            },
                            padding: EdgeInsets.all(6.w),
                            constraints: const BoxConstraints(),
                          )
                        : const SizedBox.shrink(),
                  ),
                  if (!isOut) ...[
                    SizedBox(width: 6.w),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14.sp, color: Colors.grey.shade400),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BathroomTimer extends StatefulWidget {
  final DateTime startTime;

  const _BathroomTimer({required this.startTime});

  @override
  State<_BathroomTimer> createState() => _BathroomTimerState();
}

class _BathroomTimerState extends State<_BathroomTimer> {
  late Timer _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _elapsed = now.difference(widget.startTime);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _elapsed.inMinutes;
    final seconds = _elapsed.inSeconds % 60;
    final isOver5 = minutes >= 5;
    final isOver15 = minutes >= 15;

    Color color = Colors.green;
    String statusText = 'مسموح';

    if (isOver15) {
      color = Colors.red.shade900;
      statusText = 'هروب';
    } else if (isOver5) {
      color = Colors.red;
      statusText = 'تأخير';
    } else {
      color = Colors.orange.shade800;
    }

    return Row(
      children: [
        Text(
          '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
          style: TextStyle(color: color, fontWeight: FontWeight.bold),
        ),
        SizedBox(width: 8.w),
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              color: color,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}
