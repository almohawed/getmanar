import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/student_repository.dart';
import '../../../core/domain/models/user.dart';
import '../domain/notification_record.dart';
import '../data/firestore_notification_repository.dart';
import '../domain/notification_repository.dart';

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  return FirestoreNotificationRepository();
});

final userNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationRecord>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null) return Stream.value([]);
      return ref
          .watch(notificationRepositoryProvider)
          .getUserNotifications(user.id, schoolId: user.schoolId);
    });

final roleNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationRecord>>((ref) {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null) return Stream.value([]);
      return ref
          .watch(notificationRepositoryProvider)
          .getRoleNotifications(user.schoolId!, user.role.name);
    });

final classNotificationsStreamProvider =
    StreamProvider.autoDispose<List<NotificationRecord>>((ref) async* {
      final user = ref.watch(authStateProvider).value;
      if (user == null || user.schoolId == null) {
        yield [];
        return;
      }

      final repo = ref.watch(notificationRepositoryProvider);

      if (user.role == UserRole.parent) {
        final studentRepo = ref.watch(studentRepositoryProvider);
        // Ensure phone number is available
        if (user.phoneNumber == null || user.phoneNumber!.isEmpty) {
          yield [];
          return;
        }
        
        // Fetch children
        final children = await studentRepo.getStudentsByParentPhone(
          user.schoolId!, 
          user.phoneNumber!
        );
        
        // Collect all class IDs
        final classIds = children
            .expand((s) => s.assignedClassIds ?? <String>[])
            .toSet()
            .toList();

        if (classIds.isEmpty) {
          yield [];
        } else {
          yield* repo.getClassesNotifications(user.schoolId!, classIds);
        }
      } else {
        // Student/Teacher
        if (user.assignedClassIds == null || user.assignedClassIds!.isEmpty) {
          yield [];
        } else {
          // Listen to all assigned classes
          yield* repo.getClassesNotifications(user.schoolId!, user.assignedClassIds!);
        }
      }
    });

final allNotificationsProvider = Provider.autoDispose<List<NotificationRecord>>((
  ref,
) {
  final userNotifsAsync = ref.watch(userNotificationsStreamProvider);
  final roleNotifsAsync = ref.watch(roleNotificationsStreamProvider);
  final classNotifsAsync = ref.watch(classNotificationsStreamProvider);

  // Return empty list if loading or error to avoid breaking UI,
  // or handle states properly. For now, we just return data if available.
  final userNotifs = userNotifsAsync.value ?? [];
  final roleNotifs = roleNotifsAsync.value ?? [];
  final classNotifs = classNotifsAsync.value ?? [];

  // Combine lists
  final all = [...userNotifs, ...roleNotifs, ...classNotifs];

  // Deduplicate (in case a notification is sent to both user and role, though unlikely)
  final uniqueMap = {for (var n in all) n.id: n};
  final uniqueList = uniqueMap.values.toList();

  // Sort by timestamp descending
  uniqueList.sort((a, b) => b.timestamp.compareTo(a.timestamp));

  return uniqueList;
});

final unreadNotificationsCountProvider = Provider.autoDispose<int>((ref) {
  final notifications = ref.watch(allNotificationsProvider);
  return notifications.where((n) => !n.isRead).length;
});
