import pathlib

p = pathlib.Path('lib/src/features/schedule/presentation/schedule_import_screen.dart')
c = p.read_text(encoding='utf-8')

# Replace SubjectMatcher.match(subject) with inline _matchSubject
old = "            matchResult: SubjectMatcher.match(subject),"
new = "            matchResult: _buildMatchResult(subject),"
c = c.replace(old, new)

# Replace SubjectMatcher.match(s).needsReview with inline check
old2 = "      _knownCount = rawSubjects.where((s) => !SubjectMatcher.match(s).needsReview).length;\n"
old2 += "      _unknownCount = rawSubjects.where((s) => SubjectMatcher.match(s).needsReview).length;\n"
new2 = (
    "      _knownCount = rawSubjects.where((s) => _isKnownSubject(s)).length;\n"
    "      _unknownCount = rawSubjects.where((s) => !_isKnownSubject(s)).length;\n"
)
c = c.replace(old2, new2)

# Replace reviewSubjects logic
old3 = "      final reviewSubjects = rawSubjects.where((s) => SubjectMatcher.match(s).needsReview).toSet();"
new3 = "      final reviewSubjects = rawSubjects.where((s) => !_isKnownSubject(s)).toSet();"
c = c.replace(old3, new3)

# Replace SubjectMatcher.match(e.key) in _subjectRow
old4 = "        ..._subjectStats.entries.map((e) => _subjectRow(e.key, SubjectMatcher.match(e.key), e.value)),"
new4 = "        ..._subjectStats.entries.map((e) => _subjectRow(e.key, _matchSubject(e.key), e.value)),"
c = c.replace(old4, new4)

# Add _buildMatchResult helper and update _subjectRow signature
# Find _subjectRow and update its signature
old_row = "  Widget _subjectRow(String raw, SubjectMatchResult result, int count) {"
new_row = "  SubjectMatchResult _buildMatchResult(String raw) {\n"
new_row += "    final matched = _matchSubject(raw);\n"
new_row += "    if (matched.isNotEmpty) {\n"
new_row += "      return SubjectMatchResult(rawName: raw, matched: SubjectMaster(\n"
new_row += "        id: matched.toLowerCase().replaceAll(' ', '_'),\n"
new_row += "        officialName: matched, category: matched),\n"
new_row += "        confidence: MatchConfidence.high);\n"
new_row += "    }\n"
new_row += "    return SubjectMatchResult(rawName: raw, confidence: MatchConfidence.unknown);\n"
new_row += "  }\n\n"
new_row += "  Widget _subjectRow(String raw, String matchedName, int count) {"
c = c.replace(old_row, new_row)

# Update _subjectRow body to use matchedName string instead of result object
old_body = (
    "    Color color; String badge; IconData icon;\n"
    "    if (result.confidence == MatchConfidence.high) { color = _P.emerald; badge = 'معروفة'; icon = Icons.check_circle_rounded; }\n"
    "    else if (result.confidence == MatchConfidence.medium) { color = _P.amber; badge = 'مقترحة'; icon = Icons.help_rounded; }\n"
    "    else { color = _P.rose; badge = 'غير معروفة'; icon = Icons.error_rounded; }\n"
)
new_body = (
    "    Color color; String badge; IconData icon;\n"
    "    if (matchedName.isNotEmpty) { color = _P.emerald; badge = 'معروفة'; icon = Icons.check_circle_rounded; }\n"
    "    else { color = _P.rose; badge = 'غير معروفة'; icon = Icons.error_rounded; }\n"
)
c = c.replace(old_body, new_body)

# Update the matched name display in _subjectRow
old_display = (
    "          if (result.matched != null)\n"
    "            Text('→ ' + result.matched!.officialName, style: TextStyle(color: color, fontSize: 11)),"
)
new_display = (
    "          if (matchedName.isNotEmpty)\n"
    "            Text('→ ' + matchedName, style: TextStyle(color: color, fontSize: 11)),"
)
c = c.replace(old_display, new_display)

p.write_text(c, encoding='utf-8')
print("Done")
