import 'package:cloud_firestore/cloud_firestore.dart';

class TripModel {
  final String? tripId;
  final String userId;
  final String deviceId;
  final GeoPoint startLocation;
  final GeoPoint? endLocation;
  final double distance;
  final int duration; // stored in SECONDS
  final String status;
  final List<AnomalyEvent> anomalies;
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<GeoPoint> routePolyline;
  final int escalationAttempts;
  final String? destinationName;

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
    this.destinationName,
  });

  /// Human-readable duration string (e.g. "5 min", "1h 23m")
  String get durationFormatted {
    if (duration < 60) return '${duration}s';
    if (duration < 3600) return '${duration ~/ 60} min';
    final h = duration ~/ 3600;
    final m = (duration % 3600) ~/ 60;
    return m > 0 ? '${h}h ${m}m' : '${h}h';
  }

  /// Trip display name — uses destination if available, otherwise "Trip"
  String get displayName {
    if (destinationName != null && destinationName!.isNotEmpty) {
      return 'Trip to $destinationName';
    }
    return 'Trip';
  }

  /// Number of anomaly events recorded during this trip.
  int get anomalyCount => anomalies.length;

  /// Formatted date string (e.g. "Mon, 24 Mar 2026")
  String get dateFormatted {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    final d = startedAt;
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]} ${d.year}';
  }

  factory TripModel.fromMap(String tripId, Map<String, dynamic> data) {
    final durationRaw = data['duration'];
    final escalationRaw = data['escalationAttempts'];
    return TripModel(
      tripId: tripId,
      userId: data['userId'] ?? '',
      deviceId: data['deviceId'] ?? '',

      // FIX 1: startLocation can come from different schemas.
      startLocation: _readGeoPoint(
        data['startLocation'] ??
            data['originGeo'] ??
            data['origin'],
      ),
      // FIX 2: endLocation — safe nullable cast
      endLocation: data['endLocation'] is GeoPoint
          ? data['endLocation'] as GeoPoint
          : null,

      distance: (data['distance'] ?? 0.0).toDouble(),
      // Guard against null or non-int numeric values.
      duration: durationRaw is int
          ? durationRaw
          : durationRaw is num
          ? durationRaw.toInt()
          : 0,
      status: data['status'] ?? 'active',

      anomalies: (data['anomalies'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map((e) => AnomalyEvent.fromMap(e))
          .toList(),

      // FIX 3: startedAt may be null if serverTimestamp() hasn't resolved yet
      startedAt: data['startedAt'] is Timestamp
          ? (data['startedAt'] as Timestamp).toDate()
          : DateTime.now(),

      endedAt: data['endedAt'] is Timestamp
          ? (data['endedAt'] as Timestamp).toDate()
          : null,

      // FIX 4: routePolyline stored as List<Map> by route_service, not List<GeoPoint>
      routePolyline: (data['routePolyline'] as List<dynamic>? ?? []).map((e) {
        if (e is GeoPoint) return e;
        if (e is Map) {
          final lat = (e['lat'] ?? e['latitude'] ?? 0.0) as num;
          final lng = (e['lng'] ?? e['lon'] ?? e['longitude'] ?? 0.0) as num;
          return GeoPoint(lat.toDouble(), lng.toDouble());
        }
        return const GeoPoint(0, 0);
      }).toList(),

      escalationAttempts: escalationRaw is int
          ? escalationRaw
          : escalationRaw is num
          ? escalationRaw.toInt()
          : 0,
      destinationName: data['destinationName'] as String?,
    );
  }

  static GeoPoint _readGeoPoint(dynamic value) {
    if (value is GeoPoint) return value;
    if (value is Map) {
      final lat = (value['lat'] ?? value['latitude'] ?? 5.6037) as num;
      final lon = (value['lon'] ?? value['lng'] ?? value['longitude'] ?? -0.1870)
          as num;
      return GeoPoint(lat.toDouble(), lon.toDouble());
    }
    return const GeoPoint(5.6037, -0.1870);
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
      // Store polyline consistently as List<Map> so fromMap can always read it
      'routePolyline': routePolyline
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
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
      // Safe Timestamp read — anomaly may have been written with serverTimestamp
      detectedAt: data['detectedAt'] is Timestamp
          ? (data['detectedAt'] as Timestamp).toDate()
          : DateTime.now(),
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
