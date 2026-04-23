import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/student_case.dart';
import 'counselor_providers.dart';

class CloseStudentCaseScreen extends ConsumerStatefulWidget {
  const CloseStudentCaseScreen({super.key});

  @override
  ConsumerState<CloseStudentCaseScreen> createState() => _CloseStudentCaseScreenState();
}

class _CloseStudentCaseScreenState extends ConsumerState<CloseStudentCaseScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedCaseId;
  String _closureReason = 'تحسن الحالة';
  final TextEditingController _finalReportController = TextEditingController();
  
  final List<String> _reasons = ['تحسن الحالة', 'انتفاء السبب', 'انتقال الطالب', 'تحويل لجهة خارجية'];

  @override
  Widget build(BuildContext context) {
    final casesAsync = ref.watch(activeCasesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('إغلاق حالة طلابية', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.green.shade700,
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => context.pop()),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.red.shade700),
                    SizedBox(width: 8.w),
                    Expanded(child: Text('تنبيه: إغلاق الحالة يعني اكتمال جميع الإجراءات وأرشفة الملف.', style: TextStyle(fontSize: 12.sp, color: Colors.red.shade900))),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
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
                      labelText: 'اختر الحالة للإغلاق',
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
              DropdownButtonFormField(
                decoration: InputDecoration(labelText: 'سبب الإغلاق', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                value: _closureReason,
                items: _reasons.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) => setState(() => _closureReason = val!),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _finalReportController,
                decoration: InputDecoration(labelText: 'التقرير الختامي / النتيجة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                maxLines: 4,
                validator: (val) => val == null || val.isEmpty ? 'يرجى كتابة التقرير الختامي' : null,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final user = ref.read(authStateProvider).value;
                  final schoolId = (user?.schoolId ?? '').trim();
                  if (user == null || schoolId.isEmpty) return;

                  final cases = ref.read(activeCasesProvider).value ?? const <StudentCase>[];
                  StudentCase? selected;
                  for (final c in cases) {
                    if (c.id == _selectedCaseId) {
                      selected = c;
                      break;
                    }
                  }
                  if (selected == null) return;

                  final closureText = [
                    'سبب الإغلاق: $_closureReason',
                    'التقرير الختامي:',
                    _finalReportController.text.trim(),
                  ].where((e) => e.trim().isNotEmpty).join('\n');

                  await ref.read(counselorRepositoryProvider).addCaseFollowUp(
                        schoolId: schoolId,
                        caseId: selected.id,
                        notes: closureText,
                        nextStep: null,
                        createdBy: user.id,
                      );

                  final updated = StudentCase(
                    id: selected.id,
                    studentId: selected.studentId,
                    studentName: selected.studentName,
                    schoolId: selected.schoolId,
                    title: selected.title,
                    description: selected.description,
                    status: CaseStatus.closed,
                    priority: selected.priority,
                    createdAt: selected.createdAt,
                    updatedAt: DateTime.now(),
                    assignedTo: selected.assignedTo,
                    evidenceCount: selected.evidenceCount,
                  );

                  await ref.read(counselorRepositoryProvider).updateCase(updated);

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إغلاق الحالة')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700, padding: EdgeInsets.symmetric(vertical: 16.h), minimumSize: Size(double.infinity, 50.h)),
                child: Text('إغلاق الحالة نهائياً', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
