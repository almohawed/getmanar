import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../notifications/domain/notification_record.dart';
import '../../notifications/presentation/notifications_provider.dart';
import '../../schedule/data/schedule_repository.dart';
import '../../admin/data/mock_teacher_repository.dart';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';

class TeacherWaitLoad {
  final String teacherId;
  final String teacherName;
  int nisab; // Weekly Class Load
  int waitLoad; // Wait Load

  TeacherWaitLoad({
    required this.teacherId,
    required this.teacherName,
    required this.nisab,
    required this.waitLoad,
  });
}

class MockWaitRepository {
  final Ref ref;
  final List<TeacherWaitLoad> _loads = [];
  bool _isInitialized = false;

  // In-memory storage for assigned waits: teacherId -> List<Map>
  // Map structure: {'day': 'Sunday', 'period': 1, 'class': '3/1', 'type': 'first'|'second'}
  final Map<String, List<Map<String, dynamic>>> _assignedWaits = {};

  MockWaitRepository(this.ref) {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    await _loadFromDisk();
    _isInitialized = true;
  }

  Future<void> _loadFromDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/assigned_waits.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final Map<String, dynamic> jsonMap = json.decode(content);
        _assignedWaits.clear();
        jsonMap.forEach((key, value) {
          _assignedWaits[key] = List<Map<String, dynamic>>.from(value);
        });
      }
    } catch (e) {
      // debugPrint('Error loading waits: $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/assigned_waits.json');
      await file.writeAsString(json.encode(_assignedWaits));
    } catch (e) {
      // debugPrint('Error saving waits: $e');
    }
  }

  Future<void> _refreshLoads(String schoolId) async {
    final teachers = await ref
        .read(mockTeacherRepositoryProvider)
        .getTeachers(schoolId: schoolId);
    final scheduleRepo = ref.read(scheduleRepositoryProvider);

    _loads.clear();
    for (var teacher in teachers) {
      final nisab = await scheduleRepo.getTeacherLoad(schoolId, teacher.id);

      // Calculate current wait load from memory
      final currentWaits = _assignedWaits[teacher.id]?.length ?? 0;

      _loads.add(
        TeacherWaitLoad(
          teacherId: teacher.id,
          teacherName: teacher.name,
          nisab: nisab,
          waitLoad: currentWaits,
        ),
      );
    }
  }

  // 🧠 Manar Intelligent Wait Distribution Algorithm
  int _calculateWaitQuota(int nisab) {
    if (nisab >= 24) return 0; // Exempt
    if (nisab >= 22) return 2; // Low quota
    if (nisab >= 20) return 4; // Medium quota
    if (nisab >= 18) return 6; // Standard quota
    return 8; // Low load = High wait capacity
  }

  Future<List<Map<String, dynamic>>> generateWaitSchedule(
    String schoolId,
    String absentTeacherId,
    String day,
  ) async {
    await _init();
    await _refreshLoads(schoolId);

    final scheduleRepo = ref.read(scheduleRepositoryProvider);

    // 1. Identify classes of absent teacher
    final absentTeacherSchedule = await scheduleRepo.getSchedule(
      schoolId,
      absentTeacherId,
    );
    final absentClasses = absentTeacherSchedule
        .where((s) => s.day == day && s.subject.isNotEmpty)
        .map((s) => {'period': s.period, 'class': s.className})
        .toList();

    if (absentClasses.isEmpty) return [];

    final teachers = await ref
        .read(mockTeacherRepositoryProvider)
        .getTeachers(schoolId: schoolId);
    final generatedSchedule = <Map<String, dynamic>>[];

    for (var cls in absentClasses) {
      final period = cls['period'] as int;
      bool foundPrimary = false;
      bool foundSecondary = false;

      // 2. Find teachers with FIXED Wait Duty in their schedule (Priority 1)
      for (var teacher in teachers) {
        if (teacher.id == absentTeacherId) continue;

        final teacherSchedule = await scheduleRepo.getSchedule(schoolId, teacher.id);

        try {
          final waitSlot = teacherSchedule.firstWhere(
            (s) =>
                s.day == day &&
                s.period == period &&
                s.subject.contains('منتظر'),
          );

          final nisab = await scheduleRepo.getTeacherLoad(schoolId, teacher.id);

          if (waitSlot.subject.contains('أول')) {
            generatedSchedule.add({
              'period': period,
              'class': cls['class'],
              'assignedTeacherId': teacher.id,
              'assignedTeacherName': teacher.name,
              'type': 'أساسي (مجدول)',
              'nisab': nisab,
            });
            foundPrimary = true;
          } else if (waitSlot.subject.contains('ثاني')) {
            generatedSchedule.add({
              'period': period,
              'class': cls['class'],
              'assignedTeacherId': teacher.id,
              'assignedTeacherName': teacher.name,
              'type': 'احتياطي (مجدول)',
              'nisab': nisab,
            });
            foundSecondary = true;
          } else if (waitSlot.subject.contains('ثالث')) {
            generatedSchedule.add({
              'period': period,
              'class': cls['class'],
              'assignedTeacherId': teacher.id,
              'assignedTeacherName': teacher.name,
              'type': 'احتياطي 2 (مجدول)',
              'nisab': nisab,
            });
          }
        } catch (_) {}
      }

      // 3. Fallback: Intelligent Dynamic Assignment (Priority 2)
      if (!foundPrimary && !foundSecondary) {
        final availableTeachers = <TeacherWaitLoad>[];

        for (var teacherLoad in _loads) {
          if (teacherLoad.teacherId == absentTeacherId) continue;

          // Check if exempt (Nisab >= 24)
          // Exception: If we have NO ONE else, we might have to use them, but usually we filter them out first.
          if (teacherLoad.nisab >= 24) continue;

          final teacherSchedule = await scheduleRepo.getSchedule(
            schoolId,
            teacherLoad.teacherId,
          );
          final isBusy = teacherSchedule.any(
            (s) => s.day == day && s.period == period && s.subject.isNotEmpty,
          );

          if (!isBusy) {
            availableTeachers.add(teacherLoad);
          }
        }

        // Sort by "Fairness Ratio" (Current Wait Load / Quota)
        // Teachers who have used less of their quota come first.
        availableTeachers.sort((a, b) {
          final quotaA = _calculateWaitQuota(a.nisab);
          final quotaB = _calculateWaitQuota(b.nisab);

          // Avoid division by zero
          final ratioA = quotaA > 0 ? a.waitLoad / quotaA : 999.0;
          final ratioB = quotaB > 0 ? b.waitLoad / quotaB : 999.0;

          return ratioA.compareTo(ratioB);
        });

        // Emergency fallback: If list is empty (everyone busy or exempt), include exempt teachers who are free
        if (availableTeachers.isEmpty) {
          for (var teacherLoad in _loads) {
            if (teacherLoad.teacherId == absentTeacherId) continue;
            if (teacherLoad.nisab < 24) continue; // Already checked non-exempt

            final teacherSchedule = await scheduleRepo.getSchedule(
              schoolId,
              teacherLoad.teacherId,
            );
            final isBusy = teacherSchedule.any(
              (s) => s.day == day && s.period == period && s.subject.isNotEmpty,
            );

            if (!isBusy) {
              availableTeachers.add(teacherLoad);
            }
          }
          // Sort exempt teachers by least wait load
          availableTeachers.sort((a, b) => a.waitLoad.compareTo(b.waitLoad));
        }

        if (availableTeachers.isNotEmpty) {
          final t = availableTeachers[0];
          generatedSchedule.add({
            'period': period,
            'class': cls['class'],
            'assignedTeacherId': t.teacherId,
            'assignedTeacherName': t.teacherName,
            'type': 'تلقائي (ذكاء اصطناعي)',
            'nisab': t.nisab,
            'quota_usage': '${t.waitLoad}/${_calculateWaitQuota(t.nisab)}',
          });
        }
      }
    }

    return generatedSchedule;
  }

  Future<void> confirmSchedule(
    String schoolId,
    List<Map<String, dynamic>> schedule,
    String day,
  ) async {
    await _init();
    final notificationRepo = ref.read(notificationRepositoryProvider);

    for (var item in schedule) {
      final teacherId = item['assignedTeacherId'];
      final teacherName = item['assignedTeacherName'];
      final className = item['class'];
      final period = item['period'];

      if (!_assignedWaits.containsKey(teacherId)) {
        _assignedWaits[teacherId] = [];
      }

      _assignedWaits[teacherId]!.add({
        'day': day,
        'period': period,
        'class': className,
        'type': item['type'],
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Send Polite Notification
      final notification = NotificationRecord(
        id: const Uuid().v4(),
        userId: teacherId,
        schoolId: schoolId,
        title: 'تكليف بحصة انتظار',
        body:
            'أستاذنا الفاضل والمربي القدير $teacherName، نعتذر منك ونقدر جهودك العظيمة، نأمل منك التكرم بتغطية حصة انتظار في الصف $className الحصة $period، شاكرين لك تعاونك الدائم وحرصك على مصلحة أبنائنا الطلاب.',
        timestamp: DateTime.now(),
        data: {
          'type': 'wait_assignment',
          'day': day,
          'period': period,
          'class': className,
        },
      );

      // Fire and forget notification
      notificationRepo.sendNotification(notification);
    }
    await _saveToDisk();
  }

  Future<List<Map<String, dynamic>>> getTeacherWaits(String teacherId) async {
    await _init();
    return _assignedWaits[teacherId] ?? [];
  }
}

final mockWaitRepositoryProvider = Provider<MockWaitRepository>(
  (ref) => MockWaitRepository(ref),
);
