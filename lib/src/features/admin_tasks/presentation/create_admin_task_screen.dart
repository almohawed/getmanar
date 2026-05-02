import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../common/presentation/smart_section_scaffold.dart';
import '../domain/admin_task_entity.dart';
import 'admin_task_providers.dart';
import '../../admin/data/mock_teacher_repository.dart';
import '../../admin/data/mock_staff_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../../core/domain/models/user.dart';

class CreateAdminTaskScreen extends ConsumerStatefulWidget {
  final String? initialStaffId;

  const CreateAdminTaskScreen({super.key, this.initialStaffId});

  @override
  ConsumerState<CreateAdminTaskScreen> createState() =>
      _CreateAdminTaskScreenState();
}

class _CreateAdminTaskScreenState extends ConsumerState<CreateAdminTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  String? _selectedStaffId;
  User? _selectedStaffUser;
  AdminTaskPriority _selectedPriority = AdminTaskPriority.medium;
  AdminTaskType _selectedTaskType = AdminTaskType.general;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStaffId != null) {
      _selectedStaffId = widget.initialStaffId;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      locale: const Locale('ar', 'SA'),
    );
    if (picked != null && picked != _dueDate) {
      setState(() {
        _dueDate = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    // Ensure user is selected if ID is present (e.g. from initialStaffId)
    if (_selectedStaffUser == null && _selectedStaffId != null) {
      final staffList = ref.read(staffProvider).value ?? [];
      final teachersList = ref.read(teachersProvider).value ?? [];
      final allUsers = [...staffList, ...teachersList];

      try {
        _selectedStaffUser = allUsers.firstWhere(
          (u) => u.id == _selectedStaffId,
        );
      } catch (_) {
        // User not found in list
      }
    }

    if (_selectedStaffId == null || _selectedStaffUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الموظف المكلف')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null || currentUser.schoolId == null) {
        throw Exception('User not authenticated or school ID missing');
      }

      final newTask = AdminTaskEntity(
        id: const Uuid().v4(),
        schoolId: currentUser.schoolId!,
        title: _titleController.text,
        description: _descriptionController.text.isNotEmpty
            ? _descriptionController.text
            : null,
        assignedToId: _selectedStaffUser!.id,
        assignedToName: _selectedStaffUser!.name,
        assignedToRole: _selectedStaffUser!.role.name,
        priority: _selectedPriority,
        dueDate: _dueDate,
        createdAt: DateTime.now(),
        createdByUserId: currentUser.id,
        createdByRole: currentUser.role.name,
        status: AdminTaskStatus.open,
        type: _selectedTaskType,
      );

      final repo = ref.read(adminTaskRepositoryProvider);
      await repo.createTask(newTask);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم إنشاء التكليف بنجاح وإشعار الموظف'),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء إنشاء التكليف: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _getRoleLabel(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return 'مدير';
      case UserRole.teacher:
        return 'معلم';
      case UserRole.counselor:
        return 'مرشد';
      case UserRole.deputy:
        return 'وكيل';
      case UserRole.administrative:
        return 'إداري';
      case UserRole.teacher:
        return 'معلم';
      default:
        return 'موظف';
    }
  }

  String _getTaskTypeLabel(AdminTaskType type) {
    switch (type) {
      case AdminTaskType.floorSupervisor:
        return 'مشرف دور';
      case AdminTaskType.stageDeputy:
        return 'وكيل مرحلة';
      case AdminTaskType.safetyOfficer:
        return 'مسؤول الأمن والسلامة';
      case AdminTaskType.healthGuide:
        return 'المشرف الصحي';
      case AdminTaskType.activityLeader:
        return 'مسؤول النشاط';
      case AdminTaskType.classLeader:
        return 'رائد فصل';
      case AdminTaskType.committee:
        return 'عضو لجنة';
      case AdminTaskType.deputy:
        return 'وكيل';
      case AdminTaskType.general:
        return 'مهام إدارية أخرى';
    }
  }

  void _onTaskTypeChanged(AdminTaskType? newValue) {
    if (newValue == null) return;
    setState(() {
      _selectedTaskType = newValue;
      // Auto-fill title if it's a specific role type
      if (newValue != AdminTaskType.general) {
        _titleController.text = _getTaskTypeLabel(newValue);
      } else {
        _titleController.clear();
      }
    });
  }

  Widget _buildSmartSuggestionCard() {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
      ),
      child: Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'اقتراح ذكي: بناءً على الدليل الإجرائي، يُفضل تدوير مهام "الإشراف الصحي" و"الأمن والسلامة" فصلياً.',
              style: TextStyle(fontSize: 12.sp, color: Colors.blue.shade900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Fetch staff list (mock or real)
    final staffAsync = ref.watch(staffProvider);
    final teachersAsync = ref.watch(teachersProvider);

    return SmartSectionScaffold(
      title: 'إسناد تكليف جديد',
      icon: Icons.add_task,
      themeColor: Colors.blue,
      initialRecommendation:
          'توصي الوزارة بتدوير المهام الإشرافية فصلياً لضمان تجديد الدماء واكتشاف الكفاءات.',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSmartSuggestionCard(),
              SizedBox(height: 20.h),
              Text(
                'بيانات التكليف',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade800,
                ),
              ),
              SizedBox(height: 16.h),

              // Task Type Dropdown
              DropdownButtonFormField<AdminTaskType>(
                value: _selectedTaskType,
                decoration: InputDecoration(
                  labelText: 'نوع المهمة / التكليف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.category),
                ),
                items: AdminTaskType.values.map((type) {
                  return DropdownMenuItem<AdminTaskType>(
                    value: type,
                    child: Text(_getTaskTypeLabel(type)),
                  );
                }).toList(),
                onChanged: _onTaskTypeChanged,
              ),
              SizedBox(height: 16.h),

              // Title Field
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'مسمى المهمة',
                  hintText: 'مثال: إشراف المقصف المدرسي',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.title),
                ),
                validator: (value) => value!.isEmpty ? 'هذا الحقل مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              // Staff Selection
              staffAsync.when(
                data: (staff) {
                  return teachersAsync.when(
                    data: (teachers) {
                      final allUsers = [...staff, ...teachers];

                      // Ensure selected user is in the list or handle pre-selection
                      if (_selectedStaffId != null &&
                          _selectedStaffUser == null) {
                        try {
                          _selectedStaffUser = allUsers.firstWhere(
                            (u) => u.id == _selectedStaffId,
                          );
                        } catch (_) {}
                      }

                      return DropdownButtonFormField<String>(
                        value: _selectedStaffId,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'المكلف بالمهمة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          prefixIcon: const Icon(Icons.person_search),
                        ),
                        items: allUsers.map((user) {
                          return DropdownMenuItem<String>(
                            value: user.id,
                            child: Text(
                              '${user.name} - ${_getRoleLabel(user.role)}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedStaffId = value;
                            _selectedStaffUser = allUsers.firstWhere(
                              (u) => u.id == value,
                            );
                          });
                        },
                        validator: (value) =>
                            value == null ? 'الرجاء اختيار الموظف' : null,
                      );
                    },
                    loading: () =>
                        const Center(child: CircularProgressIndicator()),
                    error: (e, s) => Text('خطأ في تحميل المعلمين: $e'),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, s) => Text('خطأ في تحميل الموظفين: $e'),
              ),
              SizedBox(height: 16.h),

              // Priority Selection
              DropdownButtonFormField<AdminTaskPriority>(
                value: _selectedPriority,
                decoration: InputDecoration(
                  labelText: 'الأهمية',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  prefixIcon: const Icon(Icons.flag),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AdminTaskPriority.low,
                    child: Text('عادية'),
                  ),
                  DropdownMenuItem(
                    value: AdminTaskPriority.medium,
                    child: Text('متوسطة'),
                  ),
                  DropdownMenuItem(
                    value: AdminTaskPriority.high,
                    child: Text('هامة'),
                  ),
                  DropdownMenuItem(
                    value: AdminTaskPriority.urgent,
                    child: Text('عاجلة جداً'),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedPriority = value);
                  }
                },
              ),
              SizedBox(height: 16.h),

              // Due Date Selection
              InkWell(
                onTap: () => _selectDate(context),
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ الاستحقاق',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        // Format date manually or use intl
                        '${_dueDate.year}-${_dueDate.month.toString().padLeft(2, '0')}-${_dueDate.day.toString().padLeft(2, '0')}',
                      ),
                      const Icon(Icons.arrow_drop_down),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Description
              TextFormField(
                controller: _descriptionController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'تفاصيل المهمة (اختياري)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              SizedBox(height: 32.h),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 50.h,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue.shade700,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'إسناد التكليف',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
