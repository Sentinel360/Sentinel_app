import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';
import 'trip_service.dart';
import 'emergency_service.dart';
import 'route_service.dart';

class AnomalyService {
  final TripService _tripService = TripService();
  final EmergencyService _emergencyService = EmergencyService();
  final RouteService _routeService = RouteService();

  // Accelerometer thresholds (in m/s²)
  // Based on: Mukherjee et al. (2017) - "Accident Detection Using Accelerometer"
  // Normal driving: < 9.8 m/s² (1g)
  // Hard braking: > 11.76 m/s² (1.2g)
  // Crash/Impact: > 19.6 m/s² (2g)
  static const double hardBrakingThreshold = 11.76;
  static const double crashThreshold = 19.6;

  // Gyroscope thresholds (in rad/s)
  // Sharp turn: > 1.5 rad/s
  // Dangerous tilt: > 2.0 rad/s
  static const double sharpTurnThreshold = 1.5;
  static const double dangerousTiltThreshold = 2.0;

  // Route deviation threshold in meters
  static const double routeDeviationThreshold = 50.0;

  // Analyze accelerometer data for motion anomalies
  Future<void> analyzeAccelerometer({
    required String tripId,
    required String userId,
    required double x,
    required double y,
    required double z,
    required GeoPoint currentLocation,
  }) async {
    // Calculate resultant acceleration magnitude
    final double magnitude = _calculateMagnitude(x, y, z);

    if (magnitude >= crashThreshold) {
      await _handleAnomaly(
        tripId: tripId,
        userId: userId,
        type: 'Crash Detected',
        location: _geoPointToString(currentLocation),
        severity: 'high',
        currentLocation: currentLocation,
      );
    } else if (magnitude >= hardBrakingThreshold) {
      await _handleAnomaly(
        tripId: tripId,
        userId: userId,
        type: 'Hard Braking',
        location: _geoPointToString(currentLocation),
        severity: 'medium',
        currentLocation: currentLocation,
      );
    }
  }

  // Analyze gyroscope data for tilt and turn anomalies
  Future<void> analyzeGyroscope({
    required String tripId,
    required String userId,
    required double x,
    required double y,
    required double z,
    required GeoPoint currentLocation,
  }) async {
    final double magnitude = _calculateMagnitude(x, y, z);

    if (magnitude >= dangerousTiltThreshold) {
      await _handleAnomaly(
        tripId: tripId,
        userId: userId,
        type: 'Dangerous Tilt',
        location: _geoPointToString(currentLocation),
        severity: 'high',
        currentLocation: currentLocation,
      );
    } else if (magnitude >= sharpTurnThreshold) {
      await _handleAnomaly(
        tripId: tripId,
        userId: userId,
        type: 'Sharp Turn',
        location: _geoPointToString(currentLocation),
        severity: 'low',
        currentLocation: currentLocation,
      );
    }
  }

  // Analyze GPS for route deviation
  Future<void> analyzeRouteDeviation({
    required String tripId,
    required String userId,
    required GeoPoint currentLocation,
    required List<GeoPoint> routePolyline,
  }) async {
    if (routePolyline.isEmpty) return;

    final bool withinRoute = _routeService.isWithinRouteCorridor(
      currentLocation: currentLocation,
      routePolyline: routePolyline,
      thresholdMeters: routeDeviationThreshold,
    );

    if (!withinRoute) {
      await _handleAnomaly(
        tripId: tripId,
        userId: userId,
        type: 'Route Deviation',
        location: _geoPointToString(currentLocation),
        severity: 'medium',
        currentLocation: currentLocation,
      );
    }
  }

  // Central anomaly handler — records anomaly and decides escalation
  Future<void> _handleAnomaly({
    required String tripId,
    required String userId,
    required String type,
    required String location,
    required String severity,
    required GeoPoint currentLocation,
  }) async {
    // Record the anomaly in the trip document
    final anomaly = AnomalyEvent(
      type: type,
      location: location,
      detectedAt: DateTime.now(),
      severity: severity,
    );

    await _tripService.addAnomaly(tripId: tripId, anomaly: anomaly);

    // High severity anomalies escalate immediately
    if (severity == 'high') {
      await _escalateToEmergency(
        tripId: tripId,
        userId: userId,
        currentLocation: currentLocation,
        triggerSource: 'auto',
      );
      return;
    }

    // Medium severity increments escalation counter
    if (severity == 'medium') {
      await _tripService.incrementEscalation(tripId);

      // Fetch current escalation count
      final trip = await _tripService.getTripById(tripId);
      if (trip == null) return;

      // After 3 unanswered escalations, trigger emergency
      if (trip.escalationAttempts >= 3) {
        await _escalateToEmergency(
          tripId: tripId,
          userId: userId,
          currentLocation: currentLocation,
          triggerSource: 'auto',
        );
      }
    }

    // Low severity anomalies are just recorded, no escalation
  }

  // Trigger full emergency protocol
  Future<void> _escalateToEmergency({
    required String tripId,
    required String userId,
    required GeoPoint currentLocation,
    required String triggerSource,
  }) async {
    await _emergencyService.triggerEmergency(
      userId: userId,
      tripId: tripId,
      location: currentLocation,
      triggerSource: triggerSource,
    );
  }

  // User confirms they are safe — reset escalation counter
  Future<void> confirmUserSafe(String tripId) async {
    await _tripService.resetEscalation(tripId);
  }

  // Calculate resultant magnitude from x, y, z components
  double _calculateMagnitude(double x, double y, double z) {
    return (x * x + y * y + z * z) < 0 ? 0 : _sqrt(x * x + y * y + z * z);
  }

  // Simple square root approximation
  double _sqrt(double value) {
    if (value <= 0) return 0;
    double x = value;
    for (int i = 0; i < 20; i++) {
      x = (x + value / x) / 2;
    }
    return x;
  }

  String _geoPointToString(GeoPoint point) {
    return '${point.latitude.toStringAsFixed(5)}, '
        '${point.longitude.toStringAsFixed(5)}';
  }
}
