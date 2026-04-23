import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:go_router/go_router.dart';
import '../../../core/domain/models/school.dart';
import '../../../core/domain/models/user.dart';
// import '../../academic/data/school_repository.dart';
import '../data/super_admin_repository.dart';

class SchoolDetailsScreen extends ConsumerStatefulWidget {
  final School school;

  const SchoolDetailsScreen({super.key, required this.school});

  @override
  ConsumerState<SchoolDetailsScreen> createState() =>
      _SchoolDetailsScreenState();
}

class _SchoolDetailsScreenState extends ConsumerState<SchoolDetailsScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final managerAsync = ref.watch(
      schoolManagerProvider((
        userId: widget.school.ownerId,
        schoolId: widget.school.id,
      )),
    );

    return Scaffold(
      appBar: AppBar(title: Text(widget.school.name)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('بيانات المدرسة'),
                  _buildInfoRow('اسم المدرسة', widget.school.name),
                  _buildInfoRow('المدينة', widget.school.city),
                  _buildInfoRow('المرحلة', widget.school.stage),
                  _buildInfoRow('النوع', widget.school.type),
                  _buildInfoRow(
                    'تربية خاصة',
                    widget.school.hasSpecialEducation ? 'نعم' : 'لا',
                  ),
                  const Divider(height: 32),
                  _buildSectionHeader('بيانات المدير'),
                  managerAsync.when(
                    data: (manager) {
                      if (manager == null) {
                        return Center(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.person_add),
                            label: const Text('إضافة مدير للمدرسة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.green,
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 12,
                              ),
                            ),
                            onPressed: _showAddManagerDialog,
                          ),
                        );
                      }
                      return Column(
                        children: [
                          _buildInfoRow('الاسم', manager.name),
                          _buildInfoRow('البريد الإلكتروني', manager.email),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.edit),
                                  label: const Text('تعديل الاسم'),
                                  onPressed: () => _showEditNameDialog(manager),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  icon: const Icon(Icons.lock_reset),
                                  label: const Text('تغيير/كلمة المرور'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () =>
                                      _showReplaceManagerDialog(manager),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.person_remove),
                              label: const Text('حذف المدير الحالي'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red),
                              ),
                              onPressed: () =>
                                  _showRemoveManagerDialog(manager),
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('خطأ: $e'),
                  ),
                  const Divider(height: 32),
                  _buildSectionHeader('الدعم الفني'),
                  _buildTechnicalSupportSection(),
                  const Divider(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.delete),
                      label: const Text('حذف المدرسة نهائياً'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: _showDeleteSchoolDialog,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.indigo,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  Future<void> _showAddManagerDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة مدير للمدرسة'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني / رقم الهوية',
                    hintText: 'أدخل البريد أو رقم الهوية',
                  ),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  validator: (v) => v!.length < 6 ? '6 أحرف على الأقل' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  final rawInput = emailController.text.trim();

                  await ref
                      .read(superAdminRepositoryProvider)
                      .addManager(
                        schoolId: widget.school.id,
                        name: nameController.text.trim(),
                        email: rawInput, // Pass raw input (email or identity)
                        password: passwordController.text.trim(),
                      );
                  // Force refresh by invalidating provider
                  ref.invalidate(
                    schoolManagerProvider((
                      userId: widget.school.ownerId,
                      schoolId: widget.school.id,
                    )),
                  );
                  // Since ownerId was updated in DB but not in widget.school, we might need to refresh school too.
                  // For now, let's just rely on list refresh if we go back, or maybe set state?
                  // Best to pop to list to ensure full refresh.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم إضافة المدير بنجاح')),
                    );
                    Navigator.pop(context); // Go back to list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                  }
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showRemoveManagerDialog(User manager) async {
    final confirmController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المدير الحالي'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من حذف المدير؟ ستبقى المدرسة بدون مدير حتى يتم تعيين مدير جديد.\n\nاكتب "حذف" للتأكيد:',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(hintText: 'حذف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (confirmController.text == 'حذف') {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(superAdminRepositoryProvider)
                      .removeManager(
                        schoolId: widget.school.id,
                        managerId: manager.id,
                      );
                  ref.invalidate(
                    schoolManagerProvider((
                      userId: widget.school.ownerId,
                      schoolId: widget.school.id,
                    )),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف المدير بنجاح')),
                    );
                    Navigator.pop(context); // Go back to list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                  }
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('تأكيد الحذف'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditNameDialog(User manager) async {
    final controller = TextEditingController(text: manager.name);
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل اسم المدير'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'الاسم الجديد'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              try {
                await ref
                    .read(superAdminRepositoryProvider)
                    .updateManagerName(
                      manager.id,
                      widget.school.id,
                      controller.text.trim(),
                    );
                ref.invalidate(
                  schoolManagerProvider((
                    userId: widget.school.ownerId,
                    schoolId: widget.school.id,
                  )),
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث الاسم بنجاح')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showReplaceManagerDialog(User currentManager) async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير المدير / كلمة المرور'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'سيتم إنشاء حساب جديد للمدير وحذف الحساب القديم. هذا الإجراء سيغير بيانات الدخول.',
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الجديد'),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني الجديد / رقم الهوية',
                    hintText: 'أدخل البريد أو رقم الهوية',
                  ),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(
                    labelText: 'كلمة المرور الجديدة',
                  ),
                  validator: (v) => v!.length < 6 ? '6 أحرف على الأقل' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  final rawInput = emailController.text.trim();

                  await ref
                      .read(superAdminRepositoryProvider)
                      .replaceManager(
                        schoolId: widget.school.id,
                        oldManagerId: currentManager.id,
                        newName: nameController.text.trim(),
                        newEmail: rawInput, // Pass raw input
                        newPassword: passwordController.text.trim(),
                      );
                  // Refresh requires navigating back because ownerId changed on school object
                  // Actually, we should probably pop back to list to refresh school data too.
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تغيير المدير بنجاح')),
                    );
                    Navigator.pop(context); // Go back to list to refresh
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                  }
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('تغيير'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteSchoolDialog() async {
    final confirmController = TextEditingController();
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف المدرسة نهائياً'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'هل أنت متأكد من حذف هذه المدرسة؟ سيتم حذف جميع البيانات المرتبطة بها.\n\nاكتب "حذف" للتأكيد:',
              style: TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(hintText: 'حذف'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              if (confirmController.text == 'حذف') {
                Navigator.pop(dialogContext); // Close dialog
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(superAdminRepositoryProvider)
                      .deleteSchool(widget.school.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم حذف المدرسة بنجاح')),
                    );
                    Navigator.pop(context); // Go back to list
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
                  }
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('حذف نهائي'),
          ),
        ],
      ),
    );
  }

  Widget _buildTechnicalSupportSection() {
    final usersAsync = ref.watch(
      schoolDetailsTechnicalSupportProvider(widget.school.id),
    );

    return Column(
      children: [
        usersAsync.when(
          data: (users) {
            if (users.isEmpty) {
              return Column(
                children: [
                  const Text(
                    'لا يوجد دعم فني',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _showAddTechnicalSupportDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('إضافة دعم فني'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                ...users.map(
                  (user) => Card(
                    margin: const EdgeInsets.only(bottom: 8.0),
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        children: [
                          ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.teal,
                              child: Icon(
                                Icons.support_agent,
                                color: Colors.white,
                              ),
                            ),
                            title: Text(user.name),
                            subtitle: Text(user.email),
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.orange,
                                    size: 20,
                                  ),
                                  label: const Text('تعديل الاسم'),
                                  onPressed: () =>
                                      _showEditTechnicalSupportDialog(user),
                                ),
                              ),
                              Expanded(
                                child: TextButton.icon(
                                  icon: const Icon(
                                    Icons.lock_reset,
                                    color: Colors.blue,
                                    size: 20,
                                  ),
                                  label: const Text('تغيير كلمة المرور'),
                                  onPressed: () =>
                                      _showChangeTechnicalSupportPasswordDialog(
                                        user,
                                      ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                              icon: const Icon(
                                Icons.delete,
                                color: Colors.red,
                                size: 20,
                              ),
                              label: const Text(
                                'حذف',
                                style: TextStyle(color: Colors.red),
                              ),
                              onPressed: () =>
                                  _confirmDeleteTechnicalSupport(user),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _showAddTechnicalSupportDialog,
                    icon: const Icon(Icons.add),
                    label: const Text('إضافة عضو آخر'),
                  ),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Text('خطأ: $e'),
        ),
      ],
    );
  }

  Future<void> _showChangeTechnicalSupportPasswordDialog(User user) async {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: passwordController,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
            validator: (v) => v!.length < 6 ? '6 أحرف على الأقل' : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(superAdminRepositoryProvider)
                      .replaceTechnicalSupportUser(
                        schoolId: widget.school.id,
                        oldUserId: user.id,
                        name: user.name,
                        email: user.email,
                        newPassword: passwordController.text.trim(),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم تغيير كلمة المرور بنجاح'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _showAddTechnicalSupportDialog() async {
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('إضافة دعم فني'),
        content: SingleChildScrollView(
          child: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: nameController,
                  decoration: const InputDecoration(labelText: 'الاسم'),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: emailController,
                  decoration: const InputDecoration(
                    labelText: 'البريد الإلكتروني / رقم الهوية',
                    helperText: 'مثال: support@school.com أو رقم الهوية',
                  ),
                  validator: (v) => v!.isEmpty ? 'مطلوب' : null,
                ),
                TextFormField(
                  controller: passwordController,
                  decoration: const InputDecoration(labelText: 'كلمة المرور'),
                  validator: (v) => v!.length < 6 ? '6 أحرف على الأقل' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext);
                setState(() => _isLoading = true);
                try {
                  await ref
                      .read(superAdminRepositoryProvider)
                      .addTechnicalSupport(
                        schoolId: widget.school.id,
                        name: nameController.text.trim(),
                        email: emailController.text.trim(),
                        password: passwordController.text.trim(),
                      );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تمت الإضافة بنجاح')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                } finally {
                  if (mounted) setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('إضافة'),
          ),
        ],
      ),
    );
  }

  Future<void> _showEditTechnicalSupportDialog(User user) async {
    final nameController = TextEditingController(text: user.name);
    await showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('تعديل البيانات'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'الاسم'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              setState(() => _isLoading = true);
              try {
                await ref
                    .read(superAdminRepositoryProvider)
                    .updateTechnicalSupportUser(
                      schoolId: widget.school.id,
                      userId: user.id,
                      name: nameController.text.trim(),
                    );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم التعديل بنجاح')),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                }
              } finally {
                if (mounted) setState(() => _isLoading = false);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteTechnicalSupport(User user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('حذف الدعم الفني'),
        content: Text('هل أنت متأكد من حذف ${user.name}؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      try {
        await ref
            .read(superAdminRepositoryProvider)
            .deleteTechnicalSupportUser(widget.school.id, user.id);
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}

final schoolDetailsTechnicalSupportProvider =
    StreamProvider.family<List<User>, String>((ref, schoolId) {
      return ref
          .read(superAdminRepositoryProvider)
          .getTechnicalSupportUsersStream(schoolId);
    });

final schoolManagerProvider =
    FutureProvider.family<User?, ({String userId, String? schoolId})>((
      ref,
      params,
    ) {
      return ref
          .read(superAdminRepositoryProvider)
          .getUser(params.userId, schoolId: params.schoolId);
    });
