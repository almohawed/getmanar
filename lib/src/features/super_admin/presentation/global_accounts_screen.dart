import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/super_admin_repository.dart';

class GlobalAccountsScreen extends ConsumerStatefulWidget {
  const GlobalAccountsScreen({super.key});

  @override
  ConsumerState<GlobalAccountsScreen> createState() =>
      _GlobalAccountsScreenState();
}

class _GlobalAccountsScreenState extends ConsumerState<GlobalAccountsScreen> {
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(globalAccountsProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('إدارة الحسابات (Firebase)'),
        actions: [
          if (_selectedIds.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _isDeleting ? null : _deleteSelected,
            ),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('لا توجد حسابات'));
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Row(
                  children: [
                    Checkbox(
                      value:
                          _selectedIds.length == accounts.length &&
                          accounts.isNotEmpty,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.addAll(accounts.map((a) => a.id));
                          } else {
                            _selectedIds.clear();
                          }
                        });
                      },
                    ),
                    const Text('تحديد الكل'),
                    const Spacer(),
                    Text('${_selectedIds.length} محدد'),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: accounts.length,
                  itemBuilder: (context, index) {
                    final account = accounts[index];
                    final isSelected = _selectedIds.contains(account.id);
                    return CheckboxListTile(
                      value: isSelected,
                      onChanged: (val) {
                        setState(() {
                          if (val == true) {
                            _selectedIds.add(account.id);
                          } else {
                            _selectedIds.remove(account.id);
                          }
                        });
                      },
                      title: Text(account.name ?? account.email ?? 'بدون اسم'),
                      subtitle: Text(
                        '${account.role ?? "N/A"} - ${account.schoolId ?? "N/A"} \n${account.email ?? ""}',
                      ),
                      secondary: CircleAvatar(
                        child: Text(
                          (account.name ?? "?").isNotEmpty
                              ? (account.name ?? "?")[0].toUpperCase()
                              : "?",
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحسابات'),
        content: Text(
          'هل أنت متأكد من حذف ${_selectedIds.length} حساب؟ لا يمكن التراجع عن هذا الإجراء.\nسيتم حذف الحساب من السجلات، لكن الحساب في المصادقة (Auth) قد يبقى حتى يتم حذفه يدويًا أو عبر أدوات المطور.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      final accounts = ref.read(globalAccountsProvider).value ?? [];

      // Filter selected accounts
      final toDelete = accounts
          .where((a) => _selectedIds.contains(a.id))
          .toList();

      for (final user in toDelete) {
        await repo.deleteGlobalAccount(user);
      }

      setState(() {
        _selectedIds.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('تم الحذف بنجاح')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }
}

// Removed duplicate provider definition as it is already defined in super_admin_repository.dart
// final globalAccountsProvider = StreamProvider<List<GlobalUser>>((ref) {
//   return ref.watch(superAdminRepositoryProvider).getAllGlobalUsers();
// });
