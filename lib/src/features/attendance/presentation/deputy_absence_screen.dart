import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart' as intl;
import '../../../core/domain/models/user.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/models/daily_absence_model.dart';
import 'providers/daily_absence_provider.dart';
import 'widgets/deputy_absence_list.dart';

class DeputyAbsenceScreen extends ConsumerStatefulWidget {
  const DeputyAbsenceScreen({super.key});

  @override
  ConsumerState<DeputyAbsenceScreen> createState() =>
      _DeputyAbsenceScreenState();
}

class _DeputyAbsenceScreenState extends ConsumerState<DeputyAbsenceScreen> {
  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;

    // Permission Check
    final isAuthorized =
        user != null &&
        user.role == UserRole.deputy &&
        (user.deputyType == 'academic' ||
            user.deputyType == 'students' ||
            user.deputyType == 'stage');

    if (!isAuthorized) {
      return Scaffold(
        appBar: AppBar(title: const Text('غير مصرح')),
        body: const Center(
          child: Text(
            'عذراً، هذه الصلاحية خاصة بوكلاء الشؤون التعليمية والطلاب والمراحل فقط.',
          ),
        ),
      );
    }

    final absenceAsync = ref.watch(dailyAbsenceProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('كشف الغياب اليومي'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () => _printReport(absenceAsync.asData?.value ?? []),
          ),
        ],
      ),
      body: const SingleChildScrollView(child: DeputyAbsenceListWidget()),
    );
  }

  Future<void> _printReport(List<DailyAbsenceModel> students) async {
    final pdf = pw.Document();

    // Load Arabic Font (Use standard font or loading logic)
    // For brevity, assuming a font loader or default font supporting Arabic
    // In real app: final font = await fontFromAssetBundle('assets/fonts/Tajawal-Regular.ttf');
    final font = await PdfGoogleFonts.cairoRegular();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font),
        textDirection: pw.TextDirection.rtl,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'المملكة العربية السعودية',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'وزارة التعليم',
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                      pw.Text(
                        'اسم المدرسة (تجريبي)',
                        style: pw.TextStyle(
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text(
                        'كشف الغياب اليومي للطلاب',
                        style: pw.TextStyle(
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.Text(
                        'التاريخ: 1447/--/-- هـ',
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                      pw.Text(
                        intl.DateFormat('yyyy-MM-dd').format(DateTime.now()),
                        style: const pw.TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 20),

              // Table
              pw.TableHelper.fromTextArray(
                headers: ['م', 'اسم الطالب', 'الفصل', 'الحصة', 'اسم المعلم'],
                data: List<List<String>>.generate(
                  students.length,
                  (index) => [
                    (index + 1).toString(),
                    students[index].studentName,
                    students[index].className,
                    students[index].period,
                    students[index].teacherName,
                  ],
                ),
                headerStyle: pw.TextStyle(
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white,
                ),
                headerDecoration: const pw.BoxDecoration(
                  color: PdfColors.indigo,
                ),
                cellAlignment: pw.Alignment.centerRight,
                tableWidth: pw.TableWidth.max,
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }
}
