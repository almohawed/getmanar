import 'dart:convert';

import '../models/policy.dart';
import '../models/snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class PolicyEngine {
  const PolicyEngine();

  Future<PolicyProfile> resolve(SchoolSnapshot snapshot) async {
    final stage = snapshot.stage;
    final policyFile = switch (stage) {
      'primary_only' => 'primary_policy',
      'middle_only' => 'middle_policy',
      'secondary_only' => 'secondary_policy',
      _ => 'combined_policy',
    };

    final assetPath = 'assets/config/timetable_policies_v2/$policyFile.json';
    String rawText;
    try {
      rawText = await rootBundle.loadString(assetPath);
    } on FlutterError {
      throw StateError(
        'Policy file missing: $policyFile.json\n'
        'stage=$stage\n'
        'path=$assetPath',
      );
    }
    final decoded = jsonDecode(rawText);
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded.cast<String, dynamic>())
        : <String, dynamic>{};
    if (stage == 'primary_only') {
      map.putIfAbsent('primary_lower_policy_id', () => 'primary_lower_policy');
      map.putIfAbsent('primary_upper_policy_id', () => 'primary_upper_policy');
      map.putIfAbsent(
        'primary_lower_policy_daily_subjects',
        () => const ['لغتي', 'رياضيات'],
      );
      map.putIfAbsent(
        'primary_lower_policy_bundle_subjects',
        () => const ['لغتي', 'رياضيات', 'اسلامية', 'علوم', 'مهارات'],
      );
    }
    final id = (map['id'] ?? 'v2_$policyFile').toString();

    return PolicyProfile(
      id: id,
      stageKey: stage,
      policyFile: policyFile,
      raw: map,
    );
  }
}
