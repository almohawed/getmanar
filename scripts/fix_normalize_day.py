import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Add normalizeDay function before the class
normalize_fn = """
String _normalizeDay(String s) {
  return s
      .replaceAll('أ', 'ا').replaceAll('إ', 'ا').replaceAll('آ', 'ا')
      .replaceAll('ة', 'ه').replaceAll('ى', 'ي').trim();
}

"""

# Insert before class definition
old_class = "class _Slot {"
new_class = normalize_fn + "class _Slot {"
c = c.replace(old_class, new_class, 1)

# Fix _importFromSchedule to normalize day names
old_day = "          final day=(slot['day']??slot['dayName']??'').toString();"
new_day = "          final rawDay=(slot['day']??slot['dayName']??'').toString();\n          final day=_normalizeDay(rawDay);"
c = c.replace(old_day, new_day)

# Fix _days list to use normalized names (without hamza)
# The _days list already uses 'الاحد' without hamza - good
# But we need to normalize when building _schedule keys too
old_schedule_key = "          _schedule[day]!.putIfAbsent(per,()=>{});\n          wm[day]![per]![wn]={'id':tid,'name':tname};"
new_schedule_key = "          wm[day]!.putIfAbsent(per,()=>{});\n          wm[day]![per]![wn]={'id':tid,'name':tname};"
# This is already correct

# Also normalize in _schedule building
old_sched_build = "      for(final day in wm.keys){\n        _schedule[day]={};"
new_sched_build = "      for(final day in wm.keys){\n        _schedule[day]={};"
# Already correct

p.write_text(c, encoding='utf-8')
print("Done")
