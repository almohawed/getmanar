class Classroom {
  final String id;
  final String name;
  final String? nameCode;
  final String? displayName;
  final int gradeLevel;
  final List<String> studentIds; // References to User IDs
  final String? secondaryProgramType;
  final String? secondaryTrack;
  final String? secondaryPhase;
  final int? sectionNumber;

  Classroom({
    required this.id,
    required this.name,
    this.nameCode,
    this.displayName,
    required this.gradeLevel,
    required this.studentIds,
    this.secondaryProgramType,
    this.secondaryTrack,
    this.secondaryPhase,
    this.sectionNumber,
  });

  String get preferredLabel {
    final code = (nameCode ?? '').trim();
    final dn = (displayName ?? '').trim();
    if (code.isNotEmpty && dn.isNotEmpty) return '$code — $dn';
    if (dn.isNotEmpty) return dn;
    if (code.isNotEmpty) return code;
    return name;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'nameCode': nameCode,
      'displayName': displayName,
      'gradeLevel': gradeLevel,
      'studentIds': studentIds,
      'secondaryProgramType': secondaryProgramType,
      'secondaryTrack': secondaryTrack,
      'track': secondaryTrack,
      'secondaryPhase': secondaryPhase,
      'sectionNumber': sectionNumber,
    };
  }

  factory Classroom.fromMap(Map<String, dynamic> map) {
    return Classroom(
      id: map['id'],
      name: map['name'],
      nameCode: (map['nameCode'] ?? '').toString().trim().isEmpty
          ? null
          : (map['nameCode'] ?? '').toString().trim(),
      displayName: (map['displayName'] ?? '').toString().trim().isEmpty
          ? null
          : (map['displayName'] ?? '').toString().trim(),
      gradeLevel: map['gradeLevel'],
      studentIds: List<String>.from(map['studentIds'] ?? []),
      secondaryProgramType: (map['secondaryProgramType'] as String?)?.trim(),
      secondaryTrack: ((map['secondaryTrack'] ?? map['track']) as String?)
          ?.trim(),
      secondaryPhase: (map['secondaryPhase'] as String?)?.trim(),
      sectionNumber: map['sectionNumber'] is int
          ? map['sectionNumber']
          : int.tryParse('${map['sectionNumber']}'),
    );
  }
}
