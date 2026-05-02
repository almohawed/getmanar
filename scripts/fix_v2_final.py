import pathlib

p = pathlib.Path('lib/src/features/admin/presentation/admin_dashboard_v2.dart')
c = p.read_text(encoding='utf-8')

# Find StreamBuilder start - use the comment before it
start_comment = "// زر الاشتراك — يُقرأ مباشرة من Firestore\n              StreamBuilder"
start = c.find(start_comment)
print(f"Start: {start}")

if start == -1:
    # Try without the comment
    start = c.find("StreamBuilder<DocumentSnapshot>")
    print(f"StreamBuilder only at: {start}")
    # Go back to find the comment
    comment_start = c.rfind("//", 0, start)
    start = comment_start
    print(f"Comment start: {start}")

# Find end - the closing of StreamBuilder ),
# Count braces from StreamBuilder
sb_start = c.find("StreamBuilder<DocumentSnapshot>", start)
depth = 0
i = sb_start
while i < len(c):
    if c[i] == '(':
        depth += 1
    elif c[i] == ')':
        depth -= 1
        if depth == 0:
            end = i + 2  # include ), and newline
            break
    i += 1

print(f"StreamBuilder ends at: {end}")
print("Removing:", repr(c[start:min(start+100, end)]))

# Replace with simple if check
new_code = (
    "if (_showSubscription)\n"
    "                  _ActionItem(icon: Icons.card_membership, label: 'الاشتراك', color: Colors.amber, route: '/subscription-plans'),\n"
    "              "
)

# But we need to put this inside the settings grid
# First just remove the StreamBuilder block
c = c[:start] + c[end:]

# Now add subscription inside settings grid
old_perm = (
    "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
    "                _ActionItem(icon: Icons.mic"
)
new_perm = (
    "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
    "                if (_showSubscription)\n"
    "                  _ActionItem(icon: Icons.card_membership, label: 'الاشتراك', color: Colors.amber, route: '/subscription-plans'),\n"
    "                _ActionItem(icon: Icons.mic"
)

if old_perm in c:
    c = c.replace(old_perm, new_perm)
    print("Added subscription in settings grid")
else:
    print("Could not find permissions pattern")

p.write_text(c, encoding='utf-8')
print("Done")
