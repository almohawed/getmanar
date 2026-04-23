import 'package:cloud_firestore/cloud_firestore.dart';

enum MaintenancePriority { low, medium, high, critical }

enum MaintenanceStatus { pending, inProgress, completed, rejected, overdue }

class MaintenanceReport {
  final String id;
  final String title;
  final String description;
  final String location;
  final MaintenancePriority priority;
  final MaintenanceStatus status;
  final DateTime createdAt;
  final String reporterId;
  final String? assignedTo;
  final int evidenceCount;
  final DateTime? dueAt;
  final String? maintenanceEmail; // إيميل فريق الصيانة

  MaintenanceReport({
    required this.id,
    required this.title,
    required this.description,
    required this.location,
    required this.priority,
    required this.status,
    required this.createdAt,
    required this.reporterId,
    this.assignedTo,
    this.evidenceCount = 0,
    this.dueAt,
    this.maintenanceEmail,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'location': location,
      'priority': priority.name,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'reporterId': reporterId,
      'assignedTo': assignedTo,
      'evidenceCount': evidenceCount,
      'dueAt': dueAt != null ? Timestamp.fromDate(dueAt!) : null,
      'maintenanceEmail': maintenanceEmail,
    };
  }

  factory MaintenanceReport.fromMap(Map<String, dynamic> map) {
    DateTime parseDate(dynamic val) {
      if (val is Timestamp) return val.toDate();
      if (val is String) return DateTime.parse(val);
      return DateTime.now(); // Fallback
    }

    return MaintenanceReport(
      id: map['id'] ?? '',
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      location: map['location'] ?? '',
      priority: MaintenancePriority.values.firstWhere(
        (e) => e.name == map['priority'],
        orElse: () => MaintenancePriority.low,
      ),
      status: MaintenanceStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MaintenanceStatus.pending,
      ),
      createdAt: parseDate(map['createdAt']),
      reporterId: map['reporterId'] ?? '',
      assignedTo: map['assignedTo'],
      evidenceCount: map['evidenceCount'] ?? 0,
      dueAt: map['dueAt'] != null ? parseDate(map['dueAt']) : null,
      maintenanceEmail: map['maintenanceEmail'],
    );
  }
}
