import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../domain/models/student_case.dart';
import '../domain/models/counselor_session.dart';
import '../domain/models/behavior_plan.dart';
import '../domain/models/audit_log_entry.dart';
import '../../admin_tasks/domain/admin_task_entity.dart';
import '../../admin_tasks/data/admin_task_model.dart';

class FirestoreCounselorRepository {
  final FirebaseFirestore _firestore;

  FirestoreCounselorRepository(this._firestore);

  // Student Cases
  Stream<List<StudentCase>> watchActiveCases(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StudentCases')
        .where(
          'status',
          whereIn: [CaseStatus.open.name, CaseStatus.in_progress.name],
        )
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => StudentCase.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Today's Sessions
  Stream<List<CounselorSession>> watchTodaySessions(String schoolId) {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = DateTime(now.year, now.month, now.day, 23, 59, 59);

    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CounselorSessions')
        .where(
          'scheduledAt',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('scheduledAt', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CounselorSession.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Active Plans - Get ALL plans without status filter to debug
  Stream<List<BehaviorPlan>> watchActivePlans(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('BehaviorPlans')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BehaviorPlan.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Counselor Admin Tasks
  Stream<List<AdminTaskEntity>> watchCounselorTasks(String schoolId) {
    // Assuming 'counselor' is the role identifier for counselors
    // Adjust logic if tasks are assigned to specific user IDs instead of role
    final query = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('AdminTasks')
        .where('assignedToRole', isEqualTo: 'counselor')
        .where('status', whereIn: ['open', 'in_progress', 'overdue'])
        .orderBy('dueDate', descending: false);

    return query.snapshots().map((snapshot) {
      return snapshot.docs.map((doc) {
        return AdminTaskModel.fromFirestore(doc);
      }).toList();
    });
  }

  // Write Methods

  Future<void> createSession(
    CounselorSession session, {
    required String userId,
    required String role,
  }) async {
    final batch = _firestore.batch();

    // 1. Create Session
    final sessionRef = _firestore
        .collection('Schools')
        .doc(session.schoolId)
        .collection('CounselorSessions')
        .doc(session.id);
    batch.set(sessionRef, session.toMap());

    // 2. Create Audit Log
    await _addAuditLogToBatch(
      batch: batch,
      schoolId: session.schoolId,
      action: 'create',
      performedBy: userId,
      performedByRole: role,
      targetType: 'session',
      targetId: session.id,
      diff: null, // No diff for creation
      details: {
        'title': session.isConfidential
            ? '*** CONFIDENTIAL ***'
            : session.title,
        'isConfidential': session.isConfidential,
        // Exclude sensitive details
      },
    );

    await batch.commit();
  }

  Future<void> updateSession(
    CounselorSession session, {
    required String userId,
    required String role,
  }) async {
    // Fetch old session for Diff
    final sessionRef = _firestore
        .collection('Schools')
        .doc(session.schoolId)
        .collection('CounselorSessions')
        .doc(session.id);

    final oldDoc = await sessionRef.get();
    Map<String, dynamic>? diff;

    if (oldDoc.exists) {
      final oldData = oldDoc.data() as Map<String, dynamic>;
      diff = _calculateDiff(oldData, session.toMap(), session.isConfidential);
    }

    final batch = _firestore.batch();

    // 1. Update Session
    batch.update(sessionRef, session.toMap());

    // 2. Create Audit Log
    await _addAuditLogToBatch(
      batch: batch,
      schoolId: session.schoolId,
      action: 'update',
      performedBy: userId,
      performedByRole: role,
      targetType: 'session',
      targetId: session.id,
      diff: diff,
      details: {'isConfidential': session.isConfidential},
    );

    await batch.commit();
  }

  Future<void> logViewSession({
    required String schoolId,
    required String sessionId,
    required String userId,
    required String role,
    required bool isConfidential,
    bool isEmergencyAccess = false,
  }) async {
    final batch = _firestore.batch();

    await _addAuditLogToBatch(
      batch: batch,
      schoolId: schoolId,
      action: isEmergencyAccess ? 'emergency_view' : 'view',
      performedBy: userId,
      performedByRole: role,
      targetType: 'session',
      targetId: sessionId,
      details: {
        'isConfidential': isConfidential,
        'isEmergencyAccess': isEmergencyAccess,
      },
    );

    await batch.commit();
  }

  // Fetch single session (useful for Emergency Access)
  Future<CounselorSession?> getSessionDetails({
    required String schoolId,
    required String sessionId,
    required String userId,
    required String role,
    bool isEmergencyAccess = false,
  }) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CounselorSessions')
        .doc(sessionId)
        .get();

    if (!doc.exists) return null;

    final session = CounselorSession.fromMap(doc.data()!, doc.id);

    // Log the view
    await logViewSession(
      schoolId: schoolId,
      sessionId: sessionId,
      userId: userId,
      role: role,
      isConfidential: session.isConfidential,
      isEmergencyAccess: isEmergencyAccess,
    );

    return session;
  }

  // --- Helper Methods ---

  Future<void> _addAuditLogToBatch({
    required WriteBatch batch,
    required String schoolId,
    required String action,
    required String performedBy,
    required String performedByRole,
    required String targetType,
    required String targetId,
    Map<String, dynamic>? diff,
    Map<String, dynamic>? details,
  }) async {
    final auditRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('AuditLogs')
        .doc(); // Auto-ID

    final deviceInfo = await _getDeviceInfo();

    final entry = AuditLogEntry(
      id: auditRef.id,
      action: action,
      performedBy: performedBy,
      performedByRole: performedByRole,
      schoolId: schoolId,
      targetType: targetType,
      targetId: targetId,
      timestamp: DateTime.now(),
      deviceInfo: deviceInfo,
      clientVersion: '1.0.0', // TODO: Get from package_info_plus if needed
      diff: diff,
      details: details,
    );

    batch.set(auditRef, entry.toMap());
  }

  Map<String, dynamic> _calculateDiff(
    Map<String, dynamic> oldData,
    Map<String, dynamic> newData,
    bool isConfidential,
  ) {
    final diff = <String, dynamic>{};
    // Sensitive fields that should NEVER be shown in diff
    final sensitiveFields = {
      'description',
      'notes',
      'medicalInfo',
      'studentName',
      'reason',
      'diagnosis',
      'recommendations',
      'attachments',
    };

    // If confidential, even the title is sensitive if changed
    if (isConfidential) {
      sensitiveFields.add('title');
    }

    // Check for changes
    for (var key in newData.keys) {
      // Skip if value hasn't changed
      if (oldData[key] == newData[key]) continue;

      // If sensitive, just mark as changed
      if (sensitiveFields.contains(key)) {
        diff[key] = {'old': '***', 'new': '*** (Changed)'};
      } else {
        // Record actual change for non-sensitive fields
        diff[key] = {'old': oldData[key], 'new': newData[key]};
      }
    }

    return diff;
  }

  Future<String> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return 'Web: ${webInfo.browserName}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'Android: ${androidInfo.model} (${androidInfo.device})';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'iOS: ${iosInfo.utsname.machine}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return 'Windows: ${windowsInfo.computerName}';
      }
      return 'Unknown Device';
    } catch (e) {
      return 'Unknown Device (Error)';
    }
  }

  Future<void> createCase(StudentCase studentCase) async {
    await _firestore
        .collection('Schools')
        .doc(studentCase.schoolId)
        .collection('StudentCases')
        .doc(studentCase.id)
        .set(studentCase.toMap());
  }

  Future<void> updateCase(StudentCase studentCase) async {
    await _firestore
        .collection('Schools')
        .doc(studentCase.schoolId)
        .collection('StudentCases')
        .doc(studentCase.id)
        .update(studentCase.toMap());
  }

  Future<void> addCaseFollowUp({
    required String schoolId,
    required String caseId,
    required String notes,
    String? nextStep,
    required String createdBy,
  }) async {
    final followUps = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StudentCases')
        .doc(caseId)
        .collection('FollowUps');

    await followUps.add({
      'notes': notes.trim(),
      'nextStep': nextStep?.trim(),
      'createdBy': createdBy.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });

    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StudentCases')
        .doc(caseId)
        .set(
      {'updatedAt': FieldValue.serverTimestamp()},
      SetOptions(merge: true),
    );
  }

  Future<void> createPlan(BehaviorPlan plan) async {
    await _firestore
        .collection('Schools')
        .doc(plan.schoolId)
        .collection('BehaviorPlans')
        .doc(plan.id)
        .set(plan.toMap());
  }

  Future<void> updatePlan(BehaviorPlan plan) async {
    await _firestore
        .collection('Schools')
        .doc(plan.schoolId)
        .collection('BehaviorPlans')
        .doc(plan.id)
        .update(plan.toMap());
  }
}
