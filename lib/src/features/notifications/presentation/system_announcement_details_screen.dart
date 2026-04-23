import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../auth/presentation/auth_controller.dart';
import 'notifications_provider.dart';

class SystemAnnouncementDetailsArgs {
  final String id;
  final String title;
  final String body;
  final String? timeText;

  SystemAnnouncementDetailsArgs({
    required this.id,
    required this.title,
    required this.body,
    this.timeText,
  });
}

class SystemAnnouncementDetailsScreen extends ConsumerWidget {
  final SystemAnnouncementDetailsArgs args;

  const SystemAnnouncementDetailsScreen({
    super.key,
    required this.args,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        title: const Text('تفاصيل الإعلان'),
        centerTitle: true,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      args.title,
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (args.timeText != null && args.timeText!.isNotEmpty)
                      Padding(
                        padding: EdgeInsets.only(top: 4.h),
                        child: Text(
                          args.timeText!,
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    SizedBox(height: 12.h),
                    Text(
                      args.body,
                      style: TextStyle(fontSize: 15.sp),
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final user = ref.read(authStateProvider).value;
                  if (user != null && user.schoolId != null) {
                    final repo = ref.read(notificationRepositoryProvider);
                    final allNotifs = await repo.fetchNotifications(
                      user.id,
                      schoolId: user.schoolId,
                    );
                    for (final n in allNotifs) {
                      if (n.data != null &&
                          n.data!['announcementId'] == args.id &&
                          !n.isRead) {
                        await repo.markAsRead(
                          n.id,
                          schoolId: user.schoolId,
                        );
                      }
                    }
                  }
                  if (context.mounted) {
                    context.go('/dashboard');
                  }
                },
                child: const Text('تمت المشاهدة'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

