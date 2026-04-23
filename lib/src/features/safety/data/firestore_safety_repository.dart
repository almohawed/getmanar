import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';

class SafetySettings {
  final String meetingPoint;
  final String evacuationOfficer;
  final int? camerasActive;
  final int? camerasTotal;
  final bool? alarmsReady;
  final DateTime? updatedAt;

  const SafetySettings({
    required this.meetingPoint,
    required this.evacuationOfficer,
    required this.camerasActive,
    required this.camerasTotal,
    required this.alarmsReady,
    required this.updatedAt,
  });

  factory SafetySettings.empty() => const SafetySettings(
        meetingPoint: '',
        evacuationOfficer: '',
        camerasActive: null,
        camerasTotal: null,
        alarmsReady: null,
        updatedAt: null,
      );

  factory SafetySettings.fromMap(Map<String, dynamic> map) {
    DateTime? asDateTime(dynamic v) {
      if (v == null) return null;
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return null;
    }

    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.toInt();
      return int.tryParse(v.toString());
    }

    return SafetySettings(
      meetingPoint: (map['meetingPoint'] as String?)?.trim() ?? '',
      evacuationOfficer: (map['evacuationOfficer'] as String?)?.trim() ?? '',
      camerasActive: asInt(map['camerasActive']),
      camerasTotal: asInt(map['camerasTotal']),
      alarmsReady: map['alarmsReady'] as bool?,
      updatedAt: asDateTime(map['updatedAt']),
    );
  }
}

class SafetyGuard {
  final String id;
  final String staffId;
  final String name;
  final String location;
  final String status;
  final DateTime? updatedAt;

  const SafetyGuard({
    required this.id,
    required this.staffId,
    required this.name,
    required this.location,
    required this.status,
    required this.updatedAt,
  });

  factory SafetyGuard.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['updatedAt'];
    final dt = ts is Timestamp ? ts.toDate() : null;
    return SafetyGuard(
      id: doc.id,
      staffId: (data['staffId'] as String?)?.trim() ?? '',
      name: (data['name'] as String?)?.trim() ?? '',
      location: (data['location'] as String?)?.trim() ?? '',
      status: (data['status'] as String?)?.trim() ?? 'غير محدد',
      updatedAt: dt,
    );
  }
}

class FirestoreSafetyRepository {
  final FirebaseFirestore _firestore;

  FirestoreSafetyRepository(this._firestore);

  DocumentReference<Map<String, dynamic>> _settingsDoc(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Safety')
        .doc('settings');
  }

  CollectionReference<Map<String, dynamic>> _guardsCollection(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('SafetyGuards');
  }

  Stream<SafetySettings?> watchSettings(String schoolId) {
    return _settingsDoc(schoolId).snapshots().map((snap) {
      final data = snap.data();
      if (data == null) return SafetySettings.empty();
      return SafetySettings.fromMap(data);
    });
  }

  Future<void> upsertSettings(
    String schoolId, {
    String? meetingPoint,
    String? evacuationOfficer,
    int? camerasActive,
    int? camerasTotal,
    bool? alarmsReady,
  }) async {
    final data = <String, dynamic>{
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (meetingPoint != null) data['meetingPoint'] = meetingPoint.trim();
    if (evacuationOfficer != null) {
      data['evacuationOfficer'] = evacuationOfficer.trim();
    }
    if (camerasActive != null) data['camerasActive'] = camerasActive;
    if (camerasTotal != null) data['camerasTotal'] = camerasTotal;
    if (alarmsReady != null) data['alarmsReady'] = alarmsReady;

    await _settingsDoc(schoolId).set(data, SetOptions(merge: true));
  }

  Stream<List<SafetyGuard>> watchGuards(String schoolId) {
    return _guardsCollection(schoolId)
        .orderBy('name')
        .snapshots()
        .map(
          (snap) => snap.docs.map(SafetyGuard.fromDoc).toList(),
        );
  }

  Future<void> upsertGuard(
    String schoolId, {
    required String guardId,
    required String staffId,
    required String name,
    required String location,
    required String status,
  }) async {
    await _guardsCollection(schoolId).doc(guardId).set(
      {
        'staffId': staffId.trim(),
        'name': name.trim(),
        'location': location.trim(),
        'status': status.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> deleteGuard(String schoolId, String guardId) async {
    await _guardsCollection(schoolId).doc(guardId).delete();
  }
}

final safetyRepositoryProvider = Provider<FirestoreSafetyRepository>((ref) {
  return FirestoreSafetyRepository(FirebaseFirestore.instance);
});

final safetySettingsProvider = StreamProvider.autoDispose<SafetySettings?>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return ref.watch(safetyRepositoryProvider).watchSettings(schoolId);
});

final safetyGuardsProvider = StreamProvider.autoDispose<List<SafetyGuard>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty) return const Stream.empty();
  return ref.watch(safetyRepositoryProvider).watchGuards(schoolId);
});

