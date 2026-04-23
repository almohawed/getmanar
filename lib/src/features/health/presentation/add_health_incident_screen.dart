import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/domain/models/user.dart';
import '../../academic/presentation/students_provider.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/firestore_health_repository.dart';

class AddHealthIncidentScreen extends ConsumerStatefulWidget {
  const AddHealthIncidentScreen({super.key});

  @override
  ConsumerState<AddHealthIncidentScreen> createState() => _AddHealthIncidentScreenState();
}

class _AddHealthIncidentScreenState extends ConsumerState<AddHealthIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  String _incidentType = 'إصابة';
  String? _selectedStudentId;
  final _locationController = TextEditingController();
  final _descController = TextEditingController();
  final _actionController = TextEditingController();
  bool _isSaving = false;

  final List<String> _types = ['إصابة', 'إغماء', 'حادث عرضي', 'مشاجرة', 'أخرى'];

  @override
  void dispose() {
    _locationController.dispose();
    _descController.dispose();
    _actionController.dispose();
    super.dispose();
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _locationController.clear();
    _descController.clear();
    _actionController.clear();
    setState(() {
      _selectedStudentId = null;
      _incidentType = 'إصابة';
    });
  }

  @override
  Widget build(BuildContext context) {
    final studentsAsync = ref.watch(studentsProvider);
    final incidentsAsync = ref.watch(healthIncidentsProvider);
    final user = ref.watch(authStateProvider).value;
    final schoolId = (user?.schoolId ?? '').trim();

    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل حادثة مدرسية',
            style: GoogleFonts.cairo(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.red.shade700,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── نموذج الإضافة ──
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14.r)),
              elevation: 2,
              child: Padding(
                padding: EdgeInsets.all(16.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('إضافة حادثة جديدة',
                          style: GoogleFonts.cairo(fontSize: 15.sp, fontWeight: FontWeight.bold)),
                      SizedBox(height: 14.h),
                      studentsAsync.when(
                        data: (students) {
                          final value = (_selectedStudentId != null &&
                                  students.any((s) => s.id == _selectedStudentId))
                              ? _selectedStudentId
                              : null;
                          return DropdownButtonFormField<String>(
                            value: value,
                            decoration: InputDecoration(
                              labelText: 'الطالب (اختياري)',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                            ),
                            items: [
                              const DropdownMenuItem<String>(value: '', child: Text('—')),
                              ...students.map((s) => DropdownMenuItem(value: s.id, child: Text(s.name))),
                            ],
                            onChanged: (val) => setState(() =>
                                _selectedStudentId = (val == null || val.isEmpty) ? null : val),
                          );
                        },
                        loading: () => const LinearProgressIndicator(),
                        error: (e, _) => Text('خطأ: $e'),
                      ),
                      SizedBox(height: 12.h),
                      DropdownButtonFormField<String>(
                        value: _incidentType,
                        decoration: InputDecoration(
                          labelText: 'نوع الحادثة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                        onChanged: (val) => setState(() => _incidentType = val!),
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _locationController,
                        decoration: InputDecoration(
                          labelText: 'الموقع (الفصل/الساحة...)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _descController,
                        decoration: InputDecoration(
                          labelText: 'وصف الحادثة',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        maxLines: 3,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'مطلوب' : null,
                      ),
                      SizedBox(height: 12.h),
                      TextFormField(
                        controller: _actionController,
                        decoration: InputDecoration(
                          labelText: 'الإجراء المتخذ',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        maxLines: 2,
                      ),
                      SizedBox(height: 20.h),
                      ElevatedButton(
                        onPressed: _isSaving ? null : () async {
                          if (!_formKey.currentState!.validate()) return;
                          if (schoolId.isEmpty) return;
                          setState(() => _isSaving = true);
                          try {
                            final students = ref.read(studentsProvider).value ?? [];
                            final student = students.where((s) => s.id == _selectedStudentId).firstOrNull;
                            await ref.read(healthRepositoryProvider).addIncident(
                              schoolId: schoolId,
                              incidentType: _incidentType,
                              location: _locationController.text.trim(),
                              description: _descController.text.trim(),
                              actionTaken: _actionController.text.trim(),
                              createdBy: user?.id ?? '',
                              studentId: student?.id,
                              studentName: student?.name,
                            );
                            _resetForm();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('تم تسجيل الحادثة بنجاح'), backgroundColor: Colors.green),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('خطأ: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => _isSaving = false);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade700,
                          padding: EdgeInsets.symmetric(vertical: 14.h),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
                        ),
                        child: _isSaving
                            ? const SizedBox(width: 22, height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : Text('حفظ الحادثة',
                                style: GoogleFonts.cairo(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            SizedBox(height: 24.h),

            // ── قائمة الحوادث المسجلة ──
            Text('الحوادث المسجلة',
                style: GoogleFonts.cairo(fontSize: 16.sp, fontWeight: FontWeight.bold)),
            SizedBox(height: 10.h),

            incidentsAsync.when(
              data: (incidents) {
                if (incidents.isEmpty) {
                  return Container(
                    padding: EdgeInsets.all(24.w),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: const Center(
                      child: Text('لا توجد حوادث مسجلة بعد', style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: incidents.length,
                  itemBuilder: (context, index) {
                    final inc = incidents[index];
                    return _buildIncidentCard(inc, schoolId);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('خطأ في تحميل الحوادث: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncidentCard(HealthIncidentRecord inc, String schoolId) {
    Color typeColor;
    switch (inc.incidentType) {
      case 'إصابة': typeColor = Colors.red; break;
      case 'إغماء': typeColor = Colors.purple; break;
      case 'مشاجرة': typeColor = Colors.orange; break;
      default: typeColor = Colors.blue;
    }

    return Card(
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: typeColor.withOpacity(0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: typeColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: typeColor.withOpacity(0.4)),
                  ),
                  child: Text(inc.incidentType,
                      style: TextStyle(color: typeColor, fontSize: 11.sp, fontWeight: FontWeight.bold)),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: Text(
                    inc.studentName?.isNotEmpty == true ? inc.studentName! : 'غير محدد',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.sp),
                  ),
                ),
                Text(
                  '${inc.createdAt.day}/${inc.createdAt.month}/${inc.createdAt.year}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.grey),
                ),
              ],
            ),
            SizedBox(height: 6.h),
            Row(
              children: [
                Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                SizedBox(width: 4.w),
                Text(inc.location, style: TextStyle(fontSize: 12.sp, color: Colors.grey.shade700)),
              ],
            ),
            SizedBox(height: 4.h),
            Text(inc.description,
                style: TextStyle(fontSize: 12.sp),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            if (inc.actionTaken.isNotEmpty) ...[
              SizedBox(height: 4.h),
              Text('الإجراء: ${inc.actionTaken}',
                  style: TextStyle(fontSize: 11.sp, color: Colors.green.shade700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
            SizedBox(height: 8.h),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // زر التعديل
                OutlinedButton.icon(
                  onPressed: () => _showEditDialog(inc, schoolId),
                  icon: const Icon(Icons.edit, size: 14),
                  label: const Text('تعديل'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.blue,
                    side: const BorderSide(color: Colors.blue),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                SizedBox(width: 8.w),
                // زر الحذف
                OutlinedButton.icon(
                  onPressed: () => _confirmDelete(inc, schoolId),
                  icon: const Icon(Icons.delete, size: 14),
                  label: const Text('حذف'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showEditDialog(HealthIncidentRecord inc, String schoolId) {
    final locationCtrl = TextEditingController(text: inc.location);
    final descCtrl = TextEditingController(text: inc.description);
    final actionCtrl = TextEditingController(text: inc.actionTaken);
    String incidentType = inc.incidentType;
    final outerContext = context;

    showDialog(
      context: outerContext,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: const Text('تعديل الحادثة'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<String>(
                value: incidentType,
                decoration: const InputDecoration(labelText: 'نوع الحادثة', border: OutlineInputBorder()),
                items: _types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (v) { if (v != null) setS(() => incidentType = v); },
              ),
              const SizedBox(height: 12),
              TextField(controller: locationCtrl,
                  decoration: const InputDecoration(labelText: 'الموقع', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: descCtrl, maxLines: 3,
                  decoration: const InputDecoration(labelText: 'وصف الحادثة', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: actionCtrl, maxLines: 2,
                  decoration: const InputDecoration(labelText: 'الإجراء المتخذ', border: OutlineInputBorder())),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              onPressed: () async {
                try {
                  await FirebaseFirestore.instance
                      .collection('Schools')
                      .doc(schoolId)
                      .collection('HealthIncidents')
                      .doc(inc.id)
                      .update({
                    'incidentType': incidentType,
                    'location': locationCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'actionTaken': actionCtrl.text.trim(),
                  });
                  Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(
                      const SnackBar(content: Text('تم تحديث الحادثة'), backgroundColor: Colors.green),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(content: Text('خطأ: $e')));
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
              child: const Text('حفظ', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDelete(HealthIncidentRecord inc, String schoolId) async {
    final outerContext = context;
    final confirmed = await showDialog<bool>(
      context: outerContext,
      builder: (ctx) => AlertDialog(
        title: const Text('حذف الحادثة'),
        content: const Text('هل أنت متأكد من حذف هذه الحادثة؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance
            .collection('Schools')
            .doc(schoolId)
            .collection('HealthIncidents')
            .doc(inc.id)
            .delete();
        if (mounted) {
          ScaffoldMessenger.of(outerContext).showSnackBar(
            const SnackBar(content: Text('تم حذف الحادثة'), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(outerContext).showSnackBar(SnackBar(content: Text('خطأ: $e')));
        }
      }
    }
  }
}
