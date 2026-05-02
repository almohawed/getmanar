import pathlib, re

router = pathlib.Path('lib/src/core/router.dart')
c = router.read_text(encoding='utf-8')

# Add import
old_import = "import '../features/schedule/presentation/current_schedule_screen.dart';"
new_import = old_import + "\nimport '../features/schedule/presentation/schedule_import_screen.dart';"
c = c.replace(old_import, new_import)

# Add route - find the smart-schedule route and add after it
old_route = "path: '/smart-schedule',"
# Find the full GoRoute block for smart-schedule and add after it
# We'll add the new route near schedule-management
old_mgmt = "path: '/schedule-management',"
new_route_block = """path: '/schedule-import',
          builder: (context, state) => const ScheduleImportScreen(),
        ),
        GoRoute(
          """ + old_mgmt

c = c.replace(old_mgmt, new_route_block, 1)

router.write_text(c, encoding='utf-8')
print('route added')
