import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_activity_repository.dart';

class EndActivityScreen extends ConsumerStatefulWidget {
  const EndActivityScreen({super.key});

  @override
  ConsumerState<EndActivityScreen> createState() => _EndActivityScreenState();
}

class _EndActivityScreenState extends ConsumerState<EndActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedActivityId;
  final TextEditingController _finalReportController = TextEditingController();
  final TextEditingController _participantsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(schoolActivitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إنهاء نشاط وإغلاق الملف',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.red.shade700,
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
              Container(
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.red.shade700),
                    SizedBox(width: 8.w),
                    Expanded(
                      child: Text(
                        'سيتم أرشفة النشاط وإصدار التقرير الختامي.',
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 12.sp,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 24.h),
              activitiesAsync.when(
                data: (activities) {
                  if (activities.isEmpty) {
                    return const Text('لا يوجد أنشطة');
                  }
                  final value = (_selectedActivityId != null &&
                          activities.any((a) => a.id == _selectedActivityId))
                      ? _selectedActivityId
                      : null;
                  return DropdownButtonFormField<String>(
                    value: value,
                    decoration: InputDecoration(
                      labelText: 'اختر النشاط للإغلاق',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                    ),
                    items: activities
                        .map(
                          (a) => DropdownMenuItem(
                            value: a.id,
                            child: Text(a.name),
                          ),
                        )
                        .toList(),
                    onChanged: (val) =>
                        setState(() => _selectedActivityId = val),
                    validator: (val) =>
                        (val == null || val.isEmpty) ? 'مطلوب' : null,
                  );
                },
                loading: () => const CircularProgressIndicator(),
                error: (e, s) => Text('خطأ: $e'),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _participantsController,
                decoration: InputDecoration(
                  labelText: 'عدد الحضور الفعلي',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _finalReportController,
                decoration: InputDecoration(
                  labelText: 'التقرير الختامي / المخرجات',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                maxLines: 4,
                validator: (val) =>
                    val!.isEmpty ? 'يرجى كتابة ملخص التقرير' : null,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final user = ref.read(authStateProvider).value;
                  final schoolId = (user?.schoolId ?? '').trim();
                  if (schoolId.isEmpty) return;

                  final actual = int.tryParse(_participantsController.text.trim());
                  await ref.read(activityRepositoryProvider).endActivity(
                        schoolId,
                        activityId: _selectedActivityId!,
                        status: 'completed',
                        actualParticipants: actual,
                        finalReport: _finalReportController.text,
                      );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم إنهاء النشاط')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  'إنهاء النشاط',
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
