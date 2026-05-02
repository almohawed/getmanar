import pathlib

# Fix in schedule_import_screen.dart
p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace all occurrences of 'التقنية الرقمية' as return value with 'المهارات الرقمية'
# But keep 'التقنية الرقمية' as an alias (input)
c = c.replace("return 'التقنية الرقمية';", "return 'المهارات الرقمية';")

p.write_text(c, encoding='utf-8')
print('schedule_import_screen fixed')

# Fix in subjects_management_screen.dart
p2 = pathlib.Path('lib/src/features/schedule/presentation/subjects_management_screen.dart')
c2 = p2.read_text(encoding='utf-8')

# Replace in default subjects list
c2 = c2.replace("'التقنية الرقمية'", "'المهارات الرقمية'")
# Remove duplicate if exists
c2 = c2.replace("  'المهارات الرقمية',\n  'المهارات الرقمية',", "  'المهارات الرقمية',")

p2.write_text(c2, encoding='utf-8')
print('subjects_management_screen fixed')

# Verify
c_check = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart').read_text(encoding='utf-8')
count = c_check.count("return 'المهارات الرقمية';")
print(f'المهارات الرقمية returns: {count}')
count2 = c_check.count("return 'التقنية الرقمية';")
print(f'التقنية الرقمية returns remaining: {count2}')
