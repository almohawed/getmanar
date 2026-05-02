import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

old_import = "import '../../auth/presentation/auth_controller.dart';"
new_import = (
    "import '../../auth/presentation/auth_controller.dart';\n"
    "// ignore: avoid_web_libraries_in_flutter\n"
    "import 'package:js/js.dart' as js;"
)
c = c.replace(old_import, new_import)

p.write_text(c, encoding='utf-8')
print("Done")
