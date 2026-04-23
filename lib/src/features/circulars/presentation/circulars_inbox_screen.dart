import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/circular.dart';
import 'circulars_providers.dart';

/// صفحة التعاميم - تصميم احترافي مع ألوان جميلة ✨
class CircularsInboxScreen extends ConsumerStatefulWidget {
  const CircularsInboxScreen({super.key});

  @override
  ConsumerState<CircularsInboxScreen> createState() =>
      _CircularsInboxScreenState();
}

class _CircularsInboxScreenState extends ConsumerState<CircularsInboxScreen> {
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
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.campaign_outlined,
                        size: 80.sp,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'لا يمكن عرض التعاميم',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'بدون مدرسة مرتبطة بالحساب',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(child: _buildBody(context)),
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
                      'الرجاء الضغط على "تم الاطلاع" لإثبات العلم رسمياً',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_unreadCount > 0) ...[
            SizedBox(height: 16.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(8.w),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      Icons.notifications_active,
                      color: Colors.white,
                      size: 20.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$_unreadCount تعميم جديد',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18.sp,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'بانتظار الاطلاع',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 11.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

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

  Widget _buildBody(BuildContext context) {
    return Column(
      children: [
        _buildFilters(),
        Expanded(
          child: _items.isEmpty && _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 80.sp,
                        color: Colors.grey.shade400,
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        'لا توجد تعاميم',
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'مطابقة للفلتر الحالي',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
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
                    final i = _items[index];
                    return _circularCard(
                      context: context,
                      id: i.circularId,
                      title: i.title,
                      createdAtMs: i.createdAtMs,
                      circularNumber: i.circularNumber,
                      attachmentType: i.attachmentType,
                      acknowledged: i.acknowledged,
                      acknowledgedAt: i.acknowledgedAt,
                      viewedAt: i.viewedAt,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 16.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Text(
            'الفلتر:',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14.sp,
              color: Colors.grey.shade800,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _filterChip(
                    label: 'الكل',
                    icon: Icons.list,
                    selected: _filter == CircularInboxFilter.all,
                    onTap: () => _setFilter(CircularInboxFilter.all),
                    color: Colors.indigo,
                  ),
                  SizedBox(width: 8.w),
                  _filterChip(
                    label: 'لم يتم الاطلاع',
                    icon: Icons.pending_actions,
                    selected: _filter == CircularInboxFilter.unacknowledged,
                    onTap: () => _setFilter(CircularInboxFilter.unacknowledged),
                    color: Colors.orange,
                  ),
                  SizedBox(width: 8.w),
                  _filterChip(
                    label: 'تم الاطلاع',
                    icon: Icons.check_circle,
                    selected: _filter == CircularInboxFilter.acknowledged,
                    onTap: () => _setFilter(CircularInboxFilter.acknowledged),
                    color: Colors.green,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    // تحويل Color إلى MaterialColor للحصول على shades
    final MaterialColor materialColor = color is MaterialColor 
        ? color 
        : Colors.primaries.firstWhere(
            (c) => c.value == color.value,
            orElse: () => Colors.indigo,
          );
    
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999.r),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
        decoration: BoxDecoration(
          gradient: selected
              ? LinearGradient(
                  colors: [materialColor.shade600, materialColor.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: selected ? null : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(999.r),
          border: Border.all(
            color: selected ? materialColor.shade700 : Colors.grey.shade300,
            width: selected ? 2 : 1,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: materialColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: selected ? Colors.white : Colors.grey.shade700,
              size: 18.sp,
            ),
            SizedBox(width: 6.w),
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : Colors.grey.shade800,
                fontWeight: FontWeight.bold,
                fontSize: 13.sp,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circularCard({
    required BuildContext context,
    required String id,
    required String title,
    required int createdAtMs,
    required int circularNumber,
    required String attachmentType,
    required bool acknowledged,
    required Timestamp? acknowledgedAt,
    required Timestamp? viewedAt,
  }) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final isNew =
        !acknowledged &&
        (viewedAt == null) &&
        (nowMs - createdAtMs) <= 48 * 60 * 60 * 1000;
    final createdStr = createdAtMs > 0
        ? DateFormat('yyyy-MM-dd').format(
            DateTime.fromMillisecondsSinceEpoch(createdAtMs),
          )
        : '—';
    final ackAtStr = acknowledgedAt == null
        ? ''
        : DateFormat('yyyy-MM-dd HH:mm').format(acknowledgedAt.toDate());

    final statusColor = acknowledged ? Colors.green : Colors.orange;
    final iconData = attachmentType == CircularAttachmentType.pdf.name
        ? Icons.picture_as_pdf
        : Icons.image;

    return Container(
      decoration: BoxDecoration(
        gradient: isNew
            ? LinearGradient(
                colors: [
                  Colors.indigo.shade50,
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isNew ? null : Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: isNew ? Colors.indigo.shade300 : Colors.grey.shade200,
          width: isNew ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isNew
                ? Colors.indigo.withOpacity(0.1)
                : Colors.grey.withOpacity(0.05),
            blurRadius: isNew ? 12 : 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(14.w),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.shade400,
                        statusColor.shade600,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12.r),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    iconData,
                    color: Colors.white,
                    size: 28.sp,
                  ),
                ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15.sp,
                                color: Colors.grey.shade900,
                                height: 1.3,
                              ),
                            ),
                          ),
                          if (isNew) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.red.shade400,
                                    Colors.red.shade600,
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(999.r),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withOpacity(0.3),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Text(
                                'جديد',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          Icon(
                            Icons.tag,
                            size: 14.sp,
                            color: Colors.grey.shade600,
                          ),
                          SizedBox(width: 4.w),
                          Text(
                            'رقم: $circularNumber',
                            style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.grey.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(width: 12.w),
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
                              color: Colors.grey.shade700,
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
            SizedBox(height: 14.h),
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: statusColor.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    acknowledged ? Icons.check_circle : Icons.pending,
                    color: statusColor.shade700,
                    size: 20.sp,
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          acknowledged ? 'تم الاطلاع' : 'بانتظار الاطلاع',
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: statusColor.shade800,
                          ),
                        ),
                        if (ackAtStr.isNotEmpty) ...[
                          SizedBox(height: 2.h),
                          Text(
                            'وقت الاطلاع: $ackAtStr',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: statusColor.shade700,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 14.h),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => context.push('/circulars/view?id=$id'),
                icon: const Icon(Icons.visibility, color: Colors.white),
                label: const Text(
                  'فتح التعميم',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigo.shade600,
                  padding: EdgeInsets.symmetric(vertical: 14.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  elevation: 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
