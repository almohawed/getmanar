/// Maps Arabic day names to their index (0-4)
class DayIndexMapper {
  static const Map<String, int> arabicDayMap = {
    'الأحد': 0,
    'الاثنين': 1,
    'الثلاثاء': 2,
    'الأربعاء': 3,
    'الخميس': 4,
  };

  /// Get day index from Arabic day name
  static int getDayIndex(String? dayName) {
    if (dayName == null || dayName.isEmpty) return -1;
    return arabicDayMap[dayName] ?? -1;
  }

  /// Get Arabic day name from index
  static String getDayName(int dayIndex) {
    const days = ['الأحد', 'الاثنين', 'الثلاثاء', 'الأربعاء', 'الخميس'];
    if (dayIndex < 0 || dayIndex >= days.length) return '';
    return days[dayIndex];
  }

  /// Check if day name is valid
  static bool isValidDay(String? dayName) {
    return dayName != null && arabicDayMap.containsKey(dayName);
  }

  /// Normalize lesson data by ensuring dayIndex is set
  static Map<String, dynamic> normalizeLessonData(Map<String, dynamic> lesson) {
    final normalized = Map<String, dynamic>.from(lesson);
    
    // If dayIndex is missing but dayName exists, calculate it
    if ((normalized['dayIndex'] == null || normalized['dayIndex'] == -1) && 
        normalized['day'] != null) {
      normalized['dayIndex'] = getDayIndex(normalized['day']);
    }
    
    return normalized;
  }

  /// Normalize a list of lessons
  static List<Map<String, dynamic>> normalizeLessons(
    List<dynamic> lessons,
  ) {
    return lessons
        .map((lesson) {
          if (lesson is Map<String, dynamic>) {
            return normalizeLessonData(lesson);
          }
          return lesson as Map<String, dynamic>;
        })
        .toList();
  }
}
