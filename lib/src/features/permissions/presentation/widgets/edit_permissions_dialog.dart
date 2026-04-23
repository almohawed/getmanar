import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../domain/permission_model.dart';
import '../../application/permission_service.dart';

class EditPermissionsDialog extends StatefulWidget {
  final List<PermissionUser> users;
  final Future<void> Function(PermissionUser) onUpdate;

  const EditPermissionsDialog({
    super.key,
    required this.users,
    required this.onUpdate,
  });

  @override
  State<EditPermissionsDialog> createState() => _EditPermissionsDialogState();
}

class _EditPermissionsDialogState extends State<EditPermissionsDialog> {
  late List<PermissionUser> _filteredUsers;
  String _searchQuery = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _filteredUsers = widget.users;
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredUsers = widget.users.where((user) {
        return user.name.toLowerCase().contains(query.toLowerCase()) ||
               user.roleLabel.toLowerCase().contains(query.toLowerCase());
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 800.w,
        height: 700.h,
        padding: EdgeInsets.all(24.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'تعديل صلاحيات المستخدمين',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey.shade900,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            SizedBox(height: 16.h),
            TextField(
              decoration: InputDecoration(
                hintText: 'ابحث عن موظف...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
              ),
              onChanged: _filterUsers,
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: ListView.separated(
                itemCount: _filteredUsers.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final user = _filteredUsers[index];
                  return _buildUserTile(user);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTile(PermissionUser user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.blue.shade100,
        child: Text(user.name[0], style: TextStyle(color: Colors.blue.shade900, fontWeight: FontWeight.bold)),
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text('${user.roleLabel} - ${user.departmentLabel}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildPermissionDropdown(user),
          SizedBox(width: 8.w),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () {
              // Delete logic
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDropdown(PermissionUser user) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<PermissionLevel>(
          value: user.permissionLevel,
          items: PermissionLevel.values.map((level) {
            return DropdownMenuItem(
              value: level,
              child: Text(
                _getLevelLabel(level),
                style: TextStyle(fontSize: 12.sp, color: _getLevelColor(level)),
              ),
            );
          }).toList(),
          onChanged: _isSaving
              ? null
              : (newLevel) async {
            if (newLevel != null) {
              final updatedUser = PermissionUser(
                id: user.id,
                name: user.name,
                role: user.role,
                department: user.department,
                permissionLevel: newLevel,
                lastLogin: user.lastLogin,
                isActive: user.isActive,
                assignedAt: user.assignedAt,
              );
              setState(() => _isSaving = true);
              try {
                await widget.onUpdate(updatedUser);
                if (!mounted) return;
                setState(() {
                  final index = _filteredUsers.indexWhere((u) => u.id == user.id);
                  if (index != -1) {
                    _filteredUsers[index] = updatedUser;
                  }
                });
              } finally {
                if (mounted) {
                  setState(() => _isSaving = false);
                }
              }
            }
          },
        ),
      ),
    );
  }

  String _getLevelLabel(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.full: return 'كاملة';
      case PermissionLevel.medium: return 'متوسطة';
      case PermissionLevel.limited: return 'محدودة';
    }
  }

  Color _getLevelColor(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.full: return Colors.red;
      case PermissionLevel.medium: return Colors.orange;
      case PermissionLevel.limited: return Colors.green;
    }
  }
}
