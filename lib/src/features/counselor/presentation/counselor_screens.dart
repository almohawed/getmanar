import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/counselor_session.dart';
import 'counselor_providers.dart';

class CounselingSessionsScreen extends ConsumerWidget {
  const CounselingSessionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    final sessionsAsync = ref.watch(todaySessionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('جلسات التوجيه والإرشاد')),
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            _showCreateSessionDialog(context, ref, schoolId, user?.id ?? ''),
        child: const Icon(Icons.add),
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          if (sessions.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.meeting_room,
                    size: 80.sp,
                    color: Colors.teal.withValues(alpha: 0.3),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'لا توجد جلسات نشطة حالياً',
                    style: TextStyle(fontSize: 18.sp, color: Colors.grey),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: sessions.length,
            itemBuilder: (context, index) {
              final session = sessions[index];
              return Card(
                margin: EdgeInsets.only(bottom: 12.h),
                child: ListTile(
                  onTap: () => _showSessionDetails(
                    context,
                    ref,
                    session,
                    user?.id ?? '',
                    user?.role.name ?? '',
                  ),
                  leading: CircleAvatar(
                    backgroundColor: session.isConfidential
                        ? Colors.red.withValues(alpha: 0.1)
                        : Colors.teal.withValues(alpha: 0.1),
                    child: Icon(
                      session.isConfidential ? Icons.lock : Icons.people,
                      color: session.isConfidential ? Colors.red : Colors.teal,
                    ),
                  ),
                  title: Text(session.title),
                  subtitle: Text(
                    session.isConfidential
                        ? 'جلسة سرية'
                        : 'جلسة توجيه اعتيادية',
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  void _showSessionDetails(
    BuildContext context,
    WidgetRef ref,
    CounselorSession session,
    String userId,
    String role,
  ) {
    // Check if it's a masked confidential session
    // We know it's masked if isConfidential is true AND title is 'جلسة سرية' (or checks IDs if we had them handy, but masked object has IDs too)
    // Actually, checking session.counselorId != userId is the most robust way, assuming userId is passed correctly.
    final isMasked = session.isConfidential && session.counselorId != userId;

    if (isMasked) {
      // Show Restricted Access Dialog (Escalation Override)
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('⚠️ دخول طارئ'),
          content: const Text(
            'هذه الجلسة مشفرة وسرية.\n\n'
            'هل تريد استخدام صلاحية "الدخول الطارئ" (Escalation Override)؟\n\n'
            'سيتم تسجيل هذا الإجراء في سجل التدقيق الأمني (Audit Log) تحت تصنيف "Emergency View".',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                Navigator.pop(context); // Close dialog
                // Perform Emergency Access
                final fullSession = await ref
                    .read(counselorRepositoryProvider)
                    .getSessionDetails(
                      schoolId: session.schoolId,
                      sessionId: session.id,
                      userId: userId,
                      role: role,
                      isEmergencyAccess: true,
                    );

                if (fullSession != null && context.mounted) {
                  _showFullDetails(context, fullSession);
                }
              },
              icon: const Icon(Icons.warning_amber_rounded),
              label: const Text('دخول طارئ'),
            ),
          ],
        ),
      );
    } else {
      // Normal View - Log it
      ref
          .read(counselorRepositoryProvider)
          .logViewSession(
            schoolId: session.schoolId,
            sessionId: session.id,
            userId: userId,
            role: role,
            isConfidential: session.isConfidential,
            isEmergencyAccess: false,
          );
      _showFullDetails(context, session);
    }
  }

  void _showFullDetails(BuildContext context, CounselorSession session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: EdgeInsets.all(24.w),
        height: 0.7.sh,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              session.title,
              style: TextStyle(
                fontSize: 22.sp,
                fontWeight: FontWeight.bold,
                color: session.isConfidential ? Colors.red : Colors.black,
              ),
            ),
            if (session.isConfidential)
              Container(
                margin: EdgeInsets.only(top: 8.h),
                padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                ),
                child: const Text(
                  'سري للغاية',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              ),
            SizedBox(height: 16.h),
            const Divider(),
            SizedBox(height: 16.h),
            Text(
              'الوصف:',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text(
              session.description ?? 'لا يوجد وصف',
              style: TextStyle(fontSize: 14.sp),
            ),
            SizedBox(height: 24.h),
            Text(
              'المرفقات:',
              style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            if (session.attachments.isEmpty)
              const Text('لا توجد مرفقات')
            else
              ...session.attachments.map(
                (a) => ListTile(
                  leading: const Icon(Icons.attachment),
                  title: Text(a),
                  onTap: () {}, // Open attachment
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showCreateSessionDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    String counselorId,
  ) {
    showDialog(
      context: context,
      builder: (context) =>
          _CreateSessionDialog(schoolId: schoolId, counselorId: counselorId),
    );
  }
}

class _CreateSessionDialog extends ConsumerStatefulWidget {
  final String schoolId;
  final String counselorId;

  const _CreateSessionDialog({
    required this.schoolId,
    required this.counselorId,
  });

  @override
  ConsumerState<_CreateSessionDialog> createState() =>
      _CreateSessionDialogState();
}

class _CreateSessionDialogState extends ConsumerState<_CreateSessionDialog> {
  final _titleController = TextEditingController();
  bool _isConfidential = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _createSession() async {
    if (_titleController.text.isEmpty) return;

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) return;

      final session = CounselorSession(
        id: const Uuid().v4(),
        schoolId: widget.schoolId,
        counselorId: widget.counselorId,
        title: _titleController.text,
        description: '',
        scheduledAt: DateTime.now(),
        attendeeIds: [], // Add logic to select student
        isConfidential: _isConfidential,
        status: SessionStatus.scheduled,
        type: SessionType.individual,
      );

      await ref
          .read(counselorRepositoryProvider)
          .createSession(session, userId: user.id, role: user.role.name);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error creating session: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('جلسة جديدة'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'عنوان الجلسة'),
          ),
          SizedBox(height: 16.h),
          SwitchListTile(
            title: const Text('جلسة سرية'),
            subtitle: const Text('لا تظهر تفاصيلها للمرشدين الآخرين'),
            value: _isConfidential,
            onChanged: (val) => setState(() => _isConfidential = val),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('إلغاء'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _createSession,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('إنشاء'),
        ),
      ],
    );
  }
}

class PledgesScreen extends StatelessWidget {
  const PledgesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('سجل التعهدات')),
      body: Center(
        child: Text(
          'لا توجد بيانات',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      ),
    );
  }
}

// REMOVED: Old placeholder ModificationPlansScreen
// Use ActivePlansScreen from lib/src/features/academic/presentation/active_plans_screen.dart instead
// Route: /counselor/active-plans
