import 'package:cloud_firestore/cloud_firestore.dart';
import '../domain/announcement.dart';

class AnnouncementService {
  static final AnnouncementService _instance = AnnouncementService._internal();
  factory AnnouncementService() => _instance;
  AnnouncementService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> _col(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('Announcements');
  }

  Future<List<Announcement>> fetchAnnouncements(String schoolId) async {
    final snap = await _col(schoolId)
        .orderBy('publishDate', descending: true)
        .limit(200)
        .get();
    return snap.docs.map(_fromDoc).toList();
  }

  Future<Map<String, dynamic>> fetchStatistics(String schoolId) async {
    final items = await fetchAnnouncements(schoolId);
    final now = DateTime.now();
    final today = items
        .where(
          (a) =>
              a.publishDate.year == now.year &&
              a.publishDate.month == now.month &&
              a.publishDate.day == now.day,
        )
        .length;
    final thisWeek =
        items.where((a) => a.publishDate.isAfter(now.subtract(const Duration(days: 7)))).length;
    final active = items.where((a) => a.status == AnnouncementStatus.active).length;
    final totalViews = items.fold<int>(0, (sum, a) => sum + a.viewCount);
    return {
      'today': today,
      'thisWeek': thisWeek,
      'active': active,
      'totalViews': totalViews,
    };
  }

  Future<void> createAnnouncement(String schoolId, Announcement announcement) async {
    await _col(schoolId).doc(announcement.id).set(_toMap(announcement));
  }

  Announcement _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    DateTime asDate(dynamic v) {
      if (v is Timestamp) return v.toDate();
      if (v is DateTime) return v;
      return DateTime.tryParse(v?.toString() ?? '') ?? DateTime.now();
    }

    TargetAudience audience(dynamic v) {
      final s = (v ?? '').toString();
      for (final a in TargetAudience.values) {
        if (a.name == s) return a;
      }
      return TargetAudience.all;
    }

    AnnouncementType type(dynamic v) {
      final s = (v ?? '').toString();
      for (final t in AnnouncementType.values) {
        if (t.name == s) return t;
      }
      return AnnouncementType.general;
    }

    AnnouncementStatus status(dynamic v) {
      final s = (v ?? '').toString();
      for (final st in AnnouncementStatus.values) {
        if (st.name == s) return st;
      }
      return AnnouncementStatus.active;
    }

    return Announcement(
      id: doc.id,
      title: (data['title'] as String?)?.trim() ?? '',
      content: (data['content'] as String?)?.trim() ?? '',
      targetAudience: audience(data['targetAudience']),
      type: type(data['type']),
      status: status(data['status']),
      publishDate: asDate(data['publishDate']),
      viewCount: (data['viewCount'] as num?)?.toInt() ?? 0,
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      creatorName: (data['creatorName'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> _toMap(Announcement a) {
    return {
      'title': a.title.trim(),
      'content': a.content.trim(),
      'targetAudience': a.targetAudience.name,
      'type': a.type.name,
      'status': a.status.name,
      'publishDate': Timestamp.fromDate(a.publishDate),
      'viewCount': a.viewCount,
      'imageUrl': a.imageUrl,
      'creatorName': a.creatorName.trim(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }
}
