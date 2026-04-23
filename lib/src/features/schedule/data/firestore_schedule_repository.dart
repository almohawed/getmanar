import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/schedule_slot.dart';
import '../domain/schedule_stats.dart';
import '../domain/teacher_constraints_profile.dart';
import 'schedule_repository.dart';

class FirestoreScheduleRepository implements ScheduleRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const String _teacherCollection = 'TeacherSchedules';
  static const String _classCollection = 'ClassSchedules';
  static const String _teacherEmergencyCollection = 'TeacherSchedulesEmergency';
  static const String _classEmergencyCollection = 'ClassSchedulesEmergency';
  static const String _variantSettingsDoc = 'schedule_variant';

  String _classDocId(String classId) {
    return classId.replaceAll('/', '_');
  }

  Future<String> _activeVariant(String schoolId) async {
    try {
      final doc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Settings')
          .doc(_variantSettingsDoc)
          .get();
      if (!doc.exists) return 'base';
      return (doc.data()?['active'] ?? 'base').toString();
    } catch (_) {
      return 'base';
    }
  }

  String _teacherCollectionForVariant(String variant) {
    return variant == 'emergency' ? _teacherEmergencyCollection : _teacherCollection;
  }

  String _classCollectionForVariant(String variant) {
    return variant == 'emergency' ? _classEmergencyCollection : _classCollection;
  }

  @override
  Future<void> saveSchedule(
    String schoolId,
    String teacherId,
    List<ScheduleSlot> schedule,
  ) async {
    // We store the schedule as a single document with a list of maps
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_teacherCollection)
        .doc(teacherId)
        .set({
          'slots': schedule.map((slot) => slot.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<List<ScheduleSlot>> getSchedule(
    String schoolId,
    String teacherId,
  ) async {
    final variant = await _activeVariant(schoolId);
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_teacherCollectionForVariant(variant))
        .doc(teacherId)
        .get();
    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null || !data.containsKey('slots')) return [];

    final slotsList = data['slots'] as List<dynamic>;
    return slotsList.map((item) => ScheduleSlot.fromMap(item)).toList();
  }

  @override
  Future<void> saveClassSchedule(
    String schoolId,
    String classId,
    List<ScheduleSlot> schedule,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_classCollection)
        .doc(_classDocId(classId))
        .set({
          'slots': schedule.map((slot) => slot.toMap()).toList(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<List<ScheduleSlot>> getClassSchedule(
    String schoolId,
    String classId,
  ) async {
    final variant = await _activeVariant(schoolId);
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection(_classCollectionForVariant(variant))
        .doc(_classDocId(classId))
        .get();
    if (!doc.exists) return [];

    final data = doc.data();
    if (data == null || !data.containsKey('slots')) return [];

    final slotsList = data['slots'] as List<dynamic>;
    return slotsList.map((item) => ScheduleSlot.fromMap(item)).toList();
  }

  @override
  Future<String> saveFullSchedule(
    String schoolId,
    Map<String, List<ScheduleSlot>> scheduleMap,
  ) async {
    final batch = _firestore.batch();

    // Save each teacher's schedule
    for (final entry in scheduleMap.entries) {
      final teacherId = entry.key;
      final slots = entry.value;

      final docRef = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection(_teacherCollection)
          .doc(teacherId);

      batch.set(docRef, {
        'slots': slots.map((slot) => slot.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    // Create a record in Timetables collection to track this version
    final timetableRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Timetables')
        .doc(); // Auto-ID

    batch.set(timetableRef, {
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'smart_schedule',
      'teacherCount': scheduleMap.length,
    });

    await batch.commit();
    return timetableRef.id;
  }

  @override
  Future<String> saveEmergencySchedule(
    String schoolId,
    Map<String, List<ScheduleSlot>> teacherScheduleMap,
    Map<String, List<ScheduleSlot>> classScheduleMap, {
    required Map<String, dynamic> metadata,
  }) async {
    final batch = _firestore.batch();

    for (final entry in teacherScheduleMap.entries) {
      final teacherId = entry.key;
      final slots = entry.value;
      final docRef = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection(_teacherEmergencyCollection)
          .doc(teacherId);
      batch.set(docRef, {
        'slots': slots.map((slot) => slot.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    for (final entry in classScheduleMap.entries) {
      final classId = entry.key;
      final slots = entry.value;
      final docRef = _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection(_classEmergencyCollection)
          .doc(_classDocId(classId));
      batch.set(docRef, {
        'slots': slots.map((slot) => slot.toMap()).toList(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    final timetableRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Timetables')
        .doc();

    batch.set(timetableRef, {
      'createdAt': FieldValue.serverTimestamp(),
      'source': 'emergency_plan',
      'variant': 'emergency',
      'teacherCount': teacherScheduleMap.length,
      'classCount': classScheduleMap.length,
      'metadata': metadata,
    });

    await batch.commit();
    return timetableRef.id;
  }

  @override
  Future<void> setActiveScheduleVariant(
    String schoolId,
    String variant, {
    String? emergencyTimetableId,
  }) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc(_variantSettingsDoc)
        .set({
          'active': variant,
          'emergencyTimetableId': emergencyTimetableId,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  @override
  Future<String> getActiveScheduleVariant(String schoolId) async {
    return _activeVariant(schoolId);
  }

  @override
  Future<void> publishSchedule(String schoolId) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('schedule_status')
        .set({
          'isPublished': true,
          'publishedAt': FieldValue.serverTimestamp(),
        });
  }

  @override
  Future<bool> isSchedulePublished(String schoolId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Settings')
        .doc('schedule_status')
        .get();
    if (!doc.exists) return false;
    return doc.data()?['isPublished'] ?? false;
  }

  @override
  Future<int> getTeacherLoad(String schoolId, String teacherId) async {
    final slots = await getSchedule(schoolId, teacherId);
    return slots.where((slot) {
      final s = slot.subject.trim();
      if (s.isEmpty) return false;
      final lower = s.toLowerCase();
      if (s.contains('منتظر')) return false;
      if (lower == 'activity' || s.contains('نشاط')) return false;
      return true;
    }).length;
  }

  @override
  Future<ScheduleStats> getScheduleStats(String schoolId) async {
    try {
      final schoolDoc = _firestore.collection('Schools').doc(schoolId);

      // 1. Get Classes Count
      final classesSnapshot = await schoolDoc.collection('Classes').get();
      final classesCount = classesSnapshot.size;

      // 2. Get Teachers Count
      final teachersCountQuery = await schoolDoc
          .collection('Teachers')
          .count()
          .get();
      final teachersCount = teachersCountQuery.count ?? 0;

      // 3. Check for Active Schedule (Timetables collection)
      final timetablesQuery = await schoolDoc
          .collection('Timetables')
          .limit(1)
          .get();
      final hasActiveSchedule = timetablesQuery.docs.isNotEmpty;

      // 4. Get Last Update from TimetableChanges
      final changesQuery = await schoolDoc
          .collection('TimetableChanges')
          .orderBy('createdAt', descending: true)
          .limit(1)
          .get();

      DateTime? lastUpdate;
      if (changesQuery.docs.isNotEmpty) {
        final data = changesQuery.docs.first.data();
        if (data['createdAt'] is Timestamp) {
          lastUpdate = (data['createdAt'] as Timestamp).toDate();
        }
      }

      // 5. Active Schedules Count (Teachers with schedules)
      final activeSchedulesQuery = await schoolDoc
          .collection(_teacherCollection)
          .count()
          .get();
      final activeSchedulesCount = activeSchedulesQuery.count ?? 0;

      return ScheduleStats(
        classesCount: classesCount,
        teachersCount: teachersCount,
        hasActiveSchedule: hasActiveSchedule,
        lastUpdate: lastUpdate,
        activeSchedulesCount: activeSchedulesCount,
      );
    } catch (e) {
      // In case of error (e.g. permission denied or collection missing), return empty stats
      // You might want to log this error
      print('Error fetching schedule stats: $e');
      return ScheduleStats.empty();
    }
  }

  @override
  Future<List<TeacherConstraintsProfile>> getTeacherConstraints(
    String schoolId,
  ) async {
    final query = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('TeacherConstraints')
        .get();

    return query.docs
        .map((d) => TeacherConstraintsProfile.fromMap(d.data(), d.id))
        .toList();
  }

  @override
  Future<void> saveTeacherConstraints(TeacherConstraintsProfile profile) async {
    await _firestore
        .collection('Schools')
        .doc(profile.schoolId)
        .collection('TeacherConstraints')
        .doc(profile.teacherId) // Use teacherId as document ID for easy lookup
        .set(profile.toMap(), SetOptions(merge: true));
  }
}
