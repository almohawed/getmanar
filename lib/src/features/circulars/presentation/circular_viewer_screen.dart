import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:pdfx/pdfx.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../../core/utils/device_context_info.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';
import '../domain/circular.dart';
import 'circulars_providers.dart';

class CircularViewerScreen extends ConsumerStatefulWidget {
  final String circularId;
  final bool adminView;

  const CircularViewerScreen({
    super.key,
    required this.circularId,
    this.adminView = false,
  });

  @override
  ConsumerState<CircularViewerScreen> createState() =>
      _CircularViewerScreenState();
}

class _CircularViewerScreenState extends ConsumerState<CircularViewerScreen> {
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _minTimer;
  bool _attachmentOpened = false;
  bool _minSecondsOk = false;
  bool _viewRecorded = false;
  bool _finalized = false;
  DeviceContextInfo? _deviceInfo;

  PdfControllerPinch? _pdfController;
  String? _pdfError;

  @override
  void initState() {
    super.initState();
    _stopwatch.start();
    unawaited(_loadDeviceInfo());
  }

  Future<void> _loadDeviceInfo() async {
    final info = await DeviceContextInfo.collect();
    if (!mounted) return;
    setState(() => _deviceInfo = info);
  }

  void _startMinTimerIfNeeded() {
    if (_minTimer != null) return;
    _minTimer = Timer(const Duration(seconds: 3), () {
      if (!mounted) return;
      setState(() => _minSecondsOk = true);
    });
  }

  Future<void> _recordViewOnce({required String schoolId}) async {
    if (widget.adminView) return;
    if (_viewRecorded) return;
    final user = ref.read(authStateProvider).value;
    final info = _deviceInfo;
    if (user == null || info == null) return;
    _viewRecorded = true;
    try {
      final repo = ref.read(circularRepositoryProvider);
      await repo.recordView(
        schoolId: schoolId,
        circularId: widget.circularId,
        userId: user.id,
        device: info.device,
        platform: info.platform,
        userAgent: info.userAgent,
      );
    } catch (_) {}
  }

  Future<void> _finalize({required String schoolId}) async {
    if (widget.adminView) return;
    if (_finalized) return;
    final user = ref.read(authStateProvider).value;
    final info = _deviceInfo;
    if (user == null || info == null) return;
    _finalized = true;
    try {
      final repo = ref.read(circularRepositoryProvider);
      await repo.finalizeView(
        schoolId: schoolId,
        circularId: widget.circularId,
        viewDurationMs: _stopwatch.elapsedMilliseconds,
        device: info.device,
        platform: info.platform,
        userAgent: info.userAgent,
      );
    } catch (_) {}
  }

  @override
  void dispose() {
    _minTimer?.cancel();
    _stopwatch.stop();
    _pdfController?.dispose();
    super.dispose();
  }

  Future<PdfDocument> _loadPdfDocument(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('تعذر تحميل PDF');
    }
    return PdfDocument.openData(res.bodyBytes);
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (user == null || schoolId.isEmpty) {
      return const UnifiedPageScaffold(
        title: 'التعميم',
        allowedRoles: [UserRole.teacher],
        body: UnifiedEmptyState(
          message: 'لا يمكن عرض التعميم بدون مدرسة مرتبطة بالحساب.',
          icon: Icons.campaign,
        ),
      );
    }

    final circularDoc = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffCirculars')
        .doc(widget.circularId);

    final recipientAsync = ref.watch(
      circularRecipientStatusProvider((
        circularId: widget.circularId,
        userId: user.id,
      )),
    );
    final recipient = recipientAsync.value ?? const {};
    final acknowledged = widget.adminView
        ? false
        : (recipient['acknowledged'] ?? false) == true;

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: circularDoc.snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return UnifiedPageScaffold(
            title: 'التعميم',
            subtitle: '',
            allowedRoles: const [
              UserRole.teacher,
              UserRole.administrative,
              UserRole.deputy,
              UserRole.admin,
              UserRole.supportAdmin,
              UserRole.technicalSupport,
              UserRole.superAdmin,
            ],
            body: Center(
              child: Text(
                'تعذر تحميل التعميم.\n${snap.error}',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
              ),
            ),
          );
        }
        if (!snap.hasData || !snap.data!.exists) {
          return const UnifiedPageScaffold(
            title: 'التعميم',
            allowedRoles: [
              UserRole.teacher,
              UserRole.administrative,
              UserRole.deputy,
              UserRole.admin,
              UserRole.supportAdmin,
              UserRole.technicalSupport,
              UserRole.superAdmin,
            ],
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snap.data!.data() ?? {};
        final title = (data['title'] ?? '').toString().trim();
        final attachmentUrl = (data['attachmentUrl'] ?? '').toString().trim();
        final typeRaw = (data['attachmentType'] ?? '').toString().trim();
        final circularNumber = (data['circularNumber'] as num?)?.toInt() ?? 0;
        final attachmentType = CircularAttachmentType.values.firstWhere(
          (e) => e.name == typeRaw,
          orElse: () => CircularAttachmentType.pdf,
        );

        Future<void> acknowledge() async {
          if (widget.adminView) return;
          if (!_attachmentOpened || !_minSecondsOk || acknowledged) return;
          final info = _deviceInfo;
          if (info == null) return;
          try {
            await _finalize(schoolId: schoolId);
            final repo = ref.read(circularRepositoryProvider);
            await repo.acknowledge(
              schoolId: schoolId,
              circularId: widget.circularId,
              userId: user.id,
              userName: user.name,
              userRole: user.role.name,
              device: info.device,
              platform: info.platform,
              userAgent: info.userAgent,
              viewDurationMs: _stopwatch.elapsedMilliseconds,
            );
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('تم تسجيل الاطلاع بنجاح'),
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.pop();
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  e.toString().replaceAll('Exception:', '').trim().isEmpty
                      ? 'تعذر تسجيل الاطلاع الآن'
                      : e.toString().replaceAll('Exception:', '').trim(),
                ),
                behavior: SnackBarBehavior.floating,
                backgroundColor: Colors.red,
              ),
            );
          }
        }

        Widget attachmentWidget() {
          if (attachmentUrl.isEmpty) {
            return const UnifiedEmptyState(
              message: 'لا يوجد مرفق لهذا التعميم.',
              icon: Icons.attach_file,
            );
          }

          if (attachmentType == CircularAttachmentType.image) {
            return Center(
              child: InteractiveViewer(
                maxScale: 4,
                child: Image.network(
                  attachmentUrl,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) {
                      if (!_attachmentOpened) {
                        _attachmentOpened = true;
                        _startMinTimerIfNeeded();
                        unawaited(_recordViewOnce(schoolId: schoolId));
                      }
                      return child;
                    }
                    return const Center(child: CircularProgressIndicator());
                  },
                  errorBuilder: (_, __, ___) => const UnifiedEmptyState(
                    message: 'تعذر تحميل الصورة',
                    icon: Icons.broken_image,
                  ),
                ),
              ),
            );
          }

          if (_pdfError != null) {
            return Center(
              child: Text(
                _pdfError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red, fontSize: 13.sp),
              ),
            );
          }

          _pdfController ??= PdfControllerPinch(
            document: _loadPdfDocument(attachmentUrl),
          );

          return PdfViewPinch(
            controller: _pdfController!,
            onDocumentLoaded: (_) {
              if (!_attachmentOpened) {
                setState(() => _attachmentOpened = true);
                _startMinTimerIfNeeded();
                unawaited(_recordViewOnce(schoolId: schoolId));
              }
            },
            onDocumentError: (e) {
              if (!mounted) return;
              setState(() => _pdfError = e.toString());
            },
            builders: PdfViewPinchBuilders<DefaultBuilderOptions>(
              options: const DefaultBuilderOptions(),
              documentLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              pageLoaderBuilder: (_) =>
                  const Center(child: CircularProgressIndicator()),
              errorBuilder: (_, error) => Center(
                child: Text(
                  'تعذر تحميل PDF\n$error',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red, fontSize: 13.sp),
                ),
              ),
            ),
          );
        }

        final showAck =
            !widget.adminView &&
            !acknowledged &&
            _attachmentOpened &&
            _minSecondsOk;

        Widget hintBar() {
          if (widget.adminView || acknowledged) return const SizedBox();
          String msg = '';
          Color accent = Colors.blueGrey;
          if (!_attachmentOpened) {
            msg = 'افتح المرفق أولاً ليتاح زر تم الاطلاع.';
            accent = Colors.orange;
          } else if (!_minSecondsOk) {
            msg = 'يرجى البقاء داخل التعميم 3 ثوانٍ على الأقل.';
            accent = Colors.orange;
          } else {
            msg = 'يمكنك الآن تأكيد الاطلاع.';
            accent = Colors.green;
          }
          return Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
            color: accent.withValues(alpha: 0.12),
            child: Text(
              msg,
              style: TextStyle(color: accent, fontWeight: FontWeight.w600),
            ),
          );
        }

        return PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) async {
            if (!didPop) return;
            await _finalize(schoolId: schoolId);
          },
          child: UnifiedPageScaffold(
            title: 'التعميم',
            subtitle: title.isEmpty
                ? (circularNumber > 0 ? 'رقم $circularNumber' : '')
                : (circularNumber > 0 ? 'رقم $circularNumber • $title' : title),
            allowedRoles: const [
              UserRole.teacher,
              UserRole.administrative,
              UserRole.deputy,
              UserRole.admin,
              UserRole.supportAdmin,
              UserRole.technicalSupport,
              UserRole.superAdmin,
            ],
            floatingActionButton: showAck
                ? FloatingActionButton.extended(
                    onPressed: acknowledge,
                    icon: const Icon(Icons.verified),
                    label: const Text('تم الاطلاع'),
                    backgroundColor: Colors.indigo.shade700,
                    foregroundColor: Colors.white,
                  )
                : null,
            body: Column(
              children: [
                hintBar(),
                Expanded(child: attachmentWidget()),
              ],
            ),
          ),
        );
      },
    );
  }
}
