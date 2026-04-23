import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class GovernanceFrameworkScreen extends StatelessWidget {
  const GovernanceFrameworkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'إطار الحوكمة والتنظيم المدرسي',
          style: GoogleFonts.cairo(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(20.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildIntroduction(),
            SizedBox(height: 32.h),
            _buildMappingTable(),
            SizedBox(height: 32.h),
            _buildStrategicNotes(),
            SizedBox(height: 40.h),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroduction() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.indigo.shade900),
              SizedBox(width: 12.w),
              Text(
                'مواءمة النظام مع الدليل التنظيمي 1447',
                style: GoogleFonts.cairo(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          Text(
            'يعتمد نظام منار الذكي نموذج "الحوكمة المدمجة"، حيث يتم دمج متطلبات الدليل التنظيمي لوزارة التعليم ضمن العمليات التشغيلية اليومية لضمان الامتثال التلقائي دون الحاجة لفصل المهام إدارياً.',
            style: GoogleFonts.cairo(
              fontSize: 14.sp,
              height: 1.6,
              color: Colors.grey.shade800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMappingTable() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'جدول المطابقة التنظيمي (Mapping Table)',
          style: GoogleFonts.cairo(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: Colors.indigo.shade900,
          ),
        ),
        SizedBox(height: 16.h),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300, width: 1),
          columnWidths: const {
            0: FlexColumnWidth(1),
            1: FlexColumnWidth(2),
          },
          children: [
            _buildTableRow('متطلب الدليل التنظيمي 1447', 'التمثيل في نظام منار الذكي', isHeader: true),
            _buildTableRow('المجالس واللجان المدرسية', 'مدمجة ضمن قسم (القيادة المدرسية - الاجتماعات) مع أتمتة المحاضر والقرارات.'),
            _buildTableRow('إدارة المخاطر والأزمات', 'مدمجة ضمن (الشؤون الإدارية - الأمن والسلامة) مع نظام تنبيهات استباقي.'),
            _buildTableRow('تحسين نواتج التعلم', 'مدمجة ضمن (الشؤون الأكاديمية - تحليل النتائج) مع خطط تحسين مدعومة بالذكاء الاصطناعي.'),
            _buildTableRow('الشراكة المجتمعية', 'مدمجة ضمن (الشؤون الأكاديمية - أولياء الأمور) من خلال بوابة تواصل ذكية.'),
            _buildTableRow('السجلات النظامية والمتابعة', 'مؤرشفة آلياً ضمن (الشؤون الإدارية - التكليفات) وسجل الوارد والصادر الرقمي.'),
          ],
        ),
      ],
    );
  }

  TableRow _buildTableRow(String col1, String col2, {bool isHeader = false}) {
    return TableRow(
      decoration: BoxDecoration(
        color: isHeader ? Colors.indigo.shade900 : Colors.white,
      ),
      children: [
        Padding(
          padding: EdgeInsets.all(12.w),
          child: Text(
            col1,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
              color: isHeader ? Colors.white : Colors.indigo.shade900,
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.all(12.w),
          child: Text(
            col2,
            style: GoogleFonts.cairo(
              fontSize: 13.sp,
              color: isHeader ? Colors.white : Colors.grey.shade800,
              fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStrategicNotes() {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Colors.amber.shade900),
              SizedBox(width: 12.w),
              Text(
                'ملاحظات استراتيجية للعرض الرسمي',
                style: GoogleFonts.cairo(
                  fontSize: 16.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber.shade900,
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          _buildBulletPoint('النظام لا يفصل اللجان عن العمل التنفيذي؛ بل يجعل الحوكمة جزءاً من المهام اليومية لضمان سرعة الإنجاز.'),
          _buildBulletPoint('كافة التقارير المطلوبة في الدليل التنظيمي يتم توليدها آلياً بناءً على البيانات المدخلة في الأقسام التشغيلية.'),
          _buildBulletPoint('التصميم يركز على الكفاءة الإدارية (Operational Efficiency) مع الحفاظ على الامتثال الكامل (Compliance).'),
        ],
      ),
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 16.sp, color: Colors.amber.shade700),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.cairo(
                fontSize: 13.sp,
                color: Colors.amber.shade900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
