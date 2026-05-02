import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Find the function containing AnchorElement and replace it
idx = c.find("  final a = html.AnchorElement()")
if idx != -1:
    # Go back to find function start
    fn_start = c.rfind("\nvoid ", 0, idx)
    if fn_start == -1:
        fn_start = c.rfind("\nFuture<void> ", 0, idx)
    fn_start += 1  # skip the newline
    
    # Find function end
    depth = 0
    i = fn_start
    while i < len(c):
        if c[i] == '{': depth += 1
        elif c[i] == '}':
            depth -= 1
            if depth == 0:
                fn_end = i + 1
                break
        i += 1
    
    print(f"Function: {repr(c[fn_start:fn_start+50])}")
    
    # Replace with url_launcher version
    new_fn = (
        "Future<void> _openPrintPage(String htmlContent) async {\n"
        "  final encoded = Uri.encodeComponent(htmlContent);\n"
        "  final dataUrl = 'data:text/html;charset=utf-8,\$encoded';\n"
        "  final uri = Uri.parse(dataUrl);\n"
        "  if (await canLaunchUrl(uri)) {\n"
        "    await launchUrl(uri, mode: LaunchMode.externalApplication);\n"
        "  }\n"
        "}"
    )
    c = c[:fn_start] + new_fn + c[fn_end:]
    print("Replaced function")

# Fix the call to this function
c = c.replace("  _launchPrint(htmlContent);", "  _openPrintPage(htmlContent);")
c = c.replace("  unawaited(_launchPrint(htmlContent));", "  _openPrintPage(htmlContent);")

# Remove dart:html import
c = c.replace(
    "// ignore: avoid_web_libraries_in_flutter\nimport 'dart:html' as html;",
    ""
)

# Remove unawaited import if added
c = c.replace(
    "import 'dart:async' show unawaited;\n",
    ""
)

p.write_text(c, encoding='utf-8')
print("Done")
