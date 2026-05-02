import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix broken string interpolation - \\$ should be just $
c = c.replace("'تعديل: \\$day - الحصة \\$period'", "'تعديل: \$day - الحصة \$period'")
c = c.replace("'منتظر \\${i+1}'", "'منتظر \${i+1}'")
c = c.replace("'منتظر \\${wi+1}'", "'منتظر \${wi+1}'")
c = c.replace("'\\$p'", "'\$p'")
c = c.replace("'\\${i+1}'", "'\${i+1}'")
c = c.replace("'\\${wi+1}'", "'\${wi+1}'")

# Count remaining broken patterns
broken = c.count('\\\\$')
print(f'Remaining broken: {broken}')

# Fix all \\$ to $ in string literals
import re
# Replace \\$ with $ only inside string literals (between quotes)
c = c.replace("\\'\\$", "'\$")  # won't work well

# Better: just replace all \\$ with $
c = c.replace('\\$', '$')

print('Fixed dollar signs')

# Also fix the sid issue - ensure it's not empty
old_stream = "stream:FirebaseFirestore.instance.collection('Schools').doc(sid).collection('Teachers').snapshots(),"
new_stream = "stream:sid.isNotEmpty?FirebaseFirestore.instance.collection('Schools').doc(sid).collection('Teachers').snapshots():const Stream.empty(),"
c = c.replace(old_stream, new_stream)
print('Fixed stream guard')

p.write_text(c, encoding='utf-8')
print('Done')
