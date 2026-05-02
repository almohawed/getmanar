import pathlib

# Fix 1: Make WaitManagementScreen accept schoolId as parameter
p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace class definition to accept schoolId
old_class = (
    "class WaitManagementScreen extends ConsumerStatefulWidget {\n"
    "  const WaitManagementScreen({super.key});\n"
    "  @override ConsumerState<WaitManagementScreen> createState()=>_State();\n"
    "}"
)
new_class = (
    "class WaitManagementScreen extends ConsumerStatefulWidget {\n"
    "  final String? schoolId;\n"
    "  const WaitManagementScreen({super.key, this.schoolId});\n"
    "  @override ConsumerState<WaitManagementScreen> createState()=>_State();\n"
    "}"
)
c = c.replace(old_class, new_class)

# Fix _sid getter to use widget.schoolId first
old_sid = "  String? get _sid => ref.read(authStateProvider).value?.schoolId;"
new_sid = (
    "  String? get _sid {\n"
    "    if (widget.schoolId != null && widget.schoolId!.isNotEmpty) return widget.schoolId;\n"
    "    return ref.read(authStateProvider).value?.schoolId;\n"
    "  }"
)
c = c.replace(old_sid, new_sid)

# Fix build to use widget.schoolId or authState
old_build_sid = "    final sid=ref.watch(authStateProvider).value?.schoolId??'';"
new_build_sid = (
    "    final authSid=ref.watch(authStateProvider).value?.schoolId??'';\n"
    "    final sid=widget.schoolId?.isNotEmpty==true?widget.schoolId!:authSid;"
)
c = c.replace(old_build_sid, new_build_sid)

p.write_text(c, encoding='utf-8')
print("Fixed WaitManagementScreen")

# Fix 2: Pass schoolId from router
router = pathlib.Path('lib/src/core/router.dart')
rc = router.read_text(encoding='utf-8')

old_route = "      path: '/wait-management',\n      builder: (context, state) => const WaitManagementScreen(),"
new_route = (
    "      path: '/wait-management',\n"
    "      builder: (context, state) {\n"
    "        // Get schoolId from extra or from auth\n"
    "        final extra = state.extra as Map<String, dynamic>?;\n"
    "        final schoolId = extra?['schoolId'] as String?;\n"
    "        return WaitManagementScreen(schoolId: schoolId);\n"
    "      },"
)
rc = rc.replace(old_route, new_route)
router.write_text(rc, encoding='utf-8')
print("Fixed router")

# Fix 3: Pass schoolId when navigating to wait-management
smart = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
sc = smart.read_text(encoding='utf-8')

old_nav = "                case 'waiting':\n                  context.push('/wait-management');"
new_nav = (
    "                case 'waiting':\n"
    "                  context.push('/wait-management', extra: {'schoolId': _schoolId ?? ''});"
)
sc = sc.replace(old_nav, new_nav)
smart.write_text(sc, encoding='utf-8')
print("Fixed navigation")
