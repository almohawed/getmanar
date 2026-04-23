import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Import Firestore
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../../../core/domain/models/user.dart'; // Use User model
import '../../../../features/auth/presentation/auth_controller.dart'; // Fixed Import path

class StudentAbsenceDetailsScreen extends ConsumerWidget {
  final User student;

  const StudentAbsenceDetailsScreen({super.key, required this.student});

  // Function to Notify Parent
  Future<void> _notifyParent(BuildContext context, WidgetRef ref) async {
    try {
      final currentUser = ref.read(authStateProvider).value;
      if (currentUser == null || currentUser.schoolId == null) {
        throw Exception('User not logged in or no School ID');
      }

      // 1. Find Parent ID
      String? parentId = student.parentId;

      // If parentId is not directly available, try to find by parentIdentityNumber if exists
      if (parentId == null && student.parentIdentityNumber != null) {
        final parentQuery = await FirebaseFirestore.instance
            .collection('Schools')
            .doc(currentUser.schoolId)
            .collection('Users')
            .where('identityNumber', isEqualTo: student.parentIdentityNumber)
            .limit(1)
            .get();
        if (parentQuery.docs.isNotEmpty) {
          parentId = parentQuery.docs.first.id;
        }
      }

      if (parentId == null) {
        // Fallback: Try to find any parent linked to this student (if logic differs)
        // For now, assume failure if no link
        throw Exception('لم يتم العثور على ولي أمر مرتبط بهذا الطالب');
      }

      // 2. Send Notification
      await FirebaseFirestore.instance
          .collection('Schools')
          .doc(currentUser.schoolId)
          .collection('Notifications')
          .add({
            'userId': parentId,
            'title': 'استدعاء ولي أمر',
            'body':
                'نرجو حضوركم للمدرسة لمناقشة وضع الطالب ${student.name} الدراسي والسلوكي.',
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
            'type': 'administrative',
            'targetRole': 'parent',
            'schoolId': currentUser.schoolId,
          });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إرسال استدعاء لولي الأمر بنجاح'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'فشل الإرسال: ${e.toString().replaceAll("Exception:", "")}',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Function to Print Undertaking
  Future<void> _printUndertaking(BuildContext context, WidgetRef ref) async {
    final doc = pw.Document();
    final font = await PdfGoogleFonts.cairoRegular();
    final fontBold = await PdfGoogleFonts.cairoBold();

    // 1. Load Logo
    final logoImage = await imageFromAssetBundle('images/logo1.png');

    final currentUser = ref.read(authStateProvider).value;
    final schoolId = (currentUser?.schoolId ?? '').trim();
    var schoolName = '';
    var educationAdmin = '';
    if (schoolId.isNotEmpty) {
      final docSnap = await FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .get();
      final data = docSnap.data();
      schoolName = (data?['name'] ?? data?['schoolName'] ?? '').toString();
      educationAdmin =
          (data?['educationAdministration'] ?? data?['educationAdmin'] ?? '')
              .toString();
    }

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        theme: pw.ThemeData.withFont(base: font, bold: fontBold),
        build: (pw.Context context) {
          return pw.Directionality(
            textDirection: pw.TextDirection.rtl,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.center,
                  children: [
                    // Right Side: Ministry Info
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'المملكة العربية السعودية',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          'وزارة التعليم',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        pw.Text(
                          educationAdmin.trim().isEmpty
                              ? 'إدارة التعليم'
                              : 'إدارة التعليم ب$educationAdmin',
                          style: pw.TextStyle(fontSize: 10),
                        ),
                        if (schoolName.trim().isNotEmpty)
                          pw.Text(
                            schoolName,
                            style: pw.TextStyle(
                              fontSize: 10,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                      ],
                    ),
                    
                    // Center: Logo
                    pw.Container(
                      height: 60,
                      width: 60,
                      child: pw.Image(logoImage),
                    ),

                    // Left Side: Title
                    pw.Column(
                      children: [
                        pw.Text(
                          'تعهد خطي',
                          style: pw.TextStyle(
                            fontSize: 16,
                            fontWeight: pw.FontWeight.bold,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                        pw.Text('غياب طالب', style: pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
                pw.Divider(height: 20, thickness: 2),
                pw.SizedBox(height: 20),

                // Content
                pw.Text(
                  'إنه في يوم ............ الموافق ..../..../14هـ',
                  style: pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'الطالب: ${student.name} ................. الصف: ${student.assignedClassIds?.isNotEmpty == true ? student.assignedClassIds!.first : "....."}',
                  style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text(
                  'نظراً لتكرار غياب الطالب المذكور أعلاه بدون عذر مقبول، مما يؤثر سلباً على مستواه الدراسي ومسيرته التعليمية، ويخالف قواعد السلوك والمواظبة المقرة من وزارة التعليم.',
                  style: pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 10),
                pw.Text(
                  'لذا أتعهد أنا (الطالب / ولي الأمر) بالالتزام بالأنظمة والتعليمات المدرسية، والمواظبة على الحضور وعدم الغياب مستقبلاً إلا بعذر شرعي مقبول، وفي حال تكرار الغياب أتحمل كافة الإجراءات النظامية المترتبة على ذلك.',
                  style: pw.TextStyle(fontSize: 12),
                  textAlign: pw.TextAlign.justify,
                ),
                pw.SizedBox(height: 40),

                // Signatures
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'اسم الطالب',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Text('....................'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'ولي الأمر',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Text('....................'),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      children: [
                        pw.Text(
                          'الموجه الطلابي',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Text('....................'),
                      ],
                    ),
                    pw.Column(
                      children: [
                        pw.Text(
                          'مدير المدرسة',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                        ),
                        pw.SizedBox(height: 30),
                        pw.Text('....................'),
                      ],
                    ),
                  ],
                ),

                pw.Spacer(),
                pw.Text(
                  'حرر بتاريخ: ${DateTime.now().toString().split(' ')[0]}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => doc.save(),
      name: 'تعهد_خطي_${student.name}.pdf',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Mock Data for Detail Screen (You can replace this with a provider fetch)
    final absenceHistory = [
      {'date': '2026-03-01', 'type': 'بدون عذر', 'day': 'الأحد'},
      {'date': '2026-02-25', 'type': 'مرضي', 'day': 'الأربعاء'},
      {'date': '2026-02-18', 'type': 'بدون عذر', 'day': 'الأربعاء'},
      {'date': '2026-02-10', 'type': 'عائلي', 'day': 'الثلاثاء'},
    ];

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'ملف متابعة الغياب',
          style: GoogleFonts.cairo(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1A237E),
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
            // 1. Student Profile Header
            _buildStudentProfileHeader(),
            SizedBox(height: 16.h),

            // 2. Key Indicators (KPIs)
            _buildKeyIndicators(),
            SizedBox(height: 16.h),

            // 3. Smart Recommendations
            _buildSmartRecommendations(),
            SizedBox(height: 16.h),

            // 4. Absence Trend Chart
            _buildAbsenceTrendChart(),
            SizedBox(height: 16.h),

            // 5. Absence History List
            _buildAbsenceHistoryList(absenceHistory),
            SizedBox(height: 24.h),

            // 6. Actions
            _buildActionButtons(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentProfileHeader() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30.r,
            backgroundColor: Colors.blue.shade100,
            child: Text(
              student.name.isNotEmpty ? student.name[0] : '?',
              style: TextStyle(
                fontSize: 24.sp,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade800,
              ),
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  student.name,
                  style: GoogleFonts.cairo(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'الصف: ${student.assignedClassIds?.isNotEmpty == true ? student.assignedClassIds!.first : "غير محدد"}', // Use assignedClassIds
                  style: GoogleFonts.cairo(
                    fontSize: 14.sp,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 4.h),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4.r),
                    border: Border.all(color: Colors.red.withOpacity(0.3)),
                  ),
                  child: Text(
                    'حالة الخطر: مرتفع',
                    style: GoogleFonts.cairo(
                      fontSize: 10.sp,
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeyIndicators() {
    return Row(
      children: [
        Expanded(
          child: _buildIndicatorCard(
            'إجمالي الغياب',
            '6 أيام',
            Icons.person_off,
            Colors.red,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildIndicatorCard(
            'نسبة الحضور',
            '85%',
            Icons.pie_chart,
            Colors.orange,
          ),
        ),
        SizedBox(width: 8.w),
        Expanded(
          child: _buildIndicatorCard(
            'الإنذارات',
            '2',
            Icons.warning,
            Colors.amber,
          ),
        ),
      ],
    );
  }

  Widget _buildIndicatorCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24.sp),
          SizedBox(height: 8.h),
          Text(
            value,
            style: GoogleFonts.cairo(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.cairo(
              fontSize: 10.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSmartRecommendations() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.blue.shade50, Colors.white]),
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: Colors.blue.shade700),
              SizedBox(width: 8.w),
              Text(
                'توصيات النظام الذكي',
                style: GoogleFonts.cairo(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            '• يلاحظ تكرار الغياب يوم الأربعاء (نمط متكرر).\n• يوصى بعقد جلسة توجيه فردي مع الطالب.\n• التواصل مع ولي الأمر للتأكد من عدم وجود مشاكل نقل.',
            style: GoogleFonts.cairo(
              fontSize: 12.sp,
              color: Colors.black87,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceTrendChart() {
    return Container(
      height: 200.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'اتجاه الغياب (آخر 4 أسابيع)',
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16.h),
          Expanded(
            child: BarChart(
              BarChartData(
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          'الأسبوع ${value.toInt() + 1}',
                          style: GoogleFonts.cairo(fontSize: 10.sp),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                gridData: FlGridData(show: false),
                barGroups: [
                  BarChartGroupData(
                    x: 0,
                    barRods: [
                      BarChartRodData(toY: 1, color: Colors.blue, width: 12.w),
                    ],
                  ),
                  BarChartGroupData(
                    x: 1,
                    barRods: [
                      BarChartRodData(toY: 2, color: Colors.blue, width: 12.w),
                    ],
                  ),
                  BarChartGroupData(
                    x: 2,
                    barRods: [
                      BarChartRodData(toY: 1, color: Colors.blue, width: 12.w),
                    ],
                  ),
                  BarChartGroupData(
                    x: 3,
                    barRods: [
                      BarChartRodData(toY: 2, color: Colors.red, width: 12.w),
                    ],
                  ), // Current week
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAbsenceHistoryList(List<Map<String, String>> history) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'سجل الغياب التفصيلي',
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 12.h),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: history.length,
            separatorBuilder: (context, index) => Divider(),
            itemBuilder: (context, index) {
              final item = history[index];
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: EdgeInsets.all(8.w),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Icon(
                    Icons.calendar_today,
                    size: 20.sp,
                    color: Colors.blue,
                  ),
                ),
                title: Text(
                  '${item['day']} - ${item['date']}',
                  style: GoogleFonts.cairo(
                    fontWeight: FontWeight.bold,
                    fontSize: 12.sp,
                  ),
                ),
                subtitle: Text(
                  item['type']!,
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.grey),
                ),
                trailing: Text(
                  'غياب كامل',
                  style: GoogleFonts.cairo(fontSize: 11.sp, color: Colors.red),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () {
              _notifyParent(context, ref);
            },
            icon: Icon(Icons.call, color: Colors.white),
            label: Text(
              'استدعاء ولي الأمر',
              style: GoogleFonts.cairo(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.purple,
              padding: EdgeInsets.symmetric(vertical: 12.h),
            ),
          ),
        ),
        SizedBox(height: 12.h),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // Simulate Referral
                  Future.delayed(Duration(seconds: 1), () {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم تحويل الطالب للمرشد الطلابي بنجاح'),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  });
                },
                icon: Icon(Icons.psychology),
                label: Text('تحويل للمرشد', style: GoogleFonts.cairo()),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  _printUndertaking(context, ref); // Call Print Function
                },
                icon: Icon(Icons.assignment),
                label: Text('تعهد خطي', style: GoogleFonts.cairo()),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
