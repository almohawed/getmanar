import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Update _reviewCard to use simple string matching
old_review = (
    "  Widget _reviewCard(ImportedLesson lesson) {\n"
    "    final resolved = lesson.matchResult.matched != null;"
)
new_review = (
    "  Widget _reviewCard(ImportedLesson lesson) {\n"
    "    final resolved = lesson.matchResult.matched != null || _matchSubject(lesson.rawSubject).isNotEmpty;"
)
c = c.replace(old_review, new_review)

# Update the dropdown items to use simple list
old_dropdown = (
    "              ...SubjectMatcher.defaultSubjects.map((s) => DropdownMenuItem(\n"
    "                value: s.id, child: Text(s.officialName, style: const TextStyle(color: _P.text)))),\n"
)
new_dropdown = (
    "              ..._subjectAliases.values.toSet().map((name) => DropdownMenuItem(\n"
    "                value: name, child: Text(name, style: const TextStyle(color: _P.text)))),\n"
)
c = c.replace(old_dropdown, new_dropdown)

# Update onChanged in dropdown
old_onchanged = (
    "            onChanged: (id) {\n"
    "              if (id == null) return;\n"
    "              final master = SubjectMatcher.findById(id);\n"
    "              if (master == null) return;\n"
    "              setState(() {\n"
    "                lesson.matchResult = SubjectMatchResult(rawName: lesson.rawSubject, matched: master, confidence: MatchConfidence.high);\n"
    "                for (final l in _allLessons) { if (l.rawSubject == lesson.rawSubject) l.matchResult = lesson.matchResult; }\n"
    "              });\n"
    "              SubjectMatcher.saveAlias(_schoolId ?? '', lesson.rawSubject, id);\n"
    "            },"
)
new_onchanged = (
    "            onChanged: (name) {\n"
    "              if (name == null) return;\n"
    "              setState(() {\n"
    "                lesson.matchResult = SubjectMatchResult(\n"
    "                  rawName: lesson.rawSubject,\n"
    "                  matched: SubjectMaster(id: name.toLowerCase().replaceAll(' ', '_'), officialName: name, category: name),\n"
    "                  confidence: MatchConfidence.high);\n"
    "                for (final l in _allLessons) { if (l.rawSubject == lesson.rawSubject) l.matchResult = lesson.matchResult; }\n"
    "              });\n"
    "            },"
)
c = c.replace(old_onchanged, new_onchanged)

# Update dropdown value
old_val = "            value: lesson.matchResult.matched?.id,"
new_val = "            value: lesson.matchResult.matched?.officialName,"
c = c.replace(old_val, new_val)

# Update the save alias text
old_save = (
    "            Expanded(child: Text(\n"
    "              'سيحفظ كمرادف: \"' + lesson.rawSubject + '\" → ' + (lesson.matchResult.matched?.officialName ?? ''),\n"
    "              style: const TextStyle(color: _P.emerald, fontSize: 11))),\n"
)
new_save = (
    "            Expanded(child: Text(\n"
    "              'تم تحديد: \"' + lesson.rawSubject + '\" → ' + (lesson.matchResult.matched?.officialName ?? ''),\n"
    "              style: const TextStyle(color: _P.emerald, fontSize: 11))),\n"
)
c = c.replace(old_save, new_save)

p.write_text(c, encoding='utf-8')
print("Done")
