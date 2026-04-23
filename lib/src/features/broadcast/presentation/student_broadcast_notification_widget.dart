import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// يُعرض في لوحة الطالب إذا كان مضافاً في الإذاعة هذا الأسبوع
class StudentBroadcastNotificationWidget extends StatelessWidget {
  final String studentId;
  final String schoolId;

  const StudentBroadcastNotificationWidget({
    super.key,
    required this.studentId,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schools')
          .doc(schoolId)
          .collection('Students')
          .doc(studentId)
          .collection('Notifications')
          .where('type', isEqualTo: 'broadcast')
          .where('isRead', isEqualTo: false)
          .orderBy('createdAt', descending: true)
          .limit(1)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink();
        }

        final doc = snapshot.data!.docs.first;
        final data = doc.data() as Map<String, dynamic>;
        final day = data['day'] as String? ?? '';
        final role = data['role'] as String? ?? '';

        return Container(
          margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
          padding: EdgeInsets.all(16.w),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF1A237E), Color(0xFF3949AB)],
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
            ),
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1A237E).withValues(alpha: 0.3),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(10.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.mic, color: Colors.white, size: 24.sp),
              ),
              SizedBox(width: 14.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📢 أنت في الإذاعة المدرسية!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'يوم $day • الدور: $role',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Text(
                      'لا تنسَ الحضور في الوقت المحدد',
                      style: TextStyle(
                        color: Colors.amber.shade200,
                        fontSize: 11.sp,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, color: Colors.white70, size: 18.sp),
                onPressed: () {
                  // Mark as read
                  FirebaseFirestore.instance
                      .collection('Schools')
                      .doc(schoolId)
                      .collection('Students')
                      .doc(studentId)
                      .collection('Notifications')
                      .doc(doc.id)
                      .update({'isRead': true});
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
