import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
c = p.read_text(encoding='utf-8')

if 'excel_import_wizard' not in c:
    old = "import '../../auth/presentation/auth_controller.dart';"
    new = old + "\nimport 'excel_import_wizard.dart';"
    c = c.replace(old, new)
    p.write_text(c, encoding='utf-8')
    print('import added')
else:
    print('import already exists')
