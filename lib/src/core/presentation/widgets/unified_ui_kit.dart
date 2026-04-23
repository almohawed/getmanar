import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../domain/models/user.dart';
import '../../../features/auth/presentation/auth_controller.dart';

/// A standard scaffold for all module screens.
/// Includes an Arabic header, optional subtitle, and permission checks.
class UnifiedPageScaffold extends ConsumerWidget {
  final String title;
  final String? subtitle;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;
  final TabController? tabController;
  final List<String>? tabs;
  final bool isLoading;
  final bool showAppBar;

  // RBAC Parameters
  final List<UserRole>? allowedRoles;
  final String? requiredDeputyType; // 'academic', 'school', 'student'
  final String? requiredPermission; // Key in delegatedPermissions

  const UnifiedPageScaffold({
    super.key,
    required this.title,
    required this.body,
    this.subtitle,
    this.actions,
    this.floatingActionButton,
    this.tabController,
    this.tabs,
    this.isLoading = false,
    this.allowedRoles,
    this.requiredDeputyType,
    this.requiredPermission,
    this.showAppBar = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userState = ref.watch(authStateProvider);
    final user = userState.value;

    // RBAC Check
    bool hasAccess = true;

    // Only perform check if restrictions are defined
    if (allowedRoles != null ||
        requiredDeputyType != null ||
        requiredPermission != null) {
      hasAccess = false;
      if (user != null) {
        // 1. SuperAdmin/Admin always have access
        if (user.role == UserRole.superAdmin || user.role == UserRole.admin) {
          hasAccess = true;
        } else {
          // 2. Evaluate Constraints
          bool matchesRole =
              allowedRoles == null || allowedRoles!.contains(user.role);
          bool matchesDeputyType =
              requiredDeputyType == null ||
              (user.role == UserRole.deputy &&
                  user.deputyType == requiredDeputyType);
          bool hasDelegatedPermission =
              requiredPermission != null &&
              (user.delegatedPermissions?.containsKey(requiredPermission) ??
                  false);

          // 3. Combine Logic:
          // Access granted if:
          // (Matches Role AND Matches Deputy Type)
          // OR
          // (Has Delegated Permission)
          if ((matchesRole && matchesDeputyType) || hasDelegatedPermission) {
            hasAccess = true;
          }
        }
      }
    }

    if (!hasAccess && !isLoading) {
      return const PermissionDeniedScreen();
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: showAppBar
          ? AppBar(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18.sp,
                      fontFamily: 'Cairo',
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.white70,
                        fontFamily: 'Cairo',
                      ),
                    ),
                ],
              ),
              centerTitle: false,
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              actions: actions,
              bottom: tabs != null
                  ? TabBar(
                      controller: tabController,
                      isScrollable: true,
                      indicatorColor: Colors.white,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      labelStyle: TextStyle(
                        fontFamily: 'Cairo',
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                      tabs: tabs!.map((t) => Tab(text: t)).toList(),
                    )
                  : null,
            )
          : null,
      body: isLoading ? const Center(child: CircularProgressIndicator()) : body,
      floatingActionButton: floatingActionButton,
    );
  }
}

/// A standard toolbar for lists/tables.
class UnifiedAction {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const UnifiedAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });
}

class UnifiedToolbar extends StatelessWidget {
  final VoidCallback? onSearch;
  final VoidCallback? onFilter;
  final List<Widget>? extraActions;
  final UnifiedAction? primaryAction;

  const UnifiedToolbar({
    super.key,
    this.onSearch,
    this.onFilter,
    this.extraActions,
    this.primaryAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        children: [
          if (onSearch != null)
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: onSearch,
              tooltip: 'بحث',
            ),
          if (onFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_list),
              onPressed: onFilter,
              tooltip: 'تصفية',
            ),
          if (primaryAction != null) ...[
            const SizedBox(width: 8),
            ElevatedButton.icon(
              onPressed: primaryAction!.onTap,
              icon: Icon(primaryAction!.icon),
              label: Text(primaryAction!.label),
            ),
          ],
          const Spacer(),
          if (extraActions != null) ...extraActions!,
        ],
      ),
    );
  }
}

/// A standard empty state widget.
class UnifiedEmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  final VoidCallback? onRetry;
  final UnifiedAction? action;

  const UnifiedEmptyState({
    super.key,
    this.message = 'لا توجد بيانات حالياً',
    this.icon = Icons.inbox,
    this.onRetry,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64.sp, color: Colors.grey.shade300),
          SizedBox(height: 16.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 16.sp,
              color: Colors.grey.shade500,
              fontFamily: 'Cairo',
            ),
          ),
          if (onRetry != null) ...[
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('تحديث'),
            ),
          ] else if (action != null) ...[
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: action!.onTap,
              icon: Icon(action!.icon),
              label: Text(action!.label),
            ),
          ],
        ],
      ),
    );
  }
}

/// Screen displayed when user lacks permission.
class PermissionDeniedScreen extends StatelessWidget {
  const PermissionDeniedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 80.sp, color: Colors.red),
            SizedBox(height: 24.h),
            Text(
              'عفواً، ليس لديك صلاحية للوصول إلى هذه الصفحة',
              style: TextStyle(fontSize: 18.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16.h),
            ElevatedButton(
              onPressed: () => context.go('/dashboard'),
              child: const Text('العودة للرئيسية'),
            ),
          ],
        ),
      ),
    );
  }
}

/// A simple placeholder widget for tabs that are "UIOnly" but not yet fully implemented.
class PlaceholderTab extends StatelessWidget {
  final String title;
  final IconData icon;

  const PlaceholderTab({
    super.key,
    required this.title,
    this.icon = Icons.construction,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        UnifiedToolbar(
          onSearch: () {},
          onFilter: () {},
          extraActions: [
            IconButton(
              icon: const Icon(Icons.print),
              onPressed: () {},
              tooltip: 'طباعة',
            ),
          ],
        ),
        Expanded(
          child: UnifiedEmptyState(
            message: '$title - قيد التطوير حالياً',
            icon: icon,
            onRetry: () {},
          ),
        ),
      ],
    );
  }
}
