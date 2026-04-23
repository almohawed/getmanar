import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../core/domain/models/behavior_record.dart';
import '../../../core/domain/models/user.dart';
import '../../behavior/presentation/behavior_controller.dart';

class ParentViolationsScreen extends ConsumerWidget {
  final User student;

  const ParentViolationsScreen({super.key, required this.student});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final behaviorAsync = ref.watch(studentBehaviorProvider(student.id));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('المخالفات السلوكية'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.red.shade800,
        elevation: 0,
        centerTitle: true,
      ),
      body: behaviorAsync.when(
        data: (records) {
          final violations = records
              .where(
                (r) =>
                    r.type == BehaviorType.negative ||
                    r.type == BehaviorType.escape,
              )
              .toList();
          return _buildBody(context, violations);
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, s) => Center(child: Text('حدث خطأ: $e')),
      ),
    );
  }

  Widget _buildBody(BuildContext context, List<BehaviorRecord> violations) {
    // Categorize violations (Mock logic based on keywords or random for demo if description doesn't match)
    final inClass = violations
        .where(
          (v) => v.description.contains('فصل') || v.description.contains('حصة'),
        )
        .toList();
    final outClass = violations
        .where(
          (v) =>
              v.description.contains('ساحة') || v.description.contains('ممر'),
        )
        .toList();
    final escapeClass = violations
        .where(
          (v) =>
              v.type == BehaviorType.escape ||
              v.description.contains('هروب من حصة'),
        )
        .toList();
    final escapeSchool = violations
        .where((v) => v.description.contains('هروب من المدرسة'))
        .toList();

    // Fallback for demo: if lists are empty but we have violations, distribute them
    if (violations.isNotEmpty &&
        inClass.isEmpty &&
        outClass.isEmpty &&
        escapeClass.isEmpty &&
        escapeSchool.isEmpty) {
      // Just put them all in "General" or distribute for visual demo
      inClass.addAll(violations);
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Statistics Chart
          _buildStatsChart(
            inClass.length,
            outClass.length,
            escapeClass.length,
            escapeSchool.length,
          ),
          SizedBox(height: 24.h),

          // 2. Violation Categories
          _buildCategoryTile(
            context,
            'مخالفات داخل الفصل',
            inClass,
            Icons.class_,
            Colors.orange,
          ),
          SizedBox(height: 12.h),
          _buildCategoryTile(
            context,
            'مخالفات خارج الفصل',
            outClass,
            Icons.directions_walk,
            Colors.blue,
          ),
          SizedBox(height: 12.h),
          _buildCategoryTile(
            context,
            'الهروب من الحصص',
            escapeClass,
            Icons.timer_off,
            Colors.purple,
          ),
          SizedBox(height: 12.h),
          _buildCategoryTile(
            context,
            'الهروب من المدرسة',
            escapeSchool,
            Icons.warning,
            Colors.red,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsChart(int c1, int c2, int c3, int c4) {
    final total = c1 + c2 + c3 + c4;
    if (total == 0) {
      return Container(
        height: 200.h,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            'لا توجد مخالفات مسجلة',
            style: TextStyle(fontSize: 16.sp, color: Colors.grey),
          ),
        ),
      );
    }

    return Container(
      height: 250.h,
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            'إحصائيات المخالفات',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16.sp),
          ),
          Expanded(
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 40,
                sections: [
                  if (c1 > 0)
                    PieChartSectionData(
                      value: c1.toDouble(),
                      color: Colors.orange,
                      title: '$c1',
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (c2 > 0)
                    PieChartSectionData(
                      value: c2.toDouble(),
                      color: Colors.blue,
                      title: '$c2',
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (c3 > 0)
                    PieChartSectionData(
                      value: c3.toDouble(),
                      color: Colors.purple,
                      title: '$c3',
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  if (c4 > 0)
                    PieChartSectionData(
                      value: c4.toDouble(),
                      color: Colors.red,
                      title: '$c4',
                      radius: 50,
                      titleStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(height: 10.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildLegendItem('داخل الفصل', Colors.orange),
              SizedBox(width: 8.w),
              _buildLegendItem('خارج الفصل', Colors.blue),
              SizedBox(width: 8.w),
              _buildLegendItem('هروب حصص', Colors.purple),
              SizedBox(width: 8.w),
              _buildLegendItem('هروب مدرسة', Colors.red),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 8.w,
          height: 8.w,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        SizedBox(width: 4.w),
        Text(
          title,
          style: TextStyle(fontSize: 10.sp, color: Colors.grey.shade700),
        ),
      ],
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    String title,
    List<BehaviorRecord> records,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      color: Colors.white,
      child: ExpansionTile(
        leading: Container(
          padding: EdgeInsets.all(8.w),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15.sp),
        ),
        trailing: Container(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${records.length}',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        children: records.isEmpty
            ? [
                Padding(
                  padding: EdgeInsets.all(16.w),
                  child: const Text('لا توجد مخالفات'),
                ),
              ]
            : records
                  .map(
                    (r) => ListTile(
                      title: Text(r.description),
                      subtitle: Text(r.timestamp.toString().substring(0, 16)),
                      trailing: Text(
                        '${r.points}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  )
                  .toList(),
      ),
    );
  }
}
