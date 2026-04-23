import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class MyScheduleScreen extends ConsumerWidget {
  final String userId;
  final String userType; // 'student', 'teacher', 'parent'
  final String schoolId;

  const MyScheduleScreen({
    super.key,
    required this.userId,
    required this.userType,
    required this.schoolId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('جدولي', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Color(0xFF6366F1),
        elevation: 0,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: _getScheduleStream(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data?.data() == null) {
            return _buildEmptyState();
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final schedule = List<Map<String, dynamic>>.from(data['schedule'] ?? []);

          if (schedule.isEmpty) {
            return _buildEmptyState();
          }

          return _buildScheduleView(schedule);
        },
      ),
    );
  }

  Stream<DocumentSnapshot> _getScheduleStream() {
    if (userType == 'student') {
      return FirebaseFirestore.instance
          .doc('Schools/$schoolId/Students/$userId')
          .snapshots();
    } else if (userType == 'teacher') {
      return FirebaseFirestore.instance
          .doc('Schools/$schoolId/Teachers/$userId')
          .snapshots();
    } else {
      // parent - get first child's schedule
      return FirebaseFirestore.instance
          .collection('Schools/$schoolId/Students')
          .where('parentId', isEqualTo: userId)
          .limit(1)
          .snapshots()
          .map((snap) => snap.docs.first);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_today_outlined,
            size: 80,
            color: Color(0xFF6366F1).withOpacity(0.5),
          ),
          SizedBox(height: 24),
          Text(
            'لا يوجد جدول حالياً',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 12),
          Text(
            'سيتم إضافة الجدول قريباً',
            style: TextStyle(fontSize: 16, color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleView(List<Map<String, dynamic>> schedule) {
    final days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildWelcomeCard(),
          SizedBox(height: 16),
          ...days.map((day) => _buildDaySchedule(day, schedule)),
        ],
      ),
    );
  }

  Widget _buildWelcomeCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF6366F1).withOpacity(0.3),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_month, size: 40, color: Colors.white),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'جدولك الأسبوعي',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'تم التحديث اليوم',
                  style: TextStyle(fontSize: 14, color: Colors.white70),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySchedule(String day, List<Map<String, dynamic>> schedule) {
    final dayLessons = schedule.where((l) => l['day'] == day).toList();
    dayLessons.sort((a, b) => (a['period'] as int).compareTo(b['period'] as int));

    if (dayLessons.isEmpty) return SizedBox.shrink();

    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Color(0xFF6366F1).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.today, color: Color(0xFF6366F1)),
                ),
                SizedBox(width: 12),
                Text(
                  day,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Color(0xFF10B981).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${dayLessons.length} حصة',
                    style: TextStyle(
                      color: Color(0xFF10B981),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            ...dayLessons.map((lesson) => _buildLessonCard(lesson)),
          ],
        ),
      ),
    );
  }

  Widget _buildLessonCard(Map<String, dynamic> lesson) {
    final color = Color(lesson['color'] ?? 0xFF6366F1);
    
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                '${lesson['period']}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lesson['subject'] ?? 'مادة',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person, size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 4),
                    Text(
                      lesson['teacherName'] ?? 'معلم',
                      style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                    ),
                    if (userType == 'teacher' && lesson['className'] != null) ...[
                      SizedBox(width: 12),
                      Icon(Icons.class_, size: 16, color: Color(0xFF64748B)),
                      SizedBox(width: 4),
                      Text(
                        lesson['className'],
                        style: TextStyle(fontSize: 14, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: color),
        ],
      ),
    );
  }
}
