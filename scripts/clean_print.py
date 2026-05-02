import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Remove _openUrl function
for fn_name in ['// ignore: avoid_web_libraries_in_flutter\nvoid _openUrl(', 'void _printViaBlob(']:
    idx = c.find(fn_name)
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
        print(f'Removed {fn_name[:30]}')

# Fix the broken call
c = c.replace('import_dart_html_anchor(url);',
    'final a = html.AnchorElement();\n'
    '  a.href = url;\n'
    '  a.target = "_blank";\n'
    '  html.document.body?.append(a);\n'
    '  a.click();\n'
    '  a.remove();')

p.write_text(c, encoding='utf-8')
print("Done")
