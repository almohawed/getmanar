import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../domain/staff_assignment.dart';
import '../application/staff_assignment_service.dart';
import '../../auth/presentation/auth_controller.dart';

class CreateStaffAssignmentScreen extends ConsumerStatefulWidget {
  final String schoolId;

  const CreateStaffAssignmentScreen({super.key, required this.schoolId});

  @override
  ConsumerState<CreateStaffAssignmentScreen> createState() => _CreateStaffAssignmentScreenState();
}

class _CreateStaffAssignmentScreenState extends ConsumerState<CreateStaffAssignmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _customTitleController = TextEditingController();
  
  String? _selectedUserId;
  String? _selectedUserName;
  String? _selectedUserRole;
  String _selectedType = AssignmentType.gradeDeputy;
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _customTitleController.dispose();
    super.dispose();
  }

  Future<void> _createAssignment() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الرجاء اختيار الموظف')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = ref.read(authStateProvider).value!;
      final service = StaffAssignmentService();

      final title = _selectedType == AssignmentType.custom
          ? _customTitleController.text
          : AssignmentType.getDisplayName(_selectedType);

      await service.createAssignment(
        schoolId: widget.schoolId,
        assignedUserId: _selectedUserId!,
        assignedUserName: _selectedUserName!,
        assignedUserRole: _selectedUserRole!,
        assignmentTitle: title,
        assignmentType: _selectedType,
        description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
        createdBy: user.id,
        createdByName: user.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إنشاء التكليف بنجاح')),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطأ: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إنشاء تكليف جديد'),
        backgroundColor: const Color(0xFF2D3494),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('نوع التكليف', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                items: AssignmentType.getAllTypes().map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Text(AssignmentType.getDisplayName(type)),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedType = value!);
                },
              ),
              if (_selectedType == AssignmentType.custom) ...[
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _customTitleController,
                  decoration: InputDecoration(
                    labelText: 'اسم التكليف',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  validator: (value) {
                    if (_selectedType == AssignmentType.custom && (value == null || value.isEmpty)) {
                      return 'الرجاء إدخال اسم التكليف';
                    }
                    return null;
                  },
                ),
              ],
              SizedBox(height: 16.h),
              Text('اختر الموظف', style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.bold)),
              SizedBox(height: 8.h),
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(8.r),
                  color: Colors.grey.shade50,
                ),
                child: _selectedUserId == null
                    ? TextButton.icon(
                        onPressed: () => _showUserSelectionDialog(),
                        icon: const Icon(Icons.person_add),
                        label: const Text('اختر موظف'),
                      )
                    : ListTile(
                        leading: CircleAvatar(child: Text(_selectedUserName![0])),
                        title: Text(_selectedUserName!),
                        subtitle: Text(_selectedUserRole!),
                        trailing: IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () {
                            setState(() {
                              _selectedUserId = null;
                              _selectedUserName = null;
                              _selectedUserRole = null;
                            });
                          },
                        ),
                      ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _descriptionController,
                decoration: InputDecoration(
                  labelText: 'الوصف (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8.r)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                ),
                maxLines: 3,
              ),
              SizedBox(height: 24.h),
              ElevatedButton(
                onPressed: _isLoading ? null : _createAssignment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2D3494),
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text('إنشاء التكليف', style: TextStyle(fontSize: 16.sp, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('اختر موظف'),
        content: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: const Text('معلم تجريبي'),
                subtitle: const Text('معلم'),
                onTap: () {
                  setState(() {
                    _selectedUserId = 'demo_teacher_1';
                    _selectedUserName = 'معلم تجريبي';
                    _selectedUserRole = 'معلم';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.admin_panel_settings)),
                title: const Text('إداري تجريبي'),
                subtitle: const Text('إداري'),
                onTap: () {
                  setState(() {
                    _selectedUserId = 'demo_admin_1';
                    _selectedUserName = 'إداري تجريبي';
                    _selectedUserRole = 'إداري';
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
