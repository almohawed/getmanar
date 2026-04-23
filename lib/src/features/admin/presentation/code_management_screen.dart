import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../data/firestore_user_code_repository.dart';

// Provider for fetching UserCodes
final userCodesProvider =
    StreamProvider.family<List<Map<String, dynamic>>, String>((ref, schoolId) {
      if (schoolId.isEmpty) return Stream.value([]);
      return ref.read(userCodeRepositoryProvider).watchUserCodes(schoolId);
    });

class CodeManagementScreen extends ConsumerStatefulWidget {
  const CodeManagementScreen({super.key});

  @override
  ConsumerState<CodeManagementScreen> createState() =>
      _CodeManagementScreenState();
}

class _CodeManagementScreenState extends ConsumerState<CodeManagementScreen> {
  String _searchQuery = '';
  bool _isLoading = false;

  Future<void> _manageCode(
    String code,
    String action,
    String email,
    String schoolId,
    String role,
    String name,
  ) async {
    setState(() {
      _isLoading = true;
    });
    try {
      final functions = FirebaseFunctions.instance;
      final callable = functions.httpsCallable('manageUserCode');
      final result = await callable.call({
        'action': action,
        'code': code.toUpperCase(),
        'email': email,
        'schoolId': schoolId,
        'role': role,
        'name': name,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(result.data['message'])));
      }
    } on FirebaseFunctionsException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطأ: ${e.message}')));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _runMigration() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تهجير المستخدمين القدامى'),
        content: const Text(
          'سيقوم هذا الإجراء بتوليد أكواد دخول جديدة لجميع المستخدمين الذين لا يملكون كوداً حالياً. هل أنت متأكد؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('بدء التهجير'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isLoading = true);
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'migrateExistingUsersToCodes',
      );
      final result = await callable.call();
      final data = result.data as Map<Object?, Object?>;

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تمت عملية التهجير بنجاح. تم تحديث ${data['totalMigrated']} مستخدماً.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل التهجير: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _generatePdf(List<Map<String, dynamic>> userCodes) async {
    final pdf = pw.Document();

    // Use a font that supports Arabic
    final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Directionality(
                textDirection: pw.TextDirection.rtl,
                child: pw.Text('قائمة أكواد الدخول الموحدة'),
              ),
            ),
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.TableHelper.fromTextArray(
                context: context,
                data: <List<String>>[
                  <String>['الكود', 'الاسم', 'البريد', 'الدور'],
                  ...userCodes.map(
                    (u) => [
                      u['code'] ?? '',
                      u['name'] ?? '',
                      u['email'] ?? '',
                      u['role'] ?? '',
                    ],
                  ),
                ],
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                cellAlignment: pw.Alignment.centerRight,
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'أكواد_الدخول.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final schoolId = currentUser?.schoolId ?? '';

    final userCodesAsync = ref.watch(userCodesProvider(schoolId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة أكواد الدخول'),
        actions: [
          if (currentUser?.role == UserRole.superAdmin ||
              currentUser?.role.name == 'Owner')
            IconButton(
              icon: const Icon(Icons.cloud_sync, color: Colors.orange),
              onPressed: _runMigration,
              tooltip: 'تهجير المستخدمين القدامى',
            ),
          userCodesAsync.when(
            data: (userCodes) => IconButton(
              icon: const Icon(Icons.picture_as_pdf),
              onPressed: userCodes.isNotEmpty
                  ? () => _generatePdf(userCodes)
                  : null,
              tooltip: 'تصدير كـ PDF',
            ),
            loading: () => const SizedBox.shrink(),
            error: (e, s) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'بحث بالكود أو الاسم أو البريد',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: userCodesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('خطأ: $e')),
              data: (userCodes) {
                final filteredCodes = userCodes.where((codeData) {
                  final code = codeData['code']?.toString().toLowerCase() ?? '';
                  final name = codeData['name']?.toString().toLowerCase() ?? '';
                  final email =
                      codeData['email']?.toString().toLowerCase() ?? '';
                  final query = _searchQuery.toLowerCase();
                  return code.contains(query) ||
                      name.contains(query) ||
                      email.contains(query);
                }).toList();

                if (filteredCodes.isEmpty) {
                  return const Center(child: Text('لا توجد أكواد مطابقة.'));
                }

                return ListView.builder(
                  itemCount: filteredCodes.length,
                  itemBuilder: (context, index) {
                    final codeData = filteredCodes[index];
                    final code = codeData['code'] as String;
                    final email = codeData['email'] as String;
                    final name = codeData['name'] as String;
                    final role = codeData['role'] as String;
                    final isActive = codeData['isActive'] as bool? ?? true;
                    final deviceId = codeData['deviceId'] as String?;

                    return Card(
                      margin: EdgeInsets.symmetric(
                        horizontal: 16.w,
                        vertical: 8.h,
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16.w),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'الكود: $code',
                                  style: TextStyle(
                                    fontSize: 18.sp,
                                    fontWeight: FontWeight.bold,
                                    color: isActive ? Colors.green : Colors.red,
                                  ),
                                ),
                                if (deviceId != null)
                                  Chip(
                                    label: const Text(
                                      'جهاز مربوط',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    backgroundColor: Colors.blue.shade50,
                                    avatar: const Icon(
                                      Icons.phonelink_lock,
                                      size: 14,
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Text('الاسم: $name'),
                            Text('البريد: $email'),
                            Text('الدور: $role'),
                            Text('الحالة: ${isActive ? 'مفعل' : 'معطل'}'),
                            SizedBox(height: 8.h),
                            _isLoading
                                ? const CircularProgressIndicator()
                                : Wrap(
                                    spacing: 8.w,
                                    runSpacing: 8.h,
                                    children: [
                                      if (isActive)
                                        ElevatedButton.icon(
                                          onPressed: () => _manageCode(
                                            code,
                                            'disable',
                                            email,
                                            schoolId,
                                            role,
                                            name,
                                          ),
                                          icon: const Icon(
                                            Icons.block,
                                            size: 16,
                                          ),
                                          label: const Text('تعطيل'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.orange,
                                          ),
                                        )
                                      else
                                        ElevatedButton.icon(
                                          onPressed: () => _manageCode(
                                            code,
                                            'enable',
                                            email,
                                            schoolId,
                                            role,
                                            name,
                                          ),
                                          icon: const Icon(
                                            Icons.check_circle,
                                            size: 16,
                                          ),
                                          label: const Text('تفعيل'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.green,
                                          ),
                                        ),
                                      if (deviceId != null)
                                        ElevatedButton.icon(
                                          onPressed: () => _manageCode(
                                            code,
                                            'unbind',
                                            email,
                                            schoolId,
                                            role,
                                            name,
                                          ),
                                          icon: const Icon(
                                            Icons.phonelink_erase,
                                            size: 16,
                                          ),
                                          label: const Text('إلغاء ربط الجهاز'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                Colors.red.shade400,
                                          ),
                                        ),
                                      ElevatedButton.icon(
                                        onPressed: () => _manageCode(
                                          code,
                                          'rotate',
                                          email,
                                          schoolId,
                                          role,
                                          name,
                                        ),
                                        icon: const Icon(
                                          Icons.refresh,
                                          size: 16,
                                        ),
                                        label: const Text('إعادة إصدار'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.blue,
                                        ),
                                      ),
                                    ],
                                  ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
