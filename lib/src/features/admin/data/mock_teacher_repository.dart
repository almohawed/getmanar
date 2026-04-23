import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/data/mock_data.dart'; // Import mock data
import '../domain/teacher_repository.dart';
export '../domain/teacher_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import 'firestore_teacher_repository.dart';
export 'firestore_teacher_repository.dart';

class MockTeacherRepository implements TeacherRepository {
  // Initialize with teachers from mock_data.dart
  final List<User> _teachers = [...mockTeachers];
  bool _isInitialized = false;

  MockTeacherRepository() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/teachers.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _teachers.clear();
        _teachers.addAll(jsonList.map((e) => User.fromMap(e)).toList());
      } else {
        await _saveToDisk();
      }
    } catch (e) {
      debugPrint('Error initializing teachers: $e');
    }
    _isInitialized = true;
  }

  Future<void> _saveToDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/teachers.json');
      final jsonList = _teachers.map((t) => t.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving teachers: $e');
    }
  }

  Future<void> _syncTeacherToFirebase(User teacher) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(teacher.id)
            .set(
              teacher.toMap()
                ..addAll({'updatedAt': FieldValue.serverTimestamp()}),
            );
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Teacher): $e');
    }
  }

  Future<void> _deleteTeacherFromFirebase(String teacherId) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(teacherId)
            .delete();
      }
    } catch (e) {
      debugPrint('Firebase Delete Error (Teacher): $e');
    }
  }

  @override
  Future<TeacherProvisioningResult> addTeacher(
    User teacher,
    String password,
  ) async {
    await _init();
    // 1. Update Memory
    _teachers.add(teacher);

    // 2. Persist Local
    await _saveToDisk();

    // 3. Sync Remote (Fire & Forget)
    _syncTeacherToFirebase(teacher);

    debugPrint('Teacher added: ${teacher.name} with password: $password');
    return TeacherProvisioningResult(
      uid: teacher.id,
      mnCode: teacher.mnCode ?? '',
      password: password,
    );
  }

  @override
  Future<void> updateTeacher(User teacher) async {
    await _init();
    final index = _teachers.indexWhere((t) => t.id == teacher.id);
    if (index != -1) {
      _teachers[index] = teacher;
      await _saveToDisk();
      _syncTeacherToFirebase(teacher);
    }
  }

  @override
  Future<List<User>> getTeachers({String? schoolId}) async {
    await _init();
    if (schoolId != null && schoolId.isNotEmpty) {
      return _teachers.where((t) => t.schoolId == schoolId).toList();
    }
    return _teachers;
  }

  @override
  Future<void> deleteTeacher(String teacherId) async {
    await _init();
    _teachers.removeWhere((t) => t.id == teacherId);
    await _saveToDisk();
    _deleteTeacherFromFirebase(teacherId);
  }

  @override
  Future<void> deleteTeachers(List<String> teacherIds) async {
    await _init();
    _teachers.removeWhere((t) => teacherIds.contains(t.id));
    await _saveToDisk();
    for (var id in teacherIds) {
      _deleteTeacherFromFirebase(id);
    }
  }
}

// Provider
final mockTeacherRepositoryProvider = Provider<TeacherRepository>((ref) {
  return MockTeacherRepository();
});

final firestoreTeacherRepositoryProvider = Provider<FirestoreTeacherRepository>(
  (ref) {
    return FirestoreTeacherRepository(FirebaseFirestore.instance);
  },
);

final teachersProvider = FutureProvider<List<User>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (user == null || schoolId.isEmpty) return const <User>[];
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('listTeachersForSchool');
    final res = await callable.call({'schoolId': schoolId});
    final data = res.data;
    if (data is Map && data['teachers'] is List) {
      final list = (data['teachers'] as List)
          .whereType<Map>()
          .map((m) => User.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      list.sort((a, b) => a.name.compareTo(b.name));
      return list;
    }
    return const <User>[];
  } catch (_) {
    return const <User>[];
  }
});
