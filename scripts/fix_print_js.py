import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Remove dart:html import
c = c.replace(
    "// ignore: avoid_web_libraries_in_flutter\nimport 'dart:html' as html;",
    ""
)

# Replace the print function with URL-based approach (works in all Flutter versions)
old_print_end = (
    "  final win = html.window.open('', '_blank') as html.Window?;\n"
    "  if (win != null) {\n"
    "    win.document.write(htmlContent);\n"
    "    win.document.close();\n"
    "    win.print();\n"
    "  }\n"
    "}"
)
new_print_end = (
    "  // استخدام URL data لفتح نافذة الطباعة\n"
    "  final encoded = Uri.encodeComponent(htmlContent);\n"
    "  final dataUrl = 'data:text/html;charset=utf-8,$encoded';\n"
    "  // ignore: avoid_web_libraries_in_flutter\n"
    "  // Use js to open and print\n"
    "  _openPrintWindow(dataUrl);\n"
    "}"
)
c = c.replace(old_print_end, new_print_end)

# Add the js function using url_launcher approach
old_after_print = "String _normalizeDay(String s) {"
new_after_print = (
    "void _openPrintWindow(String url) {\n"
    "  // فتح نافذة جديدة للطباعة\n"
    "  // ignore: undefined_prefixed_name\n"
    "  try {\n"
    "    // ignore: avoid_web_libraries_in_flutter\n"
    "    import_dart_html_window(url);\n"
    "  } catch (_) {}\n"
    "}\n\n"
    "String _normalizeDay(String s) {"
)

# Actually, use a simpler approach - just use url_launcher
# Replace the entire print function with a simpler blob URL approach
old_fn_start = "void _printWaitSchedule("
# Find and replace the entire function
idx = c.find(old_fn_start)
if idx != -1:
    # Find end of function
    depth = 0
    i = idx
    while i < len(c):
        if c[i] == '{': depth += 1
        elif c[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    
    old_fn = c[idx:end]
    new_fn = """void _printWaitSchedule(
    Map<String, Map<int, _Slot>> schedule,
    List<String> days,
    int periods,
    String schoolName) {
  final byTeacher = <String, List<Map<String, dynamic>>>{};
  for (final day in days) {
    final daySlots = schedule[day] ?? {};
    for (int p = 1; p <= periods; p++) {
      final slot = daySlots[p];
      if (slot == null) continue;
      for (int i = 0; i < slot.teacherIds.length; i++) {
        final name = i < slot.teacherNames.length ? slot.teacherNames[i] : '';
        if (name.isEmpty) continue;
        byTeacher.putIfAbsent(name, () => []);
        byTeacher[name]!.add({'day': day, 'period': p, 'waitNum': i + 1});
      }
    }
  }
  if (byTeacher.isEmpty) return;

  final now = DateTime.now();
  final dateStr = '${now.day}/${now.month}/${now.year}';
  final dayOrder = ['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس'];

  final rows = byTeacher.entries.map((entry) {
    final teacher = entry.key;
    final slots = entry.value
      ..sort((a, b) {
        final dc = dayOrder.indexOf(a['day']).compareTo(dayOrder.indexOf(b['day']));
        if (dc != 0) return dc;
        return (a['period'] as int).compareTo(b['period'] as int);
      });
    final trs = slots.map((s) =>
      '<tr><td>${s["period"]}</td><td>${s["day"]}</td>'
      '<td>منتظر ${s["waitNum"]}</td><td></td><td></td></tr>'
    ).join();
    return '''
      <div class="teacher-block">
        <h3>المعلم: $teacher</h3>
        <table>
          <tr><th>الحصة</th><th>اليوم</th><th>نوع الانتظار</th><th>التوقيع</th><th>ملاحظات</th></tr>
          $trs
        </table>
        <p class="sig">توقيع المدير: _______________</p>
      </div>
    ''';
  }).join();

  final htmlContent = '''<!DOCTYPE html><html dir="rtl"><head>
    <meta charset="UTF-8"><title>جدول الانتظار</title>
    <style>
      body{font-family:Arial,sans-serif;margin:20px;direction:rtl;}
      h1{text-align:center;color:#1a237e;border-bottom:2px solid #1a237e;padding-bottom:8px;}
      .meta{text-align:center;color:#555;margin-bottom:20px;}
      .teacher-block{page-break-after:always;margin-bottom:30px;}
      h3{color:#1a237e;background:#e8eaf6;padding:8px 12px;border-radius:6px;}
      table{width:100%;border-collapse:collapse;margin-top:10px;}
      th{background:#1a237e;color:white;padding:8px;border:1px solid #999;}
      td{padding:8px;border:1px solid #ccc;text-align:center;}
      tr:nth-child(even){background:#f5f5f5;}
      .sig{margin-top:20px;text-align:left;color:#333;}
      @media print{.teacher-block{page-break-after:always;}}
    </style></head><body>
    <h1>جدول الانتظار — $schoolName</h1>
    <p class="meta">تاريخ الطباعة: $dateStr</p>
    $rows
    </body></html>''';

  // فتح نافذة الطباعة
  final uri = Uri.dataFromString(htmlContent, mimeType: 'text/html', encoding: Uri.encodeComponent('').isEmpty ? null : null);
  // ignore: avoid_web_libraries_in_flutter
  _launchPrint(htmlContent);
}

void _launchPrint(String html) {
  // ignore: avoid_web_libraries_in_flutter
  final script = '''
    var w = window.open('', '_blank');
    w.document.write(arguments[0]);
    w.document.close();
    w.focus();
    w.print();
  ''';
  try {
    // ignore: undefined_prefixed_name
    js.context.callMethod('eval', ['(function(h){var w=window.open("","_blank");w.document.write(h);w.document.close();w.focus();setTimeout(function(){w.print();},500);})(${_escapeJs(html)})']);
  } catch (e) {
    debugPrint('Print error: $e');
  }
}

String _escapeJs(String s) {
  return '"${s.replaceAll('\\\\', '\\\\\\\\').replaceAll('"', '\\\\"').replaceAll('\\n', '\\\\n').replaceAll('\\r', '').replaceAll('</script>', '<\\\\/script>')}"';
}"""
    
    c = c[:idx] + new_fn + c[end:]
    print("Replaced print function")

p.write_text(c, encoding='utf-8')
print("Done")
