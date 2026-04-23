import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_circular_repository.dart';
import '../domain/circular.dart';

final circularRepositoryProvider = Provider<FirestoreCircularRepository>((ref) {
  return FirestoreCircularRepository();
});

final circularsInboxProvider = StreamProvider.autoDispose<List<Circular>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (user == null || schoolId.isEmpty || !isStaffRole(user.role)) {
    return const Stream.empty();
  }
  final roleKey = switch (user.role) {
    UserRole.admin ||
    UserRole.supportAdmin ||
    UserRole.technicalSupport => UserRole.administrative.name,
    _ => user.role.name,
  };
  return ref
      .watch(circularRepositoryProvider)
      .watchCircularsForRole(schoolId: schoolId, role: roleKey);
});

final circularsAdminListProvider = StreamProvider.autoDispose<List<Circular>>((
  ref,
) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (user == null || schoolId.isEmpty) return const Stream.empty();
  return ref
      .watch(circularRepositoryProvider)
      .watchAllCirculars(schoolId: schoolId);
});

final circularRecipientStatusProvider = StreamProvider.family
    .autoDispose<Map<String, dynamic>?, ({String circularId, String userId})>((
      ref,
      args,
    ) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (user == null || schoolId.isEmpty) return const Stream.empty();
      return ref
          .watch(circularRepositoryProvider)
          .watchRecipientStatus(
            schoolId: schoolId,
            circularId: args.circularId,
            userId: args.userId,
          );
    });

final circularRecipientsProvider = StreamProvider.family
    .autoDispose<List<Map<String, dynamic>>, String>((ref, circularId) {
      final user = ref.watch(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (user == null || schoolId.isEmpty) return const Stream.empty();
      return ref
          .watch(circularRepositoryProvider)
          .watchRecipients(schoolId: schoolId, circularId: circularId);
    });

enum CircularInboxFilter { all, acknowledged, unacknowledged }

class CircularInboxItem {
  final String schoolId;
  final String circularId;
  final String title;
  final int circularNumber;
  final String attachmentType;
  final String attachmentUrl;
  final int createdAtMs;
  final bool acknowledged;
  final Timestamp? acknowledgedAt;
  final Timestamp? viewedAt;

  const CircularInboxItem({
    required this.schoolId,
    required this.circularId,
    required this.title,
    required this.circularNumber,
    required this.attachmentType,
    required this.attachmentUrl,
    required this.createdAtMs,
    required this.acknowledged,
    required this.acknowledgedAt,
    required this.viewedAt,
  });

  factory CircularInboxItem.fromMap(Map<String, dynamic> map) {
    return CircularInboxItem(
      schoolId: (map['schoolId'] ?? '').toString(),
      circularId: (map['circularId'] ?? '').toString(),
      title: (map['circularTitle'] ?? '').toString(),
      circularNumber: (map['circularNumber'] as num?)?.toInt() ?? 0,
      attachmentType: (map['attachmentType'] ?? '').toString(),
      attachmentUrl: (map['attachmentUrl'] ?? '').toString(),
      createdAtMs: (map['circularCreatedAtMs'] as num?)?.toInt() ?? 0,
      acknowledged: (map['acknowledged'] ?? false) == true,
      acknowledgedAt: map['acknowledgedAt'] as Timestamp?,
      viewedAt: map['viewedAt'] as Timestamp?,
    );
  }
}

final unreadCircularsCountProvider = FutureProvider.autoDispose<int>((
  ref,
) async {
  final user = ref.watch(authStateProvider).value;
  final schoolId = (user?.schoolId ?? '').trim();
  if (user == null || schoolId.isEmpty) return 0;
  try {
    final snap = await FirebaseFirestore.instance
        .collectionGroup('Recipients')
        .where('schoolId', isEqualTo: schoolId)
        .where('userId', isEqualTo: user.id)
        .where('acknowledged', isEqualTo: false)
        .limit(500)
        .get();
    return snap.size;
  } catch (_) {
    return 0;
  }
});
