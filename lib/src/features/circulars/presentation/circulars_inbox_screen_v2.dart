import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/circular.dart';

/// تصميم احترافي جديد لقسم التعاميم مع نظام "تم الاطلاع"
class CircularsInboxScreenV2 extends ConsumerStatefulWidget {
  const CircularsInboxScreenV2({super.key});

  @override
  ConsumerState<CircularsInboxScreenV2> createState() =>
      _CircularsInboxScreenV2State();
}

class _CircularsInboxScreenV2State extends ConsumerState<CircularsInboxScreenV2> {
  final _scroll = ScrollController();
  final _items = <CircularInboxItem>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _isLoading = false;
  bool _hasMore = true;
  CircularInboxFilter _filter = CircularInboxFilter.all;
  int _unreadCount = 0;
  String _lastUserId = '';
  String _lastSchoolId = '';

  @override
  void initState() {
    super.initState();
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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();

    if (user != null && schoolId.isNotEmpty) {
      if (_lastUserId != user.id || _lastSchoolId != schoolId) {
        _lastUserId = user.id;
        _lastSchoolId = schoolId;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _resetAndLoad(schoolId: schoolId, userId: user.id);
        });
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            if (schoolId.isEmpty || user == null)
              const Expanded(
                child: UnifiedEmptyState(
                  message: 'لا يمكن عرض التعاميم بدون مدرسة مرتبطة بالحساب.',
                  icon: Icons.campaign,
                ),
              )
            else
              Expanded(child: _buildBody(context, user)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.indigo.shade700,
            Colors.indigo.shade500,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Icon(
                  Icons.campaign,
                  color: Colors.white,
                  size: 28.sp,
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'التعاميم',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'اضغط "تم الاطلاع" للتوقيع بالعلم',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 13.sp,
                      ),
                    ),
                  ],
                ),
              ),
              if (_unreadCount > 0)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade600,
                    borderRadius: BorderRadius.circular(20.r),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    '$_unreadCount جديد',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16.h),
          _buildFilterChips(),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Row(
      children: [
        _filterChip(
          label: 'الكل',
          icon: Icons.list,
          selected: _filter == CircularInboxFilter.all,
          onTap: () => _setFilter(CircularInboxFilter.all),
        ),
        SizedBox(width: 8.w),
        _filterChip(
          label: 'لم يتم الاطلاع',
          icon: Icons.pending_actions,
          selected: _filter == CircularInboxFilter.unacknowledged,
          onTap: () => _setFilter(CircularInboxFilter.unacknowledged),
        ),
        SizedBox(width: 8.w),
        _filterChip(
          label: 'تم الاطلاع',
          icon: Icons.check_circle,
          selected: _filter == CircularInboxFilter.acknowledged,
          onTap: () => _setFilter(CircularInboxFilter.acknowledged),
        ),
      ],
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          decoration: BoxDecoration(
            color: selected
                ? Colors.white
                : Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12.r),
            border: Border.all(
              color: selected
                  ? Colors.white
                  : Colors.white.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected ? Colors.indigo.shade700 : Colors.white,
                size: 16.sp,
              ),
              SizedBox(width: 6.w),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? Colors.indigo.shade700 : Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, User user) {
    if (_items.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return const UnifiedEmptyState(
        message: 'لا توجد تعاميم مطابقة للفلتر الحالي.',
        icon: Icons.campaign,
      );
    }

    return ListView.separated(
      controller: _scroll,
      padding: EdgeInsets.all(16.w),
      itemCount: _items.length + (_hasMore ? 1 : 0),
      separatorBuilder: (_, __) => SizedBox(height: 12.h),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final item = _items[index];
        return _buildCircularCard(context, item, user);
      },
    );
  }

  Widget _buildCircularCard(BuildContext context, CircularInboxItem item, User user) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isNew =
        !item.acknowledged &&
        (item.viewedAt == null) &&
        (nowMs - item.createdAtMs) <= 48 * 60 * 60 * 1000;
    
    final createdStr = item.createdAtMs > 0
        ? DateFormat('yyyy-MM-dd').format(
            DateTime.fromMillisecondsSinceEpoch(item.createdAtMs))
        : '—';
    
    final ackAtStr = item.acknowledgedAt == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm').format(item.acknowledgedAt!.toDate());

    return Card(
      elevation: isNew ? 4 : 2,
      shadowColor: isNew ? Colors.indigo.withOpacity(0.3) : Colors.black12,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(
          color: isNew ? Colors.indigo.shade300 : Colors.transparent,
          width: 2,
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16.r),
          gradient: item.acknowledged
              ? null
              : LinearGradient(
                  colors: [
                    Colors.orange.shade50,
                    Colors.white,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
        ),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: (item.acknowledged
                              ? Colors.green
                              : Colors.orange)
                          .withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(
                      item.attachmentType == CircularAttachmentType.pdf.name
                          ? Icons.picture_as_pdf
                          : Icons.image,
                      color: item.acknowledged
                          ? Colors.green.shade700
                          : Colors.orange.shade700,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15.sp,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Row(
                          children: [
                            if (item.circularNumber > 0) ...[
                              Icon(
                                Icons.tag,
                                size: 14.sp,
                                color: Colors.grey.shade600,
                              ),
                              SizedBox(width: 4.w),
                              Text(
                                'رقم: ${item.circularNumber}',
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SizedBox(width: 8.w),
                            ],
                            Icon(
                              Icons.calendar_today,
                              size: 14.sp,
                              color: Colors.grey.shade600,
                            ),
                            SizedBox(width: 4.w),
                            Text(
                              createdStr,
                              style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.grey.shade600,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (item.acknowledged && ackAtStr.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10.r),
                    border: Border.all(
                      color: Colors.green.shade200,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                        size: 18.sp,
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: Text(
                          'تم الاطلاع: $ackAtStr',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              SizedBox(height: 12.h),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => context.push('/circulars/view?id=${item.circularId}'),
                      icon: const Icon(Icons.visibility),
                      label: const Text('فتح التعميم'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 12.h),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.r),
                        ),
                      ),
                    ),
                  ),
                  if (!item.acknowledged) ...[
                    SizedBox(width: 10.w),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _acknowledgeCircular(
                          context,
                          item.circularId,
                          user,
                        ),
                        icon: const Icon(Icons.check),
                        label: const Text('تم الاطلاع'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green.shade600,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 12.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.r),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _acknowledgeCircular(
    BuildContext context,
    String circularId,
    User user,
  ) async {
    try {
      final schoolId = user.schoolId ?? '';
      if (schoolId.isEmpty) return;

      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Circulars')
          .doc(circularId)
          .collection('Recipients')
          .doc(user.id)
          .update({
        'acknowledged': true,
        'acknowledgedAt': FieldValue.serverTimestamp(),
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('✅ تم تسجيل اطلاعك على التعميم'),
              ],
            ),
            backgroundColor: Colors.green.shade600,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }

      // Refresh the list
      await _resetAndLoad(schoolId: schoolId, userId: user.id);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ خطأ: $e'),
            backgroundColor: Colors.red.shade600,
          ),
        );
      }
    }
  }

  // ... بقية الـ methods من الملف الأصلي ...
  
  Query<Map<String, dynamic>> _baseQuery({
    required String schoolId,
    required String userId,
    required CircularInboxFilter filter,
  }) {
    var q = FirebaseFirestore.instance
        .collectionGroup('Recipients')
        .where('schoolId', isEqualTo: schoolId)
        .where('userId', isEqualTo: userId);
    if (filter == CircularInboxFilter.acknowledged) {
      q = q.where('acknowledged', isEqualTo: true);
    } else if (filter == CircularInboxFilter.unacknowledged) {
      q = q.where('acknowledged', isEqualTo: false);
    }
    return q.orderBy('circularCreatedAtMs', descending: true);
  }

  Future<void> _refreshUnread({
    required String schoolId,
    required String userId,
  }) async {
    try {
      final snap = await FirebaseFirestore.instance
          .collectionGroup('Recipients')
          .where('schoolId', isEqualTo: schoolId)
          .where('userId', isEqualTo: userId)
          .where('acknowledged', isEqualTo: false)
          .limit(500)
          .get();
      if (!mounted) return;
      setState(() => _unreadCount = snap.size);
    } catch (_) {}
  }

  Future<void> _resetAndLoad({
    required String schoolId,
    required String userId,
  }) async {
    _last = null;
    _items.clear();
    _hasMore = true;
    _isLoading = false;
    if (mounted) setState(() {});
    await _refreshUnread(schoolId: schoolId, userId: userId);
    await _loadFirstPage(schoolId: schoolId, userId: userId);
  }

  Future<void> _loadFirstPage({
    required String schoolId,
    required String userId,
  }) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final snap = await _baseQuery(
        schoolId: schoolId,
        userId: userId,
        filter: _filter,
      ).limit(20).get();
      _last = snap.docs.isEmpty ? null : snap.docs.last;
      _items
        ..clear()
        ..addAll(snap.docs.map((d) => CircularInboxItem.fromMap(d.data())));
      setState(() {
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

  Future<void> _loadMore() async {
    if (_isLoading || !_hasMore) return;
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (user == null || schoolId.isEmpty) return;
    if (_last == null) return;

    setState(() => _isLoading = true);
    try {
      final snap = await _baseQuery(
        schoolId: schoolId,
        userId: user.id,
        filter: _filter,
      ).startAfterDocument(_last!).limit(20).get();
      if (snap.docs.isNotEmpty) _last = snap.docs.last;
      _items.addAll(snap.docs.map((d) => CircularInboxItem.fromMap(d.data())));
      setState(() {
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

  Future<void> _setFilter(CircularInboxFilter filter) async {
    if (_filter == filter) return;
    setState(() => _filter = filter);
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (user == null || schoolId.isEmpty) return;
    await _loadFirstPage(schoolId: schoolId, userId: user.id);
  }
}
