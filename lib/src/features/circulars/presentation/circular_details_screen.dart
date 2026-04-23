import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../academic/data/school_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../application/circular_ack_pdf_service.dart';
import '../domain/circular.dart';
import 'circulars_providers.dart';

class CircularDetailsScreen extends ConsumerWidget {
  final Circular circular;

  const CircularDetailsScreen({super.key, required this.circular});

  String _roleLabel(String role) {
    switch (role) {
      case 'teacher':
        return 'معلم';
      case 'administrative':
      case 'admin':
      case 'supportAdmin':
      case 'technicalSupport':
        return 'إداري';
      case 'deputy':
        return 'وكيل';
      default:
        return role;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final schoolAsync = schoolId.isEmpty
        ? const AsyncValue.data(null)
        : ref.watch(schoolProvider(schoolId));
    final schoolName = schoolAsync.value?.name ?? '';
    final adminRegion = schoolAsync.value?.adminRegion ?? '';

    final createdStr = DateFormat(
      'yyyy-MM-dd HH:mm',
    ).format(circular.createdAt);
    final circularNo = circular.circularNumber > 0
        ? 'رقم التعميم: ${circular.circularNumber}'
        : '';

    return UnifiedPageScaffold(
      title: 'تفاصيل التعميم',
      subtitle: circular.title,
      allowedRoles: const [
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.deputy,
      ],
      body: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.r),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      circular.title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16.sp,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    SizedBox(height: 8.h),
                    Text(
                      'المرسل: ${circular.createdByName} • $createdStr',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (circularNo.isNotEmpty) ...[
                      SizedBox(height: 6.h),
                      Text(
                        circularNo,
                        style: TextStyle(
                          color: Colors.indigo.shade800,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                    if (circular.description.trim().isNotEmpty) ...[
                      SizedBox(height: 10.h),
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12.r),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Text(
                          circular.description.trim(),
                          style: TextStyle(
                            color: Colors.grey.shade900,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                    SizedBox(height: 10.h),
                    Wrap(
                      spacing: 10.w,
                      runSpacing: 10.h,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => context.push(
                            '/circulars/view?id=${circular.id}&admin=1',
                          ),
                          icon: const Icon(Icons.visibility_outlined),
                          label: Text(
                            circular.attachmentType ==
                                    CircularAttachmentType.pdf
                                ? 'عرض PDF'
                                : 'عرض الصورة',
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            try {
                              final recipients = await ref.read(
                                circularRecipientsProvider(circular.id).future,
                              );

                              final normalized = recipients.map((r) {
                                final out = Map<String, dynamic>.from(r);
                                final ackAt = out['acknowledgedAt'];
                                if (ackAt is Timestamp) {
                                  out['acknowledgedAt'] = ackAt.toDate();
                                }
                                return out;
                              }).toList();

                              final bytes = await CircularAckPdfService.build(
                                schoolName: schoolName,
                                adminRegion: adminRegion,
                                circularTitle: [
                                  if (circularNo.isNotEmpty) circularNo,
                                  circular.title,
                                ].join(' - '),
                                recipients: normalized,
                              );
                              await Printing.layoutPdf(
                                onLayout: (_) async =>
                                    Uint8List.fromList(bytes),
                                name:
                                    'Circular_Ack_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
                              );
                            } catch (_) {
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('تعذر إنشاء كشف الاطلاع'),
                                  behavior: SnackBarBehavior.floating,
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.print),
                          label: const Text('طباعة كشف الاطلاع'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo.shade700,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Expanded(
              child: _CircularRecipientsPaginatedList(
                circularId: circular.id,
                roleLabel: _roleLabel,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircularRecipientsPaginatedList extends ConsumerStatefulWidget {
  final String circularId;
  final String Function(String role) roleLabel;

  const _CircularRecipientsPaginatedList({
    required this.circularId,
    required this.roleLabel,
  });

  @override
  ConsumerState<_CircularRecipientsPaginatedList> createState() =>
      _CircularRecipientsPaginatedListState();
}

class _CircularRecipientsPaginatedListState
    extends ConsumerState<_CircularRecipientsPaginatedList> {
  final _rows = <Map<String, dynamic>>[];
  DocumentSnapshot<Map<String, dynamic>>? _last;
  bool _isLoading = false;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadMore();
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
          .doc(widget.circularId)
          .collection('Recipients')
          .orderBy('name')
          .limit(50);
      if (_last != null) q = q.startAfterDocument(_last!);
      final snap = await q.get();
      if (snap.docs.isNotEmpty) _last = snap.docs.last;
      _rows.addAll(snap.docs.map((d) => d.data()));
      setState(() {
        _isLoading = false;
        _hasMore = snap.docs.length == 50;
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
    if (_rows.isEmpty && _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_rows.isEmpty && !_isLoading) {
      return const UnifiedEmptyState(
        message: 'لا توجد بيانات مستقبلين لهذا التعميم.',
        icon: Icons.table_chart,
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ListView.separated(
        padding: EdgeInsets.all(12.w),
        itemCount: _rows.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, __) =>
            Divider(height: 12.h, color: Colors.grey.shade200),
        itemBuilder: (context, index) {
          if (index >= _rows.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 8.h),
              child: Center(
                child: OutlinedButton.icon(
                  onPressed: _isLoading ? null : _loadMore,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.expand_more),
                  label: const Text('تحميل المزيد'),
                ),
              ),
            );
          }

          final r = _rows[index];
          final name = (r['name'] ?? '').toString().trim();
          final role = (r['role'] ?? '').toString().trim();
          final acknowledged = (r['acknowledged'] ?? false) == true;
          final ackAt = r['acknowledgedAt'] is Timestamp
              ? (r['acknowledgedAt'] as Timestamp).toDate()
              : null;
          final ackAtStr = ackAt == null
              ? '—'
              : DateFormat('yyyy-MM-dd HH:mm').format(ackAt);

          return ListTile(
            leading: CircleAvatar(
              backgroundColor: (acknowledged ? Colors.green : Colors.grey)
                  .withValues(alpha: 0.12),
              child: Icon(
                acknowledged ? Icons.verified : Icons.hourglass_empty,
                color: acknowledged
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
              ),
            ),
            title: Text(
              name.isEmpty ? '—' : name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: Text(
              '${widget.roleLabel(role)} • $ackAtStr',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Container(
              padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
              decoration: BoxDecoration(
                color: (acknowledged ? Colors.green : Colors.orange).withValues(
                  alpha: 0.10,
                ),
                borderRadius: BorderRadius.circular(999.r),
              ),
              child: Text(
                acknowledged ? 'تم الاطلاع' : 'لم يطلع',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.bold,
                  color: acknowledged
                      ? Colors.green.shade700
                      : Colors.orange.shade800,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
