import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/counselor_session.dart';
import 'counselor_providers.dart';

class AddCounselingSessionScreen extends ConsumerStatefulWidget {
  const AddCounselingSessionScreen({super.key});

  @override
  ConsumerState<AddCounselingSessionScreen> createState() => _AddCounselingSessionScreenState();
}

class _AddCounselingSessionScreenState extends ConsumerState<AddCounselingSessionScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedStudentId;
  String _sessionType = 'فردية';
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _recsController = TextEditingController();
  final List<String> _types = ['فردية', 'جماعية', 'طارئة'];

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل جلسة توجيه', style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.teal.shade700,
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
                decoration: InputDecoration(labelText: 'نوع الجلسة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                value: _sessionType,
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _sessionType = val!),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(labelText: 'ملاحظات الجلسة', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                maxLines: 3,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _recsController,
                decoration: InputDecoration(labelText: 'التوصيات', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r))),
                maxLines: 2,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final user = ref.read(authStateProvider).value;
                  final schoolId = (user?.schoolId ?? '').trim();
                  if (user == null || schoolId.isEmpty) return;

                  final students =
                      ref.read(studentsProvider).value ?? const <User>[];
                  User? student;
                  for (final s in students) {
                    if (s.id == _selectedStudentId) {
                      student = s;
                      break;
                    }
                  }
                  if (student == null) return;

                  final type = _sessionType == 'جماعية'
                      ? SessionType.group
                      : SessionType.individual;
                  final title = 'جلسة توجيه (${student.name})';
                  final desc = [
                    _notesController.text.trim(),
                    _recsController.text.trim(),
                  ].where((e) => e.isNotEmpty).join('\n');

                  final session = CounselorSession(
                    id: const Uuid().v4(),
                    schoolId: schoolId,
                    title: title,
                    description: desc.isEmpty ? null : desc,
                    scheduledAt: DateTime.now(),
                    durationMinutes: 30,
                    status: SessionStatus.completed,
                    type: type,
                    attendeeIds: [student.id],
                    counselorId: user.id,
                    isConfidential: true,
                  );

                  await ref.read(counselorRepositoryProvider).createSession(
                        session,
                        userId: user.id,
                        role: user.role.name,
                      );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تسجيل الجلسة')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700, padding: EdgeInsets.symmetric(vertical: 16.h), minimumSize: Size(double.infinity, 50.h)),
                child: Text('حفظ الجلسة', style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
