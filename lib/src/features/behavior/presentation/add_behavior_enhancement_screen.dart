import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import 'behavior_controller.dart';

class AddBehaviorEnhancementScreen extends ConsumerStatefulWidget {
  const AddBehaviorEnhancementScreen({super.key});

  @override
  ConsumerState<AddBehaviorEnhancementScreen> createState() => _AddBehaviorEnhancementScreenState();
}

class _AddBehaviorEnhancementScreenState extends ConsumerState<AddBehaviorEnhancementScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _enhancementType = 'نقطة إيجابية';
  final TextEditingController _notesController = TextEditingController();

  final List<String> _types = ['نقطة إيجابية', 'بطاقة تميز', 'شهادة شكر', 'تكريم في الطابور'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تسجيل تعزيز سلوكي',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Icon
              Center(
                child: Container(
                  padding: EdgeInsets.all(20.w),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.thumb_up, size: 60.sp, color: Colors.green.shade700),
                ),
              ),
              SizedBox(height: 32.h),

              // Student Selection
              studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) return const Text('لا يوجد طلاب');
                  final value = (_selectedStudentId != null &&
                          students.any((s) => s.id == _selectedStudentId))
                      ? _selectedStudentId
                      : null;
                  return DropdownButtonFormField<String>(
                    decoration: InputDecoration(
                      labelText: 'اسم الطالب',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      prefixIcon: const Icon(Icons.person),
                    ),
                    value: value,
                    items: students
                        .map(
                          (s) => DropdownMenuItem(
                            value: s.id,
                            child: Text(s.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedStudentId = val),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'مطلوب' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              SizedBox(height: 20.h),

              // Enhancement Type
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'نوع التعزيز',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  prefixIcon: const Icon(Icons.star),
                ),
                value: _enhancementType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _enhancementType = val!),
              ),
              SizedBox(height: 20.h),

              // Notes
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'ملاحظات إضافية (اختياري)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  prefixIcon: const Icon(Icons.note),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 40.h),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text(
                  'تسجيل التعزيز',
                  style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    () async {
      final user = ref.read(authStateProvider).value;
      final schoolId = (user?.schoolId ?? '').trim();
      if (user == null || schoolId.isEmpty) return;

      final students = ref.read(studentsProvider).value ?? const <User>[];
      User? student;
      for (final s in students) {
        if (s.id == _selectedStudentId) {
          student = s;
          break;
        }
      }
      if (student == null) return;

      final points = _enhancementType == 'نقطة إيجابية'
          ? 1
          : (_enhancementType == 'بطاقة تميز' ? 2 : 3);

      final record = BehaviorRecord(
        id: const Uuid().v4(),
        studentId: student.id,
        teacherId: user.id,
        schoolId: schoolId,
        studentName: student.name,
        type: BehaviorType.positive,
        description: _enhancementType,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
        points: points,
        timestamp: DateTime.now(),
        status: BehaviorStatus.approved,
      );

      await ref.read(behaviorControllerProvider.notifier).addRecord(record);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم تسجيل التعزيز', style: GoogleFonts.cairo()),
          backgroundColor: Colors.green,
        ),
      );
      context.pop();
    }();
  }
}
