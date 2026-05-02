import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix 1: Add key to DropdownButtonFormField
old_dropdown = "                    child: DropdownButtonFormField<String>(\n                      value: sel[i],"
new_dropdown = "                    child: DropdownButtonFormField<String>(\n                      key: ValueKey('drop_${i}_${teachers.length}'),\n                      value: sel[i],"
c = c.replace(old_dropdown, new_dropdown)

# Fix 2: Fix name extraction to handle both 'name' and 'displayName'
old_name = "            'name': (data['name'] ?? '').toString(),"
new_name = "            'name': (data['name'] ?? data['displayName'] ?? '').toString(),"
c = c.replace(old_name, new_name)

# Fix 3: Show teachers count in dialog for debugging
old_title = "              title: Text('تعديل: $day - الحصة $period',"
new_title = "              title: Text('تعديل: $day - الحصة $period (${teachers.length} معلم)',"
c = c.replace(old_title, new_title)

p.write_text(c, encoding='utf-8')
print("Done")
