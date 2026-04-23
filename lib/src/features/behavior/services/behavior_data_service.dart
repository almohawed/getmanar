import 'package:cloud_firestore/cloud_firestore.dart';

/// خدمة مركزية لإدارة بيانات السلوك والربط بين جميع الأقسام
class BehaviorDataService {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Collections
  static const String _behavioralCasesCollection = 'behavioral_cases';
  static const String _behavioralViolationsCollection = 'behavioral_violations';
  static const String _positiveBehaviorCollection = 'positive_behavior';
  static const String _studentsCollection = 'students';
  static const String _behaviorStatsCollection = 'behavior_stats';

  /// إضافة حالة سلوكية جديدة مع تحديث جميع الإحصائيات
  static Future<String> addBehavioralCase({
    required String studentName,
    required String studentId,
    required String caseType,
    required String priority,
    required String description,
    required String assignedTo,
    String? studentGrade,
    String? studentClass,
  }) async {
    try {
      // إضافة الحالة
      final caseRef = await _firestore.collection(_behavioralCasesCollection).add({
        'studentName': studentName,
        'studentId': studentId,
        'caseType': caseType,
        'priority': priority,
        'description': description,
        'assignedTo': assignedTo,
        'studentGrade': studentGrade,
        'studentClass': studentClass,
        'status': 'active',
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'followUps': [],
      });

      // تحديث إحصائيات الطالب
      await _updateStudentBehaviorStats(studentId, studentName);
      
      // تحديث الإحصائيات العامة
      await _updateGeneralBehaviorStats();
      
      // إضافة إشعار للمسؤولين
      await _addBehaviorNotification(
        studentName: studentName,
        caseType: caseType,
        priority: priority,
        caseId: caseRef.id,
      );

      return caseRef.id;
    } catch (e) {
      throw Exception('خطأ في إضافة الحالة السلوكية: $e');
    }
  }

  /// إضافة مخالفة سلوكية مع تحديث الإحصائيات
  static Future<String> addBehavioralViolation({
    required String studentName,
    required String studentId,
    required String violationType,
    required String level,
    required String description,
    required int points,
    String? studentGrade,
    String? studentClass,
  }) async {
    try {
      // إضافة المخالفة
      final violationRef = await _firestore.collection(_behavioralViolationsCollection).add({
        'studentName': studentName,
        'studentId': studentId,
        'violationType': violationType,
        'level': level,
        'description': description,
        'points': points,
        'studentGrade': studentGrade,
        'studentClass': studentClass,
        'timestamp': Timestamp.now(),
        'status': 'active',
      });

      // تحديث إحصائيات الطالب
      await _updateStudentBehaviorStats(studentId, studentName);
      
      // تحديث الإحصائيات العامة
      await _updateGeneralBehaviorStats();

      // إنشاء حالة سلوكية تلقائياً للمخالفات الخطيرة
      if (level == 'خطيرة' || level == 'شديدة') {
        await addBehavioralCase(
          studentName: studentName,
          studentId: studentId,
          caseType: 'سلوكي',
          priority: 'عالي',
          description: 'حالة تلقائية بسبب مخالفة: $violationType',
          assignedTo: 'المرشد الطلابي',
          studentGrade: studentGrade,
          studentClass: studentClass,
        );
      }

      return violationRef.id;
    } catch (e) {
      throw Exception('خطأ في إضافة المخالفة: $e');
    }
  }

  /// إضافة سلوك إيجابي مع تحديث الإحصائيات
  static Future<String> addPositiveBehavior({
    required String studentName,
    required String studentId,
    required String behaviorType,
    required String description,
    required int points,
    String? studentGrade,
    String? studentClass,
  }) async {
    try {
      // إضافة السلوك الإيجابي
      final behaviorRef = await _firestore.collection(_positiveBehaviorCollection).add({
        'studentName': studentName,
        'studentId': studentId,
        'behaviorType': behaviorType,
        'description': description,
        'points': points,
        'studentGrade': studentGrade,
        'studentClass': studentClass,
        'timestamp': Timestamp.now(),
      });

      // تحديث إحصائيات الطالب
      await _updateStudentBehaviorStats(studentId, studentName);
      
      // تحديث الإحصائيات العامة
      await _updateGeneralBehaviorStats();

      return behaviorRef.id;
    } catch (e) {
      throw Exception('خطأ في إضافة السلوك الإيجابي: $e');
    }
  }

  /// تحديث إحصائيات الطالب
  static Future<void> _updateStudentBehaviorStats(String studentId, String studentName) async {
    try {
      // جلب مخالفات الطالب
      final violations = await _firestore
          .collection(_behavioralViolationsCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      // جلب السلوك الإيجابي للطالب
      final positiveBehavior = await _firestore
          .collection(_positiveBehaviorCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      // جلب الحالات السلوكية للطالب
      final behavioralCases = await _firestore
          .collection(_behavioralCasesCollection)
          .where('studentId', isEqualTo: studentId)
          .get();

      // حساب النقاط
      int violationPoints = 0;
      int positivePoints = 0;
      
      for (var violation in violations.docs) {
        violationPoints += (violation.data()['points'] as int? ?? 0);
      }
      
      for (var positive in positiveBehavior.docs) {
        positivePoints += (positive.data()['points'] as int? ?? 0);
      }

      final netScore = positivePoints - violationPoints;
      
      // تحديد التصنيف السلوكي
      String behaviorCategory;
      if (netScore >= 10) {
        behaviorCategory = 'ممتاز';
      } else if (netScore >= 0) {
        behaviorCategory = 'جيد';
      } else if (netScore >= -5) {
        behaviorCategory = 'يحتاج متابعة';
      } else {
        behaviorCategory = 'حرج';
      }

      // تحديث بيانات الطالب
      await _firestore.collection(_studentsCollection).doc(studentId).update({
        'behaviorStats': {
          'violationCount': violations.docs.length,
          'positiveCount': positiveBehavior.docs.length,
          'casesCount': behavioralCases.docs.length,
          'violationPoints': violationPoints,
          'positivePoints': positivePoints,
          'netScore': netScore,
          'behaviorCategory': behaviorCategory,
          'lastUpdated': Timestamp.now(),
        }
      });

    } catch (e) {
      print('خطأ في تحديث إحصائيات الطالب: $e');
    }
  }

  /// تحديث الإحصائيات العامة للمدرسة
  static Future<void> _updateGeneralBehaviorStats() async {
    try {
      // جلب جميع البيانات
      final violations = await _firestore.collection(_behavioralViolationsCollection).get();
      final positiveBehavior = await _firestore.collection(_positiveBehaviorCollection).get();
      final behavioralCases = await _firestore.collection(_behavioralCasesCollection).get();
      final students = await _firestore.collection(_studentsCollection).get();

      // حساب الإحصائيات
      final totalViolations = violations.docs.length;
      final totalPositive = positiveBehavior.docs.length;
      final totalCases = behavioralCases.docs.length;
      final totalStudents = students.docs.length;
      
      final activeCases = behavioralCases.docs.where((doc) => 
          (doc.data() as Map)['status'] == 'active').length;
      
      final criticalCases = behavioralCases.docs.where((doc) {
        final data = doc.data() as Map;
        return data['priority'] == 'عالي' && data['status'] == 'active';
      }).length;

      // حساب مؤشر السلوك العام
      final behaviorScore = totalStudents > 0 
          ? ((totalPositive - totalViolations) / totalStudents * 100).clamp(0, 100)
          : 0;

      // تحليل المخالفات حسب النوع
      Map<String, int> violationsByType = {};
      Map<String, int> violationsByLevel = {};
      Map<String, int> casesByType = {};
      Map<String, int> casesByPriority = {};

      for (var doc in violations.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['violationType'] ?? 'غير محدد';
        final level = data['level'] ?? 'غير محدد';
        
        violationsByType[type] = (violationsByType[type] ?? 0) + 1;
        violationsByLevel[level] = (violationsByLevel[level] ?? 0) + 1;
      }

      for (var doc in behavioralCases.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final type = data['caseType'] ?? 'غير محدد';
        final priority = data['priority'] ?? 'غير محدد';
        
        casesByType[type] = (casesByType[type] ?? 0) + 1;
        casesByPriority[priority] = (casesByPriority[priority] ?? 0) + 1;
      }

      // حفظ الإحصائيات العامة
      await _firestore.collection(_behaviorStatsCollection).doc('general').set({
        'totalViolations': totalViolations,
        'totalPositive': totalPositive,
        'totalCases': totalCases,
        'activeCases': activeCases,
        'criticalCases': criticalCases,
        'totalStudents': totalStudents,
        'behaviorScore': behaviorScore.round(),
        'violationsByType': violationsByType,
        'violationsByLevel': violationsByLevel,
        'casesByType': casesByType,
        'casesByPriority': casesByPriority,
        'lastUpdated': Timestamp.now(),
      }, SetOptions(merge: true));

    } catch (e) {
      print('خطأ في تحديث الإحصائيات العامة: $e');
    }
  }

  /// إضافة إشعار للمسؤولين
  static Future<void> _addBehaviorNotification({
    required String studentName,
    required String caseType,
    required String priority,
    required String caseId,
  }) async {
    try {
      await _firestore.collection('notifications').add({
        'title': 'حالة سلوكية جديدة',
        'body': 'تم إنشاء حالة سلوكية جديدة للطالب $studentName',
        'type': 'behavioral_case',
        'priority': priority,
        'data': {
          'studentName': studentName,
          'caseType': caseType,
          'caseId': caseId,
        },
        'timestamp': Timestamp.now(),
        'isRead': false,
        'targetRoles': ['admin', 'deputy', 'counselor'],
      });
    } catch (e) {
      print('خطأ في إضافة الإشعار: $e');
    }
  }

  /// تحديث الإحصائيات من البيانات الموجودة (للمزامنة الأولية)
  static Future<void> refreshStatsFromExistingData() async {
    try {
      await _updateGeneralBehaviorStats();
    } catch (e) {
      print('خطأ في تحديث الإحصائيات: $e');
    }
  }

  /// جلب الإحصائيات العامة
  static Future<Map<String, dynamic>> getGeneralBehaviorStats() async {
    try {
      final doc = await _firestore.collection(_behaviorStatsCollection).doc('general').get();
      if (doc.exists) {
        return doc.data() as Map<String, dynamic>;
      }
      
      // إذا لم توجد إحصائيات، قم بإنشائها
      await _updateGeneralBehaviorStats();
      final newDoc = await _firestore.collection(_behaviorStatsCollection).doc('general').get();
      return newDoc.data() as Map<String, dynamic>? ?? {};
    } catch (e) {
      print('خطأ في جلب الإحصائيات: $e');
      return {};
    }
  }

  /// جلب إحصائيات طالب محدد
  static Future<Map<String, dynamic>> getStudentBehaviorStats(String studentId) async {
    try {
      final doc = await _firestore.collection(_studentsCollection).doc(studentId).get();
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        return data['behaviorStats'] as Map<String, dynamic>? ?? {};
      }
      return {};
    } catch (e) {
      print('خطأ في جلب إحصائيات الطالب: $e');
      return {};
    }
  }

  /// Stream للإحصائيات العامة (للتحديث المباشر)
  static Stream<Map<String, dynamic>> getBehaviorStatsStream() {
    return _firestore
        .collection(_behaviorStatsCollection)
        .doc('general')
        .snapshots()
        .map((doc) => doc.exists ? doc.data() as Map<String, dynamic> : {});
  }

  /// Stream للحالات النشطة (للتحديث المباشر)
  static Stream<List<Map<String, dynamic>>> getActiveCasesStream() {
    return _firestore
        .collection(_behavioralCasesCollection)
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
          final data = doc.data() as Map<String, dynamic>;
          data['id'] = doc.id;
          return data;
        }).toList());
  }

  /// إغلاق حالة سلوكية مع تحديث الإحصائيات
  static Future<void> closeBehavioralCase(String caseId, String reason) async {
    try {
      await _firestore.collection(_behavioralCasesCollection).doc(caseId).update({
        'status': 'closed',
        'closedAt': Timestamp.now(),
        'closedReason': reason,
        'updatedAt': Timestamp.now(),
      });

      // تحديث الإحصائيات العامة
      await _updateGeneralBehaviorStats();
    } catch (e) {
      throw Exception('خطأ في إغلاق الحالة: $e');
    }
  }

  /// إضافة متابعة لحالة سلوكية
  static Future<void> addCaseFollowUp(String caseId, String followUpText, String createdBy) async {
    try {
      final caseDoc = await _firestore.collection(_behavioralCasesCollection).doc(caseId).get();
      if (caseDoc.exists) {
        final data = caseDoc.data() as Map<String, dynamic>;
        final followUps = List<Map<String, dynamic>>.from(data['followUps'] ?? []);
        
        followUps.add({
          'text': followUpText,
          'createdAt': Timestamp.now(),
          'createdBy': createdBy,
        });

        await _firestore.collection(_behavioralCasesCollection).doc(caseId).update({
          'followUps': followUps,
          'updatedAt': Timestamp.now(),
        });
      }
    } catch (e) {
      throw Exception('خطأ في إضافة المتابعة: $e');
    }
  }
}