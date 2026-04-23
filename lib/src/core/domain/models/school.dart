class School {
  final String id;
  final String name;
  final String type; // government, private, international
  final String stage; // 'الابتدائية', 'المتوسطة', 'الثانوية'
  final String city;
  final String adminRegion; // المنطقة الإدارية (إدارة التعليم بمنطقة ...)
  final String ownerId;
  final String countryCode; // ISO code like SA, BH, AE
  final String policyVersion; // For future per-country policy packs
  final bool showSubscriptionSection; // New field to control visibility
  final String startTime; // "HH:mm" format, e.g., "06:30"
  final String? schoolEducationProfile;
  final String? secondaryProgramType;
  final String? secondaryStructure;
  final List<String> enabledTracks;
  final int? daysPerWeek;
  final int? periodsPerDay;
  final double? latitude;
  final double? longitude;
  final DateTime? trialEndsAt;
  final DateTime? subscriptionEndsAt; // Added field
  final bool isLifetimeAccess;
  final String subscriptionPlan; // 'free', 'basic', 'standard', 'premium', 'elite'
  final bool hasSpecialEducation; // New field for Inclusion School logic
  final SmsConfig smsConfig;

  School({
    required this.id,
    required this.name,
    required this.type,
    required this.stage,
    required this.city,
    this.adminRegion = '',
    required this.ownerId,
    this.countryCode = 'SA',
    this.policyVersion = 'v1',
    this.showSubscriptionSection = true, // Default to true
    this.startTime = '06:30', // Default start time
    this.schoolEducationProfile,
    this.secondaryProgramType,
    this.secondaryStructure,
    this.enabledTracks = const <String>[],
    this.daysPerWeek,
    this.periodsPerDay,
    this.latitude,
    this.longitude,
    this.trialEndsAt,
    this.subscriptionEndsAt,
    this.isLifetimeAccess = false,
    this.subscriptionPlan = 'free',
    this.hasSpecialEducation = false,
    SmsConfig? smsConfig,
  }) : smsConfig = smsConfig ?? SmsConfig();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'stage': stage,
      'city': city,
      'adminRegion': adminRegion,
      'ownerId': ownerId,
      'countryCode': countryCode,
      'policyVersion': policyVersion,
      'showSubscriptionSection': showSubscriptionSection,
      'startTime': startTime,
      'schoolEducationProfile': schoolEducationProfile,
      'secondaryProgramType': secondaryProgramType,
      'secondaryStructure': secondaryStructure,
      'enabledTracks': enabledTracks,
      'daysPerWeek': daysPerWeek,
      'periodsPerDay': periodsPerDay,
      'latitude': latitude,
      'longitude': longitude,
      'trialEndsAt': trialEndsAt?.toIso8601String(),
      'subscriptionEndsAt': subscriptionEndsAt?.toIso8601String(),
      'isLifetimeAccess': isLifetimeAccess,
      'subscriptionPlan': subscriptionPlan,
      'hasSpecialEducation': hasSpecialEducation,
      'smsConfig': smsConfig.toMap(),
    };
  }

  factory School.fromMap(Map<String, dynamic> map) {
    return School(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'government',
      stage: map['stage'] ?? 'الابتدائية',
      city: map['city'] ?? '',
      adminRegion: map['adminRegion'] ?? '',
      ownerId: map['ownerId'] ?? '',
      countryCode: map['countryCode'] ?? 'SA',
      policyVersion: map['policyVersion'] ?? 'v1',
      showSubscriptionSection: map['showSubscriptionSection'] ?? true,
      startTime: map['startTime'] ?? '06:30',
      schoolEducationProfile: map['schoolEducationProfile'],
      secondaryProgramType: map['secondaryProgramType'],
      secondaryStructure: map['secondaryStructure'],
      enabledTracks: (map['enabledTracks'] as List<dynamic>?)
              ?.map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList() ??
          const <String>[],
      daysPerWeek: map['daysPerWeek'],
      periodsPerDay: map['periodsPerDay'],
      latitude: map['latitude'],
      longitude: map['longitude'],
      trialEndsAt: map['trialEndsAt'] != null
          ? DateTime.tryParse(map['trialEndsAt'])
          : null,
      subscriptionEndsAt: map['subscriptionEndsAt'] != null
          ? DateTime.tryParse(map['subscriptionEndsAt'])
          : null,
      isLifetimeAccess: map['isLifetimeAccess'] ?? false,
      subscriptionPlan: map['subscriptionPlan'] ?? 'free',
      hasSpecialEducation: map['hasSpecialEducation'] ?? false,
      smsConfig: map['smsConfig'] != null
          ? SmsConfig.fromMap(map['smsConfig'])
          : null,
    );
  }
}

class SmsConfig {
  final String apiUrl;
  final String apiKey; // Bearer Token
  final String senderName; // اسم المرسل
  final bool isEnabled;

  SmsConfig({
    this.apiUrl = '',
    this.apiKey = '',
    this.senderName = 'School1',
    this.isEnabled = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'apiUrl': apiUrl,
      'apiKey': apiKey,
      'senderName': senderName,
      'isEnabled': isEnabled,
    };
  }

  factory SmsConfig.fromMap(Map<String, dynamic> map) {
    return SmsConfig(
      apiUrl: map['apiUrl'] ?? 'https://app.mobile.net.sa/api/v1/send',
      apiKey: map['apiKey'] ?? '',
      senderName: map['senderName'] ?? 'School1',
      isEnabled: map['isEnabled'] ?? false,
    );
  }
}
