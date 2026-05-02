import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# The _printWaitSchedule was replaced by _openPrintPage
# But the button still calls _printWaitSchedule
# We need to add back _printWaitSchedule that calls _openPrintPage

# Find where _openPrintPage is defined and add _printWaitSchedule before it
old_open = "Future<void> _openPrintPage(String htmlContent) async {"
new_open = (
    "void _printWaitSchedule(\n"
    "    Map<String, Map<int, _Slot>> schedule,\n"
    "    List<String> days,\n"
    "    int periods,\n"
    "    String schoolName) {\n"
    "  final byTeacher = <String, List<Map<String, dynamic>>>{};\n"
    "  for (final day in days) {\n"
    "    final daySlots = schedule[day] ?? {};\n"
    "    for (int p = 1; p <= periods; p++) {\n"
    "      final slot = daySlots[p];\n"
    "      if (slot == null) continue;\n"
    "      for (int i = 0; i < slot.teacherIds.length; i++) {\n"
    "        final name = i < slot.teacherNames.length ? slot.teacherNames[i] : '';\n"
    "        if (name.isEmpty) continue;\n"
    "        byTeacher.putIfAbsent(name, () => []);\n"
    "        byTeacher[name]!.add({'day': day, 'period': p, 'waitNum': i + 1});\n"
    "      }\n"
    "    }\n"
    "  }\n"
    "  if (byTeacher.isEmpty) return;\n"
    "  final now = DateTime.now();\n"
    "  final dateStr = '${now.day}/${now.month}/${now.year}';\n"
    "  final dayOrder = ['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس'];\n"
    "  final rows = byTeacher.entries.map((entry) {\n"
    "    final teacher = entry.key;\n"
    "    final slots = entry.value\n"
    "      ..sort((a, b) {\n"
    "        final dc = dayOrder.indexOf(a['day']).compareTo(dayOrder.indexOf(b['day']));\n"
    "        if (dc != 0) return dc;\n"
    "        return (a['period'] as int).compareTo(b['period'] as int);\n"
    "      });\n"
    "    final trs = slots.map((s) =>\n"
    "      '<tr><td>${s[\"period\"]}</td><td>${s[\"day\"]}</td>'\n"
    "      '<td>منتظر ${s[\"waitNum\"]}</td><td></td><td></td></tr>'\n"
    "    ).join();\n"
    "    return '<div class=\"tb\"><h3>المعلم: $teacher</h3>'\n"
    "      '<table><tr><th>الحصة</th><th>اليوم</th><th>نوع الانتظار</th><th>التوقيع</th><th>ملاحظات</th></tr>'\n"
    "      '$trs</table><p class=\"sig\">توقيع المدير: _______________</p></div>';\n"
    "  }).join();\n"
    "  final html = '<!DOCTYPE html><html dir=\"rtl\"><head><meta charset=\"UTF-8\">'\n"
    "    '<title>جدول الانتظار</title><style>'\n"
    "    'body{font-family:Arial;margin:20px;direction:rtl;}'\n"
    "    'h1{text-align:center;color:#1a237e;border-bottom:2px solid #1a237e;padding-bottom:8px;}'\n"
    "    '.meta{text-align:center;color:#555;margin-bottom:20px;}'\n"
    "    '.tb{page-break-after:always;margin-bottom:30px;}'\n"
    "    'h3{color:#1a237e;background:#e8eaf6;padding:8px 12px;border-radius:6px;}'\n"
    "    'table{width:100%;border-collapse:collapse;margin-top:10px;}'\n"
    "    'th{background:#1a237e;color:white;padding:8px;border:1px solid #999;}'\n"
    "    'td{padding:8px;border:1px solid #ccc;text-align:center;}'\n"
    "    'tr:nth-child(even){background:#f5f5f5;}'\n"
    "    '.sig{margin-top:20px;text-align:left;}'\n"
    "    '@media print{.tb{page-break-after:always;}}'\n"
    "    '</style></head><body>'\n"
    "    '<h1>جدول الانتظار — $schoolName</h1>'\n"
    "    '<p class=\"meta\">تاريخ الطباعة: $dateStr</p>'\n"
    "    '$rows</body></html>';\n"
    "  _openPrintPage(html);\n"
    "}\n\n"
    "Future<void> _openPrintPage(String htmlContent) async {"
)

if old_open in c:
    c = c.replace(old_open, new_open)
    print("Added _printWaitSchedule")
else:
    print("Could not find _openPrintPage")

p.write_text(c, encoding='utf-8')
print("Done")
