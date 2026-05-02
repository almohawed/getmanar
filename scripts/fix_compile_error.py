import pathlib

p = pathlib.Path('lib/src/features/wait_management/presentation/wait_management_screen.dart')
c = p.read_text(encoding='utf-8')

# Fix: replace _generate(teachers) with _generate([]) in _importFromSchedule
# since teachers is no longer a parameter
old1 = "if(wm.isEmpty){_generate(teachers);if(mounted)"
new1 = "if(wm.isEmpty){_generate([]);if(mounted)"
c = c.replace(old1, new1)

old2 = "    }catch(e){_generate(teachers);}"
new2 = "    }catch(e){_generate([]);}"
c = c.replace(old2, new2)

p.write_text(c, encoding='utf-8')
print("Fixed compile errors")
