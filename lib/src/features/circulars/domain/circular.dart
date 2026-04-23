import 'package:cloud_firestore/cloud_firestore.dart';

enum CircularAttachmentType { pdf, image }

class Circular {
  final String id;
  final String schoolId;
  final String title;
  final String description;
  final List<String> targetRoles;
  final CircularAttachmentType attachmentType;
  final String attachmentUrl;
  final String attachmentPath;
  final String attachmentFileName;
  final String attachmentMimeType;
  final String createdById;
  final String createdByName;
  final DateTime createdAt;
  final int circularNumber;
  final int recipientsCount;
  final int acknowledgedCount;

  const Circular({
    required this.id,
    required this.schoolId,
    required this.title,
    this.description = '',
    required this.targetRoles,
    required this.attachmentType,
    required this.attachmentUrl,
    required this.attachmentPath,
    required this.attachmentFileName,
    required this.attachmentMimeType,
    required this.createdById,
    required this.createdByName,
    required this.createdAt,
    this.circularNumber = 0,
    this.recipientsCount = 0,
    this.acknowledgedCount = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'schoolId': schoolId,
      'title': title,
      'description': description,
      'targetRoles': targetRoles,
      'attachmentType': attachmentType.name,
      'attachmentUrl': attachmentUrl,
      'attachmentPath': attachmentPath,
      'attachmentFileName': attachmentFileName,
      'attachmentMimeType': attachmentMimeType,
      'createdById': createdById,
      'createdByName': createdByName,
      'createdAt': Timestamp.fromDate(createdAt),
      'circularNumber': circularNumber,
      'recipientsCount': recipientsCount,
      'acknowledgedCount': acknowledgedCount,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  factory Circular.fromMap(Map<String, dynamic> map) {
    final createdAtRaw = map['createdAt'];
    DateTime createdAt = DateTime.now();
    if (createdAtRaw is Timestamp) createdAt = createdAtRaw.toDate();
    if (createdAtRaw is String)
      createdAt = DateTime.tryParse(createdAtRaw) ?? createdAt;
    return Circular(
      id: (map['id'] ?? '').toString(),
      schoolId: (map['schoolId'] ?? '').toString(),
      title: (map['title'] ?? '').toString(),
      description: (map['description'] ?? '').toString(),
      targetRoles:
          (map['targetRoles'] as List?)?.map((e) => e.toString()).toList() ??
          const [],
      attachmentType: CircularAttachmentType.values.firstWhere(
        (e) => e.name == (map['attachmentType'] ?? '').toString(),
        orElse: () => CircularAttachmentType.pdf,
      ),
      attachmentUrl: (map['attachmentUrl'] ?? '').toString(),
      attachmentPath: (map['attachmentPath'] ?? '').toString(),
      attachmentFileName: (map['attachmentFileName'] ?? '').toString(),
      attachmentMimeType: (map['attachmentMimeType'] ?? '').toString(),
      createdById: (map['createdById'] ?? '').toString(),
      createdByName: (map['createdByName'] ?? '').toString(),
      createdAt: createdAt,
      circularNumber: (map['circularNumber'] as num?)?.toInt() ?? 0,
      recipientsCount: (map['recipientsCount'] ?? 0).toString().isEmpty
          ? 0
          : (map['recipientsCount'] as num?)?.toInt() ?? 0,
      acknowledgedCount: (map['acknowledgedCount'] ?? 0).toString().isEmpty
          ? 0
          : (map['acknowledgedCount'] as num?)?.toInt() ?? 0,
    );
  }
}
