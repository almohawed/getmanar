import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/excel_import_wizard.dart')
c = p.read_text(encoding='utf-8')

old = (
    "          final content = row[c]?.value?.toString().trim() ?? '';\n"
    "          if (content.isEmpty) continue;"
)
new = (
    "          final rawVal = row[c]?.value;\n"
    "          if (rawVal == null) continue;\n"
    "          final content = rawVal.toString().trim();\n"
    "          if (content.isEmpty) continue;\n"
    "          if (content.startsWith('=') || content.contains('COUNTIF') ||\n"
    "              content.contains('COUNTA') || content.contains('SUM(') ||\n"
    "              content.contains('IF(') || content.contains('VLOOKUP')) continue;\n"
    "          if (RegExp(r'^[\\d\\.\\,\\s]+\$').hasMatch(content)) continue;\n"
    "          if (content.length <= 1) continue;"
)

count = c.count(old)
print(f"Found {count} occurrences")
if count > 0:
    c = c.replace(old, new)
    p.write_text(c, encoding='utf-8')
    print("Fixed")
else:
    idx = c.find("final content = row[c]?.value?.toString().trim()")
    print(f"Pattern at index: {idx}")
    if idx != -1:
        print(repr(c[max(0,idx-50):idx+150]))
