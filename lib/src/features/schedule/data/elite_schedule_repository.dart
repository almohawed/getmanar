import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart'; // For debugPrint
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/scheduling_session.dart';
import '../domain/teacher_preference.dart';

final eliteScheduleRepositoryProvider = Provider<EliteScheduleRepository>((
  ref,
) {
  return EliteScheduleRepository(FirebaseFirestore.instance);
});

class EliteScheduleRepository {
  final FirebaseFirestore _firestore;

  EliteScheduleRepository(this._firestore);

  // --- Session Management ---

  Stream<SchedulingSession?> watchCurrentSession(String schoolId) {
    debugPrint(
      'PROOF_LOG: Watching session for school $schoolId in collection Schools/schedulingSessions',
    );
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('schedulingSessions')
        .orderBy('createdAt', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) {
            debugPrint('PROOF_LOG: No session found for school $schoolId');
            return null;
          }
          try {
            final data = snapshot.docs.first.data();
            data['id'] = snapshot.docs.first.id; // Ensure ID is set
            debugPrint(
              'PROOF_LOG: Found session ${data['id']} with status ${data['status']}',
            );
            return SchedulingSession.fromMap(data);
          } catch (e) {
            debugPrint('Error parsing SchedulingSession: $e');
            // Return null or rethrow?
            // If we return null, the UI treats it as "Open State" (Start new session) which is better than crashing.
            return null;
          }
        });
  }

  Future<void> createSession(SchedulingSession session) async {
    await _firestore
        .collection('schools')
        .doc(session.schoolId)
        .collection('schedulingSessions')
        .doc(session.id)
        .set(session.toMap());
  }

  Future<void> updateSessionStatus(
    String schoolId,
    String sessionId,
    SessionStatus status,
  ) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('schedulingSessions')
        .doc(sessionId)
        .update({'status': status.name});
  }

  Future<SchedulingSession> getSession(
    String schoolId,
    String sessionId,
  ) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('schedulingSessions')
        .doc(sessionId)
        .get();

    if (!doc.exists) {
      throw Exception('Session not found');
    }
    final data = doc.data()!;
    data['id'] = doc.id;
    return SchedulingSession.fromMap(data);
  }

  // --- Preferences ---

  Future<void> savePreference(TeacherPreference pref) async {
    await _firestore
        .collection('Schools')
        .doc(pref.schoolId)
        .collection('schedulingSessions')
        .doc(pref.sessionId)
        .collection('preferences')
        .doc(pref.teacherId)
        .set(pref.toMap());
  }

  Stream<int> watchSubmittedCount(String schoolId, String sessionId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('schedulingSessions')
        .doc(sessionId)
        .collection('preferences')
        .snapshots()
        .map((s) => s.docs.length);
  }

  Future<List<TeacherPreference>> getPreferences(
    String schoolId,
    String sessionId,
  ) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('schedulingSessions')
        .doc(sessionId)
        .collection('preferences')
        .get();

    return snapshot.docs
        .map((d) => TeacherPreference.fromMap(d.data()))
        .toList();
  }

  Future<void> sendReminders(
    List<String> teacherIds,
    String title,
    String body,
  ) async {
    // Process in chunks of 500 to respect Firestore batch limits
    for (var i = 0; i < teacherIds.length; i += 500) {
      final batch = _firestore.batch();
      final end = (i + 500 < teacherIds.length) ? i + 500 : teacherIds.length;
      final chunk = teacherIds.sublist(i, end);

      for (final id in chunk) {
        // Using GlobalUsers for notifications as it's the central user record
        final ref = _firestore
            .collection('GlobalUsers')
            .doc(id)
            .collection('notifications')
            .doc();

        batch.set(ref, {
          'title': title,
          'body': body,
          'createdAt': FieldValue.serverTimestamp(),
          'read': false,
          'type': 'reminder',
        });
      }
      await batch.commit();
    }
  }
}
