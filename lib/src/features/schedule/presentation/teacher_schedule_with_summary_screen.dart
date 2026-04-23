import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'widgets/teacher_load_summary_widget.dart';

class TeacherScheduleWithSummaryScreen extends ConsumerWidget {
  final String teacherId;
  final String schoolId;

  const TeacherScheduleWithSummaryScreen({
    super.key,
    required this.teacherId,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('جدول المعلم'),
        backgroundColor: const Color(0xFF3F51B5),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .doc('Schools/$schoolId/Teachers/$teacherId')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return _buildEmptyState();
          }

          final teacherData = snapshot.data!.data() as Map<String, dynamic>;
          final teacherName = teacherData['name'] ?? 'معلم';
          final requiredLessons = teacherData['requiredLessons'] as int? ?? 0;

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('Schools/$schoolId/Schedules')
                .snapshots(),
            builder: (context, scheduleSnapshot) {
              if (scheduleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              final teacherSchedule = _buildTeacherSchedule(
                teacherId,
                scheduleSnapshot.data?.docs ?? [],
              );

              final actualLessons = _countLessons(teacherSchedule);
              final totalPeriods = _countTotalPeriods(teacherSchedule);
              final freePeriods = totalPeriods - actualLessons;

              return SingleChildScrollView(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Teacher Load Summary
                    TeacherLoadSummaryWidget(
                      teacherName: teacherName,
                      requiredLessons: requiredLessons,
                      actualLessons: actualLessons,
                      freePeriods: freePeriods,
                      totalPeriods: totalPeriods,
                    ),

                    SizedBox(height: 24.h),

                    // Schedule Table
                    _buildScheduleTable(teacherSchedule),

                    SizedBox(height: 32.h),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80.sp,
            color: const Color(0xFF3F51B5).withValues(alpha: 0.5),
          ),
          SizedBox(height: 24.h),
          Text(
            'لا يوجد جدول حالياً',
            style: TextStyle(
              fontSize: 24.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 12.h),
          Text(
            'سيتم إضافة الجدول قريباً',
            style: TextStyle(
              fontSize: 16.sp,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, List<Map<String, dynamic>>> _buildTeacherSchedule(
    String teacherId,
    List<QueryDocumentSnapshot> classSchedules,
  ) {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    final teacherSchedule = <String, List<Map<String, dynamic>>>{};

    // Initialize days
    for (var day in days) {
      teacherSchedule[day] = List.generate(7, (_) => <String, dynamic>{});
    }

    // Collect teacher's lessons from all classes
    for (var classDoc in classSchedules) {
      try {
        final data = classDoc.data() as Map<String, dynamic>;
        final className = data['className'] ?? classDoc.id;
        final scheduleData = data['schedule'];

        if (scheduleData == null) continue;

        Map<String, dynamic> schedule;
        if (scheduleData is Map<String, dynamic>) {
          schedule = scheduleData;
        } else if (scheduleData is Map) {
          schedule = Map<String, dynamic>.from(scheduleData);
        } else {
          continue;
        }

        schedule.forEach((day, lessons) {
          if (lessons == null || !days.contains(day)) return;

          List<dynamic> lessonsList;
          if (lessons is List) {
            lessonsList = lessons;
          } else {
            return;
          }

          for (int period = 0; period < lessonsList.length && period < 7; period++) {
            final lesson = lessonsList[period];
            if (lesson == null) continue;

            Map<String, dynamic> lessonMap;
            if (lesson is Map<String, dynamic>) {
              lessonMap = lesson;
            } else if (lesson is Map) {
              lessonMap = Map<String, dynamic>.from(lesson);
            } else {
              continue;
            }

            final lessonTeacherId = lessonMap['teacherId']?.toString() ?? '';
            final subjectName = lessonMap['subjectName']?.toString() ?? '';

            if (lessonTeacherId == teacherId && subjectName.isNotEmpty) {
              teacherSchedule[day]![period] = {
                'subjectName': subjectName,
                'className': className,
                'teacherId': teacherId,
              };
            }
          }
        });
      } catch (e) {
        debugPrint('Error processing class: $e');
        continue;
      }
    }

    return teacherSchedule;
  }

  int _countLessons(Map<String, List<Map<String, dynamic>>> schedule) {
    int count = 0;
    schedule.forEach((day, lessons) {
      for (var lesson in lessons) {
        if (lesson.isNotEmpty) count++;
      }
    });
    return count;
  }

  int _countTotalPeriods(Map<String, List<Map<String, dynamic>>> schedule) {
    int count = 0;
    schedule.forEach((day, lessons) {
      count += lessons.length;
    });
    return count;
  }

  Widget _buildScheduleTable(Map<String, List<Map<String, dynamic>>> schedule) {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: MaterialStateProperty.all(
            const Color(0xFF3F51B5).withValues(alpha: 0.1),
          ),
          columns: [
            DataColumn(
              label: Text(
                'اليوم',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 12.sp,
                ),
              ),
            ),
            ...List.generate(
              7,
              (index) => DataColumn(
                label: Text(
                  'الحصة ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
              ),
            ),
          ],
          rows: days.map((day) {
            final dayLessons = schedule[day] ?? [];
            return DataRow(
              cells: [
                DataCell(
                  Text(
                    day,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.sp,
                    ),
                  ),
                ),
                ...dayLessons.asMap().entries.map((entry) {
                  final lesson = entry.value;
                  final hasLesson = lesson.isNotEmpty;

                  return DataCell(
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: hasLesson
                            ? const Color(0xFF3F51B5).withValues(alpha: 0.1)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      child: hasLesson
                          ? Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  lesson['subjectName'] ?? '',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11.sp,
                                    color: const Color(0xFF3F51B5),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  lesson['className'] ?? '',
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey.shade600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            )
                          : Center(
                              child: Text(
                                '-',
                                style: TextStyle(
                                  color: Colors.grey.shade400,
                                  fontSize: 14.sp,
                                ),
                              ),
                            ),
                    ),
                  );
                }),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
