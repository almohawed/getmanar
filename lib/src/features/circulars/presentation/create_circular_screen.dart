import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/presentation/widgets/unified_ui_kit.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/circular.dart';
import 'circulars_providers.dart';

class CreateCircularScreen extends ConsumerStatefulWidget {
  const CreateCircularScreen({super.key});

  @override
  ConsumerState<CreateCircularScreen> createState() =>
      _CreateCircularScreenState();
}

class _CreateCircularScreenState extends ConsumerState<CreateCircularScreen> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _allStaff = false;
  bool _toTeachers = true;
  bool _toAdministrative = true;
  bool _toDeputies = false;

  Uint8List? _bytes;
  String _fileName = '';
  String _mimeType = '';
  CircularAttachmentType? _attachmentType;
  bool _isSending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  List<String> _selectedRoles() {
    if (_allStaff) {
      return [
        UserRole.teacher.name,
        UserRole.administrative.name,
        UserRole.deputy.name,
      ];
    }
    final roles = <String>[];
    if (_toTeachers) roles.add(UserRole.teacher.name);
    if (_toAdministrative) roles.add(UserRole.administrative.name);
    if (_toDeputies) roles.add(UserRole.deputy.name);
    return roles;
  }

  Future<void> _pickPdf() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['pdf'],
      withData: true,
    );
    final f = result?.files.firstOrNull;
    if (f == null) return;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _bytes = bytes;
      _fileName = f.name;
      _mimeType = 'application/pdf';
      _attachmentType = CircularAttachmentType.pdf;
    });
  }

  Future<void> _pickImageFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final f = result?.files.firstOrNull;
    if (f == null) return;
    final bytes = f.bytes;
    if (bytes == null || bytes.isEmpty) return;
    final mime = (f.extension ?? '').toLowerCase() == 'png'
        ? 'image/png'
        : 'image/jpeg';
    setState(() {
      _bytes = bytes;
      _fileName = f.name;
      _mimeType = mime;
      _attachmentType = CircularAttachmentType.image;
    });
  }

  Future<void> _captureWithCamera() async {
    if (kIsWeb) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 1800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (bytes.isEmpty) return;
    setState(() {
      _bytes = bytes;
      _fileName = picked.name.isEmpty ? 'circular.jpg' : picked.name;
      _mimeType = 'image/jpeg';
      _attachmentType = CircularAttachmentType.image;
    });
  }

  Future<void> _send() async {
    if (_isSending) return;
    final user = ref.read(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    if (user == null || schoolId.isEmpty) return;

    final title = _titleCtrl.text.trim();
    final description = _descCtrl.text.trim();
    final roles = _selectedRoles();
    if (title.isEmpty || roles.isEmpty) return;
    if (_bytes == null || _attachmentType == null) return;

    setState(() => _isSending = true);
    try {
      final repo = ref.read(circularRepositoryProvider);
      await repo.createCircular(
        schoolId: schoolId,
        title: title,
        description: description,
        targetRoles: roles,
        attachmentType: _attachmentType!,
        attachmentFileName: _fileName.isEmpty ? 'attachment' : _fileName,
        attachmentMimeType: _mimeType.isEmpty
            ? 'application/octet-stream'
            : _mimeType,
        attachmentBytes: _bytes!,
        createdById: user.id,
        createdByName: user.name,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إرسال التعميم بنجاح'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/circulars');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.toString().replaceAll('Exception:', '').trim().isEmpty
                ? 'تعذر إرسال التعميم'
                : e.toString().replaceAll('Exception:', '').trim(),
          ),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();
    final canCreate =
        user != null &&
        (user.role == UserRole.admin ||
            user.role == UserRole.superAdmin ||
            (user.role == UserRole.deputy && user.deputyType == 'academic'));

    return UnifiedPageScaffold(
      title: 'إرسال تعميم',
      subtitle: 'رفع ملف وإلزام الموظفين بزر “تم الاطلاع”',
      allowedRoles: const [
        UserRole.admin,
        UserRole.superAdmin,
        UserRole.deputy,
      ],
      body: !canCreate
          ? const UnifiedEmptyState(
              message: 'لا توجد صلاحية لإرسال التعاميم من هذا الحساب.',
              icon: Icons.lock,
            )
          : Padding(
              padding: EdgeInsets.all(16.w),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 820),
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
                              TextField(
                                controller: _titleCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'عنوان التعميم',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.title),
                                ),
                              ),
                              SizedBox(height: 12.h),
                              TextField(
                                controller: _descCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'وصف (اختياري)',
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.subject),
                                ),
                                maxLines: 3,
                              ),
                              SizedBox(height: 14.h),
                              Text(
                                'الفئة المستهدفة',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('جميع الكوادر'),
                                subtitle: const Text(
                                  'المعلمين + الإداريين + الوكلاء',
                                ),
                                value: _allStaff,
                                onChanged: (v) {
                                  setState(() {
                                    _allStaff = v;
                                    if (v) {
                                      _toTeachers = true;
                                      _toAdministrative = true;
                                      _toDeputies = true;
                                    }
                                  });
                                },
                              ),
                              Wrap(
                                spacing: 10.w,
                                runSpacing: 6.h,
                                children: [
                                  FilterChip(
                                    label: const Text('المعلمين'),
                                    selected: _toTeachers,
                                    onSelected: _allStaff
                                        ? null
                                        : (v) =>
                                              setState(() => _toTeachers = v),
                                  ),
                                  FilterChip(
                                    label: const Text('الإداريين'),
                                    selected: _toAdministrative,
                                    onSelected: _allStaff
                                        ? null
                                        : (v) => setState(
                                            () => _toAdministrative = v,
                                          ),
                                  ),
                                  FilterChip(
                                    label: const Text('الوكلاء'),
                                    selected: _toDeputies,
                                    onSelected: _allStaff
                                        ? null
                                        : (v) =>
                                              setState(() => _toDeputies = v),
                                  ),
                                ],
                              ),
                              SizedBox(height: 14.h),
                              Text(
                                'مرفق التعميم',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey.shade900,
                                ),
                              ),
                              SizedBox(height: 8.h),
                              Wrap(
                                spacing: 10.w,
                                runSpacing: 10.h,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: _isSending ? null : _pickPdf,
                                    icon: const Icon(Icons.picture_as_pdf),
                                    label: const Text('رفع PDF'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: _isSending
                                        ? null
                                        : _pickImageFile,
                                    icon: const Icon(Icons.image),
                                    label: const Text('رفع صورة'),
                                  ),
                                  if (!kIsWeb)
                                    OutlinedButton.icon(
                                      onPressed: _isSending
                                          ? null
                                          : _captureWithCamera,
                                      icon: const Icon(Icons.camera_alt),
                                      label: const Text('تصوير بالكاميرا'),
                                    ),
                                ],
                              ),
                              SizedBox(height: 12.h),
                              if ((_bytes?.isNotEmpty ?? false) &&
                                  _attachmentType ==
                                      CircularAttachmentType.image)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12.r),
                                  child: Image.memory(
                                    _bytes!,
                                    height: 180.h,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else if ((_bytes?.isNotEmpty ?? false) &&
                                  _attachmentType == CircularAttachmentType.pdf)
                                Container(
                                  padding: EdgeInsets.all(12.w),
                                  decoration: BoxDecoration(
                                    color: Colors.blueGrey.withValues(
                                      alpha: 0.06,
                                    ),
                                    borderRadius: BorderRadius.circular(12.r),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.picture_as_pdf),
                                      SizedBox(width: 10.w),
                                      Expanded(
                                        child: Text(
                                          _fileName.isEmpty
                                              ? 'ملف PDF'
                                              : _fileName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              SizedBox(height: 16.h),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _isSending || schoolId.isEmpty
                                      ? null
                                      : _send,
                                  icon: _isSending
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : const Icon(Icons.send),
                                  label: Text(
                                    _isSending
                                        ? 'جارٍ الإرسال...'
                                        : 'إرسال التعميم',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.indigo.shade700,
                                    foregroundColor: Colors.white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: 14.h,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 10.h),
                      Text(
                        'سيظهر للموظفين زر “تم الاطلاع” ويُسجل كـ توقيع رسمي بالوقت والتاريخ.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
