import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' as intl;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../academic/data/firestore_parent_repository.dart';
import '../../academic/presentation/students_provider.dart';
import '../../attendance/presentation/providers/daily_absence_provider.dart';
import '../../attendance/domain/models/daily_absence_model.dart';
import '../../sms/data/firestore_sms_repository.dart';
import '../../sms/domain/sms_message.dart';
import 'package:uuid/uuid.dart';

// Provider to fetch all parents
final parentsProvider = StreamProvider<List<User>>((ref) {
  final userAsync = ref.watch(authStateProvider);
  final user = userAsync.value;
  if (user == null || user.schoolId == null) return Stream.value([]);
  final repo = ref.watch(firestoreParentRepositoryProvider);
  return repo.watchParents(user.schoolId!);
});

class DeputySmsScreen extends ConsumerStatefulWidget {
  const DeputySmsScreen({super.key});

  @override
  ConsumerState<DeputySmsScreen> createState() => _DeputySmsScreenState();
}

class _DeputySmsScreenState extends ConsumerState<DeputySmsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _messageController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  bool _isSending = false;
  String _targetType = 'custom'; // 'all', 'custom'
  Set<String> _selectedParentIds = {};
  Set<String> _selectedAbsenceStudentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('رسائل SMS'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'رسالة جديدة'),
            Tab(text: 'إرسال غياب'),
            Tab(text: 'سجل الرسائل'),
            Tab(text: 'رسائل المرشد'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildNewMessageTab(), _buildAbsenceTab(), _buildLogTab(), _buildCounselorSmsTab()],
      ),
    );
  }

  // --- Tab 1: New Message ---
  Widget _buildNewMessageTab() {
    final parentsAsync = ref.watch(parentsProvider);
    final schoolId = ref.watch(authStateProvider).value?.schoolId;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _messageController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'نص الرسالة',
              border: OutlineInputBorder(),
              hintText: 'اكتب رسالتك هنا...',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Radio<String>(
                value: 'custom',
                groupValue: _targetType,
                onChanged: (v) => setState(() => _targetType = v!),
              ),
              const Text('تحديد مخصص'),
              const SizedBox(width: 16),
              Radio<String>(
                value: 'all',
                groupValue: _targetType,
                onChanged: (v) => setState(() {
                  _targetType = v!;
                  if (v == 'all' && parentsAsync.value != null) {
                    _selectedParentIds =
                        parentsAsync.value!.map((e) => e.id).toSet();
                  } else {
                    _selectedParentIds.clear();
                  }
                }),
              ),
              const Text('إرسال للجميع'),
            ],
          ),
          if (_targetType == 'custom') ...[
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                labelText: 'بحث عن ولي أمر',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() {}),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: parentsAsync.when(
                data: (parents) {
                  final filtered = parents
                      .where(
                        (p) =>
                            p.name.contains(_searchController.text) ||
                            (p.phoneNumber?.contains(_searchController.text) ??
                                false),
                      )
                      .toList();

                  if (filtered.isEmpty) {
                    return const Center(child: Text('لا يوجد أولياء أمور'));
                  }

                  return ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final parent = filtered[index];
                      final isSelected = _selectedParentIds.contains(parent.id);
                      return CheckboxListTile(
                        title: Text(parent.name),
                        subtitle: Text(parent.phoneNumber ?? 'لا يوجد رقم'),
                        value: isSelected,
                        onChanged: (val) {
                          setState(() {
                            if (val == true) {
                              _selectedParentIds.add(parent.id);
                            } else {
                              _selectedParentIds.remove(parent.id);
                            }
                          });
                        },
                      );
                    },
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Center(child: Text('خطأ: $e')),
              ),
            ),
          ] else
            const Spacer(),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed:
                _isSending ||
                    _messageController.text.isEmpty ||
                    _selectedParentIds.isEmpty
                ? null
                : () => _sendCustomMessage(schoolId),
            icon: _isSending
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: const Text('إرسال الرسالة'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              backgroundColor: Colors.blue.shade800,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendCustomMessage(String? schoolId) async {
    if (schoolId == null) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(smsRepositoryProvider);
      final user = ref.read(authStateProvider).value;

      // 1. Check Settings
      if (!await repo.isSmsEnabled(schoolId)) {
        throw Exception('خدمة الرسائل غير مفعلة من الإعدادات');
      }

      // 2. Check Rate Limit
      await repo.checkRateLimit(schoolId, user?.id ?? '');

      // 3. Prepare Messages
      final parents = ref.read(parentsProvider).when(
        data: (value) => value,
        loading: () => <User>[],
        error: (_, __) => <User>[],
      );
      final messages = <SmsMessage>[];
      final now = DateTime.now();

      for (var parentId in _selectedParentIds) {
        final parent = parents.firstWhere(
          (p) => p.id == parentId,
          orElse: () =>
              User(id: '', name: '', email: '', role: UserRole.parent),
        );
        if (parent.phoneNumber == null || parent.phoneNumber!.isEmpty) continue;

        messages.add(
          SmsMessage(
            id: const Uuid().v4(),
            body: _messageController.text,
            recipientId: parentId,
            phoneNumber: parent.phoneNumber!,
            status: SmsStatus.queued,
            createdAt: now,
            createdBy: user?.id ?? 'system',
          ),
        );
      }

      if (messages.isEmpty) {
        throw Exception('لم يتم العثور على أرقام هواتف للمستلمين المحددين');
      }

      // 4. Queue
      await repo.queueMessages(schoolId, messages);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم جدولة ${messages.length} رسالة للإرسال')),
      );

      // Reset
      setState(() {
        _messageController.clear();
        _selectedParentIds.clear();
        _targetType = 'custom';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // --- Tab 2: Send Absence ---
  Widget _buildAbsenceTab() {
    final absenceAsync = ref.watch(dailyAbsenceProvider);
    final schoolId = ref.watch(authStateProvider).value?.schoolId;

    return absenceAsync.when(
      data: (absences) {
        if (absences.isEmpty) {
          return const Center(child: Text('لا يوجد غياب مسجل لليوم'));
        }

        // Auto-select new items if not tracked
        // Simple logic: if selection is empty, select all initially?
        // Or just let user select.

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ListTile(
                title: const Text('تحديد الكل'),
                leading: Checkbox(
                  value: _selectedAbsenceStudentIds.length == absences.length,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _selectedAbsenceStudentIds = absences
                            .where((a) => a.student?.id != null)
                            .map((a) => a.student!.id)
                            .toSet();
                      } else {
                        _selectedAbsenceStudentIds.clear();
                      }
                    });
                  },
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: absences.length,
                itemBuilder: (context, index) {
                  final record = absences[index];
                  final isSelected = _selectedAbsenceStudentIds.contains(
                    record.student?.id ?? '',
                  );
                  return CheckboxListTile(
                    title: Text(record.student?.name ?? 'طالب'),
                    subtitle: Text('${record.className} - ${record.period}'),
                    value: isSelected,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          if (record.student?.id != null) {
                            _selectedAbsenceStudentIds.add(record.student!.id);
                          }
                        } else {
                          if (record.student?.id != null) {
                            _selectedAbsenceStudentIds
                                .remove(record.student!.id);
                          }
                        }
                      });
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton.icon(
                onPressed: _isSending || _selectedAbsenceStudentIds.isEmpty
                    ? null
                    : () => _sendAbsenceMessages(schoolId, absences),
                icon: const Icon(Icons.sms_failed),
                label: const Text('إرسال رسائل الغياب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  Future<void> _sendAbsenceMessages(
    String? schoolId,
    List<DailyAbsenceModel> absences,
  ) async {
    if (schoolId == null) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(smsRepositoryProvider);
      final user = ref.read(authStateProvider).value;
      final parents = ref.read(parentsProvider).when(
        data: (value) => value,
        loading: () => <User>[],
        error: (_, __) => <User>[],
      );

      // 1. Check Settings & Limit
      if (!await repo.isSmsEnabled(schoolId)) {
        throw Exception('خدمة الرسائل غير مفعلة');
      }
      await repo.checkRateLimit(schoolId, user?.id ?? '');

      final messages = <SmsMessage>[];
      final now = DateTime.now();
      final dateStr = intl.DateFormat('yyyy-MM-dd').format(now);

      for (var record in absences) {
        final sid = record.student?.id;
        if (sid == null) continue;
        if (!_selectedAbsenceStudentIds.contains(sid)) continue;

        // Find Parent Phone
        String targetPhone = '';
        String parentId = '';

        // Try to find linked parent
        if (record.student?.parentId != null) {
          final parent = parents.firstWhere(
            (p) => p.id == record.student!.parentId,
            orElse: () =>
                User(id: '', name: '', email: '', role: UserRole.parent),
          );
          if (parent.id.isNotEmpty && parent.phoneNumber != null) {
            targetPhone = parent.phoneNumber!;
            parentId = parent.id;
          }
        }

        // Fallback to student phone if no parent phone found (or as per requirement "Parents Linked")
        // If requirement is strict "Parents Linked", maybe skip if no parent found?
        // Requirement: "الإرسال فقط لأرقام أولياء الأمور المرتبطين بالطلاب"
        if (targetPhone.isEmpty) {
          // Skip or Log? Let's skip and maybe show count of failed.
          continue;
        }

        final body =
            'عزيزي ولي الأمر، نود إشعاركم بتغيب الطالب {studentName} بتاريخ {date}. نأمل المتابعة.'
                .replaceAll('{studentName}', record.student?.name ?? '')
                .replaceAll('{date}', dateStr);

        messages.add(
          SmsMessage(
            id: const Uuid().v4(),
            body: body,
            recipientId: parentId,
            phoneNumber: targetPhone,
            status: SmsStatus.queued,
            createdAt: now,
            createdBy: user?.id ?? 'system',
            metadata: {'type': 'absence', 'studentId': sid},
          ),
        );
      }

      if (messages.isEmpty) {
        throw Exception('لم يتم العثور على أرقام أولياء أمور للطلاب المحددين');
      }

      await repo.queueMessages(schoolId, messages);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تم جدولة ${messages.length} رسالة غياب')),
      );

      setState(() => _selectedAbsenceStudentIds.clear());
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الإرسال: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSending = false);
    }
  }

  // --- Tab 3: Log ---
  Widget _buildLogTab() {
    final schoolId = ref.watch(authStateProvider).value?.schoolId;
    if (schoolId == null) return const SizedBox.shrink();

    final logAsync = ref.watch(smsLogProvider(schoolId));

    return logAsync.when(
      data: (messages) {
        if (messages.isEmpty) return const Center(child: Text('السجل فارغ'));

        return ListView.separated(
          itemCount: messages.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final msg = messages[index];
            return ListTile(
              title: Text(
                msg.body,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                intl.DateFormat('yyyy-MM-dd HH:mm').format(msg.createdAt),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildStatusBadge(msg.status),
                  if (msg.error != null)
                    Icon(Icons.error, color: Colors.red, size: 16),
                ],
              ),
              onTap: msg.error != null
                  ? () {
                      showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text('خطأ'),
                          content: Text(msg.error!),
                        ),
                      );
                    }
                  : null,
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ: $e')),
    );
  }

  // --- Tab 4: Counselor SMS Log ---
  Widget _buildCounselorSmsTab() {
    final user = ref.watch(authStateProvider).value;
    final schoolId = user?.schoolId ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('counselor_sms_log')
          .where('schoolId', isEqualTo: schoolId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data?.docs ?? [];

        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sms_outlined, size: 64, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                Text('لا توجد رسائل من المرشد بعد',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 15)),
              ],
            ),
          );
        }

        // ترتيب حسب التاريخ
        final sorted = docs.toList()
          ..sort((a, b) {
            final at = ((a.data() as Map)['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            final bt = ((b.data() as Map)['sentAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
            return bt.compareTo(at);
          });

        return Column(
          children: [
            // شريط ملخص
            Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1565C0), Color(0xFF1976D2)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.sms, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'إجمالي رسائل المرشد: ${docs.length}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: sorted.length,
                itemBuilder: (context, i) {
                  final data = sorted[i].data() as Map<String, dynamic>;
                  final ts = (data['sentAt'] as Timestamp?)?.toDate();
                  final dateStr = ts != null
                      ? intl.DateFormat('dd/MM/yyyy HH:mm', 'ar').format(ts)
                      : '—';

                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 1,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: المرشد والطالب
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF1565C0).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.support_agent,
                                    color: Color(0xFF1565C0), size: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'المرشد: ${data['counselorName'] ?? '—'}',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    Text(
                                      'الطالب: ${data['studentName'] ?? '—'}',
                                      style: TextStyle(
                                          fontSize: 12, color: Colors.grey.shade600),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.shade300),
                                ),
                                child: Text(
                                  'تم الإرسال',
                                  style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          // نص الرسالة
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey.shade200),
                            ),
                            child: Text(
                              data['messageText'] ?? '',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          const SizedBox(height: 6),
                          // التاريخ
                          Row(
                            children: [
                              Icon(Icons.access_time,
                                  size: 12, color: Colors.grey.shade400),
                              const SizedBox(width: 4),
                              Text(
                                dateStr,
                                style: TextStyle(
                                    fontSize: 11, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatusBadge(SmsStatus status) {
    Color color;
    String text;
    switch (status) {
      case SmsStatus.queued:
        color = Colors.orange;
        text = 'قيد الانتظار';
        break;
      case SmsStatus.sent:
        color = Colors.green;
        text = 'تم الإرسال';
        break;
      case SmsStatus.failed:
        color = Colors.red;
        text = 'فشل';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
