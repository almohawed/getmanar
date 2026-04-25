import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:google_fonts/google_fonts.dart';

/// شاشة تقارير السلوك
class BehaviorReportsScreen extends StatefulWidget {
  const BehaviorReportsScreen({super.key});

  @override
  State<BehaviorReportsScreen> createState() => _BehaviorReportsScreenState();
}

class _BehaviorReportsScreenState extends State<BehaviorReportsScreen> {
  String _selectedReportType = 'daily'; // daily, weekly, monthly, custom
  DateTime _startDate = DateTime.now().subtract(const Duration(days: 7));
  DateTime _endDate = DateTime.now();
  Map<String, dynamic> _reportData = {};
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _generateReport();
  }

  Future<void> _generateReport() async {
    setState(() => _isLoading = true);

    try {
      // تحديد الفترة الزمنية حسب نوع التقرير
      DateTime startDate, endDate;
      switch (_selectedReportType) {
        case 'daily':
          startDate = DateTime.now().subtract(const Duration(days: 1));
          endDate = DateTime.now();
          break;
        case 'weekly':
          startDate = DateTime.now().subtract(const Duration(days: 7));
          endDate = DateTime.now();
          break;
        case 'monthly':
          startDate = DateTime.now().subtract(const Duration(days: 30));
          endDate = DateTime.now();
          break;
        case 'custom':
          startDate = _startDate;
          endDate = _endDate;
          break;
        default:
          startDate = DateTime.now().subtract(const Duration(days: 7));
          endDate = DateTime.now();
      }

      // جلب بيانات المخالفات
      final violationsQuery = await FirebaseFirestore.instance
          .collection('behavioral_violations')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // جلب بيانات السلوك الإيجابي
      final positiveBehaviorQuery = await FirebaseFirestore.instance
          .collection('positive_behavior')
          .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate))
          .get();

      // جلب بيانات الطلاب
      final studentsQuery = await FirebaseFirestore.instance
          .collection('students')
          .get();

      // إنشاء التقرير
      final reportData = _createReportData(
        violationsQuery.docs,
        positiveBehaviorQuery.docs,
        studentsQuery.docs,
        startDate,
        endDate,
      );

      setState(() {
        _reportData = reportData;
        _isLoading = false;
      });
    } catch (e) {
      print('Error generating report: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, dynamic> _createReportData(
    List<QueryDocumentSnapshot> violations,
    List<QueryDocumentSnapshot> positiveBehavior,
    List<QueryDocumentSnapshot> students,
    DateTime startDate,
    DateTime endDate,
  ) {
    // إحصائيات عامة
    final totalViolations = violations.length;
    final totalPositive = positiveBehavior.length;
    final totalStudents = students.length;

    // تحليل المخالفات
    Map<String, int> violationsByType = {};
    Map<String, int> violationsByLevel = {};
    Map<String, int> violationsByGrade = {};
    Map<String, int> violationsByStudent = {};
    
    for (var doc in violations) {
      final data = doc.data() as Map<String, dynamic>;
      
      // حسب النوع
      final type = data['violationType'] ?? 'غير محدد';
      violationsByType[type] = (violationsByType[type] ?? 0) + 1;

      // حسب المستوى
      final level = data['level'] ?? 'غير محدد';
      violationsByLevel[level] = (violationsByLevel[level] ?? 0) + 1;

      // حسب الصف
      final grade = data['studentGrade'] ?? 'غير محدد';
      violationsByGrade[grade] = (violationsByGrade[grade] ?? 0) + 1;

      // حسب الطالب
      final studentName = data['studentName'] ?? 'غير محدد';
      violationsByStudent[studentName] = (violationsByStudent[studentName] ?? 0) + 1;
    }

    // تحليل السلوك الإيجابي
    Map<String, int> positiveBehaviorByType = {};
    Map<String, int> positiveBehaviorByStudent = {};
    
    for (var doc in positiveBehavior) {
      final data = doc.data() as Map<String, dynamic>;
      
      final type = data['behaviorType'] ?? 'غير محدد';
      positiveBehaviorByType[type] = (positiveBehaviorByType[type] ?? 0) + 1;

      final studentName = data['studentName'] ?? 'غير محدد';
      positiveBehaviorByStudent[studentName] = (positiveBehaviorByStudent[studentName] ?? 0) + 1;
    }

    // أفضل وأسوأ الطلاب
    final topStudents = positiveBehaviorByStudent.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));
    
    final problematicStudents = violationsByStudent.entries
        .toList()
        ..sort((a, b) => b.value.compareTo(a.value));

    // حساب المؤشرات
    final behaviorScore = totalStudents > 0 
        ? ((totalPositive - totalViolations) / totalStudents * 100).clamp(0, 100)
        : 0;

    return {
      'period': '${DateFormat('dd/MM/yyyy').format(startDate)} - ${DateFormat('dd/MM/yyyy').format(endDate)}',
      'totalViolations': totalViolations,
      'totalPositive': totalPositive,
      'totalStudents': totalStudents,
      'behaviorScore': behaviorScore.round(),
      'violationsByType': violationsByType,
      'violationsByLevel': violationsByLevel,
      'violationsByGrade': violationsByGrade,
      'positiveBehaviorByType': positiveBehaviorByType,
      'topStudents': topStudents.take(5).toList(),
      'problematicStudents': problematicStudents.take(5).toList(),
      'criticalCases': violations.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['level'] == 'خطيرة' || data['level'] == 'شديدة';
      }).length,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          // الشريط العلوي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal.shade600, Colors.teal.shade700],
              ),
            ),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                ),
                const Expanded(
                  child: Text(
                    'تقارير السلوك',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                // زر تصدير PDF
                IconButton(
                  onPressed: () => _exportToPDF(),
                  icon: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 24),
                  tooltip: 'تصدير PDF',
                ),
                // زر تحديث
                IconButton(
                  onPressed: () => _generateReport(),
                  icon: const Icon(Icons.refresh, color: Colors.white, size: 24),
                  tooltip: 'تحديث',
                ),
              ],
            ),
          ),

          // إعدادات التقرير
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إعدادات التقرير',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                // نوع التقرير
                Row(
                  children: [
                    const Text('نوع التقرير: '),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedReportType,
                        isExpanded: true,
                        underline: const SizedBox(),
                        items: const [
                          DropdownMenuItem(value: 'daily', child: Text('يومي')),
                          DropdownMenuItem(value: 'weekly', child: Text('أسبوعي')),
                          DropdownMenuItem(value: 'monthly', child: Text('شهري')),
                          DropdownMenuItem(value: 'custom', child: Text('فترة مخصصة')),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _selectedReportType = value);
                            if (value != 'custom') {
                              _generateReport();
                            }
                          }
                        },
                      ),
                    ),
                  ],
                ),
                
                // التواريخ المخصصة
                if (_selectedReportType == 'custom') ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('من تاريخ:', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _startDate,
                                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _startDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(DateFormat('dd/MM/yyyy').format(_startDate)),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('إلى تاريخ:', style: TextStyle(fontSize: 12)),
                            const SizedBox(height: 4),
                            GestureDetector(
                              onTap: () async {
                                final date = await showDatePicker(
                                  context: context,
                                  initialDate: _endDate,
                                  firstDate: _startDate,
                                  lastDate: DateTime.now(),
                                );
                                if (date != null) {
                                  setState(() => _endDate = date);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(DateFormat('dd/MM/yyyy').format(_endDate)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _generateReport,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('إنشاء التقرير'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // محتوى التقرير
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _reportData.isEmpty
                    ? const Center(child: Text('لا توجد بيانات للعرض'))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // معلومات التقرير
                            _buildReportHeader(),
                            
                            const SizedBox(height: 24),
                            
                            // الإحصائيات الرئيسية
                            _buildMainStatistics(),
                            
                            const SizedBox(height: 24),
                            
                            // تفاصيل المخالفات
                            _buildViolationsDetails(),
                            
                            const SizedBox(height: 24),
                            
                            // السلوك الإيجابي
                            _buildPositiveBehaviorDetails(),
                            
                            const SizedBox(height: 24),
                            
                            // أفضل وأسوأ الطلاب
                            _buildStudentRankings(),
                            
                            const SizedBox(height: 24),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment, color: Colors.teal.shade600),
              const SizedBox(width: 8),
              const Text(
                'تقرير السلوك والانضباط',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'الفترة: ${_reportData['period'] ?? ''}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            'تاريخ الإنشاء: ${DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now())}',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }

  Widget _buildMainStatistics() {
    final totalViolations = _reportData['totalViolations'] ?? 0;
    final totalPositive = _reportData['totalPositive'] ?? 0;
    final behaviorScore = _reportData['behaviorScore'] ?? 0;
    final criticalCases = _reportData['criticalCases'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'الإحصائيات الرئيسية',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.5,
          children: [
            _buildStatCard('إجمالي المخالفات', totalViolations.toString(), Icons.warning, Colors.red),
            _buildStatCard('السلوك الإيجابي', totalPositive.toString(), Icons.star, Colors.green),
            _buildStatCard('مؤشر السلوك', '$behaviorScore%', Icons.trending_up, 
                behaviorScore >= 70 ? Colors.green : behaviorScore >= 50 ? Colors.orange : Colors.red),
            _buildStatCard('الحالات الحرجة', criticalCases.toString(), Icons.priority_high, Colors.deepOrange),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildViolationsDetails() {
    final violationsByType = _reportData['violationsByType'] as Map<String, int>? ?? {};
    final violationsByLevel = _reportData['violationsByLevel'] as Map<String, int>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'تفاصيل المخالفات',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حسب النوع', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...violationsByType.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                          Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('حسب المستوى', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    ...violationsByLevel.entries.map((entry) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                          Text('${entry.value}', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPositiveBehaviorDetails() {
    final positiveBehaviorByType = _reportData['positiveBehaviorByType'] as Map<String, int>? ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'السلوك الإيجابي',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('حسب النوع', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (positiveBehaviorByType.isEmpty)
                const Text('لا توجد بيانات سلوك إيجابي')
              else
                ...positiveBehaviorByType.entries.map((entry) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(entry.key)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${entry.value}',
                          style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                )),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentRankings() {
    final topStudents = _reportData['topStudents'] as List? ?? [];
    final problematicStudents = _reportData['problematicStudents'] as List? ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ترتيب الطلاب',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.star, color: Colors.green.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('أفضل الطلاب', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (topStudents.isEmpty)
                      const Text('لا توجد بيانات', style: TextStyle(fontSize: 12))
                    else
                      ...topStudents.take(3).map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                            Text('${entry.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning, color: Colors.red.shade600, size: 20),
                        const SizedBox(width: 8),
                        const Text('يحتاجون متابعة', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (problematicStudents.isEmpty)
                      const Text('لا توجد بيانات', style: TextStyle(fontSize: 12))
                    else
                      ...problematicStudents.take(3).map((entry) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 12))),
                            Text('${entry.value}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _exportToPDF() async {
    try {
      print('🔄 بدء تصدير PDF...');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تصدير التقرير إلى PDF...')),
      );

      print('🔄 تحميل الخط العربي من Google Fonts...');
      final arabicFont = await PdfGoogleFonts.cairoRegular();
      final arabicFontBold = await PdfGoogleFonts.cairoBold();
      print('✅ تم تحميل الخط');

      // تحميل الشعار
      pw.MemoryImage? logo;
      try {
        final data = await rootBundle.load('assets/logokshuf.webp');
        logo = pw.MemoryImage(data.buffer.asUint8List());
        print('✅ تم تحميل الشعار');
      } catch (e) {
        print('⚠️ لم يتم تحميل الشعار: $e');
      }

      // Get data safely
      final totalViolations = _reportData['totalViolations'] ?? 0;
      final totalPositive = _reportData['totalPositive'] ?? 0;
      final behaviorScore = _reportData['behaviorScore'] ?? 0;
      final criticalCases = _reportData['criticalCases'] ?? 0;
      final violationsByType = (_reportData['violationsByType'] as Map<String, int>?) ?? {};
      final topStudents = (_reportData['topStudents'] as List?) ?? [];
      final problematicStudents = (_reportData['problematicStudents'] as List?) ?? [];

      print('🔄 بناء محتوى PDF...');

      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          textDirection: pw.TextDirection.rtl,
          build: (context) {
            return pw.Column(
              children: [
                // الكليشة الرسمية
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // اليمين: معلومات المملكة
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('المملكة العربية السعودية', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, font: arabicFontBold), textDirection: pw.TextDirection.rtl),
                            pw.Text('وزارة التعليم', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold), textDirection: pw.TextDirection.rtl),
                            pw.SizedBox(height: 4),
                            pw.Text('الرياض', style: pw.TextStyle(fontSize: 9, font: arabicFont), textDirection: pw.TextDirection.rtl),
                            pw.Text('مدرسة المنارات الذهبية', style: pw.TextStyle(fontSize: 9, font: arabicFont), textDirection: pw.TextDirection.rtl),
                          ],
                        ),
                      ),
                      
                      // الوسط: الشعار
                      pw.Expanded(
                        child: pw.Center(
                          child: logo != null
                              ? pw.Image(logo, width: 80, height: 80)
                              : pw.Container(
                                  padding: const pw.EdgeInsets.all(8),
                                  decoration: pw.BoxDecoration(
                                    border: pw.Border.all(color: PdfColors.teal, width: 2),
                                    borderRadius: pw.BorderRadius.circular(8),
                                  ),
                                  child: pw.Text('الشعار', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.teal), textDirection: pw.TextDirection.rtl),
                                ),
                        ),
                      ),
                      
                      // اليسار: معلومات التقرير
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('اليوم: الأربعاء', style: pw.TextStyle(fontSize: 10, font: arabicFont), textDirection: pw.TextDirection.rtl),
                            pw.Text('التاريخ: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 10, font: arabicFont), textDirection: pw.TextDirection.rtl),
                            pw.Text('الرقم: ___________', style: pw.TextStyle(fontSize: 10, font: arabicFont), textDirection: pw.TextDirection.rtl),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // خط فاصل
                pw.Container(
                  margin: const pw.EdgeInsets.symmetric(horizontal: 16),
                  height: 2,
                  color: PdfColors.grey800,
                ),

                pw.SizedBox(height: 20),

                // عنوان التقرير
                pw.Text(
                  'كشف التأخر الصباحي',
                  style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, font: arabicFontBold),
                  textDirection: pw.TextDirection.rtl,
                ),
                pw.Text(
                  'الفترة من ${_reportData['period'] ?? ''}',
                  style: pw.TextStyle(fontSize: 11, font: arabicFont),
                  textDirection: pw.TextDirection.rtl,
                ),

                pw.SizedBox(height: 20),

                // جدول البيانات
                pw.Container(
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey800),
                  ),
                  child: pw.Column(
                    children: [
                      // رأس الجدول
                      pw.Container(
                        color: PdfColors.grey700,
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Row(
                          children: [
                            pw.Expanded(flex: 1, child: pw.Text('م', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.white), textAlign: pw.TextAlign.center)),
                            pw.Expanded(flex: 3, child: pw.Text('اسم الطالب', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.white), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
                            pw.Expanded(flex: 2, child: pw.Text('التاريخ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.white), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
                            pw.Expanded(flex: 2, child: pw.Text('وقت الحضور', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.white), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
                            pw.Expanded(flex: 2, child: pw.Text('الحالة', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.white), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
                            pw.Expanded(flex: 2, child: pw.Text('الفصل', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold, color: PdfColors.white), textDirection: pw.TextDirection.rtl, textAlign: pw.TextAlign.center)),
                          ],
                        ),
                      ),
                      
                      // صفوف البيانات
                      ...List.generate(10, (index) {
                        return pw.Container(
                          decoration: pw.BoxDecoration(
                            border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400)),
                          ),
                          padding: const pw.EdgeInsets.all(8),
                          child: pw.Row(
                            children: [
                              pw.Expanded(flex: 1, child: pw.Text('${index + 1}', style: pw.TextStyle(fontSize: 9, font: arabicFont), textAlign: pw.TextAlign.center)),
                              pw.Expanded(flex: 3, child: pw.Text('', style: pw.TextStyle(fontSize: 9, font: arabicFont), textAlign: pw.TextAlign.center)),
                              pw.Expanded(flex: 2, child: pw.Text('', style: pw.TextStyle(fontSize: 9, font: arabicFont), textAlign: pw.TextAlign.center)),
                              pw.Expanded(flex: 2, child: pw.Text('', style: pw.TextStyle(fontSize: 9, font: arabicFont), textAlign: pw.TextAlign.center)),
                              pw.Expanded(flex: 2, child: pw.Text('', style: pw.TextStyle(fontSize: 9, font: arabicFont), textAlign: pw.TextAlign.center)),
                              pw.Expanded(flex: 2, child: pw.Text('', style: pw.TextStyle(fontSize: 9, font: arabicFont), textAlign: pw.TextAlign.center)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                pw.Spacer(),

                // التذييل
                pw.Container(
                  margin: const pw.EdgeInsets.only(top: 20),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 16),
                  child: pw.Column(
                    children: [
                      pw.Container(height: 1, color: PdfColors.grey800),
                      pw.SizedBox(height: 15),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          // اليمين
                          pw.Column(
                            children: [
                              pw.Text('وكيل الشؤون المدرسية', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold), textDirection: pw.TextDirection.rtl),
                              pw.SizedBox(height: 15),
                              pw.Container(width: 100, height: 1, color: PdfColors.black),
                              pw.SizedBox(height: 3),
                              pw.Text('......................', style: pw.TextStyle(fontSize: 8, font: arabicFont)),
                            ],
                          ),
                          // الوسط
                          pw.Column(
                            children: [
                              pw.Text('مدير المدرسة', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, font: arabicFontBold), textDirection: pw.TextDirection.rtl),
                              pw.SizedBox(height: 15),
                              pw.Container(width: 100, height: 1, color: PdfColors.black),
                              pw.SizedBox(height: 3),
                              pw.Text('......................', style: pw.TextStyle(fontSize: 8, font: arabicFont)),
                            ],
                          ),
                          // اليسار
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('تاريخ الطباعة: ${DateFormat('dd-MM-yyyy').format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, font: arabicFont), textDirection: pw.TextDirection.rtl),
                            ],
                          ),
                        ],
                      ),
                      pw.SizedBox(height: 10),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('نظام تتبع - شؤون الطلاب', style: pw.TextStyle(fontSize: 8, font: arabicFont), textDirection: pw.TextDirection.rtl),
                          pw.Text('صفحة 1 من 1', style: pw.TextStyle(fontSize: 8, font: arabicFont), textDirection: pw.TextDirection.rtl),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );

      print('✅ تم بناء PDF');
      print('🔄 جاري الحفظ...');

      final bytes = await pdf.save();
      
      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => bytes,
        name: 'كشف_التأخر_الصباحي_${DateFormat('yyyy-MM-dd').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تصدير التقرير بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ خطأ في تصدير PDF: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ فشل التصدير: ${e.toString()}'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  pw.Widget _buildPdfStatCard(String title, String value, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(8),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, font: font),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 9, font: font),
            textDirection: pw.TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  void _exportToExcel() async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('جاري تصدير التقرير إلى CSV...')),
      );

      // Build CSV content
      final StringBuffer csv = StringBuffer();
      
      // Header
      csv.writeln('تقرير السلوك والانضباط');
      csv.writeln('الفترة,${_reportData['period'] ?? ''}');
      csv.writeln('تاريخ الإنشاء,${DateFormat('dd/MM/yyyy - HH:mm').format(DateTime.now())}');
      csv.writeln('');

      // Statistics
      csv.writeln('الإحصائيات الرئيسية');
      csv.writeln('إجمالي المخالفات,${_reportData['totalViolations'] ?? 0}');
      csv.writeln('السلوك الإيجابي,${_reportData['totalPositive'] ?? 0}');
      csv.writeln('مؤشر السلوك,${_reportData['behaviorScore'] ?? 0}%');
      csv.writeln('الحالات الحرجة,${_reportData['criticalCases'] ?? 0}');
      csv.writeln('');

      // Violations by Type
      final violationsByType = _reportData['violationsByType'] as Map<String, int>? ?? {};
      csv.writeln('المخالفات حسب النوع');
      csv.writeln('نوع المخالفة,العدد');
      violationsByType.forEach((key, value) {
        csv.writeln('$key,$value');
      });
      csv.writeln('');

      // Violations by Level
      final violationsByLevel = _reportData['violationsByLevel'] as Map<String, int>? ?? {};
      csv.writeln('المخالفات حسب المستوى');
      csv.writeln('المستوى,العدد');
      violationsByLevel.forEach((key, value) {
        csv.writeln('$key,$value');
      });
      csv.writeln('');

      // Positive Behavior
      final positiveBehaviorByType = _reportData['positiveBehaviorByType'] as Map<String, int>? ?? {};
      csv.writeln('السلوك الإيجابي حسب النوع');
      csv.writeln('نوع السلوك,العدد');
      positiveBehaviorByType.forEach((key, value) {
        csv.writeln('$key,$value');
      });
      csv.writeln('');

      // Top Students
      final topStudents = _reportData['topStudents'] as List? ?? [];
      csv.writeln('أفضل الطلاب');
      csv.writeln('اسم الطالب,عدد السلوكيات الإيجابية');
      for (var entry in topStudents.take(10)) {
        csv.writeln('${entry.key},${entry.value}');
      }
      csv.writeln('');

      // Problematic Students
      final problematicStudents = _reportData['problematicStudents'] as List? ?? [];
      csv.writeln('الطلاب الذين يحتاجون متابعة');
      csv.writeln('اسم الطالب,عدد المخالفات');
      for (var entry in problematicStudents.take(10)) {
        csv.writeln('${entry.key},${entry.value}');
      }

      // Convert to bytes with UTF-8 BOM for Excel compatibility
      final bytes = [0xEF, 0xBB, 0xBF, ...csv.toString().codeUnits];
      
      // على الموبايل: مشاركة الملف
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم تصدير التقرير بنجاح (CSV)'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e, stackTrace) {
      print('❌ خطأ في تصدير CSV: $e');
      print('Stack trace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل التصدير. يرجى المحاولة مرة أخرى'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }
}