import 'package:cloud_firestore/cloud_firestore.dart';

class SchoolRequest {
  final String id;
  final String schoolName;
  final String schoolType; // 'government', 'private', 'international'
  final String schoolStage; // 'الابتدائية', 'المتوسطة', 'الثانوية'
  final String city;
  final String adminRegion; // المنطقة الإدارية (إدارة التعليم بمنطقة ...)
  final String principalName;
  final String mobile;
  final String email;
  final String? identityNumber;
  final int studentCount;
  final String ownerUserId;
  final String status; // 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final bool hasSpecialEducation;

  SchoolRequest({
    required this.id,
    required this.schoolName,
    required this.schoolType,
    required this.schoolStage,
    required this.city,
    this.adminRegion = '',
    required this.principalName,
    required this.mobile,
    required this.email,
    this.identityNumber,
    required this.studentCount,
    required this.ownerUserId,
    this.status = 'pending',
    required this.createdAt,
    this.hasSpecialEducation = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'schoolName': schoolName,
      'schoolType': schoolType,
      'schoolStage': schoolStage,
      'city': city,
      'adminRegion': adminRegion,
      'principalName': principalName,
      'mobile': mobile,
      'email': email,
      'identityNumber': identityNumber,
      'studentCount': studentCount,
      'ownerUserId': ownerUserId,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
      'hasSpecialEducation': hasSpecialEducation,
    };
  }

  factory SchoolRequest.fromMap(Map<String, dynamic> map, String id) {
    return SchoolRequest(
      id: id,
      schoolName: map['schoolName'] ?? '',
      schoolType: map['schoolType'] ?? 'government',
      schoolStage: map['schoolStage'] ?? 'الابتدائية',
      city: map['city'] ?? '',
      adminRegion: map['adminRegion'] ?? '',
      principalName: map['principalName'] ?? '',
      mobile: map['mobile'] ?? '',
      email: map['email'] ?? '',
      identityNumber: map['identityNumber'],
      studentCount: map['studentCount']?.toInt() ?? 0,
      ownerUserId: map['ownerUserId'] ?? '',
      status: map['status'] ?? 'pending',
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      hasSpecialEducation: map['hasSpecialEducation'] ?? false,
    );
  }
}
