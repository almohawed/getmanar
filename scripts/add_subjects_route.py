import pathlib

# 1. Add import and route to router.dart
router = pathlib.Path('lib/src/core/router.dart')
c = router.read_text(encoding='utf-8')

old_import = "import '../features/schedule/presentation/schedule_import_screen.dart';"
new_import = old_import + "\nimport '../features/schedule/presentation/subjects_management_screen.dart';"
c = c.replace(old_import, new_import)

old_route = "path: '/schedule-import',"
new_route = (
    "path: '/subjects-management',\n"
    "          builder: (context, state) => const SubjectsManagementScreen(),\n"
    "        ),\n"
    "        GoRoute(\n"
    "          " + old_route
)
c = c.replace(old_route, new_route, 1)

router.write_text(c, encoding='utf-8')
print('router updated')

# 2. Add button in smart_schedule_screen.dart popup menu
smart = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
c2 = smart.read_text(encoding='utf-8')

# Add to popup menu - after 'assignments' item
old_menu = (
    "              PopupMenuItem(\n"
    "                value: 'assignments',\n"
    "                child: Row(\n"
    "                  children: [\n"
    "                    Icon(Icons.assignment_ind, size: 20),\n"
    "                    SizedBox(width: 12),\n"
    "                    Text('إسناد المواد'),\n"
    "                  ],\n"
    "                ),\n"
    "              ),"
)
new_menu = (
    "              PopupMenuItem(\n"
    "                value: 'subjects',\n"
    "                child: Row(\n"
    "                  children: [\n"
    "                    Icon(Icons.menu_book_rounded, size: 20, color: Color(0xFF7C3AED)),\n"
    "                    SizedBox(width: 12),\n"
    "                    Text('المواد الدراسية'),\n"
    "                  ],\n"
    "                ),\n"
    "              ),\n"
    "              PopupMenuItem(\n"
    "                value: 'assignments',\n"
    "                child: Row(\n"
    "                  children: [\n"
    "                    Icon(Icons.assignment_ind, size: 20),\n"
    "                    SizedBox(width: 12),\n"
    "                    Text('إسناد المواد'),\n"
    "                  ],\n"
    "                ),\n"
    "              ),"
)
c2 = c2.replace(old_menu, new_menu)

# Add case in onSelected switch
old_case = "                case 'assignments':\n                  context.push('/subject-assignment');"
new_case = (
    "                case 'subjects':\n"
    "                  context.push('/subjects-management');\n"
    "                  break;\n"
    "                case 'assignments':\n"
    "                  context.push('/subject-assignment');"
)
c2 = c2.replace(old_case, new_case)

smart.write_text(c2, encoding='utf-8')
print('smart_schedule_screen updated')
