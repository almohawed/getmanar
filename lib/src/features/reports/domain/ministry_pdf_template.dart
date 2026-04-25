import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;

// ─── Country Header Config ────────────────────────────────────────────────────
class _CountryHeaderConfig {
  final String countryName;
  final String ministryName;
  final String? departmentName;
  final String logoAsset;
  final bool isRtl;
  final String language; // 'ar' | 'en'

  const _CountryHeaderConfig({
    required this.countryName,
    required this.ministryName,
    this.departmentName,
    required this.logoAsset,
    this.isRtl = true,
    this.language = 'ar',
  });
}

const Map<String, _CountryHeaderConfig> _countryConfigs = {
  'SA': _CountryHeaderConfig(
    countryName: 'المملكة العربية السعودية',
    ministryName: 'وزارة التعليم',
    logoAsset: 'images/logokshuf.webp',
  ),
  'AE': _CountryHeaderConfig(
    countryName: 'دولة الإمارات العربية المتحدة',
    ministryName: 'وزارة التربية والتعليم',
    departmentName: 'إدارة التقويم والامتحانات',
    logoAsset: 'images/emlogo.png',
  ),
  'QA': _CountryHeaderConfig(
    countryName: 'دولة قطر',
    ministryName: 'وزارة التعليم والتعليم العالي',
    logoAsset: 'images/qalogo.png',
  ),
  'KW': _CountryHeaderConfig(
    countryName: 'دولة الكويت',
    ministryName: 'وزارة التربية',
    logoAsset: 'images/kwlogo.png',
  ),
  'BH': _CountryHeaderConfig(
    countryName: 'مملكة البحرين',
    ministryName: 'وزارة التربية والتعليم',
    logoAsset: 'images/bhlogo.png',
  ),
  'OM': _CountryHeaderConfig(
    countryName: 'سلطنة عُمان',
    ministryName: 'وزارة التربية والتعليم',
    logoAsset: 'images/omlogo.png',
  ),
  'US': _CountryHeaderConfig(
    countryName: 'United States of America',
    ministryName: 'Department of Education',
    logoAsset: 'images/usalogo.png',
    isRtl: false,
    language: 'en',
  ),
};

// ─── MinistryPdfTemplate ──────────────────────────────────────────────────────
class MinistryPdfTemplate {
  static Future<pw.Document> generateReport({
    required String title,
    required String schoolName,
    required String subTitle,
    required List<String> tableHeaders,
    required List<List<String>> tableData,
    required String footerText,
    String? dateFrom,
    String? dateTo,
    String? adminRegion,
    String? countryCode,          // ← جديد
    PdfPageFormat? pageFormat,
    List<pw.Widget>? contentWidgets,
    bool includeSignatures = true,
  }) async {
    final pdf = pw.Document();
    final ttf     = await PdfGoogleFonts.cairoRegular();
    final boldTtf = await PdfGoogleFonts.cairoBold();
    final logo    = await _loadLogo(countryCode ?? 'SA');
    final resolvedPageFormat = pageFormat ?? PdfPageFormat.a4;
    final config = _countryConfigs[countryCode ?? 'SA'] ?? _countryConfigs['SA']!;
    final isRtl = config.isRtl;
    final isEn  = config.language == 'en';

    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: resolvedPageFormat,
          theme: pw.ThemeData.withFont(base: ttf, bold: boldTtf),
          textDirection: isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
          margin: const pw.EdgeInsets.all(40),
        ),
        header: (context) => _buildHeader(
          context, schoolName, adminRegion, ttf, boldTtf, logo,
          countryCode: countryCode ?? 'SA',
        ),
        footer: (context) => _buildFooter(context, footerText, ttf, isRtl: isRtl),
        build: (context) => [
          _buildReportTitle(
            isEn ? _translateTitle(title) : title,
            isEn ? _translateTitle(subTitle) : subTitle,
            dateFrom, dateTo, boldTtf,
          ),
          pw.SizedBox(height: 20),
          if (contentWidgets != null) ...contentWidgets,
          _buildTable(tableHeaders, tableData, ttf, boldTtf),
          if (includeSignatures) ...[
            pw.SizedBox(height: 40),
            _buildSignatures(ttf, boldTtf, countryCode: countryCode ?? 'SA'),
          ],
        ],
      ),
    );

    return pdf;
  }

  // ─── Load Logo ──────────────────────────────────────────────────────────────
  static Future<pw.MemoryImage?> _loadLogo(String countryCode) async {
    final config = _countryConfigs[countryCode];
    final primaryAsset = config?.logoAsset ?? 'images/logokshuf.webp';

    // SVG غير مدعوم في pdf package — نستخدم fallback للـ SVG
    if (primaryAsset.endsWith('.svg')) {
      try {
        final fallback = await rootBundle.load('images/mylogo.png');
        return pw.MemoryImage(fallback.buffer.asUint8List());
      } catch (_) { return null; }
    }

    try {
      final data = await rootBundle.load(primaryAsset);
      return pw.MemoryImage(data.buffer.asUint8List());
    } catch (_) {
      try {
        final fallback = await rootBundle.load('images/mylogo.png');
        return pw.MemoryImage(fallback.buffer.asUint8List());
      } catch (_) {
        return null;
      }
    }
  }

  // ─── Translate Title (English) ───────────────────────────────────────────────
  static String _translateTitle(String arabicTitle) {
    const translations = {
      'كشف التأخر الصباحي': 'Morning Tardiness Report',
      'كشف الغياب': 'Absence Report',
      'كشف المخالفات السلوكية': 'Behavioral Violations Report',
      'كشف تصاريح الحمام': 'Bathroom Passes Log',
      'كشف بلاغات الصيانة': 'Maintenance Reports',
      'كشف الحالات النشطة للمرشد': 'Active Counseling Cases',
      'كشف جلسات الإرشاد': 'Counseling Sessions',
      'كشف الخطط السلوكية النشطة': 'Active Behavior Plans',
      'قائمة تحقق الأمن والسلامة': 'Safety Checklist',
      'كشف الصادر والوارد': 'Inbound/Outbound Log',
      'Tardiness Report': 'Tardiness Report',
      'Absence Report': 'Absence Report',
      'Behavioral Violations': 'Behavioral Violations',
    };
    return translations[arabicTitle] ?? arabicTitle;
  }

  // ─── Build Header ───────────────────────────────────────────────────────────
  static pw.Widget _buildHeader(
    pw.Context context,
    String schoolName,
    String? adminRegion,
    pw.Font font,
    pw.Font boldFont,
    pw.MemoryImage? logo, {
    String countryCode = 'SA',
  }) {
    final config = _countryConfigs[countryCode] ?? _countryConfigs['SA']!;
    final now        = DateTime.now();
    final dateStr    = intl.DateFormat('yyyy-MM-dd').format(now);
    final isEn       = config.language == 'en';
    final weekdayStr = isEn
        ? intl.DateFormat.EEEE('en').format(now)
        : intl.DateFormat.EEEE('ar').format(now);

    // ─── Left info block (school/ministry) ──────────────────────────────────
    final infoBlock = pw.Column(
      crossAxisAlignment: isEn ? pw.CrossAxisAlignment.start : pw.CrossAxisAlignment.end,
      children: [
        pw.Text(config.countryName,
            style: pw.TextStyle(font: boldFont, fontSize: 11)),
        pw.Text(config.ministryName,
            style: pw.TextStyle(font: boldFont, fontSize: 11)),
        if (config.departmentName != null)
          pw.Text(config.departmentName!,
              style: pw.TextStyle(font: font, fontSize: 10)),
        if (adminRegion != null && adminRegion.isNotEmpty && countryCode == 'SA')
          pw.Text(adminRegion,
              style: pw.TextStyle(font: font, fontSize: 10)),
        if (schoolName.isNotEmpty)
          pw.Text(schoolName,
              style: pw.TextStyle(font: font, fontSize: 10)),
      ],
    );

    // ─── Right info block (date/number) ─────────────────────────────────────
    final dateBlock = pw.Column(
      crossAxisAlignment: isEn ? pw.CrossAxisAlignment.end : pw.CrossAxisAlignment.start,
      children: [
        pw.Text(isEn ? 'No.: ____________' : 'الرقم: ____________',
            style: pw.TextStyle(font: font, fontSize: 9)),
        pw.Text(isEn ? 'Date: $dateStr' : 'التاريخ: $dateStr',
            style: pw.TextStyle(font: font, fontSize: 9)),
        pw.Text(isEn ? 'Day: $weekdayStr' : 'اليوم: $weekdayStr',
            style: pw.TextStyle(font: font, fontSize: 9)),
      ],
    );

    // ─── Center logo ─────────────────────────────────────────────────────────
    final logoWidget = pw.Column(
      mainAxisAlignment: pw.MainAxisAlignment.center,
      children: [
        if (logo != null)
          pw.Container(width: 80, height: 80, child: pw.Image(logo))
        else
          pw.SizedBox(width: 80, height: 80),
      ],
    );

    return pw.Column(
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: isEn
              ? [dateBlock, logoWidget, infoBlock]   // LTR: date | logo | info
              : [infoBlock, logoWidget, dateBlock],  // RTL: info | logo | date
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 1),
        pw.SizedBox(height: 10),
      ],
    );
  }

  // ─── Footer ─────────────────────────────────────────────────────────────────
  static pw.Widget _buildFooter(
    pw.Context context,
    String footerText,
    pw.Font font, {
    bool isRtl = true,
  }) {
    final dateLabel = isRtl ? 'تاريخ الطباعة' : 'Print Date';
    final pageLabel = isRtl
        ? 'صفحة ${context.pageNumber} من ${context.pagesCount}'
        : 'Page ${context.pageNumber} of ${context.pagesCount}';

    return pw.Column(
      children: [
        pw.Divider(thickness: 0.5),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              "$dateLabel: ${DateTime.now().toString().split(' ')[0]}",
              style: pw.TextStyle(font: font, fontSize: 8),
            ),
            pw.Text(footerText, style: pw.TextStyle(font: font, fontSize: 8)),
            pw.Text(pageLabel, style: pw.TextStyle(font: font, fontSize: 8)),
          ],
        ),
      ],
    );
  }

  // ─── Report Title ────────────────────────────────────────────────────────────
  static pw.Widget _buildReportTitle(
    String title,
    String subTitle,
    String? from,
    String? to,
    pw.Font boldFont,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 18,
            decoration: pw.TextDecoration.underline,
          ),
        ),
        if (from != null && to != null)
          pw.Text(
            "الفترة من: $from إلى: $to",
            style: pw.TextStyle(fontSize: 10),
          ),
      ],
    );
  }

  // ─── Table ───────────────────────────────────────────────────────────────────
  static pw.Widget _buildTable(
    List<String> headers,
    List<List<String>> data,
    pw.Font font,
    pw.Font boldFont,
  ) {
    return pw.TableHelper.fromTextArray(
      headers: headers,
      data: data,
      border: pw.TableBorder.all(width: 0.5),
      headerStyle: pw.TextStyle(
        font: boldFont,
        fontSize: 10,
        color: PdfColors.white,
      ),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey700),
      cellStyle: pw.TextStyle(font: font, fontSize: 9),
      cellAlignment: pw.Alignment.center,
      headerAlignment: pw.Alignment.center,
      columnWidths: {
        0: const pw.FixedColumnWidth(30),
      },
    );
  }

  // ─── Signatures ──────────────────────────────────────────────────────────────
  static pw.Widget _buildSignatures(
    pw.Font font,
    pw.Font boldFont, {
    String countryCode = 'SA',
  }) {
    final config = _countryConfigs[countryCode] ?? _countryConfigs['SA']!;
    final isEn = config.language == 'en';

    final deputyTitle    = isEn ? 'Vice Principal'   : (countryCode == 'AE' ? 'مدير المدرسة المساعد' : 'وكيل الشؤون المدرسية');
    final principalTitle = isEn ? 'Principal'        : 'مدير المدرسة';
    final stampTitle     = isEn ? 'Stamp'            : 'الختم';

    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Column(children: [
          pw.Text(deputyTitle, style: pw.TextStyle(font: boldFont)),
          pw.SizedBox(height: 40),
          pw.Text("....................", style: pw.TextStyle(font: font)),
        ]),
        pw.Column(children: [
          pw.Text(principalTitle, style: pw.TextStyle(font: boldFont)),
          pw.SizedBox(height: 40),
          pw.Text("....................", style: pw.TextStyle(font: font)),
        ]),
        pw.Column(children: [
          pw.Text(stampTitle, style: pw.TextStyle(font: boldFont)),
          pw.SizedBox(height: 40),
          pw.Container(
            width: 60, height: 60,
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              shape: pw.BoxShape.circle,
            ),
          ),
        ]),
      ],
    );
  }
}
