import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/schedule_campaign.dart';
import '../domain/teacher_response.dart';

final campaignServiceProvider = Provider<CampaignService>((ref) {
  return CampaignService();
});

class CampaignService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🚀 إنشاء حملة جديدة
  Future<ScheduleCampaign> createCampaign({
    required String schoolId,
    required DateTime startDate,
    required DateTime endDate,
    required Duration responseTime,
    required String createdBy,
    String? message,
    Map<String, dynamic>? settings,
  }) async {
    final campaignRef = _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc();

    final campaign = ScheduleCampaign(
      id: campaignRef.id,
      schoolId: schoolId,
      startDate: startDate,
      endDate: endDate,
      responseTime: responseTime,
      message: message,
      status: CampaignStatus.draft,
      settings: settings ?? {},
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    await campaignRef.set(campaign.toMap());

    return campaign;
  }

  // 🎯 إطلاق الحملة
  Future<void> launchCampaign(String campaignId, String schoolId) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .update({
      'status': CampaignStatus.active.name,
      'startDate': DateTime.now().toIso8601String(),
    });
  }

  // 📝 جمع رد المعلم
  Future<void> collectResponse({
    required String campaignId,
    required String schoolId,
    required String teacherId,
    required String teacherName,
    required ResponseType response,
    List<BlockedSlot>? blockedSlots,
    String? notes,
  }) async {
    final responseDoc = TeacherResponse(
      id: '${campaignId}_$teacherId',
      campaignId: campaignId,
      teacherId: teacherId,
      teacherName: teacherName,
      response: response,
      blockedSlots: blockedSlots ?? [],
      respondedAt: DateTime.now(),
      notes: notes,
    );

    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .collection('Responses')
        .doc(teacherId)
        .set(responseDoc.toMap());

    // تحديث إحصائيات الحملة
    await _updateCampaignStatistics(campaignId, schoolId);
  }

  // 📊 تحديث الإحصائيات
  Future<void> _updateCampaignStatistics(String campaignId, String schoolId) async {
    final responses = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .collection('Responses')
        .get();

    int yesCount = 0;
    int noCount = 0;

    for (var doc in responses.docs) {
      final response = TeacherResponse.fromMap(doc.data());
      if (response.response == ResponseType.yes) {
        yesCount++;
      } else if (response.response == ResponseType.no) {
        noCount++;
      }
    }

    final campaign = await getCampaign(campaignId, schoolId);
    final notResponded = campaign.totalTeachers - (yesCount + noCount);

    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .update({
      'respondedYes': yesCount,
      'respondedNo': noCount,
      'notResponded': notResponded,
    });
  }

  // 📈 الحصول على إحصائيات مباشرة
  Stream<CampaignStatistics> getCampaignStatistics(String campaignId, String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .snapshots()
        .asyncMap((doc) async {
      if (!doc.exists) {
        throw Exception('Campaign not found');
      }

      final campaign = ScheduleCampaign.fromMap(doc.data()!);
      
      // جلب الحصص الأكثر استبعاداً
      final responses = await _firestore
          .collection('Schools')
          .doc(schoolId)
          .collection('ScheduleCampaigns')
          .doc(campaignId)
          .collection('Responses')
          .where('response', isEqualTo: ResponseType.yes.name)
          .get();

      final Map<String, int> slotCounts = {};
      for (var doc in responses.docs) {
        final response = TeacherResponse.fromMap(doc.data());
        for (var slot in response.blockedSlots) {
          final key = '${slot.day}_${slot.period}';
          slotCounts[key] = (slotCounts[key] ?? 0) + 1;
        }
      }

      final mostBlocked = slotCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return CampaignStatistics(
        campaign: campaign,
        mostBlockedSlots: mostBlocked.take(5).toList(),
      );
    });
  }

  // 📧 إرسال تذكير
  Future<void> sendReminder(String campaignId, String schoolId) async {
    // سيتم تنفيذه عبر Cloud Function
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('CampaignReminders')
        .add({
      'campaignId': campaignId,
      'sentAt': DateTime.now().toIso8601String(),
    });
  }

  // 🔒 إغلاق الحملة
  Future<void> closeCampaign(String campaignId, String schoolId) async {
    await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .update({
      'status': CampaignStatus.closed.name,
    });
  }

  // 📖 الحصول على حملة
  Future<ScheduleCampaign> getCampaign(String campaignId, String schoolId) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .get();

    if (!doc.exists) {
      throw Exception('Campaign not found');
    }

    return ScheduleCampaign.fromMap(doc.data()!);
  }

  // 📋 الحصول على ردود المعلمين
  Future<List<TeacherResponse>> getResponses(String campaignId, String schoolId) async {
    final snapshot = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .collection('Responses')
        .get();

    return snapshot.docs
        .map((doc) => TeacherResponse.fromMap(doc.data()))
        .toList();
  }

  // 🔍 الحصول على رد معلم محدد
  Future<TeacherResponse?> getTeacherResponse({
    required String campaignId,
    required String schoolId,
    required String teacherId,
  }) async {
    final doc = await _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .doc(campaignId)
        .collection('Responses')
        .doc(teacherId)
        .get();

    if (!doc.exists) return null;

    return TeacherResponse.fromMap(doc.data()!);
  }

  // 📊 الحصول على حملات المدرسة
  Stream<List<ScheduleCampaign>> getSchoolCampaigns(String schoolId) {
    return _firestore
        .collection('Schools')
        .doc(schoolId)
        .collection('ScheduleCampaigns')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ScheduleCampaign.fromMap(doc.data()))
            .toList());
  }
}

// 📊 إحصائيات الحملة
class CampaignStatistics {
  final ScheduleCampaign campaign;
  final List<MapEntry<String, int>> mostBlockedSlots;

  CampaignStatistics({
    required this.campaign,
    required this.mostBlockedSlots,
  });
}
