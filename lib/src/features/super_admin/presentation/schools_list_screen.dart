import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../data/super_admin_repository.dart';
import 'school_details_screen.dart';
import 'widgets/school_subscription_dialog.dart';

class SchoolsListScreen extends ConsumerStatefulWidget {
  const SchoolsListScreen({super.key});

  @override
  ConsumerState<SchoolsListScreen> createState() => _SchoolsListScreenState();
}

class _SchoolsListScreenState extends ConsumerState<SchoolsListScreen> {
  String _search = '';

  @override
  Widget build(BuildContext context) {
    final schoolsStream = ref.watch(schoolsStreamProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0D1B2A),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF283593), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('المدارس المسجلة',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('إدارة وعرض بيانات المدارس',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: schoolsStream.when(
        data: (schools) {
          final filtered = schools
              .where((s) =>
                  _search.isEmpty ||
                  s.name.toLowerCase().contains(_search.toLowerCase()) ||
                  s.city.toLowerCase().contains(_search.toLowerCase()))
              .toList();

          return Column(
            children: [
              // Stats + Search
              Container(
                padding: EdgeInsets.all(16.w),
                color: Colors.white.withValues(alpha: 0.03),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _statChip('الكل', schools.length.toString(), Colors.white54),
                        SizedBox(width: 8.w),
                        _statChip(
                            'حكومي',
                            schools.where((s) => s.type == 'government').length.toString(),
                            Colors.teal),
                        SizedBox(width: 8.w),
                        _statChip(
                            'أهلي',
                            schools.where((s) => s.type == 'private').length.toString(),
                            const Color(0xFF7B1FA2)),
                        SizedBox(width: 8.w),
                        _statChip(
                            'عالمي',
                            schools.where((s) => s.type == 'international').length.toString(),
                            const Color(0xFF1565C0)),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'بحث باسم المدرسة أو المدينة...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search, color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                  ],
                ),
              ),

              if (filtered.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.school_outlined,
                            color: Colors.white24, size: 56.sp),
                        SizedBox(height: 12.h),
                        Text('لا توجد مدارس مسجلة',
                            style: TextStyle(
                                color: Colors.white38, fontSize: 14.sp)),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.all(12.w),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) =>
                        _buildSchoolCard(context, ref, filtered[index]),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(
            child: CircularProgressIndicator(color: Colors.white)),
        error: (e, s) => Center(
            child: Text('خطأ: $e',
                style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _statChip(String label, String count, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 8.h),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8.r),
          border: Border.all(color: color.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(count,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 15.sp)),
            Text(label,
                style: TextStyle(
                    color: color.withValues(alpha: 0.8), fontSize: 9.sp)),
          ],
        ),
      ),
    );
  }

  Widget _buildSchoolCard(
      BuildContext context, WidgetRef ref, School school) {
    final typeColor = school.type == 'government'
        ? Colors.teal
        : school.type == 'private'
            ? const Color(0xFF7B1FA2)
            : const Color(0xFF1565C0);
    final typeLabel = school.type == 'government'
        ? 'حكومي'
        : school.type == 'private'
            ? 'أهلي'
            : 'عالمي';

    return Container(
      margin: EdgeInsets.only(bottom: 10.h),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
          colorScheme: ColorScheme.dark(
            primary: typeColor,
          ),
        ),
        child: ExpansionTile(
          tilePadding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 4.h),
          leading: Container(
            width: 42.w,
            height: 42.w,
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(Icons.school, color: typeColor, size: 20.sp),
          ),
          title: Text(school.name,
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 13.sp)),
          subtitle: Row(
            children: [
              Text('${school.city} • ${school.stage}',
                  style: TextStyle(color: Colors.white54, fontSize: 11.sp)),
              SizedBox(width: 8.w),
              Container(
                padding:
                    EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: typeColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4.r),
                ),
                child: Text(typeLabel,
                    style: TextStyle(
                        color: typeColor,
                        fontSize: 9.sp,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          iconColor: Colors.white54,
          collapsedIconColor: Colors.white38,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(14.w, 0, 14.w, 14.h),
              child: Column(
                children: [
                  Divider(color: Colors.white.withValues(alpha: 0.08)),
                  SizedBox(height: 8.h),
                  // Tech support header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('الدعم الفني',
                          style: TextStyle(
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.sp)),
                      TextButton.icon(
                        onPressed: () => _showAddTechSupportDialog(
                            context, ref, school.id),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF42A5F5),
                          padding: EdgeInsets.symmetric(
                              horizontal: 10.w, vertical: 4.h),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8.r),
                            side: const BorderSide(
                                color: Color(0xFF1565C0)),
                          ),
                        ),
                        icon: Icon(Icons.add, size: 14.sp),
                        label: Text('إضافة',
                            style: TextStyle(fontSize: 11.sp)),
                      ),
                    ],
                  ),
                  SizedBox(height: 8.h),
                  _TechnicalSupportList(schoolId: school.id),
                  SizedBox(height: 10.h),
                  Divider(color: Colors.white.withValues(alpha: 0.06)),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    SchoolDetailsScreen(school: school)),
                          ),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white70,
                            side: BorderSide(
                                color: Colors.white.withValues(alpha: 0.2)),
                            padding:
                                EdgeInsets.symmetric(vertical: 8.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r)),
                          ),
                          icon: Icon(Icons.visibility, size: 14.sp),
                          label: Text('التفاصيل',
                              style: TextStyle(fontSize: 11.sp)),
                        ),
                      ),
                      SizedBox(width: 8.w),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => showDialog(
                            context: context,
                            builder: (_) =>
                                SchoolSubscriptionDialog(school: school),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1565C0),
                            foregroundColor: Colors.white,
                            padding:
                                EdgeInsets.symmetric(vertical: 8.h),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r)),
                            elevation: 0,
                          ),
                          icon: Icon(Icons.subscriptions, size: 14.sp),
                          label: Text('الاشتراك',
                              style: TextStyle(fontSize: 11.sp)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddTechSupportDialog(
      BuildContext context, WidgetRef ref, String schoolId) async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: const Text('تعيين دعم فني',
            style: TextStyle(color: Colors.white)),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _dialogField(nameCtrl, 'الاسم', Icons.person),
              SizedBox(height: 10.h),
              _dialogField(emailCtrl, 'البريد / رقم الهوية', Icons.email),
              SizedBox(height: 10.h),
              _dialogField(passCtrl, 'كلمة المرور', Icons.lock,
                  obscure: true),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('إلغاء',
                style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (!formKey.currentState!.validate()) return;
              Navigator.pop(ctx);
              try {
                await ref
                    .read(superAdminRepositoryProvider)
                    .addTechnicalSupport(
                      schoolId: schoolId,
                      name: nameCtrl.text,
                      email: emailCtrl.text,
                      password: passCtrl.text,
                    );
                ref.invalidate(technicalSupportUsersProvider(schoolId));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('تمت إضافة الدعم الفني بنجاح'),
                    backgroundColor: Colors.green,
                  ));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('خطأ: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Widget _dialogField(TextEditingController ctrl, String label, IconData icon,
      {bool obscure = false}) {
    return TextFormField(
      controller: ctrl,
      obscureText: obscure,
      style: const TextStyle(color: Colors.white),
      validator: (v) => v == null || v.isEmpty ? 'مطلوب' : null,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 18),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10.r),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// ─── Technical Support List ───────────────────────────────────────────────────
class _TechnicalSupportList extends ConsumerWidget {
  final String schoolId;
  const _TechnicalSupportList({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(technicalSupportUsersProvider(schoolId));
    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h),
            child: Text('لا يوجد دعم فني',
                style: TextStyle(color: Colors.white38, fontSize: 11.sp)),
          );
        }
        return Column(
          children: users
              .map((user) => Container(
                    margin: EdgeInsets.only(bottom: 6.h),
                    padding: EdgeInsets.symmetric(
                        horizontal: 10.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.04),
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.support_agent,
                            color: Colors.green, size: 16.sp),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(user.name,
                                  style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 12.sp)),
                              Text(user.email,
                                  style: TextStyle(
                                      color: Colors.white38,
                                      fontSize: 10.sp)),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.edit,
                              color: Colors.orange, size: 16.sp),
                          onPressed: () =>
                              _showEditDialog(context, ref, schoolId, user),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        SizedBox(width: 8.w),
                        IconButton(
                          icon: Icon(Icons.delete,
                              color: Colors.red, size: 16.sp),
                          onPressed: () =>
                              _confirmDelete(context, ref, schoolId, user),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ))
              .toList(),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
      ),
      error: (e, s) => Text('خطأ: $e',
          style: const TextStyle(color: Colors.red)),
    );
  }

  Future<void> _showEditDialog(BuildContext context, WidgetRef ref,
      String schoolId, User user) async {
    final nameCtrl = TextEditingController(text: user.name);
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('تعديل البيانات',
            style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: nameCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            labelText: 'الاسم',
            labelStyle: TextStyle(color: Colors.white54),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(superAdminRepositoryProvider)
                  .updateTechnicalSupportUser(
                    schoolId: schoolId,
                    userId: user.id,
                    name: nameCtrl.text,
                  );
              ref.invalidate(technicalSupportUsersProvider(schoolId));
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1565C0),
                foregroundColor: Colors.white),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref,
      String schoolId, User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('حذف الدعم الفني',
            style: TextStyle(color: Colors.white)),
        content: Text('هل تريد حذف ${user.name}؟',
            style: const TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await ref
          .read(superAdminRepositoryProvider)
          .deleteTechnicalSupportUser(schoolId, user.id);
      ref.invalidate(technicalSupportUsersProvider(schoolId));
    }
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────
final schoolsStreamProvider = StreamProvider<List<School>>((ref) {
  return ref.read(superAdminRepositoryProvider).getSchools();
});

final technicalSupportUsersProvider =
    FutureProvider.family<List<User>, String>((ref, schoolId) {
  return ref
      .read(superAdminRepositoryProvider)
      .getTechnicalSupportUsers(schoolId);
});
