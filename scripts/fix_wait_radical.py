import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace the entire class with a version that uses ref.watch directly
old_class_start = (
    "class _WaitManagementScreenState extends ConsumerState<WaitManagementScreen> {\n"
    "  String? _schoolId;\n"
    "  List<Map<String, dynamic>> _teachers = [];\n"
    "  Map<String, Map<int, _Slot>> _schedule = {};\n"
    "  bool _isLoading = false;\n"
    "  bool _isSaving = false;\n"
    "  int _waitCount = 2;\n"
    "  final List<String> _days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس'];\n"
    "  final int _periods = 7;\n"
    "\n"
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
    "  }"
)

new_class_start = (
    "class _WaitManagementScreenState extends ConsumerState<WaitManagementScreen> {\n"
    "  String? _schoolId;\n"
    "  List<Map<String, dynamic>> _teachers = [];\n"
    "  Map<String, Map<int, _Slot>> _schedule = {};\n"
    "  bool _isLoading = false;\n"
    "  bool _isSaving = false;\n"
    "  int _waitCount = 2;\n"
    "  bool _dataLoaded = false;\n"
    "  final List<String> _days = ['الاحد', 'الاثنين', 'الثلاثاء', 'الاربعاء', 'الخميس'];\n"
    "  final int _periods = 7;\n"
    "\n"
    "  @override\n"
    "  void initState() {\n"
    "    super.initState();\n"
    "  }\n"
    "\n"
    "  void _initIfNeeded(String schoolId) {\n"
    "    if (_dataLoaded || schoolId.isEmpty) return;\n"
    "    _dataLoaded = true;\n"
    "    _schoolId = schoolId;\n"
    "    Future.microtask(() => _loadData());\n"
    "  }"
)

if old_class_start in c:
    c = c.replace(old_class_start, new_class_start)
    print("Fixed class start")
else:
    print("Pattern not found")
    idx = c.find("class _WaitManagementScreenState")
    print(f"Class at: {idx}")
    print(repr(c[idx:idx+500]))

p.write_text(c, encoding='utf-8')
print("Done")
