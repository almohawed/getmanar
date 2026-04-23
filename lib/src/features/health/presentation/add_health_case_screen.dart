import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_health_repository.dart';

class AddHealthCaseScreen extends ConsumerStatefulWidget {
  const AddHealthCaseScreen({super.key});

  @override
  ConsumerState<AddHealthCaseScreen> createState() =>
      _AddHealthCaseScreenState();
}

class _AddHealthCaseScreenState extends ConsumerState<AddHealthCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _conditionType = 'مزمنة';
  final TextEditingController _conditionNameController =
      TextEditingController();
  final TextEditingController _medicationController = TextEditingController();
  final List<String> _types = ['مزمنة', 'طارئة', 'مؤقتة'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إضافة حالة صحية',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.blue.shade700,
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
            children: [
              studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) {
                    return const Text('لا يوجد طلاب مسجلين');
                  }
                  final value =
                      (_selectedStudentId != null &&
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
                        (v == null || v.isEmpty) ? 'يرجى اختيار الطالب' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              SizedBox(height: 16.h),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: 'نوع الحالة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                value: _conditionType,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _conditionType = val!),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _conditionNameController,
                decoration: InputDecoration(
                  labelText: 'اسم الحالة المرضية (مثال: ربو، سكري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _medicationController,
                decoration: InputDecoration(
                  labelText: 'الأدوية / الاحتياجات الخاصة',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                maxLines: 2,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final user = ref.read(authStateProvider).value;
                  final schoolId = (user?.schoolId ?? '').trim();
                  if (user == null || schoolId.isEmpty) return;

                  final students = ref.read(studentsProvider).value ?? [];
                  User? student;
                  for (final s in students) {
                    if (s.id == _selectedStudentId) {
                      student = s;
                      break;
                    }
                  }
                  if (student == null) return;

                  await ref
                      .read(healthRepositoryProvider)
                      .addCase(
                        schoolId: schoolId,
                        studentId: student.id,
                        studentName: student.name,
                        conditionType: _conditionType,
                        conditionName: _conditionNameController.text,
                        medication: _medicationController.text,
                        createdBy: user.id,
                      );

                  // تحديث healthStatus للطالب حسب نوع الحالة
                  final healthStatus = _conditionType == 'طارئة' ? 'bathroom' : 'care';
                  await FirebaseFirestore.instance
                      .collection('Schools')
                      .doc(schoolId)
                      .collection('Students')
                      .doc(student.id)
                      .update({'healthStatus': healthStatus});

                  // إعادة تحميل قائمة الطلاب
                  ref.invalidate(studentsProvider);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إضافة الحالة الصحية')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  'حفظ الحالة',
                  style: GoogleFonts.cairo(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
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
