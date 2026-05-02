import pathlib, re

p = pathlib.Path('lib/src/features/admin/presentation/admin_dashboard_v2.dart')
c = p.read_text(encoding='utf-8')

# Find StreamBuilder start
start = c.find("              // زر الاشتراك — يُقرأ مباشرة من Firestore stream")
if start == -1:
    start = c.find("              // زر الاشتراك — يُقرأ مباشرة من Firestoree")
    
print(f"Start: {start}")

# Find the end - after the second _buildActionGrid block for settings
# Look for the line after the StreamBuilder closes
end_marker = "              _buildSectionHeader(context, 'الإعدادات'),"
end = c.find(end_marker, start)
print(f"End: {end}")

if start != -1 and end != -1:
    # Replace the StreamBuilder block with nothing (the settings section follows)
    c = c[:start] + c[end:]
    
    # Now add the subscription button inside the settings grid
    old_settings = (
        "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
        "                _ActionItem(icon: Icons.mic, label: 'مسؤول الإذاعة', color: const Color(0xFF1A237E), route: '/assign-broadcast-supervisor'),"
    )
    new_settings = (
        "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
        "                if (_showSubscription)\n"
        "                  _ActionItem(icon: Icons.card_membership, label: 'الاشتراك', color: Colors.amber, route: '/subscription-plans'),\n"
        "                _ActionItem(icon: Icons.mic, label: 'مسؤول الإذاعة', color: const Color(0xFF1A237E), route: '/assign-broadcast-supervisor'),"
    )
    if old_settings in c:
        c = c.replace(old_settings, new_settings)
        print("Added subscription button in settings grid")
    else:
        print("Could not find settings grid pattern")
    
    p.write_text(c, encoding='utf-8')
    print("Fixed admin_dashboard_v2")
else:
    print("Could not find markers")
