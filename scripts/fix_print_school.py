import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix print button to get school name from StreamBuilder context
old_print = "            onPressed:()=>_printWaitSchedule(_schedule,_days,_periods,'مدرسة عمر بن أبي سلمة'),"
new_print = "            onPressed:()=>_printWaitSchedule(_schedule,_days,_periods,_schoolName),"
c = c.replace(old_print, new_print)

# Add _schoolName field
old_field = "  Map<String,Map<int,_Slot>> _schedule={};"
new_field = "  Map<String,Map<int,_Slot>> _schedule={};\n  String _schoolName='';"
c = c.replace(old_field, new_field)

# Set _schoolName from StreamBuilder
old_stream_build = "    return Scaffold(\n      backgroundColor:const Color(0xFFF8FAFF),\n      body:sid.isEmpty"
new_stream_build = (
    "    return Scaffold(\n"
    "      backgroundColor:const Color(0xFFF8FAFF),\n"
    "      body:sid.isEmpty"
)
# Already correct - just need to set _schoolName from school data
# Add it in the StreamBuilder builder
old_teachers_build = "          final teachers=snap.hasData?snap.data!.docs.map((d){"
new_teachers_build = (
    "          // جلب اسم المدرسة\n"
    "          if (_schoolName.isEmpty && sid.isNotEmpty) {\n"
    "            FirebaseFirestore.instance.collection('Schools').doc(sid).get().then((d) {\n"
    "              if (d.exists && mounted) setState(() => _schoolName = (d.data()?['name'] ?? '').toString());\n"
    "            });\n"
    "          }\n"
    "          final teachers=snap.hasData?snap.data!.docs.map((d){"
)
c = c.replace(old_teachers_build, new_teachers_build)

p.write_text(c, encoding='utf-8')
print("Done")
