import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../../../../core/utils/motivational_quotes.dart';

class WelcomeBanner extends StatefulWidget {
  final String userName;
  final Widget? trailing;
  final Gradient? gradient;

  const WelcomeBanner({super.key, required this.userName, this.trailing, this.gradient});

  @override
  State<WelcomeBanner> createState() => _WelcomeBannerState();
}

class _WelcomeBannerState extends State<WelcomeBanner> {
  late String _quote;

  @override
  void initState() {
    super.initState();
    _quote = MotivationalQuotes.getRandomQuote();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: widget.gradient ??
            LinearGradient(
              colors: [Colors.indigo.shade800, Colors.indigo.shade500],
              begin: Alignment.centerRight,
              end: Alignment.centerLeft,
            ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24.r,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            child: Icon(Icons.waving_hand, color: Colors.white, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'أهلاً بك، ${widget.userName}',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  _quote,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 14.sp,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          if (widget.trailing != null) ...[
            SizedBox(width: 8.w),
            widget.trailing!,
          ],
        ],
      ),
    );
  }
}
