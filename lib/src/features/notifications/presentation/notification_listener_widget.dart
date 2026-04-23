import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:go_router/go_router.dart';
import 'notifications_provider.dart';
import '../../../core/services/notification_service.dart';

class NotificationListenerWidget extends ConsumerStatefulWidget {
  final Widget child;

  const NotificationListenerWidget({super.key, required this.child});

  @override
  ConsumerState<NotificationListenerWidget> createState() =>
      _NotificationListenerWidgetState();
}

class _NotificationListenerWidgetState
    extends ConsumerState<NotificationListenerWidget> {
  DateTime _lastProcessedTime = DateTime.now();

  @override
  void initState() {
    super.initState();

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        _handleMessageTap(message);
      }
    });
  }

  void _handleMessageTap(RemoteMessage message) {
    if (!mounted) return;
    context.go('/notifications');
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(allNotificationsProvider, (previous, next) {
      if (next.isEmpty) return;

      final newNotifications = next.where((n) {
        return n.timestamp.isAfter(_lastProcessedTime);
      }).toList();

      if (newNotifications.isNotEmpty) {
        final newest = newNotifications.first;
        if (newest.timestamp.isAfter(_lastProcessedTime)) {
          _lastProcessedTime = newest.timestamp;
        }

        for (final notification in newNotifications) {
          NotificationService().showNotification(
            id: notification.id.hashCode,
            title: notification.title,
            body: notification.body,
            payload: notification.id,
          );
        }
      }
    });

    return widget.child;
  }
}
