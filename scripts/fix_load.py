import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

old = (
    "  @override\n"
    "  void initState() {\n"
    "    super.initState();\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "      final user = ref.read(authStateProvider).value;\n"
    "      if (user != null) {\n"
    "        setState(() => _schoolId = user.schoolId);\n"
    "        _loadData();\n"
    "      }\n"
    "    });\n"
    "  }\n"
    "  Future<void> _loadData() async {\n"
    "    if (_schoolId == null) return;"
)

new = (
    "  @override\n"
    "  void initState() {\n"
    "    super.initState();\n"
    "    WidgetsBinding.instance.addPostFrameCallback((_) {\n"
    "      final user = ref.read(authStateProvider).value;\n"
    "      if (user != null) {\n"
    "        final sid = (user.schoolId ?? '').trim();\n"
    "        if (sid.isNotEmpty) {\n"
    "          _schoolId = sid;\n"
    "          _loadData();\n"
    "        }\n"
    "      }\n"
    "    });\n"
    "  }\n"
    "  Future<void> _loadData() async {\n"
    "    if (_schoolId == null || _schoolId!.isEmpty) return;"
)

if old in c:
    c = c.replace(old, new)
    print("Fixed initState")
else:
    print("Pattern not found")
    idx = c.find("void initState()")
    print(f"initState at: {idx}")
    print(repr(c[idx:idx+300]))

p.write_text(c, encoding='utf-8')
print("Done")
