import 'package:flutter/services.dart';
import 'dart:convert';
import '../models/unified_schedule_model.dart';
import '../models/assignment.dart';
import '../models/snapshot.dart';
import '../utils/subject_normalizer.dart';
import '../../../../../schedule/domain/saudi_subject_plans.dart';

/// جامع البيانات - يجمع كل بيانات الجدول من مصادر مختلفة
/// ويوحدها في UnifiedScheduleModel واحد
class SchoolDataCollector {
  const SchoolDataCollector();

  Future<UnifiedScheduleModel> collect({
    required SchoolSnapshot snapshot,
    required AssignmentModel assignment,
  }) async {
    // 1. جمع بيانات المعلمين
    final teachers = _collectTeachers(snapshot, assignment);

    // 2. جمع بيانات الفصول مع الخطة الدراسية
    final classes = await _collectClasses(snapshot);

    // 3. جمع بيانات المواد
    final subjects = _collectSubjects(snapshot);

    // 4. القيود
    final constraints = _collectConstraints(snapshot);

    return UnifiedScheduleModel(
      teachers: teachers,
      classes: classes,
      subjects: subjects,
      constraints: constraints,
    );
  }

  List<TeacherData> _collectTeachers(
    SchoolSnapshot snapshot,
    AssignmentModel assignment,
  ) {
    final teachers = <TeacherData>[];
    final isPrimaryOnly = snapshot.stage == 'primary_only';

    for (final t in assignment.teachers) {
      if (t.isAdministrative) continue;

      // الحصول على الفصول المسندة من snapshot
      final snapshotTeacher = snapshot.teachers
          .where((st) => st.id == t.teacherId)
          .firstOrNull;

      final assignedClassIds = snapshotTeacher?.assignedClassIds ?? [];

      // توحيد المواد
      List<String> subjects = [];

      // 1. المواد المسندة
      if (t.assignedSubjects.isNotEmpty) {
        subjects = t.assignedSubjects
            .map((s) => SubjectNormalizer.normalize(s.trim()))
            .where((s) => s.isNotEmpty)
            .toList();
      }
      // 2. المادة الأساسية
      else if ((t.primarySubject ?? '').trim().isNotEmpty) {
        final normalized =
            SubjectNormalizer.normalize(t.primarySubject!.trim());
        if (normalized.isNotEmpty) {
          subjects = [normalized];
        }
      }
      // 3. ابتدائي → general
      else if (isPrimaryOnly) {
        subjects = ['general'];
      }
      // 4. التخصص من snapshot
      else if (snapshotTeacher != null &&
          (snapshotTeacher.specialization ?? '').trim().isNotEmpty) {
        final normalized =
            SubjectNormalizer.normalize(snapshotTeacher.specialization!.trim());
        if (normalized.isNotEmpty) {
          subjects = [normalized];
        }
      }

      teachers.add(TeacherData(
        id: t.teacherId,
        name: t.teacherName,
        subjects: subjects,
        assignedClassIds: assignedClassIds,
        maxWeeklyLoad: t.maxWeeklyLoad > 0 ? t.maxWeeklyLoad : 24,
        isAdministrative: t.isAdministrative,
      ));
    }

    return teachers;
  }

  Future<List<ClassData>> _collectClasses(SchoolSnapshot snapshot) async {
    final classes = <ClassData>[];

    try {
      final text =
          await rootBundle.loadString('assets/config/saudi_subject_plans.json');
      final decoded = json.decode(text);

      if (decoded is Map) {
        final plans = SaudiSubjectPlans(decoded.cast<String, dynamic>());

        for (final c in snapshot.classes) {
          final requiredSubjects = plans.weeklyDemandForGrade(
            gradeLevel: c.gradeLevel,
            secondaryProgramType: snapshot.secondaryProgramType,
            secondaryTrack: c.secondaryTrack,
          );

          // توحيد أسماء المواد في الخطة
          final normalizedRequirements = <String, int>{};
          for (final entry in requiredSubjects.entries) {
            final normalized = SubjectNormalizer.normalize(entry.key);
            normalizedRequirements[normalized] = entry.value;
          }

          classes.add(ClassData(
            id: c.id,
            name: c.name,
            gradeLevel: c.gradeLevel,
            requiredSubjects: normalizedRequirements,
          ));
        }
      }
    } catch (e) {
      // في حالة الفشل، نستخدم قيم افتراضية
      for (final c in snapshot.classes) {
        classes.add(ClassData(
          id: c.id,
          name: c.name,
          gradeLevel: c.gradeLevel,
          requiredSubjects: {},
        ));
      }
    }

    return classes;
  }

  List<SubjectData> _collectSubjects(SchoolSnapshot snapshot) {
    final subjects = <SubjectData>[];

    for (final s in snapshot.subjects) {
      final normalized = SubjectNormalizer.normalize(s.name);
      subjects.add(SubjectData(
        id: s.id,
        name: s.name,
        normalizedName: normalized,
        maxPerDay: _getMaxPerDay(normalized),
      ));
    }

    return subjects;
  }

  ScheduleConstraints _collectConstraints(SchoolSnapshot snapshot) {
    final days = _getDays(snapshot);

    return ScheduleConstraints(
      daysPerWeek: snapshot.daysPerWeek,
      periodsPerDay: snapshot.periodsPerDay,
      days: days,
    );
  }

  List<String> _getDays(SchoolSnapshot snapshot) {
    // يمكن قراءة الأيام من policy إذا كانت متوفرة
    return ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
  }

  int _getMaxPerDay(String normalizedSubject) {
    final lower = normalizedSubject.toLowerCase();
    final allowedToRepeat = [
      'arabic',
      'عربي',
      'لغة عربية',
      'islamic',
      'إسلامية',
      'دراسات إسلامية',
      'fiqh',
      'فقه',
      'tafsir',
      'tafseer',
      'تفسير',
      'hadith',
      'hadeth',
      'حديث',
    ];

    return allowedToRepeat.any((a) => lower.contains(a)) ? 2 : 1;
  }
}
