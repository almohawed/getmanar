import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../auth/presentation/auth_controller.dart';
import '../data/school_repository.dart';
import 'students_provider.dart';
import '../../common/services/pdf_export_service.dart';

class ExportAcademicReportsTab extends ConsumerStatefulWidget {
  const ExportAcademicReportsTab({super.key});

  @override
  ConsumerState<ExportAcademicReportsTab> createState() =>
      _ExportAcademicReportsTabState();
}

class _ExportAcademicReportsTabState
    extends ConsumerState<ExportAcademicReportsTab> {
  bool _isExporting = false;

  Future<void> _exportStudentsBasicList() async {
    final user = ref.read(authStateProvider).value;

    String schoolName = '';
    if (user?.schoolId != null && user!.schoolId!.isNotEmpty) {
      try {
        final school = await ref
            .read(schoolRepositoryProvider)
            .getSchool(user.schoolId!);
        schoolName = school?.name ?? '';
      } catch (_) {}
    }
    if (schoolName.isEmpty) {
      schoolName = 'المدرسة';
    }

    final controller = TextEditingController(text: schoolName);

    final customName = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('اسم المدرسة في التقرير'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'اكتب اسم المدرسة كما تريد ظهوره في الكشف',
            ),
            textDirection: TextDirection.rtl,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(null);
              },
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop(controller.text.trim());
              },
              child: const Text('متابعة للطباعة'),
            ),
          ],
        );
      },
    );

    final finalName = customName?.trim();
    if (finalName == null || finalName.isEmpty) {
      return;
    }

    setState(() {
      _isExporting = true;
    });
    try {
      final students = await ref.read(studentsProvider.future);
      final service = PdfExportService(
        schoolName: finalName,
        teacherName: finalName,
        principalName: 'مدير المدرسة',
        signerTitle: 'مسؤول التقرير',
      );
      await service.printStudentsBasicLog(students);
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportExamCommitteesTemplate() async {
    setState(() {
      _isExporting = true;
    });
    try {
      final user = ref.read(authStateProvider).value;
      String schoolName = '';
      if (user?.schoolId != null && user!.schoolId!.isNotEmpty) {
        try {
          final school = await ref
              .read(schoolRepositoryProvider)
              .getSchool(user.schoolId!);
          schoolName = school?.name ?? '';
        } catch (_) {}
      }
      final service = PdfExportService(
        schoolName: schoolName,
        teacherName: 'إدارة المدرسة',
        principalName: 'مدير المدرسة',
        signerTitle: 'مسؤول الاختبارات',
      );
      await service.printExamCommitteesLog();
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  Future<void> _exportExamAbsenceTemplate() async {
    setState(() {
      _isExporting = true;
    });
    try {
      final user = ref.read(authStateProvider).value;
      String schoolName = '';
      if (user?.schoolId != null && user!.schoolId!.isNotEmpty) {
        try {
          final school = await ref
              .read(schoolRepositoryProvider)
              .getSchool(user.schoolId!);
          schoolName = school?.name ?? '';
        } catch (_) {}
      }
      final service = PdfExportService(
        schoolName: schoolName,
        teacherName: 'إدارة المدرسة',
        principalName: 'مدير المدرسة',
        signerTitle: 'مسؤول الاختبارات',
      );
      await service.printExamAbsenceLog();
    } finally {
      if (mounted) {
        setState(() {
          _isExporting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'تصدير التقارير الأكاديمية الرسمية بصيغة PDF',
              style: TextStyle(fontSize: 14.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12.h),
            Text(
              'اختر نوع التقرير الذي ترغب في تصديره، وسيتم توليد ملف رسمي جاهز للطباعة.',
              style: TextStyle(fontSize: 12.sp),
            ),
            SizedBox(height: 16.h),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportStudentsBasicList,
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: const Text('كشف أساسي بأسماء الطلاب'),
            ),
            SizedBox(height: 8.h),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportExamCommitteesTemplate,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('كشف توزيع لجان الاختبارات'),
            ),
            SizedBox(height: 8.h),
            ElevatedButton.icon(
              onPressed: _isExporting ? null : _exportExamAbsenceTemplate,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('كشف الغياب في الاختبارات'),
            ),
          ],
        ),
      ),
    );
  }
}
