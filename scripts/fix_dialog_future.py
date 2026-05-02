import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Find the _edit method and replace it completely with FutureBuilder approach
# First find the method
idx_start = c.find("  void _edit(String day,int period,List<Map<String,dynamic>> teachersParam) async {")
if idx_start == -1:
    idx_start = c.find("  void _edit(")
    print(f"Found _edit at: {idx_start}")

# Find the end of the method (matching braces)
depth = 0
i = idx_start
while i < len(c):
    if c[i] == '{':
        depth += 1
    elif c[i] == '}':
        depth -= 1
        if depth == 0:
            idx_end = i + 1
            break
    i += 1

print(f"Method from {idx_start} to {idx_end}")

# New method using FutureBuilder inside dialog
new_method = """  void _edit(String day, int period) {
    final authSid = ref.read(authStateProvider).value?.schoolId ?? '';
    final sid2 = (widget.schoolId?.isNotEmpty == true) ? widget.schoolId! : authSid;
    if (sid2.isEmpty) return;

    final slot = _schedule[day]?[period];
    final sel = List<String?>.filled(_waitCount, null);
    if (slot != null) {
      for (int i = 0; i < slot.teacherIds.length && i < _waitCount; i++) {
        sel[i] = slot.teacherIds[i];
      }
    }

    showDialog(
      context: context,
      builder: (_) => FutureBuilder<QuerySnapshot>(
        future: FirebaseFirestore.instance
            .collection('Schools').doc(sid2).collection('Teachers').get(),
        builder: (ctx, snap) {
          if (!snap.hasData) {
            return const AlertDialog(
              content: SizedBox(height: 80,
                child: Center(child: CircularProgressIndicator(color: Color(0xFF4F46E5)))),
            );
          }
          final teachers = snap.data!.docs.map((d) {
            final data = d.data() as Map<String, dynamic>;
            return <String, dynamic>{
              'id': d.id,
              'name': (data['name'] ?? '').toString(),
            };
          }).where((t) => (t['name'] as String).isNotEmpty).toList();

          return StatefulBuilder(
            builder: (ctx2, setS) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text('تعديل: $day - الحصة $period',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              content: SizedBox(
                width: 340,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  ...List.generate(_waitCount, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      value: sel[i],
                      decoration: InputDecoration(
                        labelText: 'منتظر ${i + 1}',
                        labelStyle: TextStyle(color: _wColors[i % _wColors.length]),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide(color: _wColors[i % _wColors.length].withOpacity(0.4))),
                        filled: true,
                        fillColor: _wColors[i % _wColors.length].withOpacity(0.04),
                      ),
                      items: [
                        const DropdownMenuItem<String>(value: null, child: Text('-- فارغ --')),
                        ...teachers.map((t) => DropdownMenuItem(
                          value: t['id'] as String,
                          child: Text(t['name'] as String, style: const TextStyle(fontSize: 13)))),
                      ],
                      onChanged: (v) => setS(() => sel[i] = v),
                    ),
                  )),
                ]),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx2),
                  child: const Text('إلغاء', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx2);
                    setState(() {
                      final ids = sel.where((s) => s != null).cast<String>().toList();
                      final names = ids.map((id) {
                        final t = teachers.firstWhere((t) => t['id'] == id, orElse: () => {'name': ''});
                        return t['name'] as String;
                      }).toList();
                      if (ids.isEmpty) {
                        _schedule[day]?.remove(period);
                      } else {
                        _schedule.putIfAbsent(day, () => {});
                        _schedule[day]![period] = _Slot(
                          day: day, period: period,
                          teacherIds: ids, teacherNames: names, isManual: true);
                      }
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5), foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  child: const Text('حفظ'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }"""

# Replace the old method
old_method = c[idx_start:idx_end]
c = c.replace(old_method, new_method)

# Also fix all calls to _edit to remove the teachers parameter
# Old: _edit(day,p,teachers) -> New: _edit(day,p)
c = c.replace("_edit(day,p,teachers)", "_edit(day,p)")
c = c.replace("onTap:()=>_edit(day,p,teachers)", "onTap:()=>_edit(day,p)")

p.write_text(c, encoding='utf-8')
print("Done - FutureBuilder dialog implemented")
