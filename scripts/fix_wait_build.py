import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

old_build = (
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    return Scaffold(\n"
    "      backgroundColor: const Color(0xFFF8FAFF),"
)

new_build = (
    "  @override\n"
    "  Widget build(BuildContext context) {\n"
    "    // تحميل البيانات عند أول render بعد تحميل المستخدم\n"
    "    final user = ref.watch(authStateProvider).value;\n"
    "    if (user != null) _initIfNeeded((user.schoolId ?? '').trim());\n"
    "\n"
    "    return Scaffold(\n"
    "      backgroundColor: const Color(0xFFF8FAFF),"
)

if old_build in c:
    c = c.replace(old_build, new_build)
    print("Fixed build method")
else:
    print("Pattern not found")
    idx = c.find("Widget build(BuildContext context)")
    print(f"build at: {idx}")
    print(repr(c[idx:idx+200]))

p.write_text(c, encoding='utf-8')
print("Done")
