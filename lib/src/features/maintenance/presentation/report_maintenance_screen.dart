import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:uuid/uuid.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../common/services/audit_service.dart';
import '../domain/models/maintenance_report.dart';
import '../data/firestore_maintenance_repository.dart';
import '../services/maintenance_email_service.dart';

class ReportMaintenanceScreen extends ConsumerStatefulWidget {
  const ReportMaintenanceScreen({super.key});

  @override
  ConsumerState<ReportMaintenanceScreen> createState() =>
      _ReportMaintenanceScreenState();
}

class _ReportMaintenanceScreenState
    extends ConsumerState<ReportMaintenanceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _emailController = TextEditingController(); // إيميل فريق الصيانة
  MaintenancePriority _priority = MaintenancePriority.medium;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('تسجيل بلاغ صيانة'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      backgroundColor: Colors.grey.shade50,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildInfoCard(),
              SizedBox(height: 24.h),
              _buildFormFields(),
              SizedBox(height: 32.h),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitReport,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    padding: EdgeInsets.symmetric(vertical: 16.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: _isSubmitting
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          'إرسال البلاغ',
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8.r),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.blue.shade800),
          SizedBox(width: 12.w),
          Expanded(
            child: Text(
              'سيتم توجيه البلاغ مباشرة إلى فريق الصيانة عبر الإيميل المحدد وتتبع حالته من خلال لوحة التحكم.',
              style: TextStyle(color: Colors.blue.shade900, fontSize: 13.sp),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormFields() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'عنوان البلاغ (مثال: تعطل مكيف)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.title),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _locationController,
            decoration: const InputDecoration(
              labelText: 'الموقع (مثال: مبنى أ - الدور 2 - فصل 3/1)',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.location_on),
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'إيميل فريق الصيانة',
              hintText: 'maintenance@company.com',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.email),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'هذا الحقل مطلوب';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'يرجى إدخال إيميل صحيح';
              }
              return null;
            },
          ),
          SizedBox(height: 16.h),
          DropdownButtonFormField<MaintenancePriority>(
            value: _priority,
            decoration: const InputDecoration(
              labelText: 'الأولوية',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.priority_high),
            ),
            items: MaintenancePriority.values.map((p) {
              Color color = Colors.green;
              String label = 'منخفضة';
              if (p == MaintenancePriority.medium) {
                color = Colors.orange;
                label = 'متوسطة';
              } else if (p == MaintenancePriority.high) {
                color = Colors.red;
                label = 'عالية';
              } else if (p == MaintenancePriority.critical) {
                color = Colors.purple;
                label = 'حرجة جداً';
              }
              return DropdownMenuItem(
                value: p,
                child: Text(
                  label,
                  style: TextStyle(color: color, fontWeight: FontWeight.bold),
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) setState(() => _priority = value);
            },
          ),
          SizedBox(height: 16.h),
          TextFormField(
            controller: _descriptionController,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'وصف المشكلة بالتفصيل',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (value) =>
                value == null || value.isEmpty ? 'هذا الحقل مطلوب' : null,
          ),
        ],
      ),
    );
  }

  Future<void> _submitReport() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final user = ref.read(authStateProvider).value;
      if (user == null) throw Exception('User not logged in');

      final report = MaintenanceReport(
        id: const Uuid().v4(),
        title: _titleController.text,
        description: _descriptionController.text,
        location: _locationController.text,
        priority: _priority,
        status: MaintenanceStatus.pending,
        createdAt: DateTime.now(),
        reporterId: user.id,
        maintenanceEmail: _emailController.text.trim(),
      );

      // Save via Repository
      if (user.schoolId == null || user.schoolId!.isEmpty) {
        throw Exception('School ID is missing for current user');
      }
      await ref
          .read(maintenanceRepositoryProvider)
          .createReport(user.schoolId!, report);

      // إرسال إيميل إلى فريق الصيانة
      if (report.maintenanceEmail != null && report.maintenanceEmail!.isNotEmpty) {
        try {
          await ref.read(maintenanceEmailServiceProvider).sendMaintenanceReportEmail(
            report: report,
            schoolName: 'المدرسة', // يمكن تحسين هذا لاحقاً بجلب اسم المدرسة من Firestore
            reporterName: user.name ?? 'مجهول',
          );
        } catch (emailError) {
          print('خطأ في إرسال الإيميل: $emailError');
          // لا نوقف العملية إذا فشل الإيميل
        }
      }

      // Audit Log
      ref
          .read(auditServiceProvider)
          .logAction(
            action: 'create_maintenance_report',
            description: 'New maintenance report: ${report.title}',
            metadata: {
              'reportId': report.id,
              'priority': report.priority.name,
              'location': report.location,
              'maintenanceEmail': report.maintenanceEmail,
            },
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('تم إرسال بلاغ الصيانة بنجاح'),
                      if (report.maintenanceEmail != null && report.maintenanceEmail!.isNotEmpty)
                        Text(
                          'تم إرسال إشعار إلى: ${report.maintenanceEmail}',
                          style: const TextStyle(fontSize: 12),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }
}
