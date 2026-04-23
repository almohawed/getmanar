import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_activity_repository.dart';

class AddActivityScreen extends ConsumerStatefulWidget {
  const AddActivityScreen({super.key});

  @override
  ConsumerState<AddActivityScreen> createState() => _AddActivityScreenState();
}

class _AddActivityScreenState extends ConsumerState<AddActivityScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  String _activityType = 'ثقافي';
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _supervisorController = TextEditingController();
  final TextEditingController _countController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime? _selectedDate;
  bool _isSubmitting = false;
  String? _createId;

  final List<String> _types = ['ثقافي', 'رياضي', 'علمي', 'اجتماعي', 'تطوعي'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إضافة نشاط جديد',
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
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'اسم النشاط',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                validator: (val) => val!.isEmpty ? 'مطلوب' : null,
              ),
              SizedBox(height: 16.h),
              DropdownButtonFormField(
                decoration: InputDecoration(
                  labelText: 'نوع النشاط',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                value: _activityType,
                items: _types
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _activityType = val!),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _dateController,
                decoration: InputDecoration(
                  labelText: 'تاريخ النشاط',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  suffixIcon: Icon(Icons.calendar_today),
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
                    _dateController.text = picked
                        .toIso8601String()
                        .split('T')
                        .first;
                  });
                },
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _supervisorController,
                decoration: InputDecoration(
                  labelText: 'المشرف',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _countController,
                decoration: InputDecoration(
                  labelText: 'عدد الطلاب المتوقع',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                keyboardType: TextInputType.number,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'وصف النشاط',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                ),
                maxLines: 3,
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
                        _createId ??= const Uuid().v4();

                        try {
                          final expected = int.tryParse(
                            _countController.text.trim(),
                          );
                          await ref
                              .read(activityRepositoryProvider)
                              .addActivity(
                                schoolId,
                                activityId: _createId,
                                name: _nameController.text,
                                type: _activityType,
                                date: _selectedDate,
                                supervisor: _supervisorController.text,
                                expectedCount: expected,
                                description: _descController.text,
                                createdBy: user?.id,
                              );
                        } finally {
                          if (mounted) setState(() => _isSubmitting = false);
                        }

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('تم إضافة النشاط')),
                        );
                        context.pop();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue.shade700,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  minimumSize: Size(double.infinity, 50.h),
                ),
                child: _isSubmitting
                    ? SizedBox(
                        width: 22.w,
                        height: 22.w,
                        child: const CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'حفظ النشاط',
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
