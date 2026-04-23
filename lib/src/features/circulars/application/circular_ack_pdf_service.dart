import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../reports/domain/ministry_pdf_template.dart';

class CircularAckPdfService {
  static Future<List<int>> build({
    required String schoolName,
    required String adminRegion,
    required String circularTitle,
    required List<Map<String, dynamic>> recipients,
  }) async {
    final now = DateTime.now();
    final dateKey = DateFormat('yyyy-MM-dd').format(now);
    final issuedAt = DateFormat('yyyy-MM-dd HH:mm').format(now);

    final rows = <List<String>>[];

    String roleLabel(String role) {
      switch (role) {
        case 'teacher':
          return 'معلم';
        case 'administrative':
        case 'admin':
        case 'supportAdmin':
        case 'technicalSupport':
          return 'إداري';
        case 'deputy':
          return 'وكيل';
        default:
          return role;
      }
    }

    for (final r in recipients) {
      final name = (r['name'] ?? '').toString().trim();
      final role = (r['role'] ?? '').toString().trim();
      final acknowledged = (r['acknowledged'] ?? false) == true;
      final ackAt = r['acknowledgedAt'];
      String ackAtStr = '';
      if (ackAt is DateTime) {
        ackAtStr = DateFormat('yyyy-MM-dd HH:mm').format(ackAt);
      } else if (ackAt != null && ackAt.toString().isNotEmpty) {
        ackAtStr = ackAt.toString();
      }

      rows.add([
        roleLabel(role),
        name.isEmpty ? '—' : name,
        acknowledged ? 'تم' : 'لم يتم',
        ackAtStr.isEmpty ? '—' : ackAtStr,
      ]);
    }

    final total = rows.length;
    final acknowledgedCount = recipients
        .where((r) => (r['acknowledged'] ?? false) == true)
        .length;
    final percent = total == 0
        ? 0
        : ((acknowledgedCount / total) * 100).round();

    final pdf = await MinistryPdfTemplate.generateReport(
      title: 'اطلاع الموظفين على التعميم',
      subTitle: circularTitle,
      schoolName: schoolName,
      adminRegion: adminRegion,
      dateFrom: dateKey,
      dateTo: dateKey,
      contentWidgets: [
        pw.Container(
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: PdfColors.grey100,
            borderRadius: pw.BorderRadius.circular(8),
            border: pw.Border.all(color: PdfColors.grey300),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('إجمالي المستلمين: $total'),
              pw.Text('عدد المطلعين: $acknowledgedCount'),
              pw.Text('نسبة الاطلاع: $percent%'),
              pw.Text('تاريخ إصدار التقرير: $issuedAt'),
            ],
          ),
        ),
        pw.SizedBox(height: 12),
      ],
      tableHeaders: const ['الفئة', 'الاسم', 'تم الاطلاع', 'تاريخ الاطلاع'],
      tableData: rows,
      footerText: 'نظام منار - توقيع الاطلاع',
      pageFormat: PdfPageFormat.a4.landscape,
    );
    return pdf.save();
  }
}
