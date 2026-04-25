import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../../../core/utils/email_generator.dart';
import '../../../core/domain/models/user.dart';
import '../../../core/utils/text_utils.dart';
import '../data/mock_staff_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/delegated_permissions.dart';
import '../../common/services/audit_service.dart';

class AddStaffScreen extends ConsumerStatefulWidget {
  final UserRole role;
  final String title;
  final User? staffToEdit;

  const AddStaffScreen({
    super.key,
    required this.role,
    required this.title,
    this.staffToEdit,
  });

  @override
  ConsumerState<AddStaffScreen> createState() => _AddStaffScreenState();
}

class _AddStaffScreenState extends ConsumerState<AddStaffScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _identityController =
      TextEditingController(); // This will store System ID
  final _nationalIdController =
      TextEditingController(); // Actual National ID (Internal)
  final _phoneController = TextEditingController();
  final _customUsernameController = TextEditingController();
  String? _selectedDeputyType;
  bool _isLoading = false;
  final bool _useCustomUsername = false;

  // Delegation State
  bool _enableDelegation = false; // "Give additional permissions" toggle
  bool _showAll = false;
  bool _sensitiveMode = false;
  final Map<String, List<String>> _selectedPermissions = {};

  static final Map<String, Map<AdminSection, List<AdminPermission>>>
  _defaultDeputyPresets = {
    'academic': {
      AdminSection.students: [
        AdminPermission.view,
        AdminPermission.edit,
        AdminPermission.export,
      ],
      AdminSection.teachers: [
        AdminPermission.view,
        AdminPermission.edit,
        AdminPermission.export,
      ],
      AdminSection.exams: [
        AdminPermission.view,
        AdminPermission.create,
        AdminPermission.edit,
        AdminPermission.export,
      ],
      AdminSection.schedule: [
        AdminPermission.view,
        AdminPermission.edit,
        AdminPermission.export,
      ],
      AdminSection.reports: [AdminPermission.view, AdminPermission.export],
    },
    'student': {
      AdminSection.students: [
        AdminPermission.view,
        AdminPermission.edit,
        AdminPermission.export,
      ],
      AdminSection.administrative: [
        AdminPermission.view,
        AdminPermission.create,
        AdminPermission.edit,
        AdminPermission.approve,
      ],
      AdminSection.reports: [AdminPermission.view, AdminPermission.export],
    },
    'school': {
      AdminSection.administrative: [
        AdminPermission.view,
        AdminPermission.create,
        AdminPermission.edit,
        AdminPermission.approve,
      ],
      AdminSection.schedule: [AdminPermission.view, AdminPermission.edit],
      AdminSection.reports: [AdminPermission.view, AdminPermission.export],
    },
  };

  @override
  void initState() {
    super.initState();
    final staff = widget.staffToEdit;

    String roleCodePrefix(UserRole role) {
      switch (role) {
        case UserRole.deputy:
          return 'WK';
        case UserRole.counselor:
          return 'CN';
        case UserRole.administrative:
          return 'AD';
        case UserRole.admin:
          return 'MG';
        case UserRole.technicalSupport:
        case UserRole.supportAdmin:
          return 'TS';
        case UserRole.teacher:
          return 'TC';
        case UserRole.student:
          return 'ST';
        case UserRole.parent:
          return 'PR';
        case UserRole.superAdmin:
          return 'MG';
      }
    }

    String generateShortCode(UserRole role) {
      final prefix = roleCodePrefix(role);
      final digits = TextUtils.generateRandomDigits(6);
      return '$prefix$digits';
    }

    if (staff == null) {
      _identityController.text = generateShortCode(widget.role);
    }

    if (staff != null) {
      _nameController.text = staff.name;
      _identityController.text = staff.mnCode ?? staff.identityNumber ?? '';
      _nationalIdController.text = staff.nationalId ?? '';
      _phoneController.text = staff.phoneNumber ?? '';
      _selectedDeputyType = staff.deputyType;
      if (staff.delegatedPermissions != null) {
        staff.delegatedPermissions!.forEach((key, value) {
          final list = (value as List).map((e) => e.toString()).toList();
          _selectedPermissions[key] = list;
        });
        if (_selectedPermissions.isNotEmpty) {
          _enableDelegation = true;
          if (staff.delegatedPermissions!.containsKey(
                AdminSection.roles.name,
              ) ||
              staff.delegatedPermissions!.containsKey(
                AdminSection.settings.name,
              )) {
            _sensitiveMode = true;
          }
        }
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _identityController.dispose();
    _phoneController.dispose();
    _customUsernameController.dispose();
    super.dispose();
  }

  void _togglePermission(
    AdminSection section,
    AdminPermission permission,
    bool? value,
  ) {
    setState(() {
      final key = section.name;
      if (value == true) {
        if (!_selectedPermissions.containsKey(key)) {
          _selectedPermissions[key] = [];
        }
        if (!_selectedPermissions[key]!.contains(permission.name)) {
          _selectedPermissions[key]!.add(permission.name);
        }
      } else {
        if (_selectedPermissions.containsKey(key)) {
          _selectedPermissions[key]!.remove(permission.name);
          if (_selectedPermissions[key]!.isEmpty) {
            _selectedPermissions.remove(key);
          }
        }
      }
    });
  }

  void _toggleAll(bool? value) {
    setState(() {
      _showAll = value ?? false;
      if (_showAll) {
        for (var section in AdminSection.values) {
          // Skip sensitive sections unless sensitive mode is on
          if ((section == AdminSection.roles ||
                  section == AdminSection.settings) &&
              !_sensitiveMode) {
            continue;
          }
          _selectedPermissions[section.name] = AdminPermission.values
              .map((e) => e.name)
              .toList();
        }
      } else {
        _selectedPermissions.clear();
      }
    });
  }

  void _applyDefaultPreset() {
    if (_selectedDeputyType == null) {
      return;
    }
    final preset = _defaultDeputyPresets[_selectedDeputyType!];
    if (preset == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا توجد صلاحيات افتراضية لهذا النوع من الوكلاء'),
        ),
      );
      return;
    }

    setState(() {
      _enableDelegation = true;
      _sensitiveMode = false;
      _showAll = false;
      _selectedPermissions.clear();

      preset.forEach((section, perms) {
        _selectedPermissions[section.name] = perms.map((e) => e.name).toList();
      });
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate Deputy Type
    if (widget.role == UserRole.deputy && _selectedDeputyType == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('يرجى اختيار نوع الوكيل')));
      return;
    }

    // Validate Sensitive Permissions
    if (_sensitiveMode &&
        (_selectedPermissions.containsKey(AdminSection.roles.name) ||
            _selectedPermissions.containsKey(AdminSection.settings.name))) {
      // Mock confirmation
      bool confirmed =
          await showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('تأكيد صلاحيات حساسة'),
              content: const Text(
                'أنت على وشك منح صلاحيات سيادية (أدوار/إعدادات). هل أنت متأكد؟',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('إلغاء'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text(
                    'تأكيد',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed) return;
    }

    setState(() => _isLoading = true);

    try {
      final currentUser = ref.read(authStateProvider).value;
      final isSchoolMode =
          currentUser != null && (currentUser.schoolId?.isNotEmpty ?? false);

      final normalizedCode = TextUtils.normalizeDigits(_identityController.text)
          .replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '')
          .trim()
          .toUpperCase();
      final normalizedNationalId = TextUtils.normalizeDigits(
        _nationalIdController.text.trim(),
      );
      final normalizedPhone = TextUtils.normalizeDigits(
        _phoneController.text.trim(),
      );
      if (widget.staffToEdit != null) {
        final base = widget.staffToEdit!;
        final updated = base.copyWith(
          name: _nameController.text.trim(),
          mnCode: normalizedCode,
          nationalId: normalizedNationalId,
          phoneNumber: normalizedPhone,
          deputyType: _selectedDeputyType,
          delegatedPermissions:
              _enableDelegation && _selectedPermissions.isNotEmpty
              ? _selectedPermissions
              : null,
        );

        if (isSchoolMode) {
          final repo = ref.read(firestoreStaffRepositoryProvider);
          await repo.updateStaff(updated);
        } else {
          final repo = ref.read(mockStaffRepositoryProvider);
          await repo.updateStaff(updated);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('تم تعديل بيانات الموظف بنجاح')),
          );
          context.pop();
        }
      } else {
        String email;

        email = EmailGenerator.generateEmail(
          widget.role,
          identityNumber: normalizedCode,
        );

        final newStaff = User(
          id: const Uuid().v4(),
          name: _nameController.text.trim(),
          email: email,
          role: widget.role,
          schoolId: isSchoolMode ? (currentUser.schoolId ?? '') : '',
          deputyType: _selectedDeputyType,
          identityNumber: null,
          mnCode: normalizedCode,
          nationalId: normalizedNationalId,
          phoneNumber: normalizedPhone,
          isPasswordChangeRequired: true,
          isTwoFactorEnabled: true, // Auto-enable 2FA for sensitive roles
          delegatedPermissions:
              _enableDelegation && _selectedPermissions.isNotEmpty
              ? _selectedPermissions
              : null,
        );

        final randomPassword = TextUtils.generateRandomDigits(6);

        final StaffProvisioningResult provision;
        if (isSchoolMode) {
          final repo = ref.read(firestoreStaffRepositoryProvider);
          provision = await repo.addStaff(newStaff, randomPassword);
        } else {
          final repo = ref.read(mockStaffRepositoryProvider);
          provision = await repo.addStaff(newStaff, randomPassword);
        }

        // Register Global Entry Code via Cloud Function
        // تم تعطيل هذا مؤقتاً لأنه يحتاج Cloud Function
        /*
        try {
          final functions = FirebaseFunctions.instance;
          final callable = functions.httpsCallable('manageUserCode');
          await callable.call({
            'action': 'create',
            'code': normalizedIdentity.toUpperCase(),
            'email': newStaff.email,
            'schoolId': currentUser?.schoolId,
            'role': newStaff.role.name,
            'name': newStaff.name,
          });
        } catch (e) {
          debugPrint('Warning: Failed to register National ID as code: $e');
          // Don't block the flow, as the user is already created
        }
        */

        // تم تعطيل Audit Log مؤقتاً
        /*
        if (newStaff.delegatedPermissions != null &&
            newStaff.delegatedPermissions!.isNotEmpty) {
          ref
              .read(auditServiceProvider)
              .logAction(
                action: 'delegate_permissions',
                description:
                    'School Manager delegated permissions to staff user',
                metadata: {
                  'target_user_id': newStaff.id,
                  'permissions': newStaff.delegatedPermissions,
                  'sensitive_mode': _sensitiveMode,
                },
              );
        }
        */

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green),
                  SizedBox(width: 8),
                  Text('تمت الإضافة بنجاح'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'كود الدخول: ${provision.mnCode.isNotEmpty ? provision.mnCode : normalizedCode}',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'كلمة المرور: ${provision.password.isNotEmpty ? provision.password : randomPassword}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'يرجى حفظ بيانات الدخول وتزويدها للمستخدم.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    context.pop();
                  },
                  child: const Text('موافق'),
                ),
              ],
            ),
          );
        }
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
  }

  @override
  @override
  Widget build(BuildContext context) {
    final roleColors = {
      UserRole.counselor:     [const Color(0xFF6A1B9A), const Color(0xFF8E24AA)],
      UserRole.deputy:        [const Color(0xFF1565C0), const Color(0xFF1976D2)],
      UserRole.administrative:[const Color(0xFF00695C), const Color(0xFF00897B)],
    };
    final roleIcons = {
      UserRole.counselor:     Icons.psychology,
      UserRole.deputy:        Icons.manage_accounts,
      UserRole.administrative:Icons.badge,
    };
    final colors = roleColors[widget.role] ?? [const Color(0xFF1A237E), const Color(0xFF283593)];
    final roleIcon = roleIcons[widget.role] ?? Icons.person_add;

    return Scaffold(
      backgroundColor: const Color(0xFF0A1628),
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: colors,
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إضافة ${widget.title}',
                style: const TextStyle(color: Colors.white,
                    fontWeight: FontWeight.bold, fontSize: 16)),
            Text('تسجيل حساب جديد في المنصة',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
          ],
        ),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    colors[0].withValues(alpha: 0.2),
                    colors[0].withValues(alpha: 0.05),
                  ]),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors[0].withValues(alpha: 0.3)),
                ),
                child: Row(children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: colors[0].withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12)),
                    child: Icon(roleIcon, color: colors[1], size: 28)),
                  const SizedBox(width: 16),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(widget.title,
                        style: TextStyle(color: colors[1], fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    const Text('أدخل بيانات الحساب الجديد',
                        style: TextStyle(color: Colors.white38, fontSize: 12)),
                  ]),
                ]),
              ),
              const SizedBox(height: 20),
              _darkField(controller: _nameController, label: 'الاسم الرباعي',
                  icon: Icons.person,
                  validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال الاسم' : null),
              const SizedBox(height: 14),
              _darkField(controller: _identityController,
                  label: 'كود الدخول (حرفين + 6 أرقام)', hint: 'مثال: AD345694',
                  icon: Icons.badge, readOnly: widget.staffToEdit != null,
                  validator: (value) {
                    final v = (value ?? '').replaceAll(RegExp(r'[\u200E\u200F\u202A-\u202E]'), '').trim().toUpperCase();
                    if (v.isEmpty) return 'يرجى إدخال كود الدخول';
                    if (!RegExp(r'^[A-Z]{2}\d{6}$').hasMatch(v)) return 'صيغة الكود غير صحيحة';
                    return null;
                  }),
              const SizedBox(height: 14),
              _darkField(controller: _nationalIdController,
                  label: 'رقم الهوية/الإقامة (اختياري - داخلي)',
                  hint: 'بيان داخلي مشفر لأغراض التحقق فقط',
                  icon: Icons.fingerprint, keyboardType: TextInputType.number,
                  validator: (v) {
                    if (v != null && v.isNotEmpty && v.length != 10) return 'رقم الهوية يجب أن يكون 10 أرقام';
                    return null;
                  }),
              const SizedBox(height: 14),
              _darkField(controller: _phoneController,
                  label: 'رقم الجوال (للتحقق OTP)',
                  icon: Icons.phone, keyboardType: TextInputType.phone,
                  validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال رقم الجوال' : null),
              const SizedBox(height: 14),
              if (widget.role == UserRole.deputy) ...[
                _darkDropdown(
                  value: _selectedDeputyType, label: 'نوع الوكيل', icon: Icons.category,
                  items: const [
                    DropdownMenuItem(value: 'student', child: Text('وكيل شؤون الطلاب', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'academic', child: Text('وكيل الشؤون التعليمية', style: TextStyle(color: Colors.white))),
                    DropdownMenuItem(value: 'school', child: Text('وكيل الشؤون المدرسية', style: TextStyle(color: Colors.white))),
                  ],
                  onChanged: (v) => setState(() => _selectedDeputyType = v),
                ),
                const SizedBox(height: 14),
              ],
              if (widget.role == UserRole.deputy && _selectedDeputyType != null) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
                  child: Column(children: [
                    SwitchListTile(
                      title: const Text('منح صلاحيات إضافية', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      subtitle: const Text('تمكين الوكيل من الوصول لأقسام محددة', style: TextStyle(color: Colors.white38, fontSize: 11)),
                      value: _enableDelegation, activeColor: colors[1],
                      onChanged: (val) => setState(() {
                        _enableDelegation = val;
                        if (!val) { _selectedPermissions.clear(); _showAll = false; _sensitiveMode = false; }
                      }),
                    ),
                    if (_enableDelegation) Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(children: [
                        OutlinedButton.icon(
                          icon: Icon(Icons.auto_awesome, color: colors[1]),
                          label: Text('تطبيق الصلاحيات الافتراضية', style: TextStyle(color: colors[1])),
                          style: OutlinedButton.styleFrom(side: BorderSide(color: colors[0].withValues(alpha: 0.4))),
                          onPressed: _applyDefaultPreset),
                        const SizedBox(height: 8),
                        SwitchListTile(title: const Text('إظهار الكل', style: TextStyle(color: Colors.white70)),
                            value: _showAll, activeColor: colors[1], onChanged: _toggleAll),
                        SwitchListTile(title: const Text('صلاحيات حساسة', style: TextStyle(color: Colors.red)),
                            value: _sensitiveMode, activeColor: Colors.red,
                            onChanged: (val) => setState(() {
                              _sensitiveMode = val;
                              if (!val) { _selectedPermissions.remove(AdminSection.roles.name); _selectedPermissions.remove(AdminSection.settings.name); }
                            })),
                        _buildPermissionsList(),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 14),
              ],
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: colors[0].withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 4))]),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                    foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                  child: _isLoading
                      ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text('إضافة ${widget.title}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _darkField({required TextEditingController controller, required String label,
      String? hint, required IconData icon, bool readOnly = false,
      TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller, readOnly: readOnly, keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white), validator: validator,
      decoration: InputDecoration(
        labelText: label, hintText: hint,
        labelStyle: const TextStyle(color: Colors.white54),
        hintStyle: const TextStyle(color: Colors.white24),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF3949AB), width: 1.5)),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Colors.red)),
      ),
    );
  }

  Widget _darkDropdown({required String? value, required String label, required IconData icon,
      required List<DropdownMenuItem<String>> items, required void Function(String?) onChanged}) {
    return DropdownButtonFormField<String>(
      value: value, dropdownColor: const Color(0xFF1B2A4A),
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: Colors.white54),
        prefixIcon: Icon(icon, color: Colors.white38, size: 20),
        filled: true, fillColor: Colors.white.withValues(alpha: 0.07),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
      ),
      items: items, onChanged: onChanged,
    );
  }


  Widget _buildPermissionsList() {
    return Column(
      children: AdminSection.values.map((section) {
        if (!_sensitiveMode &&
            (section == AdminSection.roles || section == AdminSection.settings)) {
          return const SizedBox.shrink();
        }
        final sectionName = _getSectionName(section);
        final isSelected = _selectedPermissions.containsKey(section.name);
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08))),
          child: ExpansionTile(
            title: Text(sectionName,
                style: const TextStyle(color: Colors.white70, fontSize: 13)),
            leading: Checkbox(
              value: isSelected,
              fillColor: WidgetStateProperty.all(const Color(0xFF1565C0)),
              onChanged: (val) => setState(() {
                if (val == true) {
                  _togglePermission(section, AdminPermission.view, true);
                } else {
                  _selectedPermissions.remove(section.name);
                }
              }),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.all(8),
                child: Wrap(
                  spacing: 8,
                  children: AdminPermission.values.map((perm) {
                    final hasPerm = _selectedPermissions[section.name]?.contains(perm.name) ?? false;
                    return FilterChip(
                      label: Text(_getPermissionName(perm),
                          style: const TextStyle(color: Colors.white, fontSize: 11)),
                      selected: hasPerm,
                      selectedColor: const Color(0xFF1565C0).withValues(alpha: 0.3),
                      backgroundColor: Colors.white.withValues(alpha: 0.05),
                      onSelected: (val) => _togglePermission(section, perm, val),
                      visualDensity: VisualDensity.compact,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  String _getSectionName(AdminSection section) {
    switch (section) {
      case AdminSection.leadership:    return 'القيادة والمؤشرات';
      case AdminSection.classes:       return 'الفصول والشُعب';
      case AdminSection.students:      return 'الطلاب';
      case AdminSection.teachers:      return 'المعلمين';
      case AdminSection.administrative:return 'التكليفات الإدارية';
      case AdminSection.schedule:      return 'الجداول';
      case AdminSection.exams:         return 'الاختبارات';
      case AdminSection.roles:         return 'الصلاحيات والأدوار (حساس)';
      case AdminSection.reports:       return 'التقارير';
      case AdminSection.settings:      return 'إعدادات المدرسة (حساس)';
    }
  }

  String _getPermissionName(AdminPermission perm) {
    switch (perm) {
      case AdminPermission.view:   return 'عرض';
      case AdminPermission.create: return 'إنشاء';
      case AdminPermission.edit:   return 'تعديل';
      case AdminPermission.delete: return 'حذف';
      case AdminPermission.approve:return 'اعتماد';
      case AdminPermission.export: return 'تصدير';
    }
  }
}
