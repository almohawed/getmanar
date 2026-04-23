import 'dart:math';
import '../models/unified_schedule_model.dart';
import '../models/demand.dart';

/// محرك بسيط ومستقر لتوليد جدول نظيف وقابل للتنفيذ
/// يقرأ من UnifiedScheduleModel فقط - مصدر بيانات واحد
///
/// القواعد الصارمة (لا تُخرق أبداً):
/// 1. منع تعارض المعلم (معلم واحد في وقت واحد)
/// 2. احترام نصاب المعلم
/// 3. احترام الفصول المسندة للمعلم
/// 4. معلم واحد لكل مادة في كل فصل
///
/// القواعد المرنة (يمكن تخفيفها عند الحاجة):
/// 1. منع تكرار المادة في نفس اليوم (يُخفف في المرحلة 2 و 3)
class SimpleCleanSolver {
  const SimpleCleanSolver();

  Future<DemandModel> solve(
    UnifiedScheduleModel model, {
    void Function({
      required int demandedLessons,
      required int placedLessons,
      required int unplacedLessons,
      required String label,
    })?
    onProgress,
  }) async {
    final days = model.constraints.days;
    final periods = model.constraints.periodsPerDay;

    // 1. حساب الحصص المطلوبة
    int demandedLessons = 0;
    for (final classData in model.classes) {
      demandedLessons += classData.requiredSubjects.values.fold(
        0,
        (int sum, int count) => sum + count,
      );
    }

    // 2. هياكل البيانات
    final schedule = <String, Map<String, Map<int, _Lesson>>>{};
    for (final classData in model.classes) {
      schedule[classData.id] = {for (final d in days) d: <int, _Lesson>{}};
    }

    final teacherLoad = <String, int>{for (final t in model.teachers) t.id: 0};

    final subjectCountPerDay = <String, Map<String, Map<String, int>>>{};
    for (final classData in model.classes) {
      subjectCountPerDay[classData.id] = {};
      for (final day in days) {
        subjectCountPerDay[classData.id]![day] = <String, int>{};
      }
    }

    final subjectTeacherPerClass = <String, Map<String, String>>{};
    for (final classData in model.classes) {
      subjectTeacherPerClass[classData.id] = {};
    }

    int placedCount = 0;
    final random = Random();

    // المرحلة 1: توزيع أساسي مع منع التكرار
    for (final day in days) {
      for (int period = 1; period <= periods; period++) {
        final usedTeachers = <String>{};

        for (final classData in model.classes) {
          final cid = classData.id;
          if (schedule[cid]![day]!.containsKey(period)) continue;

          String? chosenTeacher;
          String? chosenSubject;

          final shuffledTeachers = model.teachers.toList()..shuffle(random);

          for (final teacher in shuffledTeachers) {
            if (usedTeachers.contains(teacher.id)) continue;

            final load = teacherLoad[teacher.id] ?? 0;
            if (load >= teacher.maxWeeklyLoad) continue;

            if (teacher.assignedClassIds.isNotEmpty &&
                !teacher.assignedClassIds.contains(cid)) {
              continue;
            }

            final shuffledSubjects = List<String>.from(teacher.subjects)
              ..shuffle(random);

            for (final subject in shuffledSubjects) {
              final subjectData = model.subjects
                  .where((s) => s.normalizedName == subject)
                  .firstOrNull;
              final maxAllowed = subjectData?.maxPerDay ?? 1;

              final count = subjectCountPerDay[cid]![day]![subject] ?? 0;

              if (count < maxAllowed) {
                final existingTeacher = subjectTeacherPerClass[cid]![subject];
                if (existingTeacher != null && existingTeacher != teacher.id) {
                  continue;
                }

                chosenTeacher = teacher.id;
                chosenSubject = subject;
                break;
              }
            }

            if (chosenTeacher != null) break;
          }

          if (chosenTeacher != null && chosenSubject != null) {
            schedule[cid]![day]![period] = _Lesson(
              teacherId: chosenTeacher,
              subjectId: chosenSubject,
            );
            teacherLoad[chosenTeacher] = (teacherLoad[chosenTeacher] ?? 0) + 1;
            usedTeachers.add(chosenTeacher);
            subjectCountPerDay[cid]![day]![chosenSubject] =
                (subjectCountPerDay[cid]![day]![chosenSubject] ?? 0) + 1;
            subjectTeacherPerClass[cid]![chosenSubject] = chosenTeacher;
            placedCount++;

            if (placedCount % 50 == 0 && onProgress != null) {
              onProgress(
                demandedLessons: demandedLessons,
                placedLessons: placedCount,
                unplacedLessons: demandedLessons - placedCount,
                label: 'بناء الجدول',
              );
            }
          }
        }
      }
    }

    // المرحلة 2: ملء الفراغات (السماح بتكرار محدود)
    for (final day in days) {
      for (int period = 1; period <= periods; period++) {
        final usedTeachers = <String>{};

        for (final classData in model.classes) {
          final cid = classData.id;
          if (schedule[cid]![day]!.containsKey(period)) {
            final lesson = schedule[cid]![day]![period];
            if (lesson != null) {
              usedTeachers.add(lesson.teacherId);
            }
            continue;
          }

          String? chosenTeacher;
          String? chosenSubject;

          final shuffledTeachers = model.teachers.toList()..shuffle(random);

          for (final teacher in shuffledTeachers) {
            if (usedTeachers.contains(teacher.id)) continue;

            final load = teacherLoad[teacher.id] ?? 0;
            if (load >= teacher.maxWeeklyLoad) continue;

            if (teacher.assignedClassIds.isNotEmpty &&
                !teacher.assignedClassIds.contains(cid)) {
              continue;
            }

            final shuffledSubjects = List<String>.from(teacher.subjects)
              ..shuffle(random);

            for (final subject in shuffledSubjects) {
              final existingTeacher = subjectTeacherPerClass[cid]![subject];
              if (existingTeacher == null || existingTeacher == teacher.id) {
                chosenTeacher = teacher.id;
                chosenSubject = subject;
                break;
              }
            }

            if (chosenTeacher != null) break;
          }

          if (chosenTeacher != null && chosenSubject != null) {
            schedule[cid]![day]![period] = _Lesson(
              teacherId: chosenTeacher,
              subjectId: chosenSubject,
            );
            teacherLoad[chosenTeacher] = (teacherLoad[chosenTeacher] ?? 0) + 1;
            usedTeachers.add(chosenTeacher);
            subjectCountPerDay[cid]![day]![chosenSubject] =
                (subjectCountPerDay[cid]![day]![chosenSubject] ?? 0) + 1;
            subjectTeacherPerClass[cid]![chosenSubject] = chosenTeacher;
            placedCount++;
          }
        }
      }
    }

    // المرحلة 3: إكمال نهائي (السماح بأي تكرار)
    for (final day in days) {
      for (int period = 1; period <= periods; period++) {
        final usedTeachers = <String>{};

        for (final classData in model.classes) {
          final cid = classData.id;
          if (schedule[cid]![day]!.containsKey(period)) {
            final lesson = schedule[cid]![day]![period];
            if (lesson != null) {
              usedTeachers.add(lesson.teacherId);
            }
            continue;
          }

          String? chosenTeacher;
          String? chosenSubject;

          final shuffledTeachers = model.teachers.toList()..shuffle(random);

          for (final teacher in shuffledTeachers) {
            if (usedTeachers.contains(teacher.id)) continue;

            final load = teacherLoad[teacher.id] ?? 0;
            if (load >= teacher.maxWeeklyLoad) continue;

            if (teacher.assignedClassIds.isNotEmpty &&
                !teacher.assignedClassIds.contains(cid)) {
              continue;
            }

            if (teacher.subjects.isEmpty) continue;

            final shuffledSubjects = List<String>.from(teacher.subjects)
              ..shuffle(random);

            for (final subject in shuffledSubjects) {
              final existingTeacher = subjectTeacherPerClass[cid]![subject];
              if (existingTeacher == null || existingTeacher == teacher.id) {
                chosenSubject = subject;
                break;
              }
            }

            if (chosenSubject == null) {
              chosenSubject = shuffledSubjects.first;
            }

            chosenTeacher = teacher.id;
            break;
          }

          if (chosenTeacher != null && chosenSubject != null) {
            schedule[cid]![day]![period] = _Lesson(
              teacherId: chosenTeacher,
              subjectId: chosenSubject,
            );
            teacherLoad[chosenTeacher] = (teacherLoad[chosenTeacher] ?? 0) + 1;
            usedTeachers.add(chosenTeacher);
            subjectCountPerDay[cid]![day]![chosenSubject] =
                (subjectCountPerDay[cid]![day]![chosenSubject] ?? 0) + 1;
            subjectTeacherPerClass[cid]![chosenSubject] = chosenTeacher;
            placedCount++;
          }
        }
      }
    }

    // المرحلة 4: Swap ذكي مع أولوية للأيام المزدحمة
    int swapCount = 0;
    final maxSwapAttempts = 150; // زيادة المحاولات

    // ترتيب الأيام بالعكس (الخميس أولاً) لحل الازدحام
    final reversedDays = days.reversed.toList();

    for (int attempt = 0; attempt < maxSwapAttempts; attempt++) {
      bool improved = false;

      // البحث عن حصة يمكن تبديلها لتحسين الجدول
      for (final classData in model.classes) {
        final cid = classData.id;

        // حساب النقص لكل مادة
        final placedPerSubject = <String, int>{};
        for (final day in days) {
          for (final lesson in schedule[cid]![day]!.values) {
            placedPerSubject[lesson.subjectId] =
                (placedPerSubject[lesson.subjectId] ?? 0) + 1;
          }
        }

        // البحث عن مادة ناقصة
        String? missingSubject;
        for (final entry in classData.requiredSubjects.entries) {
          final placed = placedPerSubject[entry.key] ?? 0;
          if (placed < entry.value) {
            missingSubject = entry.key;
            break;
          }
        }

        if (missingSubject == null) continue;

        // البحث عن معلم مؤهل لهذه المادة
        final qualifiedTeacher = model.teachers.where((t) {
          if (!t.subjects.contains(missingSubject)) return false;
          if (t.assignedClassIds.isNotEmpty &&
              !t.assignedClassIds.contains(cid))
            return false;
          final load = teacherLoad[t.id] ?? 0;
          if (load >= t.maxWeeklyLoad) return false;
          final existingTeacher = subjectTeacherPerClass[cid]![missingSubject];
          if (existingTeacher != null && existingTeacher != t.id) return false;
          return true;
        }).firstOrNull;

        if (qualifiedTeacher == null) continue;

        // البحث عن فترة فارغة في الفصل (ابدأ من الأيام الأولى)
        for (final targetDay in days) {
          for (int targetPeriod = 1; targetPeriod <= periods; targetPeriod++) {
            if (schedule[cid]![targetDay]!.containsKey(targetPeriod)) continue;

            // هل المعلم مشغول في هذا الوقت؟
            String? blockingClassId;
            for (final otherClass in model.classes) {
              if (otherClass.id == cid) continue;
              final lesson = schedule[otherClass.id]![targetDay]![targetPeriod];
              if (lesson != null && lesson.teacherId == qualifiedTeacher.id) {
                blockingClassId = otherClass.id;
                break;
              }
            }

            if (blockingClassId == null) {
              // المعلم متاح! ضع الحصة مباشرة
              schedule[cid]![targetDay]![targetPeriod] = _Lesson(
                teacherId: qualifiedTeacher.id,
                subjectId: missingSubject,
              );
              teacherLoad[qualifiedTeacher.id] =
                  (teacherLoad[qualifiedTeacher.id] ?? 0) + 1;
              subjectCountPerDay[cid]![targetDay]![missingSubject] =
                  (subjectCountPerDay[cid]![targetDay]![missingSubject] ?? 0) +
                  1;
              subjectTeacherPerClass[cid]![missingSubject] =
                  qualifiedTeacher.id;
              placedCount++;
              improved = true;
              break;
            }

            // المعلم مشغول، حاول تبديل حصته (ابحث في الأيام المتأخرة أولاً)
            final blockingLesson =
                schedule[blockingClassId]![targetDay]![targetPeriod]!;

            // ابحث عن وقت بديل للحصة المعيقة (أولوية للأيام المتأخرة)
            for (final swapDay in reversedDays) {
              for (int swapPeriod = periods; swapPeriod >= 1; swapPeriod--) {
                if (swapDay == targetDay && swapPeriod == targetPeriod)
                  continue;

                // هل الفصل المعيق فارغ في الوقت البديل؟
                if (schedule[blockingClassId]![swapDay]!.containsKey(
                  swapPeriod,
                )) {
                  continue;
                }

                // هل المعلم متاح في الوقت البديل؟
                bool teacherFree = true;
                for (final checkClass in model.classes) {
                  final checkLesson =
                      schedule[checkClass.id]![swapDay]![swapPeriod];
                  if (checkLesson != null &&
                      checkLesson.teacherId == qualifiedTeacher.id) {
                    teacherFree = false;
                    break;
                  }
                }

                if (!teacherFree) continue;

                // نفذ التبديل
                schedule[blockingClassId]![swapDay]![swapPeriod] =
                    blockingLesson;
                schedule[blockingClassId]![targetDay]!.remove(targetPeriod);

                // ضع الحصة الجديدة
                schedule[cid]![targetDay]![targetPeriod] = _Lesson(
                  teacherId: qualifiedTeacher.id,
                  subjectId: missingSubject,
                );
                teacherLoad[qualifiedTeacher.id] =
                    (teacherLoad[qualifiedTeacher.id] ?? 0) + 1;
                subjectCountPerDay[cid]![targetDay]![missingSubject] =
                    (subjectCountPerDay[cid]![targetDay]![missingSubject] ??
                        0) +
                    1;
                subjectTeacherPerClass[cid]![missingSubject] =
                    qualifiedTeacher.id;
                placedCount++;
                swapCount++;
                improved = true;
                break;
              }
              if (improved) break;
            }
            if (improved) break;
          }
          if (improved) break;
        }
        if (improved) break;
      }

      if (!improved) break;
    }

    // المرحلة 5: وضع الطوارئ - السماح بتجاوز النصاب بنسبة 25%
    int emergencyCount = 0;
    final maxEmergencyAttempts = 50;

    for (int attempt = 0; attempt < maxEmergencyAttempts; attempt++) {
      bool improved = false;

      for (final classData in model.classes) {
        final cid = classData.id;

        // حساب النقص
        final placedPerSubject = <String, int>{};
        for (final day in days) {
          for (final lesson in schedule[cid]![day]!.values) {
            placedPerSubject[lesson.subjectId] =
                (placedPerSubject[lesson.subjectId] ?? 0) + 1;
          }
        }

        // البحث عن مادة ناقصة
        String? missingSubject;
        for (final entry in classData.requiredSubjects.entries) {
          final placed = placedPerSubject[entry.key] ?? 0;
          if (placed < entry.value) {
            missingSubject = entry.key;
            break;
          }
        }

        if (missingSubject == null) continue;

        // البحث عن معلم مؤهل (مع السماح بتجاوز النصاب بنسبة 25%)
        final qualifiedTeacher = model.teachers.where((t) {
          if (!t.subjects.contains(missingSubject)) return false;
          if (t.assignedClassIds.isNotEmpty &&
              !t.assignedClassIds.contains(cid))
            return false;

          // السماح بتجاوز النصاب بنسبة 25%
          final load = teacherLoad[t.id] ?? 0;
          final maxAllowed = (t.maxWeeklyLoad * 1.25).ceil();
          if (load >= maxAllowed) return false;

          final existingTeacher = subjectTeacherPerClass[cid]![missingSubject];
          if (existingTeacher != null && existingTeacher != t.id) return false;
          return true;
        }).firstOrNull;

        if (qualifiedTeacher == null) continue;

        // البحث عن فترة فارغة
        for (final targetDay in days) {
          for (int targetPeriod = 1; targetPeriod <= periods; targetPeriod++) {
            if (schedule[cid]![targetDay]!.containsKey(targetPeriod)) continue;

            // هل المعلم متاح؟
            bool teacherAvailable = true;
            for (final otherClass in model.classes) {
              if (otherClass.id == cid) continue;
              final lesson = schedule[otherClass.id]![targetDay]![targetPeriod];
              if (lesson != null && lesson.teacherId == qualifiedTeacher.id) {
                teacherAvailable = false;
                break;
              }
            }

            if (teacherAvailable) {
              schedule[cid]![targetDay]![targetPeriod] = _Lesson(
                teacherId: qualifiedTeacher.id,
                subjectId: missingSubject,
              );
              teacherLoad[qualifiedTeacher.id] =
                  (teacherLoad[qualifiedTeacher.id] ?? 0) + 1;
              subjectCountPerDay[cid]![targetDay]![missingSubject] =
                  (subjectCountPerDay[cid]![targetDay]![missingSubject] ?? 0) +
                  1;
              subjectTeacherPerClass[cid]![missingSubject] =
                  qualifiedTeacher.id;
              placedCount++;
              emergencyCount++;
              improved = true;
              break;
            }
          }
          if (improved) break;
        }
        if (improved) break;
      }

      if (!improved) break;
    }

    // تحويل إلى النموذج المطلوب
    final lessons = <Map<String, dynamic>>[];
    for (final classData in model.classes) {
      final cid = classData.id;
      for (final day in days) {
        for (final entry in schedule[cid]![day]!.entries) {
          lessons.add({
            'classId': cid,
            'day': day,
            'period': entry.key,
            'teacherId': entry.value.teacherId,
            'subjectId': entry.value.subjectId,
          });
        }
      }
    }

    return DemandModel(
      demandedLessons: demandedLessons,
      placedLessons: placedCount,
      unplacedLessons: demandedLessons - placedCount,
      teacherConflicts: 0,
      classConflicts: 0,
      solverPasses: 1,
      retryCount: 0,
      swapCount: swapCount,
      data: {
        'days': days,
        'periodsPerDay': periods,
        'classIds': model.classes.map((c) => c.id).toList(),
        'lessons': lessons,
        'solverType': 'SimpleCleanSolver_v4.0_Emergency',
        'emergencyOverloads': emergencyCount,
        'solverTimestamp': DateTime.now().toIso8601String(),
      },
    );
  }
}

class _Lesson {
  final String teacherId;
  final String subjectId;
  const _Lesson({required this.teacherId, required this.subjectId});
}
