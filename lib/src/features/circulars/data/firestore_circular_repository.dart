import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../../../core/domain/models/user.dart';
import '../domain/circular.dart';

class CircularRecipient {
  final String userId;
  final String name;
  final String role;

  const CircularRecipient({
    required this.userId,
    required this.name,
    required this.role,
  });
}

class FirestoreCircularRepository {
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final FirebaseFunctions _functions;

  FirestoreCircularRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _functions = functions ?? FirebaseFunctions.instance;

  CollectionReference<Map<String, dynamic>> _circularsCol(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('StaffCirculars');
  }

  Future<List<CircularRecipient>> _loadRecipients({
    required String schoolId,
    required List<String> targetRoles,
  }) async {
    final recipients = <CircularRecipient>[];

    if (targetRoles.contains(UserRole.teacher.name)) {
      final snap = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Teachers')
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final name = (data['name'] ?? '').toString().trim();
        recipients.add(
          CircularRecipient(
            userId: d.id,
            name: name.isEmpty ? d.id : name,
            role: UserRole.teacher.name,
          ),
        );
      }
    }

    final staffRoles = <String>[];
    if (targetRoles.contains(UserRole.administrative.name)) {
      staffRoles.addAll([
        UserRole.administrative.name,
        UserRole.admin.name,
        UserRole.supportAdmin.name,
        UserRole.technicalSupport.name,
      ]);
    }
    if (targetRoles.contains(UserRole.deputy.name)) {
      staffRoles.add(UserRole.deputy.name);
    }

    if (staffRoles.isNotEmpty) {
      final snap = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('Staff')
          .where('role', whereIn: staffRoles.toSet().toList())
          .get();
      for (final d in snap.docs) {
        final data = d.data();
        final role = (data['role'] ?? '').toString().trim();
        final name = (data['name'] ?? '').toString().trim();
        if (role.isEmpty) continue;
        recipients.add(
          CircularRecipient(
            userId: d.id,
            name: name.isEmpty ? d.id : name,
            role: role,
          ),
        );
      }
    }

    final unique = <String, CircularRecipient>{};
    for (final r in recipients) {
      unique[r.userId] = r;
    }
    return unique.values.toList();
  }

  Future<(String downloadUrl, String storagePath)> _upload({
    required String schoolId,
    required String circularId,
    required String fileName,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final safeName = fileName.trim().isEmpty ? 'attachment' : fileName.trim();
    final ref = _storage.ref(
      'schools/$schoolId/circulars/$circularId/$safeName',
    );
    final meta = SettableMetadata(contentType: contentType);
    final task = await ref.putData(bytes, meta);
    final url = await task.ref.getDownloadURL();
    return (url, ref.fullPath);
  }

  Stream<List<Circular>> watchCircularsForRole({
    required String schoolId,
    required String role,
  }) {
    return _circularsCol(schoolId)
        .where('targetRoles', arrayContains: role)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
          return snap.docs.map((d) => Circular.fromMap(d.data())).toList();
        });
  }

  Stream<List<Circular>> watchAllCirculars({required String schoolId}) {
    return _circularsCol(
      schoolId,
    ).orderBy('createdAt', descending: true).snapshots().map((snap) {
      return snap.docs.map((d) => Circular.fromMap(d.data())).toList();
    });
  }

  DocumentReference<Map<String, dynamic>> recipientDoc({
    required String schoolId,
    required String circularId,
    required String userId,
  }) {
    return _circularsCol(
      schoolId,
    ).doc(circularId).collection('Recipients').doc(userId);
  }

  Stream<Map<String, dynamic>?> watchRecipientStatus({
    required String schoolId,
    required String circularId,
    required String userId,
  }) {
    return recipientDoc(
      schoolId: schoolId,
      circularId: circularId,
      userId: userId,
    ).snapshots().map((d) => d.data());
  }

  Stream<List<Map<String, dynamic>>> watchRecipients({
    required String schoolId,
    required String circularId,
  }) {
    return _circularsCol(schoolId)
        .doc(circularId)
        .collection('Recipients')
        .orderBy('name')
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }

  Future<int> _reserveCircularNumber(String schoolId) async {
    final res = await _functions
        .httpsCallable('reserveStaffCircularNumber')
        .call({'schoolId': schoolId});
    final data = res.data;
    if (data is Map) {
      return (data['circularNumber'] as num?)?.toInt() ?? 0;
    }
    return 0;
  }

  Future<String> createCircular({
    required String schoolId,
    required String title,
    required String description,
    required List<String> targetRoles,
    required CircularAttachmentType attachmentType,
    required String attachmentFileName,
    required String attachmentMimeType,
    required Uint8List attachmentBytes,
    required String createdById,
    required String createdByName,
  }) async {
    final doc = _circularsCol(schoolId).doc();
    final id = doc.id;

    final circularNumber = await _reserveCircularNumber(schoolId);

    final (url, path) = await _upload(
      schoolId: schoolId,
      circularId: id,
      fileName: attachmentFileName,
      bytes: attachmentBytes,
      contentType: attachmentMimeType,
    );

    final circular = Circular(
      id: id,
      schoolId: schoolId,
      title: title,
      description: description,
      targetRoles: targetRoles,
      attachmentType: attachmentType,
      attachmentUrl: url,
      attachmentPath: path,
      attachmentFileName: attachmentFileName,
      attachmentMimeType: attachmentMimeType,
      createdById: createdById,
      createdByName: createdByName,
      createdAt: DateTime.now(),
      circularNumber: circularNumber,
    );

    final recipients = await _loadRecipients(
      schoolId: schoolId,
      targetRoles: targetRoles,
    );

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final baseMap = circular.toMap();
    await doc.set({
      ...baseMap,
      'createdAt': FieldValue.serverTimestamp(),
      'createdAtClientMs': nowMs,
      'createdAtMs': nowMs,
    }, SetOptions(merge: true));

    final batch = _firestore.batch();
    for (final r in recipients) {
      final recRef = doc.collection('Recipients').doc(r.userId);
      batch.set(recRef, {
        'schoolId': schoolId,
        'circularId': id,
        'circularTitle': title,
        'circularNumber': circularNumber,
        'attachmentType': attachmentType.name,
        'attachmentUrl': url,
        'circularCreatedAt': FieldValue.serverTimestamp(),
        'circularCreatedAtMs': nowMs,
        'userId': r.userId,
        'name': r.name,
        'role': r.role,
        'acknowledged': false,
        'acknowledgedAt': null,
        'viewedAt': null,
        'viewDurationMs': 0,
      }, SetOptions(merge: true));
    }
    batch.set(doc, {
      'recipientsCount': recipients.length,
      'acknowledgedCount': 0,
    }, SetOptions(merge: true));
    await batch.commit();

    return id;
  }

  Future<void> recordView({
    required String schoolId,
    required String circularId,
    required String userId,
    required String device,
    required String platform,
    required String userAgent,
  }) async {
    await _functions.httpsCallable('recordStaffCircularView').call({
      'schoolId': schoolId,
      'circularId': circularId,
      'device': device,
      'platform': platform,
      'userAgent': userAgent,
    });
  }

  Future<void> finalizeView({
    required String schoolId,
    required String circularId,
    required int viewDurationMs,
    required String device,
    required String platform,
    required String userAgent,
  }) async {
    await _functions.httpsCallable('finalizeStaffCircularView').call({
      'schoolId': schoolId,
      'circularId': circularId,
      'viewDurationMs': viewDurationMs,
      'device': device,
      'platform': platform,
      'userAgent': userAgent,
    });
  }

  Future<void> acknowledge({
    required String schoolId,
    required String circularId,
    required String userId,
    required String userName,
    required String userRole,
    required String device,
    required String platform,
    required String userAgent,
    required int viewDurationMs,
  }) async {
    await _functions.httpsCallable('acknowledgeStaffCircular').call({
      'schoolId': schoolId,
      'circularId': circularId,
      'device': device,
      'platform': platform,
      'userAgent': userAgent,
      'viewDurationMs': viewDurationMs,
    });
  }

  Future<Uint8List?> downloadAttachmentBytes(String url) async {
    if (kIsWeb) return null;
    return null;
  }
}
