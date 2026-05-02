import pathlib, re

p = pathlib.Path('lib/src/features/schedule/presentation/smart_schedule_screen.dart')
content = p.read_text(encoding='utf-8')

# Find and remove _showExcelMappingDialog, _importGeneralSchedule, _processImport
# Strategy: find each async function by its signature and remove until the matching closing brace

def remove_function(text, fn_name):
    """Remove a Dart method by name from class body."""
    # Find the function start
    idx = text.find(f'  Future<void> {fn_name}(')
    if idx == -1:
        idx = text.find(f'  Future<bool?> {fn_name}(')
    if idx == -1:
        print(f'  {fn_name}: not found, skipping')
        return text
    
    # Find the opening brace of the function body
    brace_start = text.find('{', idx)
    if brace_start == -1:
        return text
    
    # Count braces to find the end
    depth = 0
    i = brace_start
    while i < len(text):
        if text[i] == '{':
            depth += 1
        elif text[i] == '}':
            depth -= 1
            if depth == 0:
                # Found the end of the function
                end = i + 1
                # Remove the function (including any leading newlines before it)
                before = text[:idx].rstrip('\n')
                after = text[end:].lstrip('\n')
                text = before + '\n\n' + after
                print(f'  {fn_name}: removed ({end - idx} chars)')
                return text
        i += 1
    
    print(f'  {fn_name}: could not find end')
    return text

print('Removing old import functions...')
for fn in ['_showExcelMappingDialog', '_importGeneralSchedule', '_processImport']:
    content = remove_function(content, fn)

p.write_text(content, encoding='utf-8')
print('Done.')
