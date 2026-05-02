import pathlib, re

# Fix admin_dashboard_v2.dart - remove StreamBuilder, use simple FutureBuilder
p = pathlib.Path('lib/src/features/admin/presentation/admin_dashboard_v2.dart')
c = p.read_text(encoding='utf-8')

# Remove the StreamBuilder block entirely and replace with simple _showSubscription check
old = (
    "              // زر الاشتراك — يُقرأ مباشرة من Firestore stream\n"
    "              StreamBuilder<DocumentSnapshot>(\n"
    "                stream: schoolId.isNotEmpty\n"
    "                    ? FirebaseFirestore.instance.collection('Schools').doc(schoolId).snapshots()\n"
    "                    : const Stream.empty(),\n"
    "                builder: (context, snap) {\n"
    "                  final showSub = snap.hasData && snap.data!.exists &&\n"
    "                      (snap.data!.data() as Map<String, dynamic>?)?['showSubscriptionSection'] == true;\n"
    "                  if (!showSub) return const SizedBox.shrink();\n"
    "                  return Padding(\n"
    "                    padding: EdgeInsets.only(bottom: 8.h),\n"
    "                    child: _buildActionGrid(context, ref, [\n"
    "                      _ActionItem(icon: Icons.card_membership, label: 'الاشتراك', color: Colors.amber, route: '/subscription-plans'),\n"
    "                    ]),\n"
    "                  );\n"
    "                },\n"
    "              ),\n"
    "\n"
    "              _buildSectionHeader(context, 'الإعدادات'),\n"
    "              _buildActionGrid(context, ref, [\n"
    "                _ActionItem(icon: Icons.settings, label: 'إعدادات المدرسة', color: Colors.grey, route: '/settings'),\n"
    "                _ActionItem(icon: Icons.location_on, label: 'موقع المدرسة', color: const Color(0xFF00897B), route: '/school-location'),\n"
    "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
    "                _ActionItem(icon: Icons.mic, label: 'مسؤول الإذاعة', color: const Color(0xFF1A237E), route: '/assign-broadcast-supervisor'),"
)

new = (
    "              _buildSectionHeader(context, 'الإعدادات'),\n"
    "              _buildActionGrid(context, ref, [\n"
    "                _ActionItem(icon: Icons.settings, label: 'إعدادات المدرسة', color: Colors.grey, route: '/settings'),\n"
    "                _ActionItem(icon: Icons.location_on, label: 'موقع المدرسة', color: const Color(0xFF00897B), route: '/school-location'),\n"
    "                _ActionItem(icon: Icons.lock_person, label: liveCounts['permissions'] != null && liveCounts['permissions']! > 0 ? 'الصلاحيات (${liveCounts['permissions']})' : 'الصلاحيات', color: Colors.blueGrey, route: '/permissions-dashboard'),\n"
    "                if (_showSubscription)\n"
    "                  _ActionItem(icon: Icons.card_membership, label: 'الاشتراك', color: Colors.amber, route: '/subscription-plans'),\n"
    "                _ActionItem(icon: Icons.mic, label: 'مسؤول الإذاعة', color: const Color(0xFF1A237E), route: '/assign-broadcast-supervisor'),"
)

if old in c:
    c = c.replace(old, new)
    print("Fixed admin_dashboard_v2")
else:
    print("Pattern not found in admin_dashboard_v2")
    # Find StreamBuilder
    idx = c.find("StreamBuilder<DocumentSnapshot>")
    print(f"StreamBuilder at: {idx}")

p.write_text(c, encoding='utf-8')

# Fix smart_admin_dashboard.dart - remove StreamBuilder
p2 = pathlib.Path('lib/src/features/admin/presentation/smart_admin_dashboard.dart')
c2 = p2.read_text(encoding='utf-8')

# Find and remove StreamBuilder block
idx = c2.find("// زر الاشتراك — يُقرأ مباشرة من Firestore stream")
if idx != -1:
    # Find the end of the StreamBuilder (after _buildFullDashboardButton)
    end_marker = "_buildFullDashboardButton(context),"
    end_idx = c2.find(end_marker, idx)
    if end_idx != -1:
        # Replace the whole block with simple _showSubscription check
        old_block = c2[idx:end_idx + len(end_marker)]
        new_block = (
            "// زر الاشتراك\n"
            "                  if (_showSubscription) ...[\n"
            "                    _sectionTitle('💳 الاشتراك', ''),\n"
            "                    const SizedBox(height: 8),\n"
            "                    GestureDetector(\n"
            "                      onTap: () => context.push('/subscription-plans'),\n"
            "                      child: Container(\n"
            "                        padding: const EdgeInsets.all(16),\n"
            "                        decoration: BoxDecoration(\n"
            "                          color: Colors.amber.withOpacity(0.1),\n"
            "                          borderRadius: BorderRadius.circular(12),\n"
            "                          border: Border.all(color: Colors.amber.withOpacity(0.4)),\n"
            "                        ),\n"
            "                        child: Row(children: [\n"
            "                          const Icon(Icons.card_membership, color: Colors.amber, size: 24),\n"
            "                          const SizedBox(width: 14),\n"
            "                          const Expanded(child: Text('الاشتراك', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15))),\n"
            "                          const Icon(Icons.arrow_forward_ios, color: Colors.white38, size: 14),\n"
            "                        ]),\n"
            "                      ),\n"
            "                    ),\n"
            "                    const SizedBox(height: 16),\n"
            "                  ],\n"
            "                  _buildFullDashboardButton(context),"
        )
        c2 = c2[:idx] + new_block + c2[end_idx + len(end_marker):]
        print("Fixed smart_admin_dashboard")
    else:
        print("Could not find end marker")
else:
    print("StreamBuilder not found in smart_admin_dashboard")

p2.write_text(c2, encoding='utf-8')
print("Done")
