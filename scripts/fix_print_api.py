import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix the window.open API - cast to Window
old_win = (
    "  final win = html.window.open('', '_blank');\n"
    "  win?.document.write(htmlContent);\n"
    "  win?.document.close();\n"
    "  win?.print();"
)
new_win = (
    "  final win = html.window.open('', '_blank') as html.Window?;\n"
    "  if (win != null) {\n"
    "    win.document.write(htmlContent);\n"
    "    win.document.close();\n"
    "    win.print();\n"
    "  }"
)

if old_win in c:
    c = c.replace(old_win, new_win)
    print("Fixed window API")
else:
    print("Pattern not found")
    idx = c.find("html.window.open")
    print(f"window.open at: {idx}")
    print(repr(c[idx:idx+200]))

p.write_text(c, encoding='utf-8')
print("Done")
