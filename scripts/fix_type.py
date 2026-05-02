import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix the StreamBuilder to cast properly
old = "final teachers=snap.hasData?snap.data!.docs.map((d){final data=d.data() as Map<String,dynamic>;return {'id':d.id,'name':(data['name']??'').toString(),'max':(data['maxWeeklyClasses']??24) as int};}).where((t)=>(t['name'] as String).isNotEmpty).toList():[];"
new = "final teachers=snap.hasData?snap.data!.docs.map((d){final data=d.data() as Map<String,dynamic>;return <String,dynamic>{'id':d.id,'name':(data['name']??'').toString(),'max':(data['maxWeeklyClasses']??24) as int};}).where((t)=>(t['name'] as String).isNotEmpty).toList():<Map<String,dynamic>>[];"

if old in c:
    c = c.replace(old, new)
    print("Fixed type")
else:
    print("Not found")

p.write_text(c, encoding='utf-8')
print("Done")
