import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/domain/models/user.dart';

enum ClassClimateStatus { positive, average, needsSupport, neutral, unknown }

/// Configuration policy for Class Climate calculations.
/// Allows customization of thresholds and safety limits.
class ClassClimatePolicy {
  final int minClassSize;
  final double positiveThreshold;
  final double averageThreshold;

  const ClassClimatePolicy({
    this.minClassSize = 10,
    this.positiveThreshold = 85.0,
    this.averageThreshold = 65.0,
  });
}

class ClassClimateResult {
  final ClassClimateStatus status;
  final String message;
  final Color color;
  final IconData icon;

  ClassClimateResult({
    required this.status,
    required this.message,
    required this.color,
    this.icon = Icons.groups_outlined,
  });
}

class ClassClimateService {
  final FirebaseFirestore _firestore;

  ClassClimateService(this._firestore);

  Future<ClassClimateResult> getClassClimate(User student) async {
    const policy = ClassClimatePolicy();

    if (student.schoolId == null ||
        (student.assignedClassIds?.isEmpty ?? true)) {
      return ClassClimateResult(
        status: ClassClimateStatus.unknown,
        message: "لم يتم تحديد الفصل الدراسي.",
        color: Colors.grey,
      );
    }

    try {
      final classId = student.assignedClassIds!.first; // Primary class

      // Fetch students in this class to calculate aggregate signal
      // We do NOT store relationships or expose individual data.
      final querySnapshot = await _firestore
          .collection('Schools')
          .doc(student.schoolId)
          .collection('Students')
          .where('assignedClassIds', arrayContains: classId)
          .limit(50) // Optimization limit
          .get();

      if (querySnapshot.docs.isEmpty) {
        return ClassClimateResult(
          status: ClassClimateStatus.unknown,
          message: "لا توجد بيانات كافية عن البيئة الصفية.",
          color: Colors.grey,
        );
      }

      int totalScore = 0;
      int count = 0;

      for (var doc in querySnapshot.docs) {
        final data = doc.data();
        final score = data['excellenceScore'] as int? ?? 100;
        totalScore += score;
        count++;
      }

      if (count == 0) {
        return ClassClimateResult(
          status: ClassClimateStatus.unknown,
          message: "بيانات غير كافية",
          color: Colors.grey,
        );
      }

      // 1. Safety Rule: Minimum Class Size Check
      // If class size is too small, avoid specific indicators to prevent deduction.
      if (count < policy.minClassSize) {
        return ClassClimateResult(
          status: ClassClimateStatus.neutral,
          message: "حافظ على سلوكك الإيجابي وركز على تقدمك الدراسي.",
          color: Colors.indigo.shade400, // Neutral/Safe color
          icon: Icons
              .school_outlined, // Generic school icon, no group implication
        );
      }

      final average = totalScore / count;

      // 2. Thresholds from Policy (Configurable)
      if (average >= policy.positiveThreshold) {
        return ClassClimateResult(
          status: ClassClimateStatus.positive,
          message:
              "بيئة إيجابية: بيئتك الدراسية إيجابية ومحفزة، حافظ على مستواك.",
          color: Colors.green.shade700,
          icon: Icons.sentiment_satisfied_alt,
        );
      } else if (average >= policy.averageThreshold) {
        return ClassClimateResult(
          status: ClassClimateStatus.average,
          message:
              "بيئة متوسطة: احرص على اختيار بيئة دراسية تساعدك على التركيز والتميز.",
          color: Colors.orange.shade800,
          icon: Icons.balance,
        );
      } else {
        return ClassClimateResult(
          status: ClassClimateStatus.needsSupport,
          message:
              "بيئة تحتاج دعم: وجودك في بيئة دراسية متوازنة يبدأ باختيارك الشخصي للسلوك الإيجابي.",
          color: Colors.red.shade700,
          icon: Icons.volunteer_activism,
        );
      }
    } catch (e) {
      return ClassClimateResult(
        status: ClassClimateStatus.unknown,
        message: "تعذر تحميل مؤشر البيئة الصفية.",
        color: Colors.grey,
      );
    }
  }
}

final classClimateServiceProvider = Provider<ClassClimateService>((ref) {
  return ClassClimateService(FirebaseFirestore.instance);
});

final classClimateProvider = FutureProvider.family<ClassClimateResult, User>((
  ref,
  student,
) async {
  final service = ref.watch(classClimateServiceProvider);
  return service.getClassClimate(student);
});
