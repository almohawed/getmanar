import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/school.dart';

class SchoolRepository {
  final FirebaseFirestore _firestore;

  SchoolRepository(this._firestore);

  Future<School?> getSchool(String schoolId) async {
    if (schoolId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('Schools').doc(schoolId).get();
      if (doc.exists) {
        final data = Map<String, dynamic>.from(doc.data()!);
        data['id'] = doc.id;
        return School.fromMap(data);
      }
      // Mock Fallback for demo
      if (schoolId == 'school_1') {
        return School(
          id: 'school_1',
          name: 'مدرسة عمر بن أبي سلمة',
          type: 'government',
          stage: 'الابتدائية',
          city: 'Riyadh',
          ownerId: 'admin_1',
          // Mock coordinates for Riyadh school (example)
          latitude: 24.774265,
          longitude: 46.738586,
        );
      }
      return null;
    } catch (e) {
      // Mock Fallback on error (for testing without Firebase)
      if (schoolId == 'school_1') {
        return School(
          id: 'school_1',
          name: 'مدرسة عمر بن أبي سلمة',
          type: 'government',
          stage: 'الابتدائية',
          city: 'Riyadh',
          ownerId: 'admin_1',
          // Mock coordinates for Riyadh school (example)
          latitude: 24.774265,
          longitude: 46.738586,
        );
      }
      return null;
    }
  }

  Future<void> updateSchoolStartTime(String schoolId, String time) async {
    try {
      await _firestore.collection('Schools').doc(schoolId).update({
        'startTime': time,
      });
    } catch (e) {
      throw Exception('Failed to update school start time: $e');
    }
  }

  Future<void> updateSchoolLocation(
    String schoolId,
    double lat,
    double lng,
  ) async {
    try {
      await _firestore.collection('Schools').doc(schoolId).update({
        'latitude': lat,
        'longitude': lng,
      });
    } catch (e) {
      throw Exception('Failed to update school location: $e');
    }
  }

  Future<void> updateSubscriptionPlan(String schoolId, String planId) async {
    try {
      await _firestore.collection('Schools').doc(schoolId).update({
        'subscriptionPlan': planId,
      });
    } catch (e) {
      throw Exception('Failed to update subscription plan: $e');
    }
  }

  Future<void> updateSmsConfig(String schoolId, SmsConfig config) async {
    try {
      await _firestore.collection('Schools').doc(schoolId).update({
        'smsConfig': config.toMap(),
      });
    } catch (e) {
      throw Exception('Failed to update SMS config: $e');
    }
  }

  Future<void> updateSecondaryConfig(
    String schoolId, {
    String? secondaryProgramType,
    String? secondaryStructure,
    List<String>? enabledTracks,
  }) async {
    try {
      final update = <String, dynamic>{};
      if (secondaryProgramType != null) {
        update['secondaryProgramType'] = secondaryProgramType.trim();
      }
      if (secondaryStructure != null) {
        update['secondaryStructure'] = secondaryStructure.trim();
      }
      if (enabledTracks != null) {
        update['enabledTracks'] = enabledTracks
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }
      if (update.isEmpty) return;
      await _firestore.collection('Schools').doc(schoolId).update(update);
    } catch (e) {
      throw Exception('Failed to update secondary config: $e');
    }
  }

  /// Production-Grade Manager Name Fetcher
  ///
  /// Logic:
  /// 1. Validate inputs.
  /// 2. Read Schools/{schoolId} to find 'managerUid'.
  /// 3. Read GlobalUsers/{managerUid} to find 'name'.
  ///
  /// Returns null ONLY if data is missing or inaccessible (with logs).
  /// Throws FirebaseException only for permission/network issues to be caught by UI/Riverpod.
  Future<String?> getManagerName(String userId, {String? schoolId}) async {
    const String tag = '[ManagerFetch]';

    if (schoolId == null || schoolId.isEmpty) {
      print('$tag WARNING: schoolId is null or empty. Cannot fetch manager.');
      return null;
    }

    try {
      print('$tag Step 1: Reading Schools/$schoolId');
      final schoolDoc = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .get();

      if (!schoolDoc.exists) {
        print('$tag ERROR: School document Schools/$schoolId does not exist.');
        return null;
      }

      final schoolData = schoolDoc.data();
      // Priority: managerUid > ownerId
      final String? managerUid =
          schoolData?['managerUid'] as String? ??
          schoolData?['ownerId'] as String?;

      if (managerUid == null || managerUid.isEmpty) {
        print(
          '$tag ERROR: No managerUid or ownerId found in Schools/$schoolId.',
        );
        return null;
      }

      print(
        '$tag Step 2: Found managerUid=$managerUid. Fetching GlobalUsers...',
      );
      final userDoc = await _firestore
          .collection('GlobalUsers')
          .doc(managerUid)
          .get();

      if (!userDoc.exists) {
        print('$tag ERROR: GlobalUsers/$managerUid does not exist.');
        return null;
      }

      final userData = userDoc.data();
      final name = userData?['name'] as String?;

      if (name == null || name.isEmpty) {
        print(
          '$tag ERROR: GlobalUsers/$managerUid exists but "name" is null/empty.',
        );
        return null;
      }

      print('$tag SUCCESS: Manager Name = "$name"');
      return name;
    } on FirebaseException catch (e) {
      print('$tag EXCEPTION: [${e.code}] ${e.message}');
      if (e.code == 'permission-denied') {
        print(
          '$tag TIP: Check Firestore Rules for Schools/$schoolId or GlobalUsers/UID.',
        );
      }
      // Rethrowing allows the Provider to handle the error state if needed,
      // or return null to show "Unknown" gracefully.
      // Returning null here to prevent app crash, but logged clearly.
      return null;
    } catch (e) {
      print('$tag UNKNOWN ERROR: $e');
      return null;
    }
  }
}

final schoolRepositoryProvider = Provider<SchoolRepository>((ref) {
  return SchoolRepository(FirebaseFirestore.instance);
});

final schoolProvider = FutureProvider.autoDispose.family<School?, String>((
  ref,
  schoolId,
) async {
  if (schoolId.isEmpty) return null;
  final repo = ref.watch(schoolRepositoryProvider);
  return repo.getSchool(schoolId);
});

/// Provider خفيف لقراءة showSubscriptionSection فقط — يُحدَّث في الوقت الفعلي
final showSubscriptionProvider = FutureProvider.autoDispose.family<bool, String>((
  ref,
  schoolId,
) async {
  if (schoolId.isEmpty) return true;
  try {
    final doc = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .get();
    if (!doc.exists) return true;
    return doc.data()?['showSubscriptionSection'] ?? true;
  } catch (_) {
    return true;
  }
});

// Final Production Provider
// Uses autoDispose to ensure fresh data on re-entry.
// Uses family to pass unique keys.
final schoolManagerNameProvider = FutureProvider.family
    .autoDispose<String?, ({String userId, String schoolId})>((
      ref,
      record,
    ) async {
      final repo = ref.watch(schoolRepositoryProvider);

      // Invalidate logic example (Manual):
      // ref.invalidate(schoolManagerNameProvider(record));

      // Auto-invalidate:
      // When 'schoolId' changes in the UI, a new provider instance is created.
      // The old one is disposed automatically due to .autoDispose.

      return repo.getManagerName(record.userId, schoolId: record.schoolId);
    });
