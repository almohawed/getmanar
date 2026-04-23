import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/student_case.dart';
import 'counselor_providers.dart';

class AddStudentCaseScreen extends ConsumerStatefulWidget {
  const AddStudentCaseScreen({super.key});

  @override
  ConsumerState<AddStudentCaseScreen> createState() => _AddStudentCaseScreenState();
}

class _AddStudentCaseScreenState extends ConsumerState<AddStudentCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _caseType = 'دراسة';
  final TextEditingController _reasonController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final List<String> _types = ['دراسة', 'سلوكية', 'نفسية', 'اجتماعية'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة حالة طلابية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.blue.shade700,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) return const Text('لا يوجد طلاب');
                  final value = (_selectedStudentId != null &&
                          students.any((s) => s.id == _selectedStudentId))
                      ? _selectedStudentId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'اسم الطالب',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
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
                    validator: (v) =>
                        (v == null || v.isEmpty) ? 'مطلوب' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              SizedBox(height: 16.h),
              DropdownButtonFormField(
                decoration: InputDecoration(labelText: 'نوع الحالة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                value: _caseType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _caseType = val!),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _reasonController,
                decoration: InputDecoration(labelText: 'سبب الحالة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(labelText: 'وصف الحالة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                maxLines: 3,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
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

                  final caseTitle = _caseType;
                  final desc = [
                    _reasonController.text.trim(),
                    _descController.text.trim(),
                  ].where((e) => e.isNotEmpty).join('\n');

                  final studentCase = StudentCase(
                    id: const Uuid().v4(),
                    studentId: student.id,
                    studentName: student.name,
                    schoolId: schoolId,
                    title: caseTitle,
                    description: desc,
                    status: CaseStatus.open,
                    priority: CasePriority.medium,
                    createdAt: DateTime.now(),
                    assignedTo: user.id,
                  );

                  await ref
                      .read(counselorRepositoryProvider)
                      .createCase(studentCase);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة الحالة')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.blue.shade700, padding: EdgeInsets.symmetric(vertical: 16.h), minimumSize: Size(double.infinity, 50.h)),
                child: Text('حفظ الحالة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
