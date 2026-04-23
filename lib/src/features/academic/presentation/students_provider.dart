import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/student_repository.dart';

final studentsProvider = FutureProvider<List<User>>((ref) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (user == null || schoolId.isEmpty) return const <User>[];

  // أولاً: محاولة Cloud Function
  try {
    final callable = FirebaseFunctions.instance.httpsCallable(
      'listStudentsForSchool',
    );
    final res = await callable.call({'schoolId': schoolId});
    final data = res.data;
    if (data is Map && data['students'] is List) {
      final list = (data['students'] as List)
          .whereType<Map>()
          .map((m) => User.fromMap(Map<String, dynamic>.from(m)))
          .toList();
      if (list.isNotEmpty) {
        list.sort((a, b) => a.name.compareTo(b.name));
        return list;
      }
    }
  } catch (_) {}

  // Fallback: جلب مباشر من Firestore
  try {
    final snap = await FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Students')
        .get();
    final list = snap.docs.map((doc) {
      final m = <String, dynamic>{...doc.data(), 'id': doc.id};
      return User.fromMap(m);
    }).toList();
    list.sort((a, b) => a.name.compareTo(b.name));
    return list;
  } catch (_) {
    return const <User>[];
  }
});

final studentByIdProvider = StreamProvider.family.autoDispose<User?, String>((
  ref,
  studentId,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (schoolId.isEmpty || studentId.trim().isEmpty) {
    return Stream.value(null);
  }

  return FirebaseFirestore.instance
      .collection('Schools')
      .doc(schoolId)
      .collection('Students')
      .doc(studentId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (!doc.exists || data == null) return null;
        final m = <String, dynamic>{...data, 'id': doc.id};
        return User.fromMap(m);
      });
});
