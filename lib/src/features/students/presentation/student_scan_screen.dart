import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../auth/presentation/auth_controller.dart';

class StudentScanScreen extends ConsumerStatefulWidget {
  const StudentScanScreen({super.key});

  @override
  ConsumerState<StudentScanScreen> createState() => _StudentScanScreenState();
}

class _StudentScanScreenState extends ConsumerState<StudentScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    torchEnabled: false,
    facing: CameraFacing.back,
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: [BarcodeFormat.qrCode, BarcodeFormat.code128],
  );
  bool _processing = false;
  String _status = 'وجّه الكاميرا نحو ملصق الطالب';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_processing) return;
    final raw = cap.barcodes.firstOrNull?.rawValue ?? '';
    final code = raw.trim();
    if (code.isEmpty) return;
    setState(() {
      _processing = true;
      _status = 'جارٍ التعرف...';
    });
    try {
      final user = ref.read(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (schoolId.isEmpty) throw Exception('لا يوجد مدرسة مرتبطة بالحساب');
      final student = await _findStudentByCode(schoolId: schoolId, code: code);
      if (!mounted) return;
      if (student == null) {
        setState(() {
          _status = 'لم يتم العثور على طالب لهذا الرمز';
          _processing = false;
        });
        return;
      }
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.r),
        ),
        builder: (_) => _StudentSheet(student: student),
      );
      if (!mounted) return;
      setState(() {
        _status = 'وجّه الكاميرا نحو ملصق الطالب';
        _processing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'خطأ: ${e.toString()}';
        _processing = false;
      });
    }
  }

  Future<User?> _findStudentByCode({
    required String schoolId,
    required String code,
  }) async {
    final parts = code.split('|');
    if (parts.length == 3 && parts.first == 'MNAR') {
      final sid = parts[1].trim();
      final studentId = parts[2].trim();
      if (sid.isNotEmpty && studentId.isNotEmpty) {
        final doc = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(sid)
            .collection('Students')
            .doc(studentId)
            .get();
        if (doc.exists && doc.data() != null) {
          return User.fromMap({...doc.data()!, 'id': doc.id});
        }
      }
    }

    final col = FirebaseFirestore.instance
        .collection('Schools')
        .doc(schoolId)
        .collection('Students');
    // Try studentCode
    var q = await col.where('studentCode', isEqualTo: code).limit(1).get();
    if (q.docs.isNotEmpty) {
      final d = q.docs.first;
      return User.fromMap({...d.data(), 'id': d.id});
    }
    // Try identityNumber
    q = await col.where('identityNumber', isEqualTo: code).limit(1).get();
    if (q.docs.isNotEmpty) {
      final d = q.docs.first;
      return User.fromMap({...d.data(), 'id': d.id});
    }
    // Try document id
    final d = await col.doc(code).get();
    if (d.exists && d.data() != null) {
      return User.fromMap({...d.data()!, 'id': d.id});
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final allowed =
        user != null &&
        (user.role == UserRole.admin ||
            user.role == UserRole.superAdmin ||
            user.role == UserRole.teacher ||
            user.role == UserRole.deputy ||
            user.role == UserRole.counselor);

    return UnifiedPageScaffold(
      title: 'ماسح هوية الطلاب',
      subtitle: 'قراءة باركود عبر كاميرا الجوال داخل التطبيق',
      allowedRoles: const [
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.teacher,
        UserRole.deputy,
        UserRole.counselor,
      ],
      body: !allowed
          ? const UnifiedEmptyState(
              message: 'ليست لديك صلاحية قراءة الباركود.',
              icon: Icons.lock,
            )
          : kIsWeb
          ? const UnifiedEmptyState(
              message:
                  'الماسح متاح على تطبيق الجوال فقط. استخدم التطبيق لقراءة الباركود.',
              icon: Icons.smartphone,
            )
          : Column(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16.r),
                    child: MobileScanner(
                      controller: _controller,
                      onDetect: _onDetect,
                    ),
                  ),
                ),
                SizedBox(height: 10.h),
                Padding(
                  padding: EdgeInsets.all(12.w),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _status,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade800,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => _controller.toggleTorch(),
                        icon: const Icon(Icons.flashlight_on),
                        tooltip: 'المصباح',
                      ),
                      IconButton(
                        onPressed: () => _controller.switchCamera(),
                        icon: const Icon(Icons.cameraswitch),
                        tooltip: 'تبديل الكاميرا',
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _StudentSheet extends ConsumerWidget {
  final User student;
  const _StudentSheet({required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classLabel = (student.assignedClassIds ?? const []).isNotEmpty
        ? student.assignedClassIds!.first
        : '';
    final code = (student.studentCode ?? student.identityNumber ?? '').trim();
    return Padding(
      padding: EdgeInsets.fromLTRB(
        16.w,
        16.h,
        16.w,
        16.h + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22.r,
                backgroundColor: Colors.indigo.withValues(alpha: 0.12),
                child: Icon(Icons.person, color: Colors.indigo.shade700),
              ),
              SizedBox(width: 10.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      student.name,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                        color: Colors.grey.shade900,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      [
                        if (classLabel.isNotEmpty) 'الفصل: $classLabel',
                        if (code.isNotEmpty) 'الكود: $code',
                      ].join(' • '),
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.check),
                  label: const Text('تم'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
