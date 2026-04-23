import 'dart:async';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../data/mock_data.dart';
import 'student_repository.dart';

class MockStudentRepository implements StudentRepository {
  final List<User> _students = [...mockStudents];
  final _controller = StreamController<List<User>>.broadcast();
  bool _isInitialized = false;

  MockStudentRepository() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/students.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _students.clear();
        _students.addAll(jsonList.map((e) => User.fromMap(e)).toList());
      } else {
        await _saveToDisk();
      }
      _controller.add(_students);

      // Also try to fetch from Firebase to sync remote changes
      _syncFromFirebase();
    } catch (e) {
      debugPrint('Error initializing students: $e');
    }
    _isInitialized = true;
  }

  Future<void> _syncFromFirebase() async {
    try {
      if (Firebase.apps.isNotEmpty) {
        final query = await FirebaseFirestore.instance
            .collectionGroup('Users')
            .where('role', isEqualTo: 'student')
            .get();
        if (query.docs.isNotEmpty) {
          final remoteStudents = query.docs
              .map((d) => User.fromMap(d.data()))
              .toList();
          // Merge strategy: Remote wins if conflict, or just add new ones
          for (var remote in remoteStudents) {
            final index = _students.indexWhere((s) => s.id == remote.id);
            if (index != -1) {
              _students[index] = remote;
            } else {
              _students.add(remote);
            }
          }
          await _saveToDisk();
        }
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Student Read): $e');
    }
  }

  Future<void> _saveToDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/students.json');
      final jsonList = _students.map((t) => t.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
      _controller.add(_students);
    } catch (e) {
      debugPrint('Error saving students: $e');
    }
  }

  Future<void> _syncStudentToFirebase(String schoolId, User student) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Users')
            .doc(student.id)
            .set(student.toMap());
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Student Write): $e');
    }
  }

  @override
  Future<User?> findStudentByCode(String schoolId, String studentCode) async {
    try {
      return _students.firstWhere((s) => s.studentCode == studentCode);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<User?> findStudentByIdentity(
    String schoolId,
    String identityNumber,
  ) async {
    try {
      return _students.firstWhere((s) => s.identityNumber == identityNumber);
    } catch (_) {
      return null;
    }
  }

  @override
  Stream<List<User>> watchStudents(String schoolId) {
    if (!_isInitialized) _init();
    return _controller.stream.map((students) {
      return students.where((s) => s.schoolId == schoolId).toList();
    });
  }

  @override
  Future<User?> getStudentById(String schoolId, String studentId) async {
    try {
      return _students.firstWhere((s) => s.id == studentId);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<User>> getStudentsByParentPhone(
    String schoolId,
    String parentPhone,
  ) async {
    return _students.where((s) => s.phoneNumber == parentPhone).toList();
  }

  @override
  Future<void> addStudent(String schoolId, User student, String password) async {
    await _init();
    _students.add(student);
    await _saveToDisk();
    // Fire and Forget Sync
    _syncStudentToFirebase(schoolId, student);
  }

  @override
  Future<void> updateStudent(String schoolId, User student) async {
    await _init();
    final index = _students.indexWhere((s) => s.id == student.id);
    if (index != -1) {
      _students[index] = student;
      await _saveToDisk();
      _syncStudentToFirebase(schoolId, student);
    }
  }

  @override
  Future<void> deleteStudent(String schoolId, String studentId) async {
    await _init();
    _students.removeWhere((s) => s.id == studentId);
    await _saveToDisk();
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .doc(studentId)
            .delete();
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Student Delete): $e');
    }
  }

  @override
  Future<int> deleteAllStudents(String schoolId) async {
    await _init();
    final count = _students.where((s) => s.schoolId == schoolId).length;
    _students.removeWhere((s) => s.schoolId == schoolId);
    await _saveToDisk();
    try {
      if (Firebase.apps.isNotEmpty) {
        final snap = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .get();
        for (var i = 0; i < snap.docs.length; i += 450) {
          final chunk = snap.docs.skip(i).take(450).toList();
          final batch = FirebaseFirestore.instance.batch();
          for (final d in chunk) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Student Bulk Delete): $e');
    }
    return count;
  }

  @override
  Future<int> deleteStudentsByClass(String schoolId, String classId) async {
    await _init();
    final before = _students.length;
    _students.removeWhere(
      (s) => s.schoolId == schoolId && (s.assignedClassIds ?? []).contains(classId),
    );
    await _saveToDisk();
    final removed = before - _students.length;
    try {
      if (Firebase.apps.isNotEmpty) {
        final q = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Students')
            .where('assignedClassIds', arrayContains: classId)
            .get();
        for (var i = 0; i < q.docs.length; i += 450) {
          final chunk = q.docs.skip(i).take(450).toList();
          final batch = FirebaseFirestore.instance.batch();
          for (final d in chunk) {
            batch.delete(d.reference);
          }
          await batch.commit();
        }
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('Classes')
            .doc(classId)
            .update({'studentIds': <String>[]});
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Student Class Delete): $e');
    }
    return removed;
  }
}
