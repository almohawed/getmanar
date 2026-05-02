import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix _generate to also fetch teachers directly if empty
old_gen = "  void _generate(List<Map<String,dynamic>> teachers) {\n    if(teachers.isEmpty)return;"
new_gen = (
    "  void _generate(List<Map<String,dynamic>> teachers) {\n"
    "    if(teachers.isEmpty){\n"
    "      // جلب المعلمين مباشرة إذا كانت القائمة فارغة\n"
    "      final authSid = ref.read(authStateProvider).value?.schoolId ?? '';\n"
    "      final sid2 = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;\n"
    "      if (sid2.isNotEmpty) {\n"
    "        FirebaseFirestore.instance.collection('Schools').doc(sid2).collection('Teachers').get().then((snap) {\n"
    "          final t = snap.docs.map((d) {\n"
    "            final data = d.data();\n"
    "            return <String,dynamic>{'id': d.id, 'name': (data['name'] ?? data['displayName'] ?? '').toString(), 'max': (data['maxWeeklyClasses'] ?? 24) as int};\n"
    "          }).where((t) => (t['name'] as String).isNotEmpty).toList();\n"
    "          if (t.isNotEmpty) _generate(t);\n"
    "        });\n"
    "      }\n"
    "      return;\n"
    "    }"
)

if old_gen in c:
    c = c.replace(old_gen, new_gen)
    print("Fixed _generate")
else:
    print("Pattern not found")

p.write_text(c, encoding='utf-8')
print("Done")
