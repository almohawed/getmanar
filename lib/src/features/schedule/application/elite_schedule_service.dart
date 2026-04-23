import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../data/elite_schedule_repository.dart';
import '../domain/scheduling_session.dart';
import '../domain/teacher_preference.dart';
import '../../admin/data/firestore_teacher_repository.dart';

final eliteScheduleServiceProvider = Provider(
  (ref) => EliteScheduleService(ref),
);

class EliteScheduleService {
  final Ref _ref;

  EliteScheduleService(this._ref);

  EliteScheduleRepository get _repo =>
      _ref.read(eliteScheduleRepositoryProvider);

  Future<void> startSession(String schoolId, int durationHours) async {
    final session = SchedulingSession(
      id: const Uuid().v4(),
      schoolId: schoolId,
      status: SessionStatus.collecting,
      createdAt: DateTime.now(),
      deadline: DateTime.now().add(Duration(hours: durationHours)),
    );
    await _repo.createSession(session);
    // Future: Send Notifications to all teachers via Cloud Functions or NotificationService
  }

  Future<void> submitPreference({
    required String teacherId,
    required String schoolId,
    required String sessionId,
    required List<String> unwantedSlots,
  }) async {
    final pref = TeacherPreference(
      teacherId: teacherId,
      schoolId: schoolId,
      sessionId: sessionId,
      unwantedSlots: unwantedSlots,
      submittedAt: DateTime.now(),
    );
    await _repo.savePreference(pref);
  }

  Future<int> sendRemindersToNonSubmitters(
    String schoolId,
    String sessionId,
  ) async {
    // 1. Get all teachers
    final teachers = await _ref
        .read(firestoreTeacherRepositoryProvider)
        .getTeachers(schoolId: schoolId);

    // 2. Get submitted preferences
    final preferences = await _repo.getPreferences(schoolId, sessionId);
    final submittedIds = preferences.map((p) => p.teacherId).toSet();

    // 3. Identify missing
    final missingTeachers = teachers
        .where((t) => !submittedIds.contains(t.id))
        .toList();

    if (missingTeachers.isEmpty) return 0;

    // 4. Send reminders
    final missingIds = missingTeachers.map((t) => t.id).toList();
    await _repo.sendReminders(
      missingIds,
      'تذكير: تفضيلات الجدول المدرسي',
      'نرجو منكم سرعة إرسال رغباتكم للجدول المدرسي قبل انتهاء المهلة المحددة.',
    );

    return missingTeachers.length;
  }

  Future<void> closeAndGenerate(
    String schoolId,
    String sessionId, {
    bool force = false,
  }) async {
    final session = await _repo.getSession(schoolId, sessionId);

    // Safety Check: Prevent premature generation unless forced
    if (session.status == SessionStatus.collecting) {
      if (session.deadline != null &&
          DateTime.now().isBefore(session.deadline!) &&
          !force) {
        throw Exception(
          'لا يمكن إغلاق الجلسة قبل انتهاء الوقت المحدد (${session.deadline}). استخدم خيار "فرض الإغلاق" إذا كنت متأكداً.',
        );
      }
      // 1. Close session (State Transition)
      await _repo.updateSessionStatus(
        schoolId,
        sessionId,
        SessionStatus.closed,
      );
    } else if (session.status == SessionStatus.closed) {
      // Already closed, proceed to generation
    } else if (session.status == SessionStatus.generated) {
      // Allow re-generation if needed (Human Override scenario)
      if (!force) {
        // Optional: warning or allow silent re-gen
      }
    }

    // The actual generation logic continues in the UI or here.
    // Ideally, we mark it as 'generated' AFTER the algorithm runs successfully.
    // For now, we just ensure it's CLOSED.
  }
}
