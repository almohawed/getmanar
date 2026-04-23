import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_activity_repository.dart';

class RegisterStudentActivityScreen extends ConsumerStatefulWidget {
  const RegisterStudentActivityScreen({super.key});

  @override
  ConsumerState<RegisterStudentActivityScreen> createState() =>
      _RegisterStudentActivityScreenState();
}

class _RegisterStudentActivityScreenState
    extends ConsumerState<RegisterStudentActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String? _selectedActivityId;
  final TextEditingController _studentNameController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  final TextEditingController _otherActivityController =
      TextEditingController();
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final activitiesAsync = ref.watch(schoolActivitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تسجيل مشاركة طالب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
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
            children: [
              studentsAsync.when(
                data: (students) {
                  if (students.isEmpty) {
                    return Text(
                      'لا يوجد طلاب مسجلين',
                      style: GoogleFonts.cairo(color: Colors.grey),
                    );
                  }
                  final value =
                      (_selectedStudentId != null &&
                          students.any((s) => s.id == _selectedStudentId))
                      ? _selectedStudentId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'الطالب (اختياري)',
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
                    onChanged: (val) {
                      User? selected;
                      for (final s in students) {
                        if (s.id == val) {
                          selected = s;
                          break;
                        }
                      }
                      setState(() {
                        _selectedStudentId = val;
                        if (selected != null) {
                          _studentNameController.text = selected.name;
                        }
                      });
                    },
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _studentNameController,
                decoration: InputDecoration(
                  labelText: 'اسم الطالب',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                onChanged: (_) {
                  if (_selectedStudentId != null) {
                    setState(() => _selectedStudentId = null);
                  }
                },
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),
              activitiesAsync.when(
                data: (activities) {
                  final items = <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(value: '', child: Text('—')),
                    ...activities.map(
                      (a) => DropdownMenuItem<String>(
                        value: a.id,
                        child: Text(a.name),
                      ),
                    ),
                    const DropdownMenuItem<String>(
                      value: '__other__',
                      child: Text('أخرى'),
                    ),
                  ];

                  final value =
                      (_selectedActivityId != null &&
                          items.any((i) => i.value == _selectedActivityId))
                      ? _selectedActivityId
                      : null;

                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'النشاط',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    items: items,
                    onChanged: (val) =>
                        setState(() => _selectedActivityId = val),
                    validator: (v) => (v == null || v.isEmpty) ? 'مطلوب' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              if (_selectedActivityId == '__other__') ...[
                SizedBox(height: 16.h),
                TextFormField(
                  controller: _otherActivityController,
                  decoration: InputDecoration(
                    labelText: 'اسم النشاط',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  validator: (val) => val == null || val.isEmpty
                      ? 'يرجى كتابة اسم النشاط'
                      : null,
                ),
              ],
              SizedBox(height: 16.h),
              TextFormField(
                controller: _roleController,
                decoration: InputDecoration(
                  labelText: 'الدور في النشاط (مثال: مشارك، منظم)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: _isSubmitting
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_isSubmitting) return;
                        final user = ref.read(authStateProvider).value;
                        final schoolId = (user?.schoolId ?? '').trim();
                        if (schoolId.isEmpty) return;

                        setState(() => _isSubmitting = true);
                        try {
                          final students =
                              ref.read(studentsProvider).value ??
                              const <User>[];
                          User? selectedStudent;
                          for (final s in students) {
                            if (s.id == _selectedStudentId) {
                              selectedStudent = s;
                              break;
                            }
                          }

                          final studentName = _studentNameController.text
                              .trim();
                          final studentId =
                              selectedStudent?.id ??
                              'manual_${const Uuid().v4()}';

                          var activityId = _selectedActivityId ?? '';
                          if (activityId == '__other__') {
                            activityId = await ref
                                .read(activityRepositoryProvider)
                                .addActivity(
                                  schoolId,
                                  activityId: const Uuid().v4(),
                                  name: _otherActivityController.text,
                                  type: 'أخرى',
                                  date: null,
                                  supervisor: '',
                                  expectedCount: null,
                                  description: '',
                                  createdBy: user?.id,
                                );
                          }

                          if (activityId.isEmpty) return;
                          await ref
                              .read(activityRepositoryProvider)
                              .registerStudent(
                                schoolId,
                                activityId: activityId,
                                studentId: studentId,
                                studentName: studentName,
                                role: _roleController.text,
                              );

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('تم تسجيل المشاركة')),
                          );
                          context.pop();
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  'تسجيل المشاركة',
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
