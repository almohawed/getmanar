import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'inbox_dashboard_screen.dart';

class SimpleInboxScreen extends StatelessWidget {
  final String schoolId;
  final String userId;
  final String userName;

  const SimpleInboxScreen({
    super.key,
    required this.schoolId,
    required this.userId,
    required this.userName,
  });

  @override
  Widget build(BuildContext context) {
    return InboxDashboardScreen(
      schoolId: schoolId,
      userId: userId,
      userName: userName,
    );
  }
}
