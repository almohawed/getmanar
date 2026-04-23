import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../common/presentation/smart_section_scaffold.dart';

class SchoolGuideScreen extends ConsumerWidget {
  const SchoolGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SmartSectionScaffold(
      title: 'الدليل التنظيمي والإجرائي',
      icon: Icons.menu_book,
      themeColor: Colors.teal,
      initialRecommendation:
          'يجب التأكد من اطلاع جميع منسوبي المدرسة على الدليل الإجرائي وتحديثاته.',
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.w),
        child: Column(
          children: [
            _buildGuideSection(
              context,
              'الدليل التنظيمي',
              'الهيكل التنظيمي والوصف الوظيفي لجميع منسوبي المدرسة.',
              Icons.account_tree,
              Colors.teal,
              [
                'الهيكل التنظيمي للمدرسة',
                'الوصف الوظيفي للكادر الإداري',
                'الوصف الوظيفي للكادر التعليمي',
                'المجالس واللجان المدرسية',
              ],
            ),
            SizedBox(height: 24.h),
            _buildGuideSection(
              context,
              'الدليل الإجرائي',
              'العمليات والإجراءات والنماذج المستخدمة في المدرسة.',
              Icons.format_list_numbered,
              Colors.indigo,
              [
                'إجراءات القبول والتسجيل',
                'إجراءات الاختبارات',
                'إجراءات الأمن والسلامة',
                'إجراءات الصيانة والنقل المدرسي',
              ],
            ),
            SizedBox(height: 24.h),
            _buildGuideSection(
              context,
              'التعاميم واللوائح',
              'أحدث التعاميم واللوائح الصادرة من وزارة التعليم.',
              Icons.campaign,
              Colors.orange,
              [
                'لائحة تقويم الطالب',
                'قواعد السلوك والمواظبة',
                'دليل الصحة المدرسية',
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideSection(
    BuildContext context,
    String title,
    String description,
    IconData icon,
    Color color,
    List<String> items,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(16.w),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.black26)),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 28.sp),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18.sp,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (context, index) =>
                Divider(height: 1, color: Colors.grey[200]),
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(
                  items[index],
                  style: TextStyle(fontSize: 14.sp, color: Colors.black87),
                ),
                trailing: Icon(
                  Icons.arrow_forward_ios,
                  size: 14.sp,
                  color: Colors.grey,
                ),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('سيتم عرض "${items[index]}" قريباً'),
                    ),
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}
