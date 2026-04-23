import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'firestore_staff_repository.dart';
export 'firestore_staff_repository.dart';
import 'staff_repository.dart';

export 'staff_repository.dart';

class MockStaffRepository implements StaffRepository {
  final List<User> _staff = [];
  bool _isInitialized = false;

  MockStaffRepository() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/staff.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _staff.clear();
        _staff.addAll(jsonList.map((e) => User.fromMap(e)).toList());
      } else {
        await _saveToDisk();
      }
    } catch (e) {}
    _isInitialized = true;
  }

  Future<void> _saveToDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/staff.json');
      final jsonList = _staff.map((t) => t.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {}
  }

  @override
  Future<StaffProvisioningResult> addStaff(User user, String password) async {
    await _init();
    _staff.add(user);
    await _saveToDisk();
    return StaffProvisioningResult(
      uid: user.id,
      mnCode: user.mnCode ?? '',
      password: password,
    );
  }

  @override
  Future<List<User>> getStaffByRole(UserRole role) async {
    await _init();
    return _staff.where((u) => u.role == role).toList();
  }

  @override
  Future<List<User>> getAllStaff() async {
    await _init();
    return _staff;
  }

  @override
  Future<void> deleteStaff(List<String> ids) async {
    await _init();
    _staff.removeWhere((t) => ids.contains(t.id));
    await _saveToDisk();
  }

  @override
  Stream<List<User>> watchAllStaff(String schoolId) {
    return Stream.value(_staff);
  }

  @override
  Stream<List<User>> watchSupportStaff(String schoolId) {
    return Stream.value(
      _staff
          .where(
            (u) =>
                u.role == UserRole.supportAdmin ||
                u.role == UserRole.technicalSupport,
          )
          .toList(),
    );
  }

  @override
  Future<void> createSupportUser({
    required String email,
    required String password,
    required String name,
    required String role,
    required String schoolId,
  }) async {
    await _init();
    final userRole = role == 'support_admin'
        ? UserRole.supportAdmin
        : UserRole.technicalSupport;

    final newUser = User(
      id: 'mock_${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: name,
      role: userRole,
      schoolId: schoolId,
    );

    _staff.add(newUser);
    await _saveToDisk();
  }

  @override
  Future<void> deleteSupportUser({
    required String uid,
    required String schoolId,
  }) async {
    await deleteStaff([uid]);
  }

  @override
  Future<void> updateStaff(User user) async {
    await _init();
    final index = _staff.indexWhere((u) => u.id == user.id);
    if (index != -1) {
      _staff[index] = user;
      await _saveToDisk();
    }
  }
}

final mockStaffRepositoryProvider = Provider<StaffRepository>((ref) {
  return MockStaffRepository();
});

final firestoreStaffRepositoryProvider = Provider<FirestoreStaffRepository>((
  ref,
) {
  return FirestoreStaffRepository(FirebaseFirestore.instance);
});

final staffRepositoryProvider = Provider<StaffRepository>((ref) {
  // Return Firestore repo by default for production features
  // Ideally this should be configurable or based on auth state if we want to switch
  return ref.watch(firestoreStaffRepositoryProvider);
});

final staffProvider = StreamProvider.autoDispose<List<User>>((ref) async* {
  final userState = ref.watch(authStateProvider);
  final user = userState.value;

  if (user != null && (user.schoolId?.isNotEmpty ?? false)) {
    final repo = ref.watch(firestoreStaffRepositoryProvider);
    await for (final staff in repo.watchAllStaff(user.schoolId!)) {
      yield staff
          .where(
            (u) =>
                u.role == UserRole.admin ||
                u.role == UserRole.administrative ||
                u.role == UserRole.deputy ||
                u.role == UserRole.counselor,
          )
          .toList();
    }
  } else {
    yield const <User>[];
  }
});
