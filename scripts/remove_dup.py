import pathlib

p = pathlib.Path('lib/src/features/admin/presentation/admin_dashboard_v2.dart')
c = p.read_text(encoding='utf-8')

# Remove the first (incomplete) settings section
old_dup = (
    "              _buildSectionHeader(context, 'الإعدادات'),\n"
    "              _buildActionGrid(context, ref, [\n"
    "                _ActionItem(icon: Icons.settings, label: 'إعدادات المدرسة', color: Colors.grey, route: '/settings'),\n"
    "                _ActionItem(icon: Icons.location_on, label: 'موقع المدرسة', color: const Color(0xFF00897B), route: '/school-location'),\n"
    "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
    "              ]),\n"
    "\n"
    "              \n"
    "\n"
    "              _buildSectionHeader(context, 'الإعدادات'),"
)

new_dup = "              _buildSectionHeader(context, 'الإعدادات'),"

if old_dup in c:
    c = c.replace(old_dup, new_dup)
    print("Removed duplicate settings section")
else:
    # Try with different whitespace
    import re
    # Find the first settings section and remove it
    pattern = (
        r"              _buildSectionHeader\(context, 'الإعدادات'\),\n"
        r"              _buildActionGrid\(context, ref, \[\n"
        r"                _ActionItem\(icon: Icons\.settings.*?\n"
        r"                _ActionItem\(icon: Icons\.location_on.*?\n"
        r"                _ActionItem\(icon: Icons\.lock_person.*?\n"
        r"              \]\),\n"
        r"\n"
        r"              \n"
        r"\n"
        r"              _buildSectionHeader\(context, 'الإعدادات'\),"
    )
    match = re.search(pattern, c, re.DOTALL)
    if match:
        c = c[:match.start()] + "              _buildSectionHeader(context, 'الإعدادات')," + c[match.end():]
        print("Removed duplicate via regex")
    else:
        print("Could not find duplicate - manual check needed")
        # Show the area
        idx = c.find("_buildSectionHeader(context, 'الإعدادات')")
        print(f"First occurrence at: {idx}")
        idx2 = c.find("_buildSectionHeader(context, 'الإعدادات')", idx+1)
        print(f"Second occurrence at: {idx2}")
        print(repr(c[idx:idx+400]))

p.write_text(c, encoding='utf-8')
print("Done")
