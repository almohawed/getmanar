import 'dart:typed_data';
import 'package:intl/intl.dart' as intl;
import '../../reports/domain/ministry_pdf_template.dart';

class BehaviorNoticePdfService {
  static Future<Uint8List> buildNoticePdf({
    required String schoolName,
    required String adminRegion,
    required String noticeType,
    required String studentName,
    required String studentId,
    required String reason,
    required String notes,
    required DateTime createdAt,
    required String createdByName,
  }) async {
    final dateStr = intl.DateFormat('yyyy-MM-dd').format(createdAt);
    final pdf = await MinistryPdfTemplate.generateReport(
      title: 'إشعار سلوكي رسمي',
      subTitle: noticeType,
      schoolName: schoolName,
      adminRegion: adminRegion,
      dateFrom: dateStr,
      dateTo: dateStr,
      tableHeaders: const ['البند', 'البيان'],
      tableData: [
        ['نوع الإشعار', noticeType],
        ['اسم الطالب', studentName],
        ['معرف الطالب', studentId],
        ['السبب/المخالفة', reason],
        ['ملاحظات', notes],
        ['منشئ الإشعار', createdByName],
        ['التاريخ', dateStr],
      ],
      footerText: 'نظام منار - شؤون الطلاب',
    );
    return pdf.save();
  }
}

