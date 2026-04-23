import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:universal_io/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../academic/data/mock_data.dart';
import '../../academic/domain/classroom.dart';
import '../../auth/presentation/auth_controller.dart';
import 'firestore_class_repository.dart';
export 'firestore_class_repository.dart';

abstract class ClassRepository {
  Future<List<Classroom>> getClasses();
  Future<void> addClass(Classroom classroom);
  Future<void> addClassesBatch(List<Classroom> classes);
  Future<void> updateClass(Classroom classroom);
  Future<void> deleteClasses(List<String> ids);
  Stream<List<Classroom>> getClassesStream();
}

class MockClassRepository implements ClassRepository {
  // We use the global mockClasses list to persist changes in memory
  final List<Classroom> _classes = [...mockClasses];
  bool _isInitialized = false;

  MockClassRepository() {
    _init();
  }

  Future<void> _init() async {
    if (_isInitialized) return;
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/classes.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        _classes.clear();
        _classes.addAll(jsonList.map((e) => Classroom.fromMap(e)).toList());
      } else {
        await _saveToDisk();
      }
    } catch (e) {
      debugPrint('Error initializing classes: $e');
    }
    _isInitialized = true;
  }

  Future<void> _saveToDisk() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/classes.json');
      final jsonList = _classes.map((c) => c.toMap()).toList();
      await file.writeAsString(json.encode(jsonList));
    } catch (e) {
      debugPrint('Error saving classes: $e');
    }
  }

  Future<void> _syncClassToFirebase(Classroom classroom) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classroom.id)
            .set(
              classroom.toMap()
                ..addAll({'updatedAt': FieldValue.serverTimestamp()}),
            );
      }
    } catch (e) {
      debugPrint('Firebase Sync Error (Class): $e');
    }
  }

  Future<void> _deleteClassFromFirebase(String classId) async {
    try {
      if (Firebase.apps.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('classes')
            .doc(classId)
            .delete();
      }
    } catch (e) {
      debugPrint('Firebase Delete Error (Class): $e');
    }
  }

  @override
  Future<List<Classroom>> getClasses() async {
    await _init();
    return _classes;
  }

  @override
  Stream<List<Classroom>> getClassesStream() {
    return Stream.fromFuture(getClasses());
  }

  @override
  Future<void> addClass(Classroom classroom) async {
    await _init();
    // 1. Memory
    _classes.add(classroom);
    // 2. Local Persistence
    await _saveToDisk();
    // 3. Remote Sync
    _syncClassToFirebase(classroom);
  }

  @override
  Future<void> addClassesBatch(List<Classroom> classes) async {
    await _init();
    if (classes.isEmpty) return;
    _classes.addAll(classes);
    await _saveToDisk();
    for (final c in classes) {
      _syncClassToFirebase(c);
    }
  }

  @override
  Future<void> updateClass(Classroom classroom) async {
    await _init();
    final index = _classes.indexWhere((c) => c.id == classroom.id);
    if (index != -1) {
      _classes[index] = classroom;
      await _saveToDisk();
      _syncClassToFirebase(classroom);
    }
  }

  @override
  Future<void> deleteClasses(List<String> ids) async {
    await _init();
    _classes.removeWhere((c) => ids.contains(c.id));
    await _saveToDisk();
    for (var id in ids) {
      _deleteClassFromFirebase(id);
    }
  }
}

final mockClassRepositoryProvider = Provider<ClassRepository>((ref) {
  return MockClassRepository();
});

final classesProvider = FutureProvider<List<Classroom>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (user == null || schoolId.isEmpty) return const <Classroom>[];

  // أولاً: محاولة Cloud Function
  try {
    final callable =
        FirebaseFunctions.instance.httpsCallable('listClassesForSchool');
    final res = await callable.call({'schoolId': schoolId});
    final data = res.data;
    if (data is Map && data['classes'] is List) {
      final list = (data['classes'] as List)
          .whereType<Map>()
          .map((m) => Classroom.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      if (list.isNotEmpty) {
        list.sort((a, b) {
          final ag = a.gradeLevel.compareTo(b.gradeLevel);
          if (ag != 0) return ag;
          return a.preferredLabel.compareTo(b.preferredLabel);
        });
        return list;
      }
    }
  } catch (_) {}

  // Fallback: جلب مباشر من Firestore
  try {
    final snap = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Classes')
        .get();
    if (snap.docs.isEmpty) {
      // جرب مسار آخر
      final snap2 = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Classrooms')
          .get();
      final list2 = snap2.docs.map((doc) {
        final m = <String, dynamic>{...doc.data(), 'id': doc.id};
        // تأكد من وجود الحقول المطلوبة
        m['name'] ??= m['className'] ?? m['displayName'] ?? doc.id;
        m['gradeLevel'] ??= 0;
        m['studentIds'] ??= [];
        return Classroom.fromMap(m);
      }).toList();
      list2.sort((a, b) => a.preferredLabel.compareTo(b.preferredLabel));
      return list2;
    }
    final list = snap.docs.map((doc) {
      final m = <String, dynamic>{...doc.data(), 'id': doc.id};
      m['name'] ??= m['className'] ?? m['displayName'] ?? doc.id;
      m['gradeLevel'] ??= 0;
      m['studentIds'] ??= [];
      return Classroom.fromMap(m);
    }).toList();
    list.sort((a, b) => a.preferredLabel.compareTo(b.preferredLabel));
    return list;
  } catch (_) {
    return const <Classroom>[];
  }
});
