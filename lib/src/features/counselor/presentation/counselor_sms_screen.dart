import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/presentation/students_provider.dart';
import '../../academic/data/firestore_parent_repository.dart';
import '../../sms/data/firestore_sms_repository.dart';
import '../../sms/domain/sms_message.dart';

// Provider to fetch all parents
final parentsProvider = StreamProvider<List<User>>((ref) {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.value;
  if (user == null || user.schoolId == null) return Stream.value([]);
  final repo = ref.watch(firestoreParentRepositoryProvider);
  return repo.watchParents(user.schoolId!);
});

/// شاشة إرسال رسائل SMS لأولياء الأمور - المرشد الطلابي
/// تستخدم نفس خدمة SMS التي يضبطها الوكيل والمدير
class CounselorSmsScreen extends ConsumerStatefulWidget {
  const CounselorSmsScreen({super.key});

  @override
  ConsumerState<CounselorSmsScreen> createState() => _CounselorSmsScreenState();
}

class _CounselorSmsScreenState extends ConsumerState<CounselorSmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  bool _isSending = false;
  bool _smsEnabled = false;
  bool _checkingStatus = true;
  String _targetType = 'custom';
  final Set<String> _selectedParentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSmsStatus());
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _checkSmsStatus() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) {
      setState(() => _checkingStatus = false);
      return;
    }
    try {
      final repo = ref.read(smsRepositoryProvider);
      final enabled = await repo.isSmsEnabled(schoolId);
      setState(() {
        _smsEnabled = enabled;
        _checkingStatus = false;
      });
    } catch (_) {
      setState(() => _checkingStatus = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        title: const Text('رسائل أولياء الأمور', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.send), text: 'إرسال رسالة'),
            Tab(icon: Icon(Icons.history), text: 'سجل الرسائل'),
          ],
        ),
      ),
      body: _checkingStatus
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [_buildSendTab(), _buildLogTab()],
            ),
    );
  }

  Widget _buildSendTab() {
    // إذا لم تكن الخدمة مفعّلة
    if (!_smsEnabled) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.w),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.sms_failed_outlined, size: 72.sp, color: Colors.orange.shade300),
              SizedBox(height: 16.h),
              Text(
                'خدمة الرسائل غير مفعّلة',
                style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold, color: Colors.grey.shade700),
              ),
              SizedBox(height: 8.h),
              Text(
                'يرجى التواصل مع وكيل الشؤون التعليمية أو مدير المدرسة لتفعيل خدمة الرسائل من إعدادات النظام.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade500, height: 1.6),
              ),
              SizedBox(height: 24.h),
              OutlinedButton.icon(
                onPressed: _checkSmsStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة التحقق'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1565C0),
                  side: const BorderSide(color: Color(0xFF1565C0)),
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // الخدمة مفعّلة - عرض نموذج الإرسال
    final parentsAsync = ref.watch(parentsProvider);

    return Padding(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // شارة الخدمة مفعّلة
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(10.r),
              border: Border.all(color: Colors.green.shade300),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green.shade600, size: 16.sp),
                SizedBox(width: 8.w),
                Text('خدمة الرسائل مفعّلة',
                    style: TextStyle(color: Colors.green.shade700, fontSize: 12.sp, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          SizedBox(height: 12.h),

          // نص الرسالة
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: TextField(
              controller: _messageCtrl,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'نص الرسالة',
                hintText: 'اكتب رسالتك لأولياء الأمور...',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: const Icon(Icons.message, color: Color(0xFF1565C0)),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(height: 12.h),

          // خيار الإرسال
          Container(
            padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12.r),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Radio<String>(
                  value: 'custom',
                  groupValue: _targetType,
                  activeColor: const Color(0xFF1565C0),
                  onChanged: (v) => setState(() => _targetType = v!),
                ),
                const Text('تحديد مخصص'),
                SizedBox(width: 16.w),
                Radio<String>(
                  value: 'all',
                  groupValue: _targetType,
                  activeColor: const Color(0xFF1565C0),
                  onChanged: (v) {
                    setState(() {
                      _targetType = v!;
                      if (v == 'all') {
                        final parents = parentsAsync.value ?? [];
                        _selectedParentIds.addAll(parents.map((p) => p.id));
                      } else {
                        _selectedParentIds.clear();
                      }
                    });
                  },
                ),
                const Text('إرسال للجميع'),
              ],
            ),
          ),
          SizedBox(height: 8.h),

          // بحث
          if (_targetType == 'custom') ...[
            TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                labelText: 'بحث عن ولي أمر',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                filled: true,
                fillColor: Colors.white,
              ),
              onChanged: (_) => setState(() {}),
            ),
            SizedBox(height: 8.h),
          ],

          // قائمة أولياء الأمور
          Expanded(
            child: parentsAsync.when(
              data: (parents) {
                final filtered = _targetType == 'custom'
                    ? parents.where((p) =>
                        _searchCtrl.text.isEmpty ||
                        p.name.contains(_searchCtrl.text) ||
                        (p.phoneNumber?.contains(_searchCtrl.text) ?? false)).toList()
                    : parents;

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 48.sp, color: Colors.grey.shade300),
                        SizedBox(height: 8.h),
                        Text('لا يوجد أولياء أمور مسجلون',
                            style: TextStyle(color: Colors.grey.shade500)),
                      ],
                    ),
                  );
                }

                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
                  ),
                  child: ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade100),
                    itemBuilder: (context, i) {
                      final p = filtered[i];
                      final selected = _selectedParentIds.contains(p.id);
                      return CheckboxListTile(
                        dense: true,
                        title: Text(p.name,
                            style: TextStyle(fontSize: 13.sp, fontWeight: FontWeight.w600)),
                        subtitle: Text(p.phoneNumber ?? 'لا يوجد رقم',
                            style: TextStyle(fontSize: 11.sp,
                                color: p.phoneNumber != null ? Colors.grey.shade600 : Colors.red.shade300)),
                        value: selected,
                        activeColor: const Color(0xFF1565C0),
                        onChanged: p.phoneNumber == null ? null : (val) {
                          setState(() {
                            if (val == true) _selectedParentIds.add(p.id);
                            else _selectedParentIds.remove(p.id);
                          });
                        },
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('خطأ: $e')),
            ),
          ),

          SizedBox(height: 12.h),

          // زر الإرسال
          ElevatedButton.icon(
            onPressed: (_isSending || _messageCtrl.text.trim().isEmpty || _selectedParentIds.isEmpty)
                ? null
                : _sendMessages,
            icon: _isSending
                ? SizedBox(width: 18.w, height: 18.h,
                    child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send),
            label: Text(
              _isSending
                  ? 'جاري الإرسال...'
                  : 'إرسال الرسالة (${_selectedParentIds.length} ولي أمر)',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1565C0),
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14.h),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessages() async {
    final user = ref.read(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (user == null || schoolId.isEmpty) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(smsRepositoryProvider);

      // التحقق من تفعيل الخدمة
      if (!await repo.isSmsEnabled(schoolId)) {
        throw Exception('خدمة الرسائل غير مفعلة. يرجى التواصل مع الإدارة.');
      }

      // التحقق من حد الإرسال
      await repo.checkRateLimit(schoolId, user.id);

      // جلب أولياء الأمور
      final parents = ref.read(parentsProvider).when(
        data: (v) => v,
        loading: () => <User>[],
        error: (_, __) => <User>[],
      );

      final messages = <SmsMessage>[];
      final now = DateTime.now();

      for (final parentId in _selectedParentIds) {
        final parent = parents.where((p) => p.id == parentId).firstOrNull;
        if (parent == null || parent.phoneNumber == null || parent.phoneNumber!.isEmpty) continue;

        messages.add(SmsMessage(
          id: const Uuid().v4(),
          body: _messageCtrl.text.trim(),
          recipientId: parentId,
          phoneNumber: parent.phoneNumber!,
          status: SmsStatus.queued,
          createdAt: now,
          createdBy: user.id,
          metadata: {
            'senderName': user.name,
            'senderRole': 'counselor',
            'type': 'counselor_message',
          },
        ));
      }

      if (messages.isEmpty) {
        throw Exception('لم يتم العثور على أرقام هواتف للمستلمين المحددين');
      }

      // إرسال عبر نفس خدمة SMS
      await repo.queueMessages(schoolId, messages);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم جدولة ${messages.length} رسالة للإرسال'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
        setState(() {
          _messageCtrl.clear();
          _selectedParentIds.clear();
          _targetType = 'custom';
        });
        _tabController.animateTo(1);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Widget _buildLogTab() {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';
    if (schoolId.isEmpty) return const SizedBox.shrink();

    // جلب رسائل المرشد الحالي فقط من SmsOutbox
    final logAsync = ref.watch(smsLogProvider(schoolId));

    return logAsync.when(
      data: (allMessages) {
        // فلترة رسائل المرشد الحالي فقط
        final myMessages = allMessages
            .where((m) => m.createdBy == user?.id)
            .toList();

        if (myMessages.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sms_outlined, size: 64.sp, color: Colors.grey.shade300),
                SizedBox(height: 12.h),
                Text('لا توجد رسائل مرسلة بعد',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15.sp)),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: EdgeInsets.all(16.w),
          itemCount: myMessages.length,
          itemBuilder: (context, i) {
            final msg = myMessages[i];
            final dateStr = DateFormat('dd/MM/yyyy HH:mm', 'ar').format(msg.createdAt);

            Color statusColor;
            String statusLabel;
            switch (msg.status) {
              case SmsStatus.sent:
                statusColor = Colors.green;
                statusLabel = 'تم الإرسال';
                break;
              case SmsStatus.failed:
                statusColor = Colors.red;
                statusLabel = 'فشل';
                break;
              default:
                statusColor = Colors.orange;
                statusLabel = 'قيد الانتظار';
            }

            return Container(
              margin: EdgeInsets.only(bottom: 10.h),
              padding: EdgeInsets.all(14.w),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12.r),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.phone, size: 14.sp, color: Colors.grey.shade500),
                      SizedBox(width: 4.w),
                      Text(msg.phoneNumber,
                          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600)),
                      const Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(statusLabel,
                            style: TextStyle(color: statusColor, fontSize: 10.sp, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  Text(msg.body,
                      style: TextStyle(fontSize: 13.sp, color: Colors.grey.shade800)),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      Icon(Icons.access_time, size: 12.sp, color: Colors.grey.shade400),
                      SizedBox(width: 4.w),
                      Text(dateStr,
                          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade500)),
                    ],
                  ),
                  if (msg.error != null) ...[
                    SizedBox(height: 4.h),
                    Text('خطأ: ${msg.error}',
                        style: TextStyle(fontSize: 10.sp, color: Colors.red.shade400)),
                  ],
                ],
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('خطأ: $e')),
    );
  }
}
