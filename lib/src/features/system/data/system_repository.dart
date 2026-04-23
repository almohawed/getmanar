import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/system_settings.dart';

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  return FirestoreSystemRepository(ref);
});

abstract class SystemRepository {
  Stream<SystemSettings> watchSystemSettings(String schoolId);
  Future<void> updateSystemSettings(SystemSettings settings);
}

class FirestoreSystemRepository implements SystemRepository {
  final Ref _ref;

  FirestoreSystemRepository(this._ref);

  String? get _schoolId {
    final user = _ref.read(authStateProvider).value;
    return user?.schoolId;
  }

  @override
  Stream<SystemSettings> watchSystemSettings(String schoolId) {
    if (schoolId.isEmpty) return Stream.value(const SystemSettings());

    return FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('System')
        .doc('GeneralSettings')
        .snapshots()
        .map((snapshot) {
          if (!snapshot.exists || snapshot.data() == null) {
            return const SystemSettings();
          }
          return SystemSettings.fromJson(snapshot.data()!);
        });
  }

  @override
  Future<void> updateSystemSettings(SystemSettings settings) async {
    final schoolId = _schoolId;
    if (schoolId == null) throw Exception('No school ID found');

    await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('System')
        .doc('GeneralSettings')
        .set(settings.toJson(), SetOptions(merge: true));
  }
}
