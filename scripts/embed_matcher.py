import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace the SubjectMatcher.match call with inline matching
# First, add a local _matchSubject function after the class declaration

# Find where to insert the helper function - after the _days declaration
old_days = "  final List<String> _days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس'];"

new_days = (
    "  final List<String> _days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس'];\n"
    "\n"
    "  // ─── مطابقة المواد المدمجة مباشرة ────────────────────────────────────────\n"
    "  static const Map<String, String> _subjectAliases = {\n"
    "    // عربي\n"
    "    'عربي': 'اللغة العربية', 'لغتي': 'اللغة العربية', 'لغة عربية': 'اللغة العربية',\n"
    "    'اللغة العربية': 'اللغة العربية', 'لغتي الخالدة': 'اللغة العربية',\n"
    "    'الكفايات اللغوية': 'اللغة العربية', 'كفايات لغوية': 'اللغة العربية',\n"
    "    // رياضيات\n"
    "    'رياضيات': 'الرياضيات', 'الرياضيات': 'الرياضيات', 'حساب': 'الرياضيات',\n"
    "    // علوم\n"
    "    'علوم': 'العلوم', 'العلوم': 'العلوم', 'علوم طبيعية': 'العلوم',\n"
    "    'احياء': 'العلوم', 'فيزياء': 'العلوم', 'كيمياء': 'العلوم',\n"
    "    // انجليزي\n"
    "    'انجليزي': 'اللغة الإنجليزية', 'إنجليزي': 'اللغة الإنجليزية',\n"
    "    'اللغة الإنجليزية': 'اللغة الإنجليزية', 'لغة انجليزية': 'اللغة الإنجليزية',\n"
    "    'انجليزية': 'اللغة الإنجليزية', 'إنجليزية': 'اللغة الإنجليزية',\n"
    "    // اسلامية\n"
    "    'اسلامية': 'التربية الإسلامية', 'إسلامية': 'التربية الإسلامية',\n"
    "    'تربية اسلامية': 'التربية الإسلامية', 'تربية إسلامية': 'التربية الإسلامية',\n"
    "    'دراسات اسلامية': 'التربية الإسلامية', 'الدراسات الإسلامية': 'التربية الإسلامية',\n"
    "    // قرآن\n"
    "    'قرآن': 'القرآن الكريم', 'قران': 'القرآن الكريم', 'تحفيظ': 'القرآن الكريم',\n"
    "    'القرآن الكريم': 'القرآن الكريم', 'تحفيظ قرآن': 'القرآن الكريم',\n"
    "    // اجتماعيات\n"
    "    'اجتماعيات': 'الاجتماعيات', 'الاجتماعيات': 'الاجتماعيات',\n"
    "    'دراسات اجتماعية': 'الاجتماعيات', 'إجتماعيات': 'الاجتماعيات',\n"
    "    // رقمية\n"
    "    'حاسب': 'التقنية الرقمية', 'حاسوب': 'التقنية الرقمية',\n"
    "    'تقنية رقمية': 'التقنية الرقمية', 'الرقمية': 'التقنية الرقمية',\n"
    "    'رقمية': 'التقنية الرقمية', 'حاسب آلي': 'التقنية الرقمية',\n"
    "    // بدنية\n"
    "    'بدنية': 'التربية البدنية', 'تربية بدنية': 'التربية البدنية',\n"
    "    'رياضة': 'التربية البدنية', 'رياضية': 'التربية البدنية',\n"
    "    // فنية\n"
    "    'فنية': 'التربية الفنية', 'تربية فنية': 'التربية الفنية',\n"
    "    'رسم': 'التربية الفنية', 'فنون': 'التربية الفنية',\n"
    "    // مهارات الحياة\n"
    "    'حياتية': 'مهارات الحياة', 'حياتيه': 'مهارات الحياة',\n"
    "    'مهارات حياتية': 'مهارات الحياة', 'مهارات حياتيه': 'مهارات الحياة',\n"
    "    'مهارات الحياة': 'مهارات الحياة', 'مهارات': 'مهارات الحياة',\n"
    "    'مهارات حياه': 'مهارات الحياة', 'تنمية مهارات': 'مهارات الحياة',\n"
    "    // برايل\n"
    "    'برايل': 'برايل', 'لغة برايل': 'برايل',\n"
    "  };\n"
    "\n"
    "  String _normalizeForMatch(String s) {\n"
    "    var v = s.trim().toLowerCase();\n"
    "    v = v.replaceAll(RegExp(r'[\\u064B-\\u0652]'), '')\n"
    "        .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')\n"
    "        .replaceAll('ى', 'ي').replaceAll('ة', 'ه')\n"
    "        .replaceAll('ؤ', 'و').replaceAll('ئ', 'ي');\n"
    "    return v.trim();\n"
    "  }\n"
    "\n"
    "  String _matchSubject(String raw) {\n"
    "    final s = raw.trim();\n"
    "    if (s.isEmpty || s.length <= 1) return '';\n"
    "    // تجاهل صيغ Excel\n"
    "    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||\n"
    "        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) return '';\n"
    "    // تجاهل أرقام بحتة\n"
    "    if (RegExp(r'^[\\d\\s\\.\\,]+\$').hasMatch(s)) return '';\n"
    "    // بحث مباشر\n"
    "    final normalized = _normalizeForMatch(s);\n"
    "    for (final entry in _subjectAliases.entries) {\n"
    "      if (_normalizeForMatch(entry.key) == normalized) return entry.value;\n"
    "    }\n"
    "    // بحث جزئي\n"
    "    for (final entry in _subjectAliases.entries) {\n"
    "      final nk = _normalizeForMatch(entry.key);\n"
    "      if (nk.length >= 3 && normalized.contains(nk)) return entry.value;\n"
    "      if (normalized.length >= 3 && nk.contains(normalized)) return entry.value;\n"
    "    }\n"
    "    return ''; // غير معروف\n"
    "  }\n"
    "\n"
    "  bool _isKnownSubject(String raw) => _matchSubject(raw).isNotEmpty;\n"
)

if old_days in c:
    c = c.replace(old_days, new_days)
    print("Added inline matcher")
else:
    print("Could not find _days declaration")
    idx = c.find("_days")
    print(f"_days at index: {idx}")

p.write_text(c, encoding='utf-8')
print("Done")
