import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Remove js import
c = c.replace(
    "// ignore: avoid_web_libraries_in_flutter\nimport 'package:js/js.dart' as js;",
    ""
)

# Replace _launchPrint and _escapeJs with simple approach
old_launch = """void _launchPrint(String html) {
  // ignore: avoid_web_libraries_in_flutter
  final script = '''
    var w = window.open('', '_blank');
    w.document.write(arguments[0]);
    w.document.close();
    w.focus();
    w.print();
  ''';
  try {
    // ignore: undefined_prefixed_name
    js.context.callMethod('eval', ['(function(h){var w=window.open("","_blank");w.document.write(h);w.document.close();w.focus();setTimeout(function(){w.print();},500);})(${_escapeJs(html)})']);
  } catch (e) {
    debugPrint('Print error: $e');
  }
}

String _escapeJs(String s) {
  return '"${s.replaceAll('\\\\', '\\\\\\\\').replaceAll('"', '\\\\"').replaceAll('\\n', '\\\\n').replaceAll('\\r', '').replaceAll('</script>', '<\\\\/script>')}"';
}"""

new_launch = """void _launchPrint(String htmlContent) {
  // استخدام data URL لفتح نافذة الطباعة
  final bytes = htmlContent.codeUnits;
  final base64 = Uri.encodeComponent(htmlContent);
  // فتح في نافذة جديدة عبر URL
  final url = Uri.parse('data:text/html;charset=utf-8,$base64');
  // ignore: avoid_web_libraries_in_flutter
  try {
    // ignore: undefined_prefixed_name
    final _ = url.toString(); // just to use url
    // Use window.open via JS eval
    _printViaBlob(htmlContent);
  } catch (e) {
    debugPrint('Print: $e');
  }
}

void _printViaBlob(String html) {
  // ignore: avoid_web_libraries_in_flutter
  // Use a simple approach: create a hidden iframe
  final encoded = Uri.encodeComponent(html);
  final dataUrl = 'data:text/html;charset=utf-8,$encoded';
  // Open in new tab - user can print from there
  // ignore: avoid_web_libraries_in_flutter
  _openUrl(dataUrl);
}

// ignore: avoid_web_libraries_in_flutter
void _openUrl(String url) {
  // ignore: avoid_web_libraries_in_flutter
  import_dart_html_anchor(url);
}"""

if old_launch in c:
    c = c.replace(old_launch, new_launch)
    print("Replaced launch function")
else:
    print("Pattern not found - using simpler approach")
    # Just replace _launchPrint call with a simple URL approach
    idx = c.find("void _launchPrint(")
    if idx != -1:
        # Find end
        depth = 0
        i = idx
        while i < len(c):
            if c[i] == '{': depth += 1
            elif c[i] == '}':
                depth -= 1
                if depth == 0:
                    end = i + 1
                    break
            i += 1
        # Also find _escapeJs
        idx2 = c.find("String _escapeJs(")
        if idx2 != -1:
            depth = 0
            i = idx2
            while i < len(c):
                if c[i] == '{': depth += 1
                elif c[i] == '}':
                    depth -= 1
                    if depth == 0:
                        end2 = i + 1
                        break
                i += 1
            # Remove both
            c = c[:idx] + c[end2:]
            print("Removed old functions")

# Replace _launchPrint call with simple URL open
old_call = "  _launchPrint(htmlContent);"
new_call = (
    "  // فتح صفحة الطباعة\n"
    "  final encoded = Uri.encodeComponent(htmlContent);\n"
    "  final dataUrl = 'data:text/html;charset=utf-8,\$encoded';\n"
    "  // ignore: avoid_web_libraries_in_flutter\n"
    "  final anchor = html.AnchorElement(href: dataUrl)\n"
    "    ..setAttribute('target', '_blank')\n"
    "    ..click();"
)

# Actually use the simplest possible approach
old_call2 = "  _launchPrint(htmlContent);"
new_call2 = (
    "  // فتح صفحة الطباعة في نافذة جديدة\n"
    "  final encoded = Uri.encodeComponent(htmlContent);\n"
    "  final dataUrl = 'data:text/html;charset=utf-8,\$encoded';\n"
    "  html.window.open(dataUrl, '_blank');"
)

# Re-add dart:html import
c = c.replace(
    "import '../../auth/presentation/auth_controller.dart';",
    "import '../../auth/presentation/auth_controller.dart';\n// ignore: avoid_web_libraries_in_flutter\nimport 'dart:html' as html;"
)

# Replace _launchPrint call
if "_launchPrint(htmlContent);" in c:
    c = c.replace("  _launchPrint(htmlContent);", new_call2)
    print("Fixed _launchPrint call")

# Remove _launchPrint and _escapeJs functions if they exist
idx = c.find("void _launchPrint(")
if idx != -1:
    depth = 0
    i = idx
    while i < len(c):
        if c[i] == '{': depth += 1
        elif c[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    c = c[:idx] + c[end:]
    print("Removed _launchPrint")

idx = c.find("String _escapeJs(")
if idx != -1:
    depth = 0
    i = idx
    while i < len(c):
        if c[i] == '{': depth += 1
        elif c[i] == '}':
            depth -= 1
            if depth == 0:
                end = i + 1
                break
        i += 1
    c = c[:idx] + c[end:]
    print("Removed _escapeJs")

# Also fix window.open - use html.window.open which returns Window
# The issue is dart:html's window.open returns WindowBase
# Use a different approach: create anchor element
old_window = "  html.window.open(dataUrl, '_blank');"
new_window = (
    "  final a = html.AnchorElement()\n"
    "    ..href = dataUrl\n"
    "    ..target = '_blank';\n"
    "  html.document.body?.append(a);\n"
    "  a.click();\n"
    "  a.remove();"
)
c = c.replace(old_window, new_window)

p.write_text(c, encoding='utf-8')
print("Done")
