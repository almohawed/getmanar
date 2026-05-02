import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix the content reading to skip Excel formulas and invalid cells
old = (
    "          final content = row[c]?.value?.toString().trim() ?? '';\n"
    "          if (content.isEmpty) continue;"
)
new = (
    "          final rawVal = row[c]?.value;\n"
    "          // تجاهل صيغ Excel والقيم الرقمية\n"
    "          if (rawVal == null) continue;\n"
    "          final content = rawVal.toString().trim();\n"
    "          if (content.isEmpty) continue;\n"
    "          // تجاهل صيغ Excel\n"
    "          if (content.startsWith('=') || content.contains('COUNTIF') ||\n"
    "              content.contains('COUNTA') || content.contains('SUM(') ||\n"
    "              content.contains('IF(') || content.contains('VLOOKUP')) continue;\n"
    "          // تجاهل القيم الرقمية البحتة\n"
    "          if (RegExp(r'^[\\d\\.\\,\\s]+\$').hasMatch(content)) continue;\n"
    "          // تجاهل النصوص القصيرة جداً\n"
    "          if (content.length <= 1) continue;"
)

if old in c:
    c = c.replace(old, new)
    print("Fixed content reading in schedule_import_screen")
else:
    print("Pattern not found - checking...")
    idx = c.find("final content = row[c]?.value?.toString().trim()")
    print(f"Found at index: {idx}")
    if idx != -1:
        print(c[max(0,idx-100):idx+200])

p.write_text(c, encoding='utf-8')
print("Done")
