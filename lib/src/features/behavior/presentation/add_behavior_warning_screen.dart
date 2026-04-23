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

class AddBehaviorWarningScreen extends ConsumerStatefulWidget {
  const AddBehaviorWarningScreen({super.key});

  @override
  ConsumerState<AddBehaviorWarningScreen> createState() => _AddBehaviorWarningScreenState();
}

class _AddBehaviorWarningScreenState extends ConsumerState<AddBehaviorWarningScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _warningLevel = 'إنذار أول';
  final TextEditingController _reasonController = TextEditingController();

  final List<String> _levels = ['إنذار أول', 'إنذار ثاني', 'إنذار نهائي'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إضافة إنذار سلوكي',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.orange.shade800,
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
                    color: Colors.orange.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.warning_amber_rounded, size: 60.sp, color: Colors.orange.shade800),
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

              // Warning Level
              DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  labelText: 'درجة الإنذار',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  prefixIcon: const Icon(Icons.priority_high),
                ),
                value: _warningLevel,
                items: _levels.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _warningLevel = val!),
              ),
              SizedBox(height: 20.h),

              // Reason
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(
                  labelText: 'سبب الإنذار',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r)),
                  prefixIcon: const Icon(Icons.description),
                ),
                maxLines: 3,
                validator: (val) => val == null || val.isEmpty ? 'يرجى ذكر السبب' : null,
              ),
              SizedBox(height: 40.h),

              // Submit Button
              ElevatedButton(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade800,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
                ),
                child: Text(
                  'إصدار الإنذار',
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

      final points = _warningLevel == 'إنذار نهائي'
          ? -3
          : (_warningLevel == 'إنذار ثاني' ? -2 : -1);

      final record = BehaviorRecord(
        id: const Uuid().v4(),
        studentId: student.id,
        teacherId: user.id,
        schoolId: schoolId,
        studentName: student.name,
        type: BehaviorType.negative,
        description: '$_warningLevel: ${_reasonController.text.trim()}',
        points: points,
        timestamp: DateTime.now(),
        status: BehaviorStatus.warning,
      );

      await ref.read(behaviorControllerProvider.notifier).addRecord(record);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم إصدار $_warningLevel', style: GoogleFonts.cairo()),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      context.pop();
    }();
  }
}
