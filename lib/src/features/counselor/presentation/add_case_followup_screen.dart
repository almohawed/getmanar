// ============================================
// DEPRECATED: Old AddCaseFollowUpScreen
// تم استبدالها بـ AddFollowupScreen الاحترافية
// الموقع الجديد: lib/src/features/counselor/presentation/add_followup_screen.dart
// المسار: /counselor/add-followup أو /add-case-followup
// ============================================

/*
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/student_case.dart';
import 'counselor_providers.dart';

class AddCaseFollowUpScreen extends ConsumerStatefulWidget {
  const AddCaseFollowUpScreen({super.key});

  @override
  ConsumerState<AddCaseFollowUpScreen> createState() => _AddCaseFollowUpScreenState();
}

class _AddCaseFollowUpScreenState extends ConsumerState<AddCaseFollowUpScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCaseId;
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _nextStepController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(activeCasesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('إضافة متابعة دورية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.orange.shade700,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              casesAsync.when(
                data: (cases) {
                  if (cases.isEmpty) return const Text('لا توجد حالات نشطة');
                  final value = (_selectedCaseId != null &&
                          cases.any((c) => c.id == _selectedCaseId))
                      ? _selectedCaseId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'اختر الحالة',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    items: cases
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text('${c.studentName} - ${c.title}'),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedCaseId = val),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'مطلوب' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: 'ملاحظات المتابعة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                maxLines: 4,
                validator: (val) => val == null || val.isEmpty ? 'يرجى إدخال الملاحظات' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _nextStepController,
                decoration: InputDecoration(labelText: 'الخطوة القادمة / الإجراء', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final user = ref.read(authStateProvider).value;
                  final schoolId = (user?.schoolId ?? '').trim();
                  if (user == null || schoolId.isEmpty) return;

                  await ref.read(counselorRepositoryProvider).addCaseFollowUp(
                        schoolId: schoolId,
                        caseId: _selectedCaseId!,
                        notes: _notesController.text,
                        nextStep: _nextStepController.text,
                        createdBy: user.id,
                      );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل المتابعة')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade700, padding: EdgeInsets.symmetric(vertical: 16.h), minimumSize: Size(double.infinity, 50.h)),
                child: Text('حفظ المتابعة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
*/
