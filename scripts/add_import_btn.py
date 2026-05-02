import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace the old import button with a new one that navigates to the full screen
old = (
    "                  child: OutlinedButton.icon(\n"
    "                    onPressed: _isImportingExcel ? null : _importScheduleFromExcel,\n"
    "                    icon: _isImportingExcel\n"
    "                        ? SizedBox(width: 18, height: 18,\n"
    "                            child: CircularProgressIndicator(strokeWidth: 2))\n"
    "                        : Icon(Icons.upload_file, size: 20),\n"
    "                    label: Text(\n"
    "                      _isImportingExcel ? 'جاري الرفع...' : '📊 رفع جدول Excel جاهز',\n"
    "                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),\n"
    "                    ),\n"
    "                    style: OutlinedButton.styleFrom(\n"
    "                      foregroundColor: Colors.indigo.shade700,\n"
    "                      side: BorderSide(color: Colors.indigo.shade400, width: 1.5),\n"
    "                      padding: EdgeInsets.symmetric(vertical: 14),\n"
    "                      shape: RoundedRectangleBorder(\n"
    "                          borderRadius: BorderRadius.circular(12)),\n"
    "                    ),\n"
    "                  ),"
)

new = (
    "                  child: OutlinedButton.icon(\n"
    "                    onPressed: () => context.push('/schedule-import'),\n"
    "                    icon: const Icon(Icons.table_chart_rounded, size: 20),\n"
    "                    label: const Text(\n"
    "                      '📊 استيراد جدول Excel',\n"
    "                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),\n"
    "                    ),\n"
    "                    style: OutlinedButton.styleFrom(\n"
    "                      foregroundColor: Colors.indigo.shade700,\n"
    "                      side: BorderSide(color: Colors.indigo.shade400, width: 1.5),\n"
    "                      padding: const EdgeInsets.symmetric(vertical: 14),\n"
    "                      shape: RoundedRectangleBorder(\n"
    "                          borderRadius: BorderRadius.circular(12)),\n"
    "                    ),\n"
    "                  ),"
)

if old in c:
    c = c.replace(old, new)
    p.write_text(c, encoding='utf-8')
    print('button updated')
else:
    # Try simpler replacement
    old2 = "_importScheduleFromExcel"
    count = c.count(old2)
    print(f'Found {count} occurrences of _importScheduleFromExcel')
    # Replace the onPressed call in the button
    c2 = c.replace(
        "onPressed: _isImportingExcel ? null : _importScheduleFromExcel,",
        "onPressed: () => context.push('/schedule-import'),"
    )
    if c2 != c:
        p.write_text(c2, encoding='utf-8')
        print('button onPressed updated')
    else:
        print('could not find button to update')
