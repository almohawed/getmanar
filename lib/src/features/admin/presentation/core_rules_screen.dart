import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/core_rules_repository.dart';
import '../domain/core_rule.dart';

class CoreRulesScreen extends ConsumerStatefulWidget {
  const CoreRulesScreen({super.key});

  @override
  ConsumerState<CoreRulesScreen> createState() => _CoreRulesScreenState();
}

class _CoreRulesScreenState extends ConsumerState<CoreRulesScreen> {
  void _showRuleDialog({CoreRule? rule}) {
    final titleController = TextEditingController(text: rule?.title ?? '');
    final descriptionController = TextEditingController(
      text: rule?.description ?? '',
    );
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rule == null ? 'إضافة قاعدة جديدة' : 'تعديل القاعدة'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: titleController,
                decoration: const InputDecoration(labelText: 'عنوان القاعدة'),
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'وصف القاعدة'),
                maxLines: 3,
                validator: (value) => value?.isEmpty ?? true ? 'مطلوب' : null,
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
              if (formKey.currentState?.validate() ?? false) {
                final user = ref.read(authStateProvider).value;
                if (user == null) return;

                final newRule = CoreRule(
                  id: rule?.id ?? const Uuid().v4(),
                  title: titleController.text,
                  description: descriptionController.text,
                  isActive: rule?.isActive ?? true,
                  createdAt: rule?.createdAt ?? DateTime.now(),
                  createdBy: rule?.createdBy ?? user.id,
                );

                final repository = ref.read(coreRulesRepositoryProvider);
                if (rule == null) {
                  await repository.addRule(user.schoolId!, newRule);
                } else {
                  await repository.updateRule(user.schoolId!, newRule);
                }

                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(coreRulesStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة القواعد الأساسية'),
        centerTitle: true,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showRuleDialog(),
        child: const Icon(Icons.add),
      ),
      body: rulesAsync.when(
        data: (rules) {
          if (rules.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.rule, size: 64.sp, color: Colors.grey),
                  SizedBox(height: 16.h),
                  const Text('لا توجد قواعد مضافة بعد'),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: EdgeInsets.all(16.w),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return Card(
                child: ListTile(
                  leading: Switch(
                    value: rule.isActive,
                    onChanged: (value) {
                      final user = ref.read(authStateProvider).value;
                      if (user != null) {
                        ref
                            .read(coreRulesRepositoryProvider)
                            .toggleRuleStatus(user.schoolId!, rule.id, value);
                      }
                    },
                  ),
                  title: Text(
                    rule.title,
                    style: TextStyle(
                      decoration: rule.isActive
                          ? null
                          : TextDecoration.lineThrough,
                      color: rule.isActive ? Colors.black : Colors.grey,
                    ),
                  ),
                  subtitle: Text(rule.description),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () => _showRuleDialog(rule: rule),
                  ),
                  onLongPress: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text('حذف القاعدة'),
                        content: const Text('هل أنت متأكد من حذف هذه القاعدة؟'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('إلغاء'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: const Text(
                              'حذف',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      final user = ref.read(authStateProvider).value;
                      if (user != null) {
                        await ref
                            .read(coreRulesRepositoryProvider)
                            .deleteRule(user.schoolId!, rule.id);
                      }
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
