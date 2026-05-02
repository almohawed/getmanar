import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

old = (
    "  Future<void> _importFromSchedule(List<Map<String,dynamic>> teachers) async {\n"
    "    final sid=_sid; if(sid==null)return;\n"
    "    try{\n"
    "      final snap=await FirebaseFirestore.instance.collection('Schools').doc(sid).collection('TeacherSchedules').get();\n"
    "      final nameById=<String,String>{for(final t in teachers)t['id'] as String:t['name'] as String};"
)

new = (
    "  Future<void> _importFromSchedule(List<Map<String,dynamic>> teachersParam) async {\n"
    "    final authSid = ref.read(authStateProvider).value?.schoolId ?? '';\n"
    "    final sid = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;\n"
    "    if(sid.isEmpty) return;\n"
    "    try{\n"
    "      // جلب أسماء المعلمين مباشرة من Teachers collection\n"
    "      final teachersSnap = await FirebaseFirestore.instance\n"
    "          .collection('Schools').doc(sid).collection('Teachers').get();\n"
    "      final nameById = <String,String>{};\n"
    "      for (final t in teachersSnap.docs) {\n"
    "        final data = t.data();\n"
    "        final name = (data['name'] ?? data['displayName'] ?? '').toString();\n"
    "        if (name.isNotEmpty) nameById[t.id] = name;\n"
    "      }\n"
    "      final snap=await FirebaseFirestore.instance.collection('Schools').doc(sid).collection('TeacherSchedules').get();"
)

if old in c:
    c = c.replace(old, new)
    print("Fixed _importFromSchedule")
else:
    print("Pattern not found")
    idx = c.find("Future<void> _importFromSchedule")
    print(f"Method at: {idx}")
    print(repr(c[idx:idx+300]))

p.write_text(c, encoding='utf-8')
print("Done")
