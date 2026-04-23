import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/domain/models/school.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../academic/data/school_repository.dart';
import '../../../common/services/sms_service.dart';
import '../../domain/models/daily_absence_model.dart';
import '../providers/daily_absence_provider.dart';

class DeputyAbsenceListWidget extends ConsumerStatefulWidget {
  const DeputyAbsenceListWidget({super.key});

  @override
  ConsumerState<DeputyAbsenceListWidget> createState() =>
      _DeputyAbsenceListWidgetState();
}

class _DeputyAbsenceListWidgetState
    extends ConsumerState<DeputyAbsenceListWidget> {
  bool _isSending = false;

  Future<void> _sendBulkSms(
    List<DailyAbsenceModel> students,
    SmsConfig config,
  ) async {
    final unsentStudents = students
        .where((s) => !s.smsSent && s.parentPhone.isNotEmpty)
        .toList();

    if (unsentStudents.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لا يوجد طلاب غير مرسل لهم لديهم أرقام هواتف'),
        ),
      );
      return;
    }

    setState(() => _isSending = true);

    int successCount = 0;
    int failCount = 0;
    final service = SmsService(config);

    for (final student in unsentStudents) {
      final message =
          'السلام عليكم ولي أمر الطالب ${student.studentName}، نفيدكم بغياب ابنكم عن الحصة ${student.period} هذا اليوم. نأمل منكم متابعة ذلك حرصاً على مصلحته التعليمية.\nإدارة المدرسة';

      try {
        await service.sendBulkSms(student.parentPhone, message);
        setState(() {
          student.smsSent = true;
        });
        successCount++;
      } catch (e) {
        failCount++;
        debugPrint('Failed to send to ${student.studentName}: $e');
      }
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم الإرسال: $successCount ناجح، $failCount فشل'),
          backgroundColor: failCount > 0 ? Colors.orange : Colors.green,
        ),
      );
      setState(() => _isSending = false);
    }
  }

  Future<void> _sendIndividualSms(
    DailyAbsenceModel student,
    SmsConfig config,
  ) async {
    final message =
        'السلام عليكم ولي أمر الطالب ${student.studentName}، نفيدكم بغياب ابنكم عن الحصة ${student.period} هذا اليوم. نأمل منكم متابعة ذلك حرصاً على مصلحته التعليمية.\nإدارة المدرسة';

    try {
      final service = SmsService(config);
      await service.sendBulkSms(student.parentPhone, message);
      setState(() {
        student.smsSent = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم الإرسال لولي أمر الطالب: ${student.studentName}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('فشل الإرسال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    if (user?.schoolId == null) {
      return const Center(child: Text('لا يوجد مدرسة مرتبطة'));
    }

    final absenceAsync = ref.watch(dailyAbsenceProvider);
    final schoolAsync = ref.watch(schoolProvider(user!.schoolId!));

    return schoolAsync.when(
      data: (school) {
        final smsConfig = school?.smsConfig;
        final isSmsEnabled = smsConfig?.isEnabled ?? false;

        return absenceAsync.when(
          data: (students) {
            if (students.isEmpty) {
              return SizedBox(
                height: 200.h,
                child: const Center(child: Text('لا يوجد غياب مسجل اليوم')),
              );
            }
            return Column(
              children: [
                if (!isSmsEnabled)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12.w),
                    color: Colors.red.shade50,
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber, color: Colors.red.shade700),
                        SizedBox(width: 8.w),
                        Expanded(
                          child: Text(
                            'خدمة الرسائل غير مفعلة من قبل مدير المدرسة',
                            style: TextStyle(
                              color: Colors.red.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Header Summary
                Container(
                  padding: EdgeInsets.all(16.w),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(8.r),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'عدد الغائبين: ${students.length}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16.sp,
                        ),
                      ),
                      if (isSmsEnabled)
                        ElevatedButton.icon(
                          onPressed: _isSending
                              ? null
                              : () => _sendBulkSms(students, smsConfig!),
                          icon: _isSending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.send),
                          label: const Text('إرسال للكل'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                ),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.all(16.w),
                  itemCount: students.length,
                  separatorBuilder: (_, __) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final student = students[index];
                    return _buildStudentCard(student, isSmsEnabled, smsConfig);
                  },
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, s) => Center(child: Text('خطأ: $e')),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, s) => Center(child: Text('خطأ في تحميل بيانات المدرسة: $e')),
    );
  }

  Widget _buildStudentCard(
    DailyAbsenceModel student,
    bool isSmsEnabled,
    SmsConfig? config,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.red.shade100,
              child: const Icon(Icons.person_off, color: Colors.red),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    student.studentName,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                  Text(
                    '${student.className} • ${student.period}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
                  ),
                  Text(
                    'المعلم: ${student.teacherName}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12.sp),
                  ),
                ],
              ),
            ),
            if (isSmsEnabled && config != null)
              IconButton(
                onPressed: student.smsSent
                    ? null
                    : () => _sendIndividualSms(student, config),
                icon: Icon(
                  student.smsSent ? Icons.check_circle : Icons.send,
                  color: student.smsSent ? Colors.green : Colors.indigo,
                ),
                tooltip: student.smsSent ? 'تم الإرسال' : 'إرسال تنبيه',
              ),
          ],
        ),
      ),
    );
  }
}
