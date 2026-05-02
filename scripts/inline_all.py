import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace the entire _analyzeFile subject matching section
# Find the line that adds to lessons
old_add = (
    "          rawSubjects.add(subject);\n"
    "          final dayName = info['day'] as String;\n"
    "          final dayIndex = _days.indexOf(dayName);\n"
    "          lessons.add(ImportedLesson(teacherName: teacherName, rawSubject: subject,\n"
    "            matchResult: _buildMatchResult(subject), className: className,\n"
    "            dayName: dayName, dayIndex: dayIndex >= 0 ? dayIndex : 0, period: info['period'] as int));"
)
new_add = (
    "          rawSubjects.add(subject);\n"
    "          final dayName = info['day'] as String;\n"
    "          final dayIndex = _days.indexOf(dayName);\n"
    "          // مطابقة المادة مباشرة\n"
    "          final matchedSubject = _resolveSubject(subject);\n"
    "          final mr = matchedSubject.isNotEmpty\n"
    "              ? SubjectMatchResult(\n"
    "                  rawName: subject,\n"
    "                  matched: SubjectMaster(id: matchedSubject, officialName: matchedSubject, category: matchedSubject),\n"
    "                  confidence: MatchConfidence.high)\n"
    "              : SubjectMatchResult(rawName: subject, confidence: MatchConfidence.unknown);\n"
    "          lessons.add(ImportedLesson(teacherName: teacherName, rawSubject: subject,\n"
    "            matchResult: mr, className: className,\n"
    "            dayName: dayName, dayIndex: dayIndex >= 0 ? dayIndex : 0, period: info['period'] as int));"
)
c = c.replace(old_add, new_add)

# Replace _knownCount/_unknownCount
old_counts = (
    "      _knownCount = rawSubjects.where((s) => _isKnownSubject(s)).length;\n"
    "      _unknownCount = rawSubjects.where((s) => !_isKnownSubject(s)).length;"
)
new_counts = (
    "      _knownCount = rawSubjects.where((s) => _resolveSubject(s).isNotEmpty).length;\n"
    "      _unknownCount = rawSubjects.where((s) => _resolveSubject(s).isEmpty).length;"
)
c = c.replace(old_counts, new_counts)

# Replace reviewSubjects
old_review = "      final reviewSubjects = rawSubjects.where((s) => !_isKnownSubject(s)).toSet();"
new_review = "      final reviewSubjects = rawSubjects.where((s) => _resolveSubject(s).isEmpty).toSet();"
c = c.replace(old_review, new_review)

# Replace _subjectRow call
old_row_call = "        ..._subjectStats.entries.map((e) => _subjectRow(e.key, _matchSubject(e.key), e.value)),"
new_row_call = "        ..._subjectStats.entries.map((e) => _subjectRow(e.key, _resolveSubject(e.key), e.value)),"
c = c.replace(old_row_call, new_row_call)

# Add _resolveSubject as a simple if-else chain (not a map, not a method call)
# This will NOT be tree-shaken because it's a direct string comparison
resolve_fn = """
  // مطابقة المواد — سلسلة if-else مباشرة لتجنب tree shaking
  String _resolveSubject(String raw) {
    final s = raw.trim();
    if (s.isEmpty || s.length <= 1) return '';
    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||
        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) return '';
    final n = s.replaceAll(RegExp(r'[\\u064B-\\u0652]'), '')
        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي').replaceAll('ة', 'ه')
        .replaceAll('ؤ', 'و').replaceAll('ئ', 'ي').trim().toLowerCase();
    if (n.isEmpty) return '';
    // عربي
    if (n == 'عربي' || n == 'لغتي' || n == 'لغه عربيه' || n == 'لغة عربية' ||
        n == 'اللغه العربيه' || n == 'اللغة العربية' || n == 'لغتي الخالده' ||
        n == 'الكفايات اللغويه' || n == 'كفايات لغويه') return 'اللغة العربية';
    // رياضيات
    if (n == 'رياضيات' || n == 'الرياضيات' || n == 'حساب' || n == 'رياضه' ||
        n == 'رياضيه') return 'الرياضيات';
    // علوم
    if (n == 'علوم' || n == 'العلوم' || n == 'علوم طبيعيه' || n == 'احياء' ||
        n == 'فيزياء' || n == 'كيمياء') return 'العلوم';
    // انجليزي
    if (n == 'انجليزي' || n == 'إنجليزي' || n == 'انجليزيه' || n == 'إنجليزيه' ||
        n == 'اللغه الإنجليزيه' || n == 'لغه انجليزيه' || n == 'انجليش') return 'اللغة الإنجليزية';
    // اسلامية
    if (n == 'اسلاميه' || n == 'إسلاميه' || n == 'تربيه اسلاميه' ||
        n == 'دراسات اسلاميه' || n == 'الدراسات الإسلاميه') return 'التربية الإسلامية';
    // قرآن
    if (n == 'قران' || n == 'تحفيظ' || n == 'القران الكريم' || n == 'تلاوه') return 'القرآن الكريم';
    // اجتماعيات
    if (n == 'اجتماعيات' || n == 'الاجتماعيات' || n == 'دراسات اجتماعيه' ||
        n == 'إجتماعيات') return 'الاجتماعيات';
    // رقمية
    if (n == 'حاسب' || n == 'حاسوب' || n == 'تقنيه رقميه' || n == 'الرقميه' ||
        n == 'رقميه' || n == 'حاسب الي') return 'التقنية الرقمية';
    // بدنية
    if (n == 'بدنيه' || n == 'تربيه بدنيه' || n == 'رياضه' || n == 'رياضيه') return 'التربية البدنية';
    // فنية
    if (n == 'فنيه' || n == 'تربيه فنيه' || n == 'رسم' || n == 'فنون') return 'التربية الفنية';
    // مهارات الحياة — هذا هو الأهم
    if (n == 'حياتيه' || n == 'حياتيه' || n == 'مهارات حياتيه' ||
        n == 'مهارات الحياه' || n == 'مهارات' || n == 'مهاره' ||
        n == 'تنميه مهارات') return 'مهارات الحياة';
    // برايل
    if (n == 'برايل' || n == 'لغه برايل') return 'برايل';
    // بحث جزئي
    if (n.contains('عرب') || n.contains('لغتي')) return 'اللغة العربية';
    if (n.contains('رياضيات')) return 'الرياضيات';
    if (n.contains('علوم')) return 'العلوم';
    if (n.contains('انجليز') || n.contains('إنجليز')) return 'اللغة الإنجليزية';
    if (n.contains('اسلام') || n.contains('إسلام')) return 'التربية الإسلامية';
    if (n.contains('قران') || n.contains('تحفيظ')) return 'القرآن الكريم';
    if (n.contains('اجتماع')) return 'الاجتماعيات';
    if (n.contains('حاسب') || n.contains('رقمي')) return 'التقنية الرقمية';
    if (n.contains('بدني')) return 'التربية البدنية';
    if (n.contains('فني') || n.contains('رسم')) return 'التربية الفنية';
    if (n.contains('حياتي') || n.contains('مهارات')) return 'مهارات الحياة';
    if (n.contains('برايل')) return 'برايل';
    return '';
  }

"""

# Insert before _buildMatchResult or before _buildUpload
insert_before = "  // ─── Upload Step"
if insert_before in c:
    c = c.replace(insert_before, resolve_fn + "  // ─── Upload Step")
    print("Inserted _resolveSubject before Upload Step")
else:
    # Try another location
    insert_before2 = "  Widget _buildUpload()"
    if insert_before2 in c:
        c = c.replace(insert_before2, resolve_fn + "  Widget _buildUpload()")
        print("Inserted _resolveSubject before _buildUpload")
    else:
        print("Could not find insertion point")

p.write_text(c, encoding='utf-8')
print("Done")
