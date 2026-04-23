import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import 'notifications_provider.dart';
import 'system_announcement_details_screen.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(allNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('الإشعارات')),
      body: notifications.isEmpty
          ? const Center(child: Text('لا توجد إشعارات'))
          : ListView.builder(
              padding: EdgeInsets.all(16.w),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                return Card(
                  elevation: notification.isRead ? 0 : 2,
                  color:
                      notification.isRead ? Colors.grey.shade50 : Colors.white,
                  child: ListTile(
                    leading: Icon(
                      Icons.notifications,
                      color: notification.isRead ? Colors.grey : Colors.indigo,
                    ),
                    title: Text(
                      notification.title,
                      style: TextStyle(
                        fontWeight: notification.isRead
                            ? FontWeight.normal
                            : FontWeight.bold,
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notification.body),
                        SizedBox(height: 4.h),
                        Text(
                          notification.timestamp.toString().substring(0, 16),
                          style:
                              TextStyle(fontSize: 10.sp, color: Colors.grey),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      tooltip: 'حذف',
                      icon: const Icon(Icons.delete, color: Colors.red),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('حذف الإشعار'),
                            content: const Text(
                              'سيتم حذف هذا الإشعار من قائمتك. هل أنت متأكد؟',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('إلغاء'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text(
                                  'حذف',
                                  style: TextStyle(color: Colors.red),
                                ),
                              ),
                            ],
                          ),
                        );
                        if (confirm == true && notification.schoolId != null) {
                          await ref
                              .read(notificationRepositoryProvider)
                              .deleteNotification(
                                notification.id,
                                schoolId: notification.schoolId,
                              );
                        }
                      },
                    ),
                    onTap: () async {
                      if (!notification.isRead &&
                          notification.schoolId != null) {
                        await ref
                            .read(notificationRepositoryProvider)
                            .markAsRead(
                              notification.id,
                              schoolId: notification.schoolId,
                            );
                      }

                      final data = notification.data;
                      if (data != null &&
                          data['type'] == 'system_announcement' &&
                          data['announcementId'] != null) {
                        final args = SystemAnnouncementDetailsArgs(
                          id: data['announcementId'] as String,
                          title: notification.title,
                          body: notification.body,
                          timeText: notification.timestamp
                              .toString()
                              .substring(0, 16),
                        );
                        if (context.mounted) {
                          context.push('/system-announcement', extra: args);
                        }
                      } else if (notification.route != null &&
                          notification.route!.isNotEmpty) {
                        if (context.mounted) {
                          context.push(notification.route!);
                        }
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}
