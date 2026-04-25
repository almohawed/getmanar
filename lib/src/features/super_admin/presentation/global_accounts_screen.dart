import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../data/super_admin_repository.dart';
import '../domain/global_user.dart';

class GlobalAccountsScreen extends ConsumerStatefulWidget {
  const GlobalAccountsScreen({super.key});

  @override
  ConsumerState<GlobalAccountsScreen> createState() =>
      _GlobalAccountsScreenState();
}

class _GlobalAccountsScreenState
    extends ConsumerState<GlobalAccountsScreen> {
  final Set<String> _selectedIds = {};
  bool _isDeleting = false;
  String _search = '';
  String _filterRole = 'all';

  static const _roleColors = {
    'admin': Color(0xFF1565C0),
    'manager': Color(0xFF1565C0),
    'teacher': Color(0xFF2E7D32),
    'deputy': Color(0xFF6A1B9A),
    'counselor': Color(0xFF00695C),
    'student': Color(0xFF37474F),
    'parent': Color(0xFFE65100),
  };

  static const _roleLabels = {
    'admin': 'مدير',
    'manager': 'مدير',
    'teacher': 'معلم',
    'deputy': 'وكيل',
    'counselor': 'مرشد',
    'student': 'طالب',
    'parent': 'ولي أمر',
    'technicalSupport': 'دعم فني',
    'supportAdmin': 'دعم إداري',
  };

  // الأدوار المسموح بعرضها (بدون طلاب وأولياء أمور)
  static const _staffRoles = {
    'admin', 'manager', 'teacher', 'deputy', 'counselor',
    'technicalSupport', 'supportAdmin',
  };

  Color _roleColor(String? role) =>
      _roleColors[role] ?? Colors.grey;

  String _roleLabel(String? role) =>
      _roleLabels[role] ?? (role ?? 'غير محدد');

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(globalAccountsProvider);

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
            Text('إدارة الحسابات',
                style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16.sp)),
            Text('المدراء والكادر التعليمي والإداري',
                style: TextStyle(color: Colors.white70, fontSize: 11.sp)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            tooltip: 'تحديث',
            onPressed: () => ref.invalidate(globalAccountsProvider),
          ),
          if (_selectedIds.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(left: 8.w),
              child: TextButton.icon(
                onPressed: _isDeleting ? null : _deleteSelected,
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                  backgroundColor: Colors.red.withValues(alpha: 0.15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r)),
                  padding: EdgeInsets.symmetric(
                      horizontal: 12.w, vertical: 6.h),
                ),
                icon: _isDeleting
                    ? SizedBox(
                        width: 14.w,
                        height: 14.h,
                        child: const CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.red))
                    : Icon(Icons.delete, size: 16.sp),
                label: Text('حذف (${_selectedIds.length})',
                    style: TextStyle(fontSize: 11.sp)),
              ),
            ),
          SizedBox(width: 8.w),
        ],
      ),
      body: accountsAsync.when(
        data: (accounts) {
          final filtered = accounts.where((a) {
            // استثناء الطلاب وأولياء الأمور دائماً
            if (!_staffRoles.contains(a.role)) return false;
            final matchSearch = _search.isEmpty ||
                (a.name ?? '').toLowerCase().contains(_search.toLowerCase()) ||
                (a.email ?? '').toLowerCase().contains(_search.toLowerCase());
            final matchRole =
                _filterRole == 'all' || a.role == _filterRole;
            return matchSearch && matchRole;
          }).toList();

          return Column(
            children: [
              // Search + Filter
              Container(
                padding: EdgeInsets.all(12.w),
                color: Colors.white.withValues(alpha: 0.03),
                child: Column(
                  children: [
                    TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'بحث بالاسم أو البريد...',
                        hintStyle: const TextStyle(color: Colors.white38),
                        prefixIcon: const Icon(Icons.search,
                            color: Colors.white38),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10.r),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding:
                            EdgeInsets.symmetric(vertical: 10.h),
                      ),
                    ),
                    SizedBox(height: 10.h),
                    // Role filter chips
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _filterChip('all', 'الكل', Colors.white54),
                          SizedBox(width: 6.w),
                          _filterChip('admin', 'مدير',
                              const Color(0xFF1565C0)),
                          SizedBox(width: 6.w),
                          _filterChip('teacher', 'معلم',
                              const Color(0xFF2E7D32)),
                          SizedBox(width: 6.w),
                          _filterChip('deputy', 'وكيل',
                              const Color(0xFF6A1B9A)),
                          SizedBox(width: 6.w),
                          _filterChip('counselor', 'مرشد',
                              const Color(0xFF00695C)),
                          SizedBox(width: 6.w),
                          _filterChip('supportAdmin', 'دعم إداري',
                              const Color(0xFF795548)),
                          SizedBox(width: 6.w),
                          _filterChip('technicalSupport', 'دعم فني',
                              const Color(0xFF0277BD)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Select all bar
              if (filtered.isNotEmpty)
                Container(
                  padding: EdgeInsets.symmetric(
                      horizontal: 16.w, vertical: 8.h),
                  color: Colors.white.withValues(alpha: 0.02),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() {
                          if (_selectedIds.length == filtered.length) {
                            _selectedIds.clear();
                          } else {
                            _selectedIds
                                .addAll(filtered.map((a) => a.id));
                          }
                        }),
                        child: Container(
                          width: 20.w,
                          height: 20.w,
                          decoration: BoxDecoration(
                            color: _selectedIds.length == filtered.length
                                ? const Color(0xFF1565C0)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(4.r),
                            border: Border.all(
                                color: _selectedIds.length ==
                                        filtered.length
                                    ? const Color(0xFF1565C0)
                                    : Colors.white38),
                          ),
                          child: _selectedIds.length == filtered.length
                              ? Icon(Icons.check,
                                  color: Colors.white, size: 14.sp)
                              : null,
                        ),
                      ),
                      SizedBox(width: 10.w),
                      Text('تحديد الكل',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12.sp)),
                      const Spacer(),
                      Text('${filtered.length} حساب',
                          style: TextStyle(
                              color: Colors.white38, fontSize: 11.sp)),
                    ],
                  ),
                ),

              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.manage_accounts,
                                color: Colors.white24, size: 48.sp),
                            SizedBox(height: 12.h),
                            Text('لا توجد حسابات',
                                style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 14.sp)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.all(12.w),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _buildAccountCard(filtered[i]),
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

  Widget _filterChip(String role, String label, Color color) {
    final isSelected = _filterRole == role;
    return GestureDetector(
      onTap: () => setState(() => _filterRole = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withValues(alpha: 0.25)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
              color: isSelected ? color : Colors.white12,
              width: isSelected ? 1.5 : 1),
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? color : Colors.white38,
                fontSize: 11.sp,
                fontWeight: isSelected
                    ? FontWeight.bold
                    : FontWeight.normal)),
      ),
    );
  }

  Widget _buildAccountCard(GlobalUser account) {
    final isSelected = _selectedIds.contains(account.id);
    final color = _roleColor(account.role);

    return GestureDetector(
      onTap: () => setState(() {
        if (isSelected) {
          _selectedIds.remove(account.id);
        } else {
          _selectedIds.add(account.id);
        }
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: EdgeInsets.only(bottom: 8.h),
        padding: EdgeInsets.all(12.w),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF1565C0).withValues(alpha: 0.15)
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1565C0).withValues(alpha: 0.5)
                : Colors.white.withValues(alpha: 0.07),
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20.w,
              height: 20.w,
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF1565C0)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(4.r),
                border: Border.all(
                    color: isSelected
                        ? const Color(0xFF1565C0)
                        : Colors.white38),
              ),
              child: isSelected
                  ? Icon(Icons.check, color: Colors.white, size: 14.sp)
                  : null,
            ),
            SizedBox(width: 12.w),
            // Avatar
            Container(
              width: 38.w,
              height: 38.w,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Center(
                child: Text(
                  (account.name ?? '?').isNotEmpty
                      ? (account.name ?? '?')[0].toUpperCase()
                      : '?',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp),
                ),
              ),
            ),
            SizedBox(width: 12.w),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(account.name ?? 'بدون اسم',
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.sp)),
                  SizedBox(height: 2.h),
                  Text(account.email ?? '',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 10.sp),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            // Role badge
            Container(
              padding:
                  EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Text(_roleLabel(account.role),
                  style: TextStyle(
                      color: color,
                      fontSize: 10.sp,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _deleteSelected() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1B2A4A),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red, size: 22.sp),
            SizedBox(width: 8.w),
            const Text('حذف الحسابات',
                style: TextStyle(color: Colors.white)),
          ],
        ),
        content: Text(
          'هل تريد حذف ${_selectedIds.length} حساب؟ لا يمكن التراجع.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('إلغاء',
                  style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white),
            child: const Text('حذف'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(superAdminRepositoryProvider);
      final accounts = ref.read(globalAccountsProvider).value ?? [];
      final toDelete =
          accounts.where((a) => _selectedIds.contains(a.id)).toList();
      for (final user in toDelete) {
        await repo.deleteGlobalAccount(user);
      }
      setState(() => _selectedIds.clear());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('تم الحذف بنجاح'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('خطأ: $e')));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }
}
