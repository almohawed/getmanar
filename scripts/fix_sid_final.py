import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# The real fix: use ref.watch properly and handle loading state
old_build = (
    "  Widget build(BuildContext context){\n"
    "    final authSid=ref.watch(authStateProvider).value?.schoolId??'';\n"
    "    final sid=widget.schoolId?.isNotEmpty==true?widget.schoolId!:authSid;\n"
    "    return Scaffold(\n"
    "      backgroundColor:const Color(0xFFF8FAFF),\n"
    "      body:sid.isEmpty?const Center(child:CircularProgressIndicator()):StreamBuilder<QuerySnapshot>(\n"
    "        stream:sid.isNotEmpty?FirebaseFirestore.instance.collection('Schools').doc(sid).collection('Teachers').snapshots():const Stream.empty(),"
)

new_build = (
    "  Widget build(BuildContext context){\n"
    "    // Watch auth state - will rebuild when user loads\n"
    "    final authAsync = ref.watch(authStateProvider);\n"
    "    final authSid = authAsync.value?.schoolId ?? '';\n"
    "    final sid = (widget.schoolId != null && widget.schoolId!.isNotEmpty)\n"
    "        ? widget.schoolId!\n"
    "        : authSid;\n"
    "\n"
    "    // Show loading while auth is loading\n"
    "    if (authAsync.isLoading && sid.isEmpty) {\n"
    "      return const Scaffold(\n"
    "        backgroundColor: Color(0xFFF8FAFF),\n"
    "        body: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5))),\n"
    "      );\n"
    "    }\n"
    "\n"
    "    return Scaffold(\n"
    "      backgroundColor:const Color(0xFFF8FAFF),\n"
    "      body:sid.isEmpty?const Center(child:CircularProgressIndicator(color:Color(0xFF4F46E5))):StreamBuilder<QuerySnapshot>(\n"
    "        stream:FirebaseFirestore.instance.collection('Schools').doc(sid).collection('Teachers').snapshots(),"
)

if old_build in c:
    c = c.replace(old_build, new_build)
    print("Fixed build method")
else:
    print("Pattern not found - trying partial")
    idx = c.find("Widget build(BuildContext context){")
    print(f"build at: {idx}")
    print(repr(c[idx:idx+400]))

p.write_text(c, encoding='utf-8')
print("Done")
