import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Add url_launcher import
old_import = "import '../../auth/presentation/auth_controller.dart';"
new_import = (
    "import '../../auth/presentation/auth_controller.dart';\n"
    "import 'package:url_launcher/url_launcher.dart';"
)
if "url_launcher" not in c:
    c = c.replace(old_import, new_import)
    print("Added url_launcher import")

# Remove dart:html import if exists
c = c.replace(
    "// ignore: avoid_web_libraries_in_flutter\nimport 'dart:html' as html;",
    ""
)

# Fix the _launchPrint function - use url_launcher
old_launch = (
    "void _launchPrint(String htmlContent) {\n"
    "  // استخدام data URL لفتح نافذة الطباعة\n"
    "  final encoded = Uri.encodeComponent(htmlContent);\n"
    "  final dataUrl = 'data:text/html;charset=utf-8,$encoded';\n"
    "  // فتح في نافذة جديدة عبر URL\n"
    "  final url = Uri.parse('data:text/html;charset=utf-8,$encoded');\n"
    "  // ignore: avoid_web_libraries_in_flutter\n"
    "  try {\n"
    "    // ignore: undefined_prefixed_name\n"
    "    final _ = url.toString(); // just to use url\n"
    "    // Use window.open via JS eval\n"
    "    _printViaBlob(htmlContent);\n"
    "  } catch (e) {\n"
    "    debugPrint('Print: $e');\n"
    "  }\n"
    "}"
)

new_launch = (
    "Future<void> _launchPrint(String htmlContent) async {\n"
    "  final encoded = Uri.encodeComponent(htmlContent);\n"
    "  final dataUrl = 'data:text/html;charset=utf-8,$encoded';\n"
    "  final uri = Uri.parse(dataUrl);\n"
    "  try {\n"
    "    await launchUrl(uri, mode: LaunchMode.externalApplication);\n"
    "  } catch (e) {\n"
    "    debugPrint('Print error: $e');\n"
    "  }\n"
    "}"
)

if old_launch in c:
    c = c.replace(old_launch, new_launch)
    print("Fixed _launchPrint")
else:
    # Find and replace the function
    idx = c.find("void _launchPrint(")
    if idx == -1:
        idx = c.find("Future<void> _launchPrint(")
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
        c = c[:idx] + new_launch + c[end:]
        print("Replaced _launchPrint via index")
    else:
        print("Could not find _launchPrint")

# Fix the call - make it async
old_call = "  _launchPrint(htmlContent);"
new_call = "  unawaited(_launchPrint(htmlContent));"
c = c.replace(old_call, new_call)

# Remove AnchorElement code if exists
anchor_code = (
    "  final a = html.AnchorElement();\n"
    "  a.href = url;\n"
    "  a.target = \"_blank\";\n"
    "  html.document.body?.append(a);\n"
    "  a.click();\n"
    "  a.remove();"
)
if anchor_code in c:
    c = c.replace(anchor_code, "  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);")
    print("Fixed anchor to launchUrl")

# Add unawaited import
if "unawaited" in c and "dart:async" not in c:
    c = c.replace(
        "import 'package:url_launcher/url_launcher.dart';",
        "import 'package:url_launcher/url_launcher.dart';\nimport 'dart:async' show unawaited;"
    )

p.write_text(c, encoding='utf-8')
print("Done")
