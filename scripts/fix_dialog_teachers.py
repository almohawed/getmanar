import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Find the _edit method and replace it to fetch teachers directly
old_edit_start = "  void _edit(String day,int period,List<Map<String,dynamic>> teachers){"
new_edit_start = "  void _edit(String day,int period,List<Map<String,dynamic>> teachers) async {"

if old_edit_start in c:
    # Replace the entire _edit method to fetch teachers directly if empty
    old_method = (
        "  void _edit(String day,int period,List<Map<String,dynamic>> teachers){\n"
        "    final slot=_schedule[day]?[period];\n"
        "    final sel=List<String?>.filled(_waitCount,null);\n"
        "    if(slot!=null)for(int i=0;i<slot.teacherIds.length&&i<_waitCount;i++)sel[i]=slot.teacherIds[i];\n"
        "    showDialog(context:context,builder:(_)=>AlertDialog("
    )
    new_method = (
        "  void _edit(String day,int period,List<Map<String,dynamic>> teachersParam) async {\n"
        "    // جلب المعلمين مباشرة إذا كانت القائمة فارغة\n"
        "    List<Map<String,dynamic>> teachers = teachersParam;\n"
        "    if (teachers.isEmpty) {\n"
        "      final authSid = ref.read(authStateProvider).value?.schoolId ?? '';\n"
        "      final sid2 = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;\n"
        "      if (sid2.isNotEmpty) {\n"
        "        try {\n"
        "          final snap = await FirebaseFirestore.instance\n"
        "              .collection('Schools').doc(sid2).collection('Teachers').get();\n"
        "          teachers = snap.docs.map((d) {\n"
        "            final data = d.data();\n"
        "            return <String,dynamic>{'id': d.id, 'name': (data['name'] ?? '').toString(),\n"
        "              'max': (data['maxWeeklyClasses'] ?? 24) as int};\n"
        "          }).where((t) => (t['name'] as String).isNotEmpty).toList();\n"
        "        } catch (e) { debugPrint('fetch teachers error: $e'); }\n"
        "      }\n"
        "    }\n"
        "    if (!mounted) return;\n"
        "    final slot=_schedule[day]?[period];\n"
        "    final sel=List<String?>.filled(_waitCount,null);\n"
        "    if(slot!=null)for(int i=0;i<slot.teacherIds.length&&i<_waitCount;i++)sel[i]=slot.teacherIds[i];\n"
        "    showDialog(context:context,builder:(_)=>AlertDialog("
    )
    if old_method in c:
        c = c.replace(old_method, new_method)
        print("Fixed _edit method")
    else:
        print("Could not find _edit method body")
        idx = c.find("void _edit(")
        print(f"_edit at: {idx}")
        print(repr(c[idx:idx+300]))
else:
    print("Could not find _edit method signature")
    idx = c.find("void _edit")
    print(f"_edit at: {idx}")
    print(repr(c[idx:idx+100]))

p.write_text(c, encoding='utf-8')
print("Done")
