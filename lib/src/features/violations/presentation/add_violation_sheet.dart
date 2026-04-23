import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import 'package:masar_app/src/features/auth/presentation/auth_controller.dart';
import '../../academic/presentation/students_provider.dart';
import '../domain/behavioral_violation.dart';
import '../data/firestore_violations_repository.dart';

class AddViolationSheet extends ConsumerStatefulWidget {
  const AddViolationSheet({super.key});

  @override
  ConsumerState<AddViolationSheet> createState() => _AddViolationSheetState();
}

class _AddViolationSheetState extends ConsumerState<AddViolationSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _notesController = TextEditingController();

  String? _selectedStudentId;
  String _selectedStudentName = '';
  ViolationLevel _selectedLevel = ViolationLevel.firstDegree;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedStudentId == null) {
      if (_selectedStudentId == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('الرجاء اختيار الطالب')));
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null || user.schoolId == null) {
        throw Exception('User or School ID missing');
      }

      final violation = BehavioralViolation(
        id: const Uuid().v4(),
        studentId: _selectedStudentId!,
        studentName: _selectedStudentName,
        recorderId: user.id,
        recorderName: user.name,
        schoolId: user.schoolId!,
        violationTitle: _titleController.text,
        description:
            _titleController.text, // Using title as description for now
        level: _selectedLevel,
        date: _selectedDate,
        notes: _notesController.text,
        status: ViolationStatus.pending, // Pending approval
      );

      await ref.read(violationsRepositoryProvider).addViolation(violation);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم تسجيل المخالفة بنجاح، بانتظار الاعتماد'),
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
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);

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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'تسجيل مخالفة سلوكية',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24.h),

              // Student Selection
              studentsAsync.when(
                data: (students) => DropdownButtonFormField<String>(
                  value: _selectedStudentId,
                  decoration: InputDecoration(
                    labelText: 'الطالب',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    prefixIcon: const Icon(Icons.person),
                  ),
                  items: students
                      .map(
                        (s) => DropdownMenuItem(
                          value: s.id,
                          child: Text(s.name),
                          onTap: () => _selectedStudentName = s.name,
                        ),
                      )
                      .toList(),
                  onChanged: (val) => setState(() => _selectedStudentId = val),
                ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),
              SizedBox(height: 16.h),

              // Violation Title
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: 'عنوان المخالفة',
                  hintText: 'مثال: إتلاف ممتلكات، تأخر صباحي...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  prefixIcon: const Icon(Icons.warning_amber),
                ),
                validator: (val) => val == null || val.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),

              // Level Selection
              DropdownButtonFormField<ViolationLevel>(
                value: _selectedLevel,
                decoration: InputDecoration(
                  labelText: 'درجة المخالفة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  prefixIcon: const Icon(Icons.align_vertical_bottom),
                ),
                items: ViolationLevel.values
                    .map(
                      (l) => DropdownMenuItem(
                        value: l,
                        child: Text(_getLevelName(l)),
                      ),
                    )
                    .toList(),
                onChanged: (val) => setState(() => _selectedLevel = val!),
              ),
              SizedBox(height: 16.h),

              // Date Picker
              InkWell(
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (date != null) setState(() => _selectedDate = date);
                },
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'تاريخ المخالفة',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    prefixIcon: const Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}",
                  ),
                ),
              ),
              SizedBox(height: 16.h),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إضافية',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 24.h),

              // Submit
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade800,
                  padding: EdgeInsets.symmetric(vertical: 12.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'حفظ وإرسال للاعتماد',
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
      ),
    );
  }

  String _getLevelName(ViolationLevel level) {
    switch (level) {
      case ViolationLevel.firstDegree:
        return 'الدرجة الأولى';
      case ViolationLevel.secondDegree:
        return 'الدرجة الثانية';
      case ViolationLevel.thirdDegree:
        return 'الدرجة الثالثة';
      case ViolationLevel.fourthDegree:
        return 'الدرجة الرابعة';
      case ViolationLevel.fifthDegree:
        return 'الدرجة الخامسة';
    }
  }
}
