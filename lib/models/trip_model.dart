import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String? tripId;
  final String userId;
  final String deviceId;
  final GeoPoint startLocation;
  final GeoPoint? endLocation;
  final double distance;
  final int duration;
  final String status;
  final List<AnomalyEvent> anomalies;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<GeoPoint> routePolyline;
  final int escalationAttempts;

  TripModel({
    this.tripId,
    required this.userId,
    required this.deviceId,
    required this.startLocation,
    this.endLocation,
    this.distance = 0.0,
    this.duration = 0,
    this.status = 'active',
    this.anomalies = const [],
    required this.startedAt,
    this.endedAt,
    this.routePolyline = const [],
    this.escalationAttempts = 0,
  });

  factory TripModel.fromMap(String tripId, Map<String, dynamic> data) {
    return TripModel(
      tripId: tripId,
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'] ?? '',
      startLocation: data['startLocation'] as GeoPoint,
      endLocation: data['endLocation'] as GeoPoint?,
      distance: (data['distance'] ?? 0.0).toDouble(),
      duration: data['duration'] ?? 0,
      status: data['status'] ?? 'active',
      anomalies: (data['anomalies'] as List<dynamic>? ?? [])
          .map((e) => AnomalyEvent.fromMap(e as Map<String, dynamic>))
          .toList(),
      startedAt: (data['startedAt'] as Timestamp).toDate(),
      endedAt: data['endedAt'] != null
          ? (data['endedAt'] as Timestamp).toDate()
          : null,
      routePolyline: (data['routePolyline'] as List<dynamic>? ?? [])
          .map((e) => e as GeoPoint)
          .toList(),
      escalationAttempts: data['escalationAttempts'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'deviceId': deviceId,
      'startLocation': startLocation,
      'endLocation': endLocation,
      'distance': distance,
      'duration': duration,
      'status': status,
      'anomalies': anomalies.map((e) => e.toMap()).toList(),
      'startedAt': Timestamp.fromDate(startedAt),
      'endedAt': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
      'routePolyline': routePolyline,
      'escalationAttempts': escalationAttempts,
    };
  }
}

class AnomalyEvent {
  final String type;
  final String location;
  final DateTime detectedAt;
  final String severity;

  AnomalyEvent({
    required this.type,
    required this.location,
    required this.detectedAt,
    required this.severity,
  });

  factory AnomalyEvent.fromMap(Map<String, dynamic> data) {
    return AnomalyEvent(
      type: data['type'] ?? '',
      location: data['location'] ?? '',
      detectedAt: (data['detectedAt'] as Timestamp).toDate(),
      severity: data['severity'] ?? 'low',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'location': location,
      'detectedAt': Timestamp.fromDate(detectedAt),
      'severity': severity,
    };
  }
}
