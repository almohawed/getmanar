import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Add dart:html import for web printing
old_imports = "import '../../auth/presentation/auth_controller.dart';"
new_imports = (
    "import '../../auth/presentation/auth_controller.dart';\n"
    "// ignore: avoid_web_libraries_in_flutter\n"
    "import 'dart:html' as html;"
)
c = c.replace(old_imports, new_imports)

# Add print function before the class
old_class = "String _normalizeDay(String s) {"
new_class = (
    "// ─── طباعة جدول الانتظار ────────────────────────────────────────────────────\n"
    "void _printWaitSchedule(\n"
    "    Map<String, Map<int, _Slot>> schedule,\n"
    "    List<String> days,\n"
    "    int periods,\n"
    "    String schoolName) {\n"
    "  // تجميع البيانات حسب المعلم\n"
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
    "        byTeacher[name]!.add({\n"
    "          'day': day, 'period': p,\n"
    "          'waitNum': i + 1, 'teacherName': name,\n"
    "        });\n"
    "      }\n"
    "    }\n"
    "  }\n"
    "\n"
    "  if (byTeacher.isEmpty) return;\n"
    "\n"
    "  final now = DateTime.now();\n"
    "  final dateStr = '${now.day}/${now.month}/${now.year}';\n"
    "\n"
    "  final rows = byTeacher.entries.map((entry) {\n"
    "    final teacher = entry.key;\n"
    "    final slots = entry.value\n"
    "      ..sort((a, b) {\n"
    "        final di = ['الاحد','الاثنين','الثلاثاء','الاربعاء','الخميس'];\n"
    "        final dc = di.indexOf(a['day']).compareTo(di.indexOf(b['day']));\n"
    "        if (dc != 0) return dc;\n"
    "        return (a['period'] as int).compareTo(b['period'] as int);\n"
    "      });\n"
    "    final trs = slots.map((s) =>\n"
    "      '<tr><td>${s[\"period\"]}</td><td>${s[\"day\"]}</td>'\n"
    "      '<td>منتظر ${s[\"waitNum\"]}</td><td></td><td></td></tr>'\n"
    "    ).join();\n"
    "    return '''\n"
    "      <div class=\"teacher-block\">\n"
    "        <h3>المعلم: $teacher</h3>\n"
    "        <table>\n"
    "          <tr><th>الحصة</th><th>اليوم</th><th>نوع الانتظار</th><th>التوقيع</th><th>ملاحظات</th></tr>\n"
    "          $trs\n"
    "        </table>\n"
    "        <p class=\"sig\">توقيع المدير: _______________</p>\n"
    "      </div>\n"
    "    ''';\n"
    "  }).join();\n"
    "\n"
    "  final htmlContent = '''\n"
    "    <!DOCTYPE html><html dir=\"rtl\"><head>\n"
    "    <meta charset=\"UTF-8\">\n"
    "    <title>جدول الانتظار</title>\n"
    "    <style>\n"
    "      body{font-family:Arial,sans-serif;margin:20px;direction:rtl;}\n"
    "      h1{text-align:center;color:#1a237e;border-bottom:2px solid #1a237e;padding-bottom:8px;}\n"
    "      .meta{text-align:center;color:#555;margin-bottom:20px;}\n"
    "      .teacher-block{page-break-after:always;margin-bottom:30px;}\n"
    "      h3{color:#1a237e;background:#e8eaf6;padding:8px 12px;border-radius:6px;}\n"
    "      table{width:100%;border-collapse:collapse;margin-top:10px;}\n"
    "      th{background:#1a237e;color:white;padding:8px;border:1px solid #999;}\n"
    "      td{padding:8px;border:1px solid #ccc;text-align:center;}\n"
    "      tr:nth-child(even){background:#f5f5f5;}\n"
    "      .sig{margin-top:20px;text-align:left;color:#333;}\n"
    "      @media print{.teacher-block{page-break-after:always;}}\n"
    "    </style></head><body>\n"
    "    <h1>جدول الانتظار — $schoolName</h1>\n"
    "    <p class=\"meta\">تاريخ الطباعة: $dateStr</p>\n"
    "    $rows\n"
    "    </body></html>\n"
    "  ''';\n"
    "\n"
    "  final win = html.window.open('', '_blank');\n"
    "  win?.document.write(htmlContent);\n"
    "  win?.document.close();\n"
    "  win?.print();\n"
    "}\n"
    "\n"
    "String _normalizeDay(String s) {"
)
c = c.replace(old_class, new_class)

# Add print button in _topBar after save button
old_save_btn = (
    "          ElevatedButton.icon(onPressed:_isSaving?null:_save,"
    "icon:_isSaving?const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))"
    ":const Icon(Icons.save_rounded,size:15),"
    "label:const Text('حفظ',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold)),"
    "style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF059669),foregroundColor:Colors.white,"
    "padding:const EdgeInsets.symmetric(horizontal:20,vertical:10),"
    "shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),"
)
new_save_btn = (
    "          ElevatedButton.icon(onPressed:_isSaving?null:_save,"
    "icon:_isSaving?const SizedBox(width:14,height:14,child:CircularProgressIndicator(strokeWidth:2,color:Colors.white))"
    ":const Icon(Icons.save_rounded,size:15),"
    "label:const Text('حفظ',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold)),"
    "style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF059669),foregroundColor:Colors.white,"
    "padding:const EdgeInsets.symmetric(horizontal:20,vertical:10),"
    "shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),\n"
    "          const SizedBox(width:8),\n"
    "          ElevatedButton.icon(\n"
    "            onPressed:()=>_printWaitSchedule(_schedule,_days,_periods,'مدرسة عمر بن أبي سلمة'),\n"
    "            icon:const Icon(Icons.print_rounded,size:15),\n"
    "            label:const Text('طباعة',style:TextStyle(fontSize:13,fontWeight:FontWeight.bold)),\n"
    "            style:ElevatedButton.styleFrom(backgroundColor:const Color(0xFF4F46E5),foregroundColor:Colors.white,\n"
    "              padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),\n"
    "              shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(10)),elevation:0)),"
)

if old_save_btn in c:
    c = c.replace(old_save_btn, new_save_btn)
    print("Added print button")
else:
    print("Save button pattern not found - trying partial")
    idx = c.find("label:const Text('حفظ'")
    print(f"Save label at: {idx}")

p.write_text(c, encoding='utf-8')
print("Done")
