import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/models/counselor_session.dart';
import '../../auth/presentation/auth_controller.dart';

/// Provider لجلسات الشهر
final monthSessionsProvider = StreamProvider.autoDispose.family<List<CounselorSession>, DateTime>((ref, month) {
  final user = ref.watch(authStateProvider).value;
  final schoolId = user?.schoolId;
  
  if (user == null || schoolId == null || schoolId.isEmpty) {
    return Stream.value([]);
  }

  final startOfMonth = DateTime(month.year, month.month, 1);
  final endOfMonth = DateTime(month.year, month.month + 1, 0, 23, 59, 59);

  return FirebaseFirestore.instance
      .collection('counseling_sessions')
      .where('schoolId', isEqualTo: schoolId)
      .snapshots()
      .map((snapshot) {
    // فلترة وترتيب البيانات في الذاكرة
    final sessions = snapshot.docs
        .map((doc) => CounselorSession.fromMap(doc.data(), doc.id))
        .where((session) => 
            session.scheduledAt.isAfter(startOfMonth.subtract(const Duration(days: 1))) &&
            session.scheduledAt.isBefore(endOfMonth.add(const Duration(days: 1))))
        .toList();
    
    // ترتيب حسب التاريخ
    sessions.sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    
    return sessions;
  });
});

/// شاشة جدول الجلسات - تصميم احترافي مع تقويم
class SessionsCalendarScreen extends ConsumerStatefulWidget {
  const SessionsCalendarScreen({super.key});

  @override
  ConsumerState<SessionsCalendarScreen> createState() => _SessionsCalendarScreenState();
}

class _SessionsCalendarScreenState extends ConsumerState<SessionsCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  @override
  Widget build(BuildContext context) {
    final sessionsAsync = ref.watch(monthSessionsProvider(_focusedDay));

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'جدول الجلسات',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.blue.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/add-counseling-session'),
            tooltip: 'إضافة جلسة جديدة',
          ),
        ],
      ),
      body: sessionsAsync.when(
        data: (sessions) {
          final selectedDaySessions = _getSessionsForDay(_selectedDay, sessions);
          
          return Column(
            children: [
              _buildCalendar(sessions),
              SizedBox(height: 16.h),
              _buildSelectedDayHeader(),
              Expanded(
                child: selectedDaySessions.isEmpty
                    ? _buildEmptyDayState()
                    : _buildSessionsList(selectedDaySessions),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => _buildErrorState(error.toString()),
      ),
    );
  }

  Widget _buildCalendar(List<CounselorSession> sessions) {
    return Container(
      margin: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2030, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        calendarFormat: _calendarFormat,
        startingDayOfWeek: StartingDayOfWeek.saturday,
        locale: 'ar',
        headerStyle: HeaderStyle(
          formatButtonVisible: true,
          titleCentered: true,
          formatButtonShowsNext: false,
          formatButtonDecoration: BoxDecoration(
            color: Colors.blue.shade100,
            borderRadius: BorderRadius.circular(8.r),
          ),
          formatButtonTextStyle: TextStyle(
            color: Colors.blue.shade700,
            fontWeight: FontWeight.bold,
          ),
          titleTextStyle: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: Colors.blue.shade700,
          ),
        ),
        calendarStyle: CalendarStyle(
          todayDecoration: BoxDecoration(
            color: Colors.blue.shade300,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: Colors.blue.shade700,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(
            color: Colors.orange.shade600,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
        eventLoader: (day) => _getSessionsForDay(day, sessions),
        onDaySelected: (selectedDay, focusedDay) {
          setState(() {
            _selectedDay = selectedDay;
            _focusedDay = focusedDay;
          });
        },
        onFormatChanged: (format) {
          setState(() {
            _calendarFormat = format;
          });
        },
        onPageChanged: (focusedDay) {
          setState(() {
            _focusedDay = focusedDay;
          });
        },
      ),
    );
  }

  Widget _buildSelectedDayHeader() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
      margin: EdgeInsets.symmetric(horizontal: 16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade600, Colors.blue.shade400],
        ),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Icon(Icons.calendar_today, color: Colors.white, size: 20.sp),
          SizedBox(width: 8.w),
          Text(
            _selectedDay != null
                ? DateFormat('EEEE، d MMMM yyyy', 'ar').format(_selectedDay!)
                : 'اختر يوماً',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList(List<CounselorSession> sessions) {
    return ListView.builder(
      padding: EdgeInsets.all(16.w),
      itemCount: sessions.length,
      itemBuilder: (context, index) {
        return _buildSessionCard(sessions[index]);
      },
    );
  }

  Widget _buildSessionCard(CounselorSession session) {
    final statusColors = {
      SessionStatus.scheduled: Colors.blue,
      SessionStatus.completed: Colors.green,
      SessionStatus.cancelled: Colors.red,
      SessionStatus.no_show: Colors.orange,
    };
    final statusLabels = {
      SessionStatus.scheduled: 'مجدولة',
      SessionStatus.completed: 'مكتملة',
      SessionStatus.cancelled: 'ملغاة',
      SessionStatus.no_show: 'لم يحضر',
    };

    final color = statusColors[session.status] ?? Colors.grey;
    final statusLabel = statusLabels[session.status] ?? 'غير محدد';

    return Card(
      margin: EdgeInsets.only(bottom: 12.h),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(color: color.shade200, width: 2),
      ),
      child: InkWell(
        onTap: () {
          // فتح تفاصيل الجلسة
          context.push('/counseling-session/${session.id}');
        },
        borderRadius: BorderRadius.circular(12.r),
        child: Padding(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10.w),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.shade400, color.shade600],
                      ),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.event_note,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.title,
                          style: TextStyle(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade900,
                          ),
                        ),
                        SizedBox(height: 4.h),
                        Row(
                          children: [
                            Icon(Icons.access_time, size: 14.sp, color: Colors.grey.shade600),
                            SizedBox(width: 4.w),
                            Text(
                              DateFormat('HH:mm').format(session.scheduledAt),
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            SizedBox(width: 12.w),
                            Icon(Icons.timer, size: 14.sp, color: Colors.grey.shade600),
                            SizedBox(width: 4.w),
                            Text(
                              '${session.durationMinutes} دقيقة',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.shade400, color.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20.r),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 11.sp,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              if (session.description != null && session.description!.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Text(
                  session.description!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey.shade700,
                    height: 1.4,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (session.attendeeIds.isNotEmpty) ...[
                SizedBox(height: 12.h),
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.people, size: 16.sp, color: Colors.blue.shade700),
                      SizedBox(width: 6.w),
                      Text(
                        '${session.attendeeIds.length} طالب',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyDayState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 80.sp,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'لا توجد جلسات في هذا اليوم',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'اختر يوماً آخر أو أضف جلسة جديدة',
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 80.sp,
            color: Colors.red.shade300,
          ),
          SizedBox(height: 16.h),
          Text(
            'حدث خطأ',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.red.shade600,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            error,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey.shade600,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 24.h),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(monthSessionsProvider(_focusedDay)),
            icon: const Icon(Icons.refresh),
            label: const Text('إعادة المحاولة'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade600,
            ),
          ),
        ],
      ),
    );
  }

  List<CounselorSession> _getSessionsForDay(DateTime? day, List<CounselorSession> sessions) {
    if (day == null) return [];
    return sessions.where((session) {
      return isSameDay(session.scheduledAt, day);
    }).toList();
  }
}
