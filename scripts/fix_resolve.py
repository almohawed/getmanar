import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Find the _resolveSubject function and add special cases at the top
old_start = (
    "  // مطابقة المواد — سلسلة if-else مباشرة لتجنب tree shaking\n"
    "  String _resolveSubject(String raw) {\n"
    "    final s = raw.trim();\n"
    "    if (s.isEmpty || s.length <= 1) return '';\n"
    "    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||\n"
    "        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) return '';"
)

new_start = (
    "  // مطابقة المواد — سلسلة if-else مباشرة لتجنب tree shaking\n"
    "  String _resolveSubject(String raw) {\n"
    "    final s = raw.trim();\n"
    "    if (s.isEmpty || s.length <= 1) return '';\n"
    "    if (s.startsWith('=') || s.contains('COUNTIF') || s.contains('COUNTA') ||\n"
    "        s.contains('SUM(') || s.contains('IF(') || s.contains('VLOOKUP')) return '';\n"
    "    // حصص الانتظار والنشاط — تُقبل كما هي\n"
    "    if (s.contains('منتظر') || s.contains('انتظار') || s.contains('نوبة') ||\n"
    "        s.contains('نوبه') || s.contains('مراقبة') || s.contains('مراقبه')) return s;\n"
    "    if (s == 'نشاط' || s.contains('نشاط')) return 'نشاط';"
)

if old_start in c:
    c = c.replace(old_start, new_start)
    print("Fixed _resolveSubject with special cases")
else:
    print("Pattern not found, trying partial...")
    idx = c.find("if (s.startsWith('=') || s.contains('COUNTIF')")
    if idx != -1:
        print(f"Found at {idx}")
        print(repr(c[max(0,idx-200):idx+100]))

p.write_text(c, encoding='utf-8')
print("Done")
