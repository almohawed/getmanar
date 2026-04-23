import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_activity_repository.dart';

class UpdateActivityScreen extends ConsumerStatefulWidget {
  const UpdateActivityScreen({super.key});

  @override
  ConsumerState<UpdateActivityScreen> createState() =>
      _UpdateActivityScreenState();
}

class _UpdateActivityScreenState extends ConsumerState<UpdateActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedActivityId;
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  DateTime? _selectedDate;

  @override
  Widget build(BuildContext context) {
    final activitiesAsync = ref.watch(schoolActivitiesProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'تحديث بيانات نشاط',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.orange.shade700,
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
                      labelText: 'اختر النشاط لتحديثه',
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
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'تحديث التاريخ/الوقت (اختياري)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  suffixIcon: Icon(Icons.calendar_month),
                ),
                readOnly: true,
                onTap: () async {
                  final now = DateTime.now();
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(now.year - 2),
                    lastDate: DateTime(now.year + 2),
                    initialDate: _selectedDate ?? now,
                  );
                  if (picked == null) return;
                  setState(() {
                    _selectedDate = picked;
                    _dateController.text =
                        picked.toIso8601String().split('T').first;
                  });
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _notesController,
                decoration: InputDecoration(
                  labelText: 'مستجدات / ملاحظات إضافية',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 32.h),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate()) return;
                  final user = ref.read(authStateProvider).value;
                  final schoolId = (user?.schoolId ?? '').trim();
                  if (schoolId.isEmpty) return;

                  await ref.read(activityRepositoryProvider).updateActivity(
                        schoolId,
                        activityId: _selectedActivityId!,
                        date: _selectedDate,
                        notes: _notesController.text,
                      );

                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم تحديث بيانات النشاط')),
                  );
                  context.pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: Text(
                  'حفظ التحديثات',
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
