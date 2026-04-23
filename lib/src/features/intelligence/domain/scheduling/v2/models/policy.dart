class PolicyProfile {
  final String id;
  final String stageKey;
  final String policyFile;
  final Map<String, dynamic> raw;

  const PolicyProfile({
    required this.id,
    required this.stageKey,
    required this.policyFile,
    this.raw = const <String, dynamic>{},
  });
}
