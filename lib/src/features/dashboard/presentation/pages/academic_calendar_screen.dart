import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart' as intl;

class AcademicCalendarScreen extends StatelessWidget {
  const AcademicCalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Saudi Academic Calendar 1446 (2024-2025)
    // Source: Ministry of Education (Approximate dates for example)
    final events = [
      _CalendarEvent(
        title: 'بداية الفصل الدراسي الأول',
        date: DateTime(2024, 8, 18),
        type: _EventType.termStart,
      ),
      _CalendarEvent(
        title: 'إجازة اليوم الوطني',
        date: DateTime(2024, 9, 22),
        type: _EventType.holiday,
      ),
      _CalendarEvent(
        title: 'إجازة مطولة',
        date: DateTime(2024, 10, 17),
        type: _EventType.holiday,
      ),
      _CalendarEvent(
        title: 'نهاية الفصل الدراسي الأول',
        date: DateTime(2024, 11, 7),
        type: _EventType.termEnd,
      ),
      _CalendarEvent(
        title: 'بداية الفصل الدراسي الثاني',
        date: DateTime(2024, 11, 17),
        type: _EventType.termStart,
      ),
      _CalendarEvent(
        title: 'إجازة منتصف العام الدراسي',
        date: DateTime(2025, 1, 3),
        type: _EventType.holiday,
      ),
      _CalendarEvent(
        title: 'نهاية الفصل الدراسي الثاني',
        date: DateTime(2025, 2, 20),
        type: _EventType.termEnd,
      ),
      _CalendarEvent(
        title: 'بداية الفصل الدراسي الثالث',
        date: DateTime(2025, 3, 2),
        type: _EventType.termStart,
      ),
      _CalendarEvent(
        title: 'إجازة عيد الفطر',
        date: DateTime(2025, 3, 20),
        type: _EventType.holiday,
      ),
      _CalendarEvent(
        title: 'إجازة مطولة',
        date: DateTime(2025, 5, 4),
        type: _EventType.holiday,
      ),
      _CalendarEvent(
        title: 'بداية إجازة نهاية العام الدراسي',
        date: DateTime(2025, 6, 26),
        type: _EventType.termEnd,
      ),
    ];

    events.sort((a, b) => a.date.compareTo(b.date));

    return Scaffold(
      appBar: AppBar(
        title: const Text('التقويم الدراسي 1446'),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: EdgeInsets.all(16.w),
        itemCount: events.length,
        itemBuilder: (context, index) {
          final event = events[index];
          final isPast = event.date.isBefore(DateTime.now());
          
          return Card(
            margin: EdgeInsets.only(bottom: 12.h),
            elevation: isPast ? 1 : 3,
            color: isPast ? Colors.grey.shade100 : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: isPast ? BorderSide.none : BorderSide(color: event.color.withValues(alpha: 0.5)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isPast ? Colors.grey : event.color,
                child: Icon(event.icon, color: Colors.white),
              ),
              title: Text(
                event.title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: isPast ? Colors.grey : Colors.black87,
                  decoration: isPast ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Text(
                intl.DateFormat('EEEE, d MMMM yyyy', 'ar').format(event.date),
                style: TextStyle(
                  color: isPast ? Colors.grey : Colors.black54,
                ),
              ),
              trailing: isPast
                  ? const Icon(Icons.check_circle, color: Colors.green)
                  : null,
            ),
          );
        },
      ),
    );
  }
}

enum _EventType { termStart, termEnd, holiday }

class _CalendarEvent {
  final String title;
  final DateTime date;
  final _EventType type;

  _CalendarEvent({
    required this.title,
    required this.date,
    required this.type,
  });

  Color get color {
    switch (type) {
      case _EventType.termStart:
        return Colors.green;
      case _EventType.termEnd:
        return Colors.orange;
      case _EventType.holiday:
        return Colors.red;
    }
  }

  IconData get icon {
    switch (type) {
      case _EventType.termStart:
        return Icons.school;
      case _EventType.termEnd:
        return Icons.done_all;
      case _EventType.holiday:
        return Icons.celebration;
    }
  }
}
