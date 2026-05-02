import pathlib, re

p = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
content = p.read_text(encoding='utf-8')

# Replace the old _importScheduleFromExcel with the new wizard call
old = (
    "  // ─── استيراد جدول من Excel ────────────────────────────────────────────────\n"
    "  Future<void> _importScheduleFromExcel() async {\n"
    "    if (_schoolId == null) return;\n"
    "    setState(() { _isImportingExcel = true; _importMessage = null; });\n"
    "    try {\n"
    "      final result = await FilePicker.platform.pickFiles(\n"
    "        type: FileType.custom, allowedExtensions: ['xlsx', 'xls']);\n"
    "      if (result == null) { setState(() => _isImportingExcel = false); return; }\n"
    "\n"
    "      final platformFile = result.files.first;\n"
    "      final bytes = kIsWeb\n"
    "          ? platformFile.bytes!\n"
    "          : (platformFile.bytes ?? await XFile(platformFile.path!).readAsBytes());\n"
    "      final workbook = excel.Excel.decodeBytes(bytes);\n"
    "\n"
    "      // جلب الفصول\n"
    "      final classesSnap = await FirebaseFirestore.instance\n"
    "          .collection('Schools').doc(_schoolId).collection('Classes').get();\n"
    "      final classes = classesSnap.docs;\n"
    "\n"
    "      if (!mounted) return;\n"
    "      await _showExcelMappingDialog(workbook, classes);\n"
    "    } catch (e) {\n"
    "      setState(() => _importMessage = '❌ فشل قراءة الملف: $e');\n"
    "    } finally {\n"
    "      if (mounted) setState(() => _isImportingExcel = false);\n"
    "    }\n"
    "  }"
)

new_fn = (
    "  // ─── استيراد جدول من Excel (Wizard) ─────────────────────────────────────\n"
    "  Future<void> _importScheduleFromExcel() async {\n"
    "    if (_schoolId == null) return;\n"
    "    final result = await showExcelImportWizard(\n"
    "      context,\n"
    "      _schoolId!,\n"
    "      () => _loadSchoolSchedules(),\n"
    "    );\n"
    "    if (result == true) {\n"
    "      setState(() => _importMessage = '✅ تم استيراد الجدول بنجاح');\n"
    "      await _loadSchoolSchedules();\n"
    "    }\n"
    "  }"
)

if old in content:
    content = content.replace(old, new_fn)
    p.write_text(content, encoding='utf-8')
    print('patched ok')
else:
    # Try to find the function and replace it
    idx = content.find('  // ─── استيراد جدول من Excel')
    if idx == -1:
        idx = content.find('Future<void> _importScheduleFromExcel()')
    print(f'Function found at index: {idx}')
    print('Content around that area:')
    print(repr(content[idx:idx+200]))
