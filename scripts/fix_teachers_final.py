import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# The root cause: _teachers is loaded async but dialog opens before it's ready
# Fix: load teachers synchronously using FutureBuilder in the dialog
# OR: use ref.watch with a provider

# Find the _editSlot method and replace the teachers list with a direct Firestore call
old_edit = (
    "  void _editSlot(String day, int period) {\n"
    "    final slot = _schedule[day]?[period];\n"
    "    final selected = List<String?>.filled(_waitCount, null);\n"
    "    if (slot != null) {\n"
    "      for (int i = 0; i < slot.teacherIds.length && i < _waitCount; i++)\n"
    "        selected[i] = slot.teacherIds[i];\n"
    "    }\n"
    "    showDialog(\n"
    "      context: context,\n"
    "      builder: (_) => AlertDialog("
)

new_edit = (
    "  void _editSlot(String day, int period) {\n"
    "    final slot = _schedule[day]?[period];\n"
    "    final selected = List<String?>.filled(_waitCount, null);\n"
    "    if (slot != null) {\n"
    "      for (int i = 0; i < slot.teacherIds.length && i < _waitCount; i++)\n"
    "        selected[i] = slot.teacherIds[i];\n"
    "    }\n"
    "    // جلب المعلمين مباشرة إذا كانت القائمة فارغة\n"
    "    if (_teachers.isEmpty && _schoolId != null) {\n"
    "      FirebaseFirestore.instance\n"
    "          .collection('Schools').doc(_schoolId).collection('Teachers').get()\n"
    "          .then((snap) {\n"
    "        if (mounted) {\n"
    "          setState(() {\n"
    "            _teachers = snap.docs.map((d) {\n"
    "              final data = d.data();\n"
    "              return {'id': d.id, 'name': (data['name'] ?? '').toString(),\n"
    "                'maxWeeklyClasses': (data['maxWeeklyClasses'] ?? 24) as int};\n"
    "            }).where((t) => (t['name'] as String).isNotEmpty).toList();\n"
    "          });\n"
    "          // إعادة فتح الـ dialog بعد تحميل المعلمين\n"
    "          _editSlot(day, period);\n"
    "        }\n"
    "      });\n"
    "      return;\n"
    "    }\n"
    "    showDialog(\n"
    "      context: context,\n"
    "      builder: (_) => AlertDialog("
)

if old_edit in c:
    c = c.replace(old_edit, new_edit)
    print("Fixed _editSlot")
else:
    print("Pattern not found")
    idx = c.find("void _editSlot")
    print(f"_editSlot at: {idx}")

p.write_text(c, encoding='utf-8')
print("Done")
