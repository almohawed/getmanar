import 'package:flutter/material.dart';
import '../domain/models/user.dart';

/// Returns the color for the student's name based on their health status.
/// 
/// - Red: Needs frequent restroom access or critical care.
/// - Yellow: Has a health condition (chronic or other).
/// - Black: Healthy.
/// 
/// This logic is hidden from students and parents.
Color getStudentHealthColor(User student, UserRole viewerRole) {
  // Hide colors from students and parents
  if (viewerRole == UserRole.student || viewerRole == UserRole.parent) {
    return Colors.black;
  }

  // Check for specific health needs first (Red priority)
  if (student.healthNeeds == 'frequent_restroom' || student.healthStatus == 'critical') {
    return Colors.red;
  }

  // Check for general health conditions (Yellow)
  if (student.healthStatus != null && student.healthStatus!.isNotEmpty && student.healthStatus != 'healthy') {
    return Colors.amber.shade800; // Darker yellow for better readability on white
  }

  // Default (Healthy)
  return Colors.black;
}
