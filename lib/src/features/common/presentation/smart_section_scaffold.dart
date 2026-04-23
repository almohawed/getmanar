import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:animate_do/animate_do.dart';

class SmartSectionScaffold extends StatefulWidget {
  final String title;
  final Widget body;
  final List<Widget>? actions;
  final Color themeColor;
  final IconData icon;
  final String? initialRecommendation;
  final Widget? floatingActionButton;

  const SmartSectionScaffold({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.themeColor = Colors.indigo,
    required this.icon,
    this.initialRecommendation,
    this.floatingActionButton,
  });

  @override
  State<SmartSectionScaffold> createState() => _SmartSectionScaffoldState();
}

class _SmartSectionScaffoldState extends State<SmartSectionScaffold> {
  bool _showRecommendation = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20.sp),
        ),
        centerTitle: true,
        backgroundColor: widget.themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: widget.actions,
      ),
      floatingActionButton: widget.floatingActionButton,
      body: Column(
        children: [
          // Smart Header / Recommendation Banner
          if (_showRecommendation)
            FadeInDown(
              duration: const Duration(milliseconds: 600),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(16.w),
                decoration: BoxDecoration(
                  color: widget.themeColor.withOpacity(0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: widget.themeColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8.w),
                          decoration: BoxDecoration(
                            color: widget.themeColor.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.auto_awesome,
                            color: widget.themeColor,
                            size: 20.sp,
                          ),
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'التحليل الذكي للنظام',
                                style: TextStyle(
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.bold,
                                  color: widget.themeColor,
                                ),
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                widget.initialRecommendation ??
                                    'يقوم النظام بتحليل البيانات الحالية لتقديم توصيات فورية...',
                                style: TextStyle(
                                  fontSize: 13.sp,
                                  color: Colors.grey.shade800,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close, size: 18.sp),
                          onPressed: () =>
                              setState(() => _showRecommendation = false),
                        ),
                      ],
                    ),
                    SizedBox(height: 12.h),
                    // Simulated "Action" Button based on context
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          // TODO: Implement smart action
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('جاري تنفيذ التوصية الذكية...'),
                            ),
                          );
                        },
                        icon: Icon(Icons.flash_on, size: 16.sp),
                        label: const Text('تنفيذ الحل المقترح'),
                        style: TextButton.styleFrom(
                          foregroundColor: widget.themeColor,
                          backgroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 16.w,
                            vertical: 8.h,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: widget.themeColor),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Main Body
          Expanded(child: widget.body),
        ],
      ),
    );
  }
}
