import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
import '../data/super_admin_repository.dart';
import 'school_details_screen.dart';
import 'widgets/school_subscription_dialog.dart';

class SchoolsListScreen extends ConsumerWidget {
  const SchoolsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolsStream = ref.watch(schoolsStreamProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('بيانات المدارس')),
      body: schoolsStream.when(
        data: (schools) {
          if (schools.isEmpty) {
            return const Center(child: Text('لا توجد مدارس مسجلة'));
          }
          return ListView.builder(
            itemCount: schools.length,
            itemBuilder: (context, index) {
              final school = schools[index];
              return Card(
                elevation: 4,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Colors.indigo, width: 1),
                ),
                child: ExpansionTile(
                  leading: const CircleAvatar(
                    backgroundColor: Colors.indigo,
                    child: Icon(Icons.business, color: Colors.white),
                  ),
                  title: Text(
                    school.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${school.city} - ${school.stage}'),
                      const SizedBox(height: 4),
                      const Text(
                        'اضغط لإدارة الدعم الفني',
                        style: TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16.0,
                        vertical: 8.0,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'الدعم الفني',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () {
                              _showAddTechnicalSupportDialog(
                                context,
                                ref,
                                school.id,
                              );
                            },
                            icon: const Icon(Icons.add),
                            label: const Text('إضافة دعم فني'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.indigo,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    _TechnicalSupportList(schoolId: school.id),
                    const Divider(),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        SchoolDetailsScreen(school: school),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.visibility),
                              label: const Text('تفاصيل المدرسة'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => SchoolSubscriptionDialog(school: school),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1565C0),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.subscriptions, size: 16),
                              label: const Text('إدارة الاشتراك'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('خطأ: $e')),
      ),
    );
  }

  Future<void> _showAddTechnicalSupportDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
  ) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعيين دعم فني'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'الاسم'),
                validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'البريد الإلكتروني / رقم الهوية',
                  helperText: 'سيتم استخدامه لتسجيل الدخول (مثال: support@school.com)',
                ),
                validator: (v) => v?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              TextFormField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'كلمة المرور'),
                validator: (v) =>
                    (v?.length ?? 0) < 6 ? '6 أحرف على الأقل' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                try {
                  Navigator.pop(context); // Close dialog first

                  // Show loading
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('جاري إضافة الدعم الفني...')),
                  );

                  await ref
                      .read(superAdminRepositoryProvider)
                      .addTechnicalSupport(
                        schoolId: schoolId,
                        name: nameController.text,
                        email: emailController.text,
                        password: passwordController.text,
                      );

                  // Refresh the list by invalidating provider
                  ref.invalidate(technicalSupportUsersProvider(schoolId));

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تمت إضافة الدعم الفني بنجاح'),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

class _TechnicalSupportList extends ConsumerWidget {
  final String schoolId;
  const _TechnicalSupportList({required this.schoolId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(technicalSupportUsersProvider(schoolId));

    return usersAsync.when(
      data: (users) {
        if (users.isEmpty) {
          return const ListTile(
            title: Text(
              'لا يوجد دعم فني هنا',
              style: TextStyle(color: Colors.grey),
            ),
            leading: Icon(Icons.info_outline, color: Colors.grey),
          );
        }
        return Column(
          children: users
              .map(
                (user) => ListTile(
                  leading: const Icon(Icons.support_agent, color: Colors.green),
                  title: Text(user.name),
                  subtitle: Text(user.email),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.orange),
                        onPressed: () =>
                            _showEditDialog(context, ref, schoolId, user),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () =>
                            _confirmDelete(context, ref, schoolId, user),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(8.0),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, s) => ListTile(title: Text('خطأ في التحميل: $e')),
    );
  }

  Future<void> _showEditDialog(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    User user,
  ) async {
    final nameController = TextEditingController(text: user.name);
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تعديل البيانات'),
        content: TextFormField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'الاسم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref
                  .read(superAdminRepositoryProvider)
                  .updateTechnicalSupportUser(
                    schoolId: schoolId,
                    userId: user.id,
                    name: nameController.text,
                  );
              ref.invalidate(technicalSupportUsersProvider(schoolId));
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String schoolId,
    User user,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الدعم الفني'),
        content: Text('هل أنت متأكد من حذف ${user.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
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

final schoolsStreamProvider = StreamProvider<List<School>>((ref) {
  return ref.read(superAdminRepositoryProvider).getSchools();
});

final technicalSupportUsersProvider = FutureProvider.family<List<User>, String>(
  (ref, schoolId) {
    return ref
        .read(superAdminRepositoryProvider)
        .getTechnicalSupportUsers(schoolId);
  },
);


