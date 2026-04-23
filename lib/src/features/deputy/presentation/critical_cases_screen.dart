import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'command_center_providers.dart';
import 'dialogs/escalation_action_dialog.dart';

class CriticalCasesScreen extends ConsumerWidget {
  final int initialIndex;

  const CriticalCasesScreen({super.key, this.initialIndex = 0});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 4,
      initialIndex: initialIndex,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('الحالات الحرجة'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'نطاق الخطر'),
              Tab(text: 'التأخر الصباحي'),
              Tab(text: 'تجاوز الاستئذان'),
              Tab(text: 'استحقاق التصعيد'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DangerZoneList(),
            _LateCasesList(),
            _PermissionViolationList(),
            _EscalationList(),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final CriticalCase criticalCase;
  final Color color;

  const _ActionButton({required this.criticalCase, required this.color});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) =>
              EscalationActionDialog(criticalCase: criticalCase),
        );
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 4.h),
        minimumSize: Size(60.w, 30.h),
      ),
      child: const Text('إجراء'),
    );
  }
}

class _EscalationList extends ConsumerWidget {
  const _EscalationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(escalationCasesProvider);
    return casesAsync.when(
      data: (cases) {
        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64.sp,
                  color: Colors.green,
                ),
                SizedBox(height: 16.h),
                const Text('لا توجد حالات تستحق التصعيد'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: cases.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final c = cases[index];
            final isHigh = c.severity >= 3;
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: isHigh
                      ? Colors.purple.shade100
                      : Colors.orange.shade100,
                  child: Icon(
                    isHigh ? Icons.psychology : Icons.phone_callback,
                    color: isHigh
                        ? Colors.purple.shade900
                        : Colors.orange.shade900,
                  ),
                ),
                title: Text(
                  c.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  c.reason,
                  style: TextStyle(
                    color: isHigh ? Colors.purple : Colors.orange.shade800,
                  ),
                ),
                trailing: _ActionButton(
                  criticalCase: c,
                  color: isHigh ? Colors.purple : Colors.orange,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('حدث خطأ: $e')),
    );
  }
}

class _DangerZoneList extends ConsumerWidget {
  const _DangerZoneList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(dangerZoneCasesProvider);
    return casesAsync.when(
      data: (cases) {
        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64.sp,
                  color: Colors.green,
                ),
                SizedBox(height: 16.h),
                const Text('لا توجد حالات في نطاق الخطر'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: cases.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final c = cases[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.red.shade100,
                  child: Icon(Icons.person_off, color: Colors.red.shade900),
                ),
                title: Text(
                  c.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  c.reason,
                  style: const TextStyle(color: Colors.red),
                ),
                trailing: _ActionButton(criticalCase: c, color: Colors.red),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('حدث خطأ: $e')),
    );
  }
}

class _LateCasesList extends ConsumerWidget {
  const _LateCasesList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(lateCasesProvider);
    return casesAsync.when(
      data: (cases) {
        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64.sp,
                  color: Colors.green,
                ),
                SizedBox(height: 16.h),
                const Text('لا يوجد تأخرات اليوم'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: cases.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final c = cases[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.orange.shade100,
                  child: Icon(Icons.timer_off, color: Colors.orange.shade900),
                ),
                title: Text(
                  c.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  c.reason,
                  style: TextStyle(color: Colors.orange.shade800),
                ),
                trailing: _ActionButton(criticalCase: c, color: Colors.orange),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('حدث خطأ: $e')),
    );
  }
}

class _PermissionViolationList extends ConsumerWidget {
  const _PermissionViolationList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final casesAsync = ref.watch(permissionViolationCasesProvider);
    return casesAsync.when(
      data: (cases) {
        if (cases.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  size: 64.sp,
                  color: Colors.green,
                ),
                SizedBox(height: 16.h),
                const Text('لا توجد تجاوزات للاستئذان'),
              ],
            ),
          );
        }
        return ListView.separated(
          padding: EdgeInsets.all(16.w),
          itemCount: cases.length,
          separatorBuilder: (context, index) => SizedBox(height: 12.h),
          itemBuilder: (context, index) {
            final c = cases[index];
            return Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.deepOrange.shade100,
                  child: Icon(
                    Icons.no_meeting_room,
                    color: Colors.deepOrange.shade900,
                  ),
                ),
                title: Text(
                  c.studentName,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text(
                  c.reason,
                  style: const TextStyle(color: Colors.deepOrange),
                ),
                trailing: _ActionButton(
                  criticalCase: c,
                  color: Colors.deepOrange,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('حدث خطأ: $e')),
    );
  }
}
