import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/location_service.dart';
import '../../academic/data/school_repository.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/permission_request.dart';
import 'permission_repository.dart'; // Import requestsProvider

// Provider for GeofenceService
final geofenceServiceProvider = Provider<GeofenceService>((ref) {
  return GeofenceService(
    ref,
    ref.watch(locationServiceProvider),
    ref.watch(schoolRepositoryProvider),
  );
});

// Provider for LocationService
final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

class GeofenceService {
  final Ref _ref;
  final LocationService _locationService;
  final SchoolRepository _schoolRepository;

  StreamSubscription<Position>? _positionStreamSubscription;
  Timer? _pollingTimer;
  bool _isMonitoring = false;
  String? _currentParentId;
  // String? _currentParentName; // Removed unused field

  // Constants
  static const double geofenceRadiusMeters = 500.0;
  static const int pollingIntervalSeconds = 30;

  GeofenceService(this._ref, this._locationService, this._schoolRepository);

  void startMonitoring(String parentId, String parentName) async {
    if (_isMonitoring) return;
    _currentParentId = parentId;
    // _currentParentName = parentName;
    _isMonitoring = true;

    // Check permissions first
    final hasPermission = await _locationService.requestPermission();
    if (!hasPermission) {
      _isMonitoring = false;
      return;
    }

    // Start polling
    _pollingTimer = Timer.periodic(
      const Duration(seconds: pollingIntervalSeconds),
      (_) => _checkLocationAndNotify(),
    );

    // Also check immediately
    _checkLocationAndNotify();
  }

  void stopMonitoring() {
    _pollingTimer?.cancel();
    _positionStreamSubscription?.cancel();
    _isMonitoring = false;
    _currentParentId = null;
  }

  Future<void> _checkLocationAndNotify() async {
    if (_currentParentId == null) return;

    try {
      // 1. Get Parent's Active Permissions (Approved only) via requestsProvider
      final requests = _ref.read(requestsProvider);
      final activeRequests = requests
          .where(
            (r) =>
                r.parentId == _currentParentId &&
                r.status == PermissionRequestStatus.approved &&
                !r.isParentNear,
          )
          .toList();

      if (activeRequests.isEmpty) return;

      // 2. Get Current Position
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;

      // 3. Check distance for each relevant school
      final currentUser = _ref.read(authStateProvider).value;
      final schoolId = currentUser?.schoolId;

      if (schoolId == null) return;

      final school = await _schoolRepository.getSchool(schoolId);
      if (school == null ||
          school.latitude == null ||
          school.longitude == null) {
        return;
      }

      final distance = _locationService.calculateDistanceInMeters(
        position.latitude,
        position.longitude,
        school.latitude!,
        school.longitude!,
      );

      // 4. If within radius, update requests
      if (distance <= geofenceRadiusMeters) {
        await _notifyArrival(activeRequests);
      }
    } catch (e) {
      // ignore: avoid_print
      print('Geofence check failed: $e');
    }
  }

  Future<void> _notifyArrival(List<PermissionRequest> requests) async {
    for (var request in requests) {
      await _ref
          .read(requestsProvider.notifier)
          .notifyParentArrival(request.id);
    }
    debugPrint('Parent Arrival Notified for ${requests.length} requests');
  }
}
