import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../dashboard/presentation/providers/dashboard_providers.dart';
import '../data/permission_repository.dart';
import '../domain/permission_request.dart';

class ParentPermissionSheet extends ConsumerStatefulWidget {
  final User parent;
  final User? initialStudent;

  const ParentPermissionSheet({
    super.key,
    required this.parent,
    this.initialStudent,
  });

  @override
  ConsumerState<ParentPermissionSheet> createState() =>
      _ParentPermissionSheetState();
}

class _ParentPermissionSheetState extends ConsumerState<ParentPermissionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reasonController = TextEditingController();
  String? _selectedStudentId;
  User? _selectedStudent;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialStudent != null) {
      _selectedStudent = widget.initialStudent;
      _selectedStudentId = widget.initialStudent!.id;
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate() || _selectedStudent == null) {
      if (_selectedStudent == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الطالب')));
      }
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final schoolId = widget.parent.schoolId;
      if (schoolId == null || schoolId.isEmpty) {
        throw Exception('لا يمكن العثور على معرف المدرسة');
      }

      final request = PermissionRequest(
        id: const Uuid().v4(),
        studentId: _selectedStudent!.id,
        studentName: _selectedStudent!.name,
        parentId: widget.parent.id,
        reason: _reasonController.text,
        createdAt: DateTime.now(),
      );

      await ref.read(requestsProvider.notifier).addRequest(request, schoolId);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب الاستئذان بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('حدث خطأ: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final childrenAsync = ref.watch(parentChildrenProvider(widget.parent.id));

    return Container(
      padding: EdgeInsets.only(
        left: 16.w,
        right: 16.w,
        top: 16.w,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16.w,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20.r)),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'طلب استئذان طالب',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.indigo.shade800,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 24.h),

            // Child Selection
            childrenAsync.when(
              data: (children) {
                if (children.isEmpty) {
                  return const Text('لا يوجد أبناء مسجلين');
                }
                // Auto-select if only one child
                if (children.length == 1 && _selectedStudentId == null) {
                  _selectedStudentId = children.first.id;
                  _selectedStudent = children.first;
                }

                return DropdownButtonFormField<String>(
                  value: _selectedStudentId,
                  decoration: InputDecoration(
                    labelText: 'اختر الطالب',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  items: children.map((child) {
                    return DropdownMenuItem(
                      value: child.id,
                      child: Text(child.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedStudentId = value;
                      _selectedStudent = children.firstWhere(
                        (c) => c.id == value,
                      );
                    });
                  },
                  validator: (value) =>
                      value == null ? 'الرجاء اختيار الطالب' : null,
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ في تحميل الأبناء: $e'),
            ),

            SizedBox(height: 16.h),

            // Reason Input
            TextFormField(
              controller: _reasonController,
              decoration: InputDecoration(
                labelText: 'سبب الاستئذان',
                hintText: 'اكتب سبب الاستئذان هنا...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                prefixIcon: const Icon(Icons.edit_note),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'الرجاء كتابة سبب الاستئذان';
                }
                return null;
              },
            ),

            SizedBox(height: 24.h),

            // Submit Button
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitRequest,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.indigo,
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
              ),
              child: _isSubmitting
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(
                      'إرسال الطلب',
                      style: TextStyle(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
