import zipfile
import re
import os

def extract_strings_from_xlsx(filepath):
    try:
        with zipfile.ZipFile(filepath, 'r') as z:
            # Try to find shared strings
            if 'xl/sharedStrings.xml' in z.namelist():
                with z.open('xl/sharedStrings.xml') as f:
                    content = f.read().decode('utf-8')
                    # Simple regex to find <t>content</t>
                    # This might get all strings in the workbook
                    strings = re.findall(r'<t[^>]*>(.*?)</t>', content)
                    return strings
            # If no shared strings, maybe inline strings in sheet1?
            elif 'xl/worksheets/sheet1.xml' in z.namelist():
                with z.open('xl/worksheets/sheet1.xml') as f:
                    content = f.read().decode('utf-8')
                    strings = re.findall(r'<t[^>]*>(.*?)</t>', content)
                    return strings
            else:
                return ["No strings found"]
    except Exception as e:
        return [f"Error: {e}"]

base_dir = 'excl'
files = sorted([f for f in os.listdir(base_dir) if f.endswith('.xlsx')])

for filename in files:
    print(f"--- {filename} ---")
    strings = extract_strings_from_xlsx(os.path.join(base_dir, filename))
    # Print first 20 strings to see if they look like names
    for s in strings[:20]:
        print(s)
    print("\n")
