import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
lines = p.read_text(encoding='utf-8').splitlines(keepends=True)

# Remove unused import lines (file_picker, cross_file, kIsWeb, excel)
to_remove = [
    "import 'package:file_picker/file_picker.dart';",
    "import 'package:flutter/foundation.dart' show kIsWeb;",
    "import 'package:cross_file/cross_file.dart';",
    "import 'package:excel/excel.dart' as excel;",
]

new_lines = []
for line in lines:
    stripped = line.strip()
    if stripped in to_remove:
        print(f'Removed: {stripped}')
    else:
        new_lines.append(line)

p.write_text(''.join(new_lines), encoding='utf-8')
print('Done cleaning imports.')
