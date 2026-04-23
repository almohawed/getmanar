import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/circular.dart';

class CircularsManagementScreen extends ConsumerStatefulWidget {
  const CircularsManagementScreen({super.key});

  @override
  ConsumerState<CircularsManagementScreen> createState() =>
      _CircularsManagementScreenState();
}

class _CircularsManagementScreenState
    extends ConsumerState<CircularsManagementScreen> {
  final _scroll = ScrollController();
  final _items = <Circular>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _isLoading = false;
  bool _hasMore = true;

  bool _canCreate(User? user) {
    if (user == null) return false;
    if (user.role == UserRole.superAdmin || user.role == UserRole.admin) {
      return true;
    }
    if (user.role == UserRole.deputy && user.deputyType == 'academic') {
      return true;
    }
    return false;
  }

  @override
  void initState() {
    super.initState();
    _loadMore();
    _scroll.addListener(() {
      if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 320) {
        _loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (user == null || schoolId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      var q = FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('StaffCirculars')
          .orderBy('createdAt', descending: true)
          .limit(20);
      if (_last != null) q = q.startAfterDocument(_last!);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) _last = snap.docs.last;
      final more = snap.docs.map((d) {
        final data = d.data();
        if ((data['id'] ?? '').toString().trim().isEmpty) {
          data['id'] = d.id;
        }
        return Circular.fromMap(data);
      }).toList();
      setState(() {
        _items.addAll(more);
        _isLoading = false;
        _hasMore = snap.docs.length == 20;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _hasMore = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final canCreate = _canCreate(user);

    return UnifiedPageScaffold(
      title: 'إدارة التعاميم',
      subtitle: 'أرشيف التعاميم + كشف توقيع الاطلاع',
      allowedRoles: const [
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.deputy,
      ],
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => context.push('/circulars/create'),
              icon: const Icon(Icons.campaign),
              label: const Text('إرسال تعميم'),
              backgroundColor: Colors.indigo.shade700,
              foregroundColor: Colors.white,
            )
          : null,
      body: _items.isEmpty && _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
          ? const UnifiedEmptyState(
              message: 'لا توجد تعاميم مرسلة حتى الآن',
              icon: Icons.campaign,
            )
          : ListView.separated(
              controller: _scroll,
              padding: EdgeInsets.all(16.w),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => SizedBox(height: 10.h),
              itemBuilder: (context, index) {
                if (index >= _items.length) {
                  return Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }
                final c = _items[index];
                final createdStr = DateFormat('yyyy-MM-dd').format(c.createdAt);

                final recCount = c.recipientsCount;
                final ackCount = c.acknowledgedCount;
                final subtitle = [
                  if (c.circularNumber > 0) 'رقم: ${c.circularNumber}',
                  'تاريخ الإرسال: $createdStr',
                ].join(' • ');

                return Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16.r),
                    side: BorderSide(color: Colors.grey.shade200),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                      child: Icon(
                        c.attachmentType == CircularAttachmentType.pdf
                            ? Icons.picture_as_pdf
                            : Icons.image,
                        color: Colors.indigo.shade700,
                      ),
                    ),
                    title: Text(
                      c.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(subtitle),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$ackCount / $recCount',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اطلاع',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12.sp,
                          ),
                        ),
                      ],
                    ),
                    onTap: () => context.push('/circulars/details', extra: c),
                  ),
                );
              },
            ),
    );
  }
}
