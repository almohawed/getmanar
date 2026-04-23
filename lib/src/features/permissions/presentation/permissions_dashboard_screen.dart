import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/permission_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'widgets/edit_permissions_dialog.dart';
import 'widgets/permissions_report_dialog.dart';
import 'widgets/security_review_dialog.dart';

class PermissionsDashboardScreen extends ConsumerStatefulWidget {
  const PermissionsDashboardScreen({super.key});

  @override
  ConsumerState<PermissionsDashboardScreen> createState() =>
      _PermissionsDashboardScreenState();
}

class _PermissionsDashboardScreenState
    extends ConsumerState<PermissionsDashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ScrollController _actionsScrollController =
      ScrollController(); // Added controller
  late List<PermissionUser> _users;
  late List<PermissionLog> _logs;
  late Map<String, dynamic> _stats;
  bool _isLoading = false;
  String? _loadedSchoolId;

  @override
  void initState() {
    super.initState();
    _users = [];
    _logs = [];
    _stats = {
      'totalUsers': 0,
      'admins': 0,
      'managers': 0,
      'teachers': 0,
      'custodians': 0,
      'highPrivilege': 0,
      'newUsers': 0,
      'disabledUsers': 0,
      'activeUsers': 0,
    };
  }

  @override
  void dispose() {
    _actionsScrollController.dispose();
    super.dispose();
  }

  void _refreshData() {
    final schoolId = ref.read(authStateProvider).value?.schoolId ?? '';
    if (schoolId.trim().isEmpty) return;
    _loadFromFirestore(schoolId.trim(), force: true);
  }

  PermissionLevel _inferPermissionLevel(
    String rawRole,
    Map<String, dynamic> data,
  ) {
    final role = rawRole.trim().toLowerCase();
    if (role == 'admin' || role == 'manager' || role == 'principal') {
      return PermissionLevel.full;
    }
    if (role == 'deputy') {
      final dp = data['delegatedPermissions'];
      if (dp is Map && dp.isNotEmpty) return PermissionLevel.medium;
      return PermissionLevel.limited;
    }
    if (role == 'counselor' || role == 'administrative') {
      return PermissionLevel.medium;
    }
    if (role == 'teacher') {
      return PermissionLevel.limited;
    }
    return PermissionLevel.limited;
  }

  UserRole _mapRole(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role == 'admin' || role == 'manager' || role == 'principal') {
      return UserRole.admin;
    }
    if (role == 'teacher') return UserRole.teacher;
    if (role == 'custodian') return UserRole.custodian;
    if (role == 'student') return UserRole.student;
    if (role == 'parent') return UserRole.parent;
    if (role == 'deputy' || role == 'counselor' || role == 'administrative') {
      return UserRole.manager;
    }
    return UserRole.other;
  }

  Department _mapDepartment(String rawRole) {
    final role = rawRole.trim().toLowerCase();
    if (role == 'admin' || role == 'manager' || role == 'principal') {
      return Department.schoolManagement;
    }
    if (role == 'administrative') return Department.administrativeAffairs;
    if (role == 'deputy') return Department.academicAffairs;
    if (role == 'counselor') return Department.studentAffairs;
    if (role == 'teacher') return Department.academicAffairs;
    return Department.other;
  }

  DateTime _tsToDate(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Map<String, List<String>> _delegatedPermissionsForLevel(
    PermissionLevel level,
  ) {
    if (level == PermissionLevel.full) {
      return {
        'leadership': ['view', 'create', 'edit', 'delete', 'approve', 'export'],
        'classes': ['view', 'create', 'edit', 'delete', 'approve', 'export'],
        'students': ['view', 'create', 'edit', 'delete', 'approve', 'export'],
        'teachers': ['view', 'create', 'edit', 'delete', 'approve', 'export'],
        'administrative': [
          'view',
          'create',
          'edit',
          'delete',
          'approve',
          'export',
        ],
        'schedule': ['view', 'create', 'edit', 'delete', 'approve', 'export'],
        'exams': ['view', 'create', 'edit', 'delete', 'approve', 'export'],
        'reports': ['view', 'export'],
      };
    }
    if (level == PermissionLevel.medium) {
      return {
        'leadership': ['view'],
        'classes': ['view', 'edit'],
        'students': ['view', 'edit', 'approve'],
        'teachers': ['view'],
        'administrative': ['view', 'create', 'edit', 'approve'],
        'schedule': ['view', 'edit'],
        'exams': ['view', 'edit', 'approve'],
        'reports': ['view', 'export'],
      };
    }
    return {
      'students': ['view'],
      'classes': ['view'],
      'schedule': ['view'],
      'exams': ['view'],
      'reports': ['view'],
    };
  }

  Future<void> _loadFromFirestore(String schoolId, {bool force = false}) async {
    if (!force && _loadedSchoolId == schoolId) return;
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final staffSnap = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Staff')
          .get();
      final teachersSnap = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .get();

      final logsSnap = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('PermissionLogs')
          .orderBy('timestamp', descending: true)
          .limit(50)
          .get();

      final now = DateTime.now();
      final weekAgo = now.subtract(const Duration(days: 7));

      final users = <PermissionUser>[];

      void addUserFromDoc(
        QueryDocumentSnapshot<Map<String, dynamic>> doc,
        String fallbackRole,
      ) {
        final d = doc.data();
        final rawRole = (d['role'] ?? fallbackRole).toString();
        final name = (d['name'] ?? d['displayName'] ?? '').toString().trim();
        final createdAt = _tsToDate(d['createdAt']);
        final lastLoginAt = d['lastLoginAt'];
        final lastLogin = lastLoginAt is String
            ? DateTime.tryParse(lastLoginAt)
            : null;
        final isActive = (d['isActive'] is bool)
            ? (d['isActive'] as bool)
            : true;
        final pLevel = _inferPermissionLevel(rawRole, d);

        users.add(
          PermissionUser(
            id: doc.id,
            name: name.isEmpty ? doc.id : name,
            role: _mapRole(rawRole),
            department: _mapDepartment(rawRole),
            permissionLevel: pLevel,
            lastLogin: lastLogin ?? createdAt,
            isActive: isActive,
            assignedAt: createdAt,
          ),
        );
      }

      for (final d in staffSnap.docs) {
        addUserFromDoc(d, 'staff');
      }
      for (final d in teachersSnap.docs) {
        addUserFromDoc(d, 'teacher');
      }

      users.sort((a, b) => b.assignedAt.compareTo(a.assignedAt));

      final logs = logsSnap.docs.map((d) {
        final m = d.data();
        return PermissionLog(
          id: d.id,
          action: (m['action'] ?? '').toString(),
          targetUser: (m['targetUserName'] ?? '').toString(),
          performedBy: (m['performedByName'] ?? '').toString(),
          timestamp: _tsToDate(m['timestamp']),
        );
      }).toList();

      final total = users.length;
      final disabled = users.where((u) => !u.isActive).length;
      final active = total - disabled;
      final newUsers = users.where((u) => u.assignedAt.isAfter(weekAgo)).length;
      final admins = users.where((u) => u.role == UserRole.admin).length;
      final managers = users.where((u) => u.role == UserRole.manager).length;
      final teachers = users.where((u) => u.role == UserRole.teacher).length;
      final custodians = users
          .where((u) => u.role == UserRole.custodian)
          .length;
      final highPrivilege = users
          .where((u) => u.permissionLevel == PermissionLevel.full)
          .length;

      setState(() {
        _loadedSchoolId = schoolId;
        _users = users;
        _logs = logs;
        _stats = {
          'totalUsers': total,
          'admins': admins,
          'managers': managers,
          'teachers': teachers,
          'custodians': custodians,
          'highPrivilege': highPrivilege,
          'newUsers': newUsers,
          'disabledUsers': disabled,
          'activeUsers': active,
          'lastCheck': now.toIso8601String(),
        };
      });
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _applyPermissionLevelToUser(PermissionUser updatedUser) async {
    final currentUser = ref.read(authStateProvider).value;
    final schoolId = currentUser?.schoolId ?? '';
    if (schoolId.trim().isEmpty) return;

    final targetId = updatedUser.id;
    final callerName = currentUser?.name ?? 'مدير المدرسة';

    final staffRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Staff')
        .doc(targetId);

    final staffSnap = await staffRef.get();
    if (staffSnap.exists) {
      final staffData = staffSnap.data() ?? {};
      final roleStr = (staffData['role'] ?? '').toString().toLowerCase();
      if (roleStr == 'deputy') {
        final delegated = _delegatedPermissionsForLevel(
          updatedUser.permissionLevel,
        );
        await staffRef.set({
          'delegatedPermissions': delegated,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
      await staffRef.set({
        'permissionLevel': updatedUser.permissionLevel.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('PermissionLogs')
        .add({
          'action':
              'تحديث مستوى الصلاحيات إلى ${updatedUser.permissionLevelLabel}',
          'targetUserId': targetId,
          'targetUserName': updatedUser.name,
          'performedById': currentUser?.id ?? '',
          'performedByName': callerName,
          'timestamp': FieldValue.serverTimestamp(),
        });

    await _loadFromFirestore(schoolId.trim(), force: true);
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(authStateProvider).value;
    final schoolId = currentUser?.schoolId ?? '';
    if (schoolId.trim().isNotEmpty &&
        _loadedSchoolId != schoolId &&
        !_isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadFromFirestore(schoolId.trim());
      });
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'لوحة إدارة الصلاحيات والوصول',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(
              'مراقبة توزيع الصلاحيات داخل المدرسة لضمان أمن البيانات وسلامة الإجراءات الإدارية',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.normal,
                color: Colors.white70,
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF2C3E50), // Dark Navy
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _refreshData),
        ],
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopStats(),
            SizedBox(height: 24.h),
            _buildActionButtons(), // Moved to top
            SizedBox(height: 24.h),
            _buildRoleDistributionCard(),
            SizedBox(height: 24.h),
            _buildAnalysisSection(),
            SizedBox(height: 24.h),
            _buildUserListSection(),
            SizedBox(height: 24.h),
            _buildSecurityIndicators(),
            SizedBox(height: 24.h),
            _buildLogSection(),
          ],
        ),
      ),
    );
  }

  Widget _buildTopStats() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        final children = [
          _buildStatCard(
            'إجمالي المستخدمين',
            '${_stats['totalUsers']}',
            Icons.group,
            Colors.blue,
          ),
          _buildStatCard(
            'مديرو النظام',
            '${_stats['admins']}',
            Icons.admin_panel_settings,
            Colors.red,
          ),
          _buildStatCard(
            'المستخدمون الإداريون',
            '${_stats['managers']}',
            Icons.manage_accounts,
            Colors.orange,
          ),
          _buildStatCard(
            'المعلمون',
            '${_stats['teachers']}',
            Icons.school,
            Colors.green,
          ),
          _buildStatCard(
            'موظفو العهد',
            '${_stats['custodians']}',
            Icons.inventory,
            Colors.brown,
          ),
        ];

        if (isMobile) {
          return GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12.w,
            mainAxisSpacing: 12.h,
            childAspectRatio: 1.3,
            children: children,
          );
        }
        return Wrap(
          spacing: 12.w,
          runSpacing: 12.h,
          children: children
              .map((c) => SizedBox(width: 180.w, child: c))
              .toList(),
        );
      },
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border(
          top: BorderSide(color: color, width: 4.h),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: TextStyle(
              fontSize: 22.sp,
              fontWeight: FontWeight.bold,
              color: Colors.blueGrey.shade900,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleDistributionCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;
        return Container(
          padding: EdgeInsets.all(20.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'توزيع الصلاحيات',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
              SizedBox(height: 20.h),
              isMobile
                  ? Column(
                      children: [
                        SizedBox(
                          height: 250.h,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 2,
                              centerSpaceRadius: 40,
                              sections: _getPieChartSections(),
                            ),
                          ),
                        ),
                        SizedBox(height: 24.h),
                        Wrap(
                          spacing: 16.w,
                          runSpacing: 12.h,
                          alignment: WrapAlignment.center,
                          children: _buildLegendItems(),
                        ),
                      ],
                    )
                  : SizedBox(
                      height: 200.h,
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: _getPieChartSections(),
                              ),
                            ),
                          ),
                          SizedBox(width: 20.w),
                          Expanded(
                            flex: 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: _buildLegendItems(),
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
  }

  List<PieChartSectionData> _getPieChartSections() {
    return [
      PieChartSectionData(
        color: Colors.red,
        value: _stats['admins'].toDouble(),
        title: '${_stats['admins']}',
        radius: 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        color: Colors.orange,
        value: _stats['managers'].toDouble(),
        title: '${_stats['managers']}',
        radius: 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        color: Colors.green,
        value: _stats['teachers'].toDouble(),
        title: '${_stats['teachers']}',
        radius: 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
      PieChartSectionData(
        color: Colors.brown,
        value: _stats['custodians'].toDouble(),
        title: '${_stats['custodians']}',
        radius: 50,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ];
  }

  List<Widget> _buildLegendItems() {
    return [
      _buildLegendItem('مدير نظام', Colors.red),
      _buildLegendItem('إداري', Colors.orange),
      _buildLegendItem('معلم', Colors.green),
      _buildLegendItem('موظف عهدة', Colors.brown),
    ];
  }

  Widget _buildLegendItem(String label, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Container(width: 12.w, height: 12.w, color: color),
          SizedBox(width: 8.w),
          Text(label, style: TextStyle(fontSize: 14.sp)),
        ],
      ),
    );
  }

  Widget _buildAnalysisSection() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.analytics, color: Colors.purple.shade700),
              SizedBox(width: 8.w),
              Text(
                'التحليل الإداري للصلاحيات',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildAnalysisItem('أكثر دور مستخدم', 'المعلم'),
              _buildAnalysisItem('أكثر قسم إداري', 'الشؤون الإدارية'),
              _buildAnalysisItem('صلاحيات حساسة', 'مدير النظام'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
        SizedBox(height: 4.h),
        Text(
          value,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade800,
          ),
        ),
      ],
    );
  }

  Widget _buildUserListSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'قائمة الموظفين والصلاحيات',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade900,
          ),
        ),
        SizedBox(height: 12.h),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _users.length > 5 ? 5 : _users.length, // Show first 5
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final user = _users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: Colors.blueGrey.shade100,
                  child: Text(
                    user.name[0],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(
                  user.name,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('${user.roleLabel} - ${user.departmentLabel}'),
                trailing: Chip(
                  label: Text(
                    user.permissionLevelLabel,
                    style: TextStyle(fontSize: 10.sp, color: Colors.white),
                  ),
                  backgroundColor: _getPermissionColor(user.permissionLevel),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Color _getPermissionColor(PermissionLevel level) {
    switch (level) {
      case PermissionLevel.full:
        return Colors.red;
      case PermissionLevel.medium:
        return Colors.orange;
      case PermissionLevel.limited:
        return Colors.green;
    }
  }

  Widget _buildSecurityIndicators() {
    final active = (_stats['activeUsers'] ?? 0).toString();
    final disabled = (_stats['disabledUsers'] ?? 0).toString();
    final newUsers = (_stats['newUsers'] ?? 0).toString();
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.green.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.security, color: Colors.green.shade700),
              SizedBox(width: 8.w),
              Text(
                'مؤشرات الأمان',
                style: TextStyle(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 16.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSecurityStat('الحسابات النشطة', active, Colors.green),
              _buildSecurityStat('الحسابات المعطلة', disabled, Colors.grey),
              _buildSecurityStat('الحسابات الجديدة', newUsers, Colors.blue),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        SizedBox(height: 4.h),
        Text(
          label,
          style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade600),
        ),
      ],
    );
  }

  Widget _buildLogSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'سجل تغييرات الصلاحيات',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blueGrey.shade900,
          ),
        ),
        SizedBox(height: 12.h),
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _logs.length > 5 ? 5 : _logs.length,
            separatorBuilder: (_, __) => const Divider(),
            itemBuilder: (context, index) {
              final log = _logs[index];
              return ListTile(
                leading: const Icon(Icons.history, color: Colors.grey),
                title: Text(log.action),
                subtitle: Text(
                  'للموظف: ${log.targetUser} - بواسطة: ${log.performedBy}',
                ),
                trailing: Text(
                  timeago.format(log.timestamp, locale: 'ar'),
                  style: TextStyle(fontSize: 12.sp, color: Colors.grey),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildActionButtons() {
    return Scrollbar(
      thumbVisibility: true,
      controller: _actionsScrollController, // Use controller
      child: SingleChildScrollView(
        controller: _actionsScrollController, // Bind controller
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(bottom: 12.h),
        child: Row(
          children: [
            _buildActionButton(
              'إضافة موظف جديد',
              Icons.person_add,
              Colors.blue,
              () {
                context.push('/staff-list');
              },
            ),
            SizedBox(width: 12.w),
            _buildActionButton('تعديل صلاحيات', Icons.edit, Colors.orange, () {
              showDialog(
                context: context,
                builder: (_) => EditPermissionsDialog(
                  users: _users,
                  onUpdate: (updatedUser) async {
                    await _applyPermissionLevelToUser(updatedUser);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم تحديث الصلاحيات بنجاح'),
                        ),
                      );
                    }
                  },
                ),
              );
            }),
            SizedBox(width: 12.w),
            _buildActionButton(
              'تقرير الصلاحيات',
              Icons.summarize,
              Colors.purple,
              () {
                showDialog(
                  context: context,
                  builder: (_) =>
                      PermissionsReportDialog(users: _users, logs: _logs),
                );
              },
            ),
            SizedBox(width: 12.w),
            _buildActionButton(
              'مراجعة الأمان',
              Icons.verified_user,
              Colors.green,
              () {
                showDialog(
                  context: context,
                  builder: (_) => SecurityReviewDialog(stats: _stats),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return ElevatedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 18.sp),
      label: Text(label, style: const TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
      ),
    );
  }
}
