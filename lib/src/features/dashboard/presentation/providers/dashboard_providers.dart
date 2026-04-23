import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import '../../../../core/domain/models/user.dart';
import '../../../academic/data/firestore_parent_repository.dart';
import '../../../academic/data/student_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../notifications/domain/notification_record.dart';
import '../../../notifications/presentation/notifications_provider.dart';

// Provider to get children for a parent
final parentChildrenProvider = FutureProvider.family<List<User>, String>((
  ref,
  parentId,
) async {
  final user = ref.watch(authStateProvider).value;

  // 1. Try to get parent info from current user or fetch it
  String? parentPhone;
  String? schoolId = user?.schoolId;

  if (user != null && user.id == parentId) {
    parentPhone = user.phoneNumber;
  } else if (schoolId != null) {
    // Admin/Teacher viewing parent?
    final parentRepo = ref.watch(firestoreParentRepositoryProvider);
    final parent = await parentRepo.getParentById(schoolId, parentId);
    parentPhone = parent?.phoneNumber;
  }

  // 2. If we have phone and school, fetch children
  if (parentPhone != null && parentPhone.isNotEmpty && schoolId != null) {
    final studentRepo = ref.watch(studentRepositoryProvider);
    // Use the new method to get students by parent phone
    // (Ensure this method exists in your StudentRepository)
    try {
      final students = await studentRepo.getStudentsByParentPhone(
        schoolId,
        parentPhone,
      );
      if (students.isNotEmpty) return students;
    } catch (e) {
      if (kDebugMode) {
        // ignore
      }
    }
  }

  return [];
});

final parentNotificationsProvider =
    FutureProvider.family<List<NotificationRecord>, String>((
      ref,
      parentId,
    ) async {
      final children = await ref.watch(parentChildrenProvider(parentId).future);
      final repo = ref.watch(notificationRepositoryProvider);

      final List<NotificationRecord> allNotifications = [];
      for (final child in children) {
        final notifications = await repo.fetchNotifications(child.id);
        allNotifications.addAll(notifications);
      }

      // Filter out trivial notifications (live bathroom, minor lateness)
      final filteredNotifications = allNotifications.where((n) {
        final type = n.data?['type'] as String?;
        // Exclude bathroom/live tracking
        if (type != null && (type.contains('bathroom') || type.contains('tracking'))) {
          return false;
        }
        // Exclude minor late notifications (if distinguished by type)
        if (type == 'late_minor') return false;
        
        return true;
      }).toList();

      filteredNotifications.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      return filteredNotifications;
    });
