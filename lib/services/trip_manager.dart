import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'sensor_service.dart';
import 'ble_service.dart';
import 'emergency_service.dart';

enum TripPhase { idle, starting, active, ending }

class ActiveTripState {
  final TripPhase phase;
  final String? tripId;
  final RiskUpdate? latestRisk;
  final String activeSource; // 'PHONE' or 'IOT'
  final BLEConnectionState bleState;
  final Duration elapsed;

  ActiveTripState({
    required this.phase,
    this.tripId,
    this.latestRisk,
    this.activeSource = 'PHONE',
    this.bleState = BLEConnectionState.disconnected,
    required this.elapsed,
  });

  ActiveTripState copyWith({
    TripPhase? phase,
    String? tripId,
    RiskUpdate? latestRisk,
    String? activeSource,
    BLEConnectionState? bleState,
    Duration? elapsed,
  }) {
    return ActiveTripState(
      phase: phase ?? this.phase,
      tripId: tripId ?? this.tripId,
      latestRisk: latestRisk ?? this.latestRisk,
      activeSource: activeSource ?? this.activeSource,
      bleState: bleState ?? this.bleState,
      elapsed: elapsed ?? this.elapsed,
    );
  }
}

class TripManager {
  static final TripManager _instance = TripManager._internal();
  factory TripManager() => _instance;
  TripManager._internal() {
    _bleService.setSosFromDeviceHandler(_handleBleSosFromDevice);
    _bleService.stateStream.listen((s) {
      _updateState(_state.copyWith(bleState: s));
    });
  }

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SensorService _sensorService = SensorService();
  final BLEService _bleService = BLEService();

  ActiveTripState _state = ActiveTripState(
    phase: TripPhase.idle,
    elapsed: Duration.zero,
  );

  StreamSubscription? _riskSubscription;
  StreamSubscription<Position>? _locationSubscription;
  Timer? _elapsedTimer;
  DateTime? _tripStartTime;

  // GPS breadcrumb tracking for accurate distance calculation
  final List<Position> _gpsBreadcrumbs = [];
  double _totalDistanceKm = 0.0;

  final StreamController<ActiveTripState> _stateController =
      StreamController<ActiveTripState>.broadcast();
  final StreamController<DateTime> _wearableSosController =
      StreamController<DateTime>.broadcast();

  Stream<ActiveTripState> get stateStream => _stateController.stream;
  /// Fires when a wearable BLE SOS was accepted and written to Firestore.
  Stream<DateTime> get wearableSosAckStream => _wearableSosController.stream;
  ActiveTripState get currentState => _state;

  /// Optional list of `{lat, lon}` for the Directions API route shown in preview.
  /// When included (≥2 points), it is stored on the trip doc in the same write as
  /// trip creation so the first Firestore snapshot already has the real polyline
  /// (avoids a race where the UI briefly fell back to a straight origin→dest line).
  Future<String?> startTrip({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required String destinationName,
    List<Map<String, double>>? routePolylinePreview,
  }) async {
    if (_state.phase != TripPhase.idle) return null;
    _updateState(_state.copyWith(phase: TripPhase.starting));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final tripPayload = <String, dynamic>{
        'userId': uid,
        'driver_id': uid,
        'vehicle_type': 'unknown',
        'status': 'active',
        // Object format expected by cloud route-monitor bootstrap.
        'origin': {'lat': originLat, 'lon': originLon},
        'destination': {'lat': destLat, 'lon': destLon},
        // Keep GeoPoint copies for compatibility with existing readers/tools.
        'originGeo': GeoPoint(originLat, originLon),
        'destinationGeo': GeoPoint(destLat, destLon),
        'destinationName': destinationName,
        'startedAt': FieldValue.serverTimestamp(),
        'source': 'PHONE',
        'anomalies': [],
        'current_state': {
          'risk_score': 0.0,
          'risk_level': 'SAFE',
          'risk_color': 'green',
          'explanation': 'Trip just started',
          'active_sensor': 'PHONE',
        },
      };
      if (routePolylinePreview != null &&
          routePolylinePreview.length >= 2) {
        tripPayload['routePolyline'] = routePolylinePreview;
      }

      final tripRef = await _db.collection('trips').add(tripPayload);

      final tripId = tripRef.id;
      debugPrint('TripManager: Created trip $tripId');

      // Store activeTripId on the user document so the emergency screen,
      // ride_status_screen, and app-restart recovery can find the active trip.
      await _db.collection('users').doc(uid).update({
        'activeTripId': tripId,
      });

      // Initialize the new current-state document path used by the app listener:
      // trips/{tripId}/current_state/latest
      await _db
          .collection('trips')
          .doc(tripId)
          .collection('current_state')
          .doc('latest')
          .set({
            'riskScore': 0.0,
            'riskLevel': 'SAFE',
            'riskColor': 'green',
            'explanation': 'Trip just started',
            'activeSensor': 'PHONE',
            'updatedAt': FieldValue.serverTimestamp(),
          });

      // Connect BLE — non-blocking, trip proceeds even without IoT
      _bleService.connect().then((connected) {
        if (connected) {
          _bleService.onTripStart();
        } else {
          debugPrint('TripManager: IoT unavailable — phone-only mode');
        }
      });

      await _sensorService.startMonitoring(tripId);

      _riskSubscription = _sensorService.riskStream.listen((risk) {
        _updateState(
          _state.copyWith(
            latestRisk: risk,
            activeSource: risk.activeSensor == ActiveSensor.iot
                ? 'IOT'
                : 'PHONE',
          ),
        );
      });

      _tripStartTime = DateTime.now();
      _gpsBreadcrumbs.clear();
      _totalDistanceKm = 0.0;

      // Start GPS breadcrumb tracking for accurate distance measurement
      _startDistanceTracking();

      _elapsedTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        _updateState(
          _state.copyWith(elapsed: DateTime.now().difference(_tripStartTime!)),
        );
      });

      _updateState(
        _state.copyWith(
          phase: TripPhase.active,
          tripId: tripId,
          elapsed: Duration.zero,
        ),
      );

      return tripId;
    } catch (e) {
      debugPrint('TripManager: Error starting trip - $e');
      _updateState(_state.copyWith(phase: TripPhase.idle));
      return null;
    }
  }

  Future<void> endTrip() async {
    if (_state.phase != TripPhase.active) return;
    _updateState(_state.copyWith(phase: TripPhase.ending));
    final tripId = _state.tripId;

    try {
      _elapsedTimer?.cancel();
      _riskSubscription?.cancel();
      _locationSubscription?.cancel();
      _locationSubscription = null;

      await _sensorService.stopMonitoring();
      // Notify wearable trip ended; keep BLE connected for SOS outside trips.
      await _bleService.onTripEnd();

      if (tripId != null) {
        // Get final GPS position for end location
        GeoPoint? endGeo;
        try {
          final pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 5),
            ),
          );
          endGeo = GeoPoint(pos.latitude, pos.longitude);
        } catch (_) {
          // Use last breadcrumb if available
          if (_gpsBreadcrumbs.isNotEmpty) {
            final last = _gpsBreadcrumbs.last;
            endGeo = GeoPoint(last.latitude, last.longitude);
          }
        }

        final updateData = <String, dynamic>{
          'status': 'completed',
          'endedAt': FieldValue.serverTimestamp(),
          'duration': _state.elapsed.inSeconds,
          'distance': _totalDistanceKm,
        };
        if (endGeo != null) {
          updateData['endLocation'] = endGeo;
          updateData['endLocationGeo'] = endGeo;
        }

        await _db.collection('trips').doc(tripId).update(updateData);

        // Clear activeTripId on the user document
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await _db.collection('users').doc(uid).update({
            'activeTripId': null,
          });
        }
      }

      _tripStartTime = null;
      _gpsBreadcrumbs.clear();
      _totalDistanceKm = 0.0;
      _updateState(
        ActiveTripState(
          phase: TripPhase.idle,
          elapsed: Duration.zero,
          bleState: _bleService.state,
        ),
      );
    } catch (e) {
      debugPrint('TripManager: Error ending trip - $e');
      _gpsBreadcrumbs.clear();
      _totalDistanceKm = 0.0;
      _updateState(
        ActiveTripState(
          phase: TripPhase.idle,
          elapsed: Duration.zero,
          bleState: _bleService.state,
        ),
      );
    }
  }

  Future<void> triggerSOS() async {
    final tripId = _state.tripId;
    if (tripId == null) return;

    await _bleService.sendCommand('SOS_TRIGGERED');

    await _db.collection('trips').doc(tripId).collection('alerts').add({
      'type': 'SOS_MANUAL',
      'timestamp': FieldValue.serverTimestamp(),
      'source': _state.activeSource,
    });

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final location = await _geoPointForSos();
    await EmergencyService().triggerEmergency(
      userId: uid,
      tripId: tripId,
      location: location,
      triggerSource: 'map_sos',
    );
  }

  /// IoT wearable sends `SOS_TRIGGERED` over BLE notify — same pipeline as map SOS.
  Future<void> _handleBleSosFromDevice() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      debugPrint('TripManager: BLE SOS ignored — not signed in');
      return;
    }

    final tripId = _state.tripId;
    final location = await _geoPointForSos();

    try {
      if (tripId != null) {
        await _db.collection('trips').doc(tripId).collection('alerts').add({
          'type': 'SOS_BLE',
          'timestamp': FieldValue.serverTimestamp(),
          'source': _state.activeSource,
        });
        await EmergencyService().triggerEmergency(
          userId: uid,
          tripId: tripId,
          location: location,
          triggerSource: 'iot_ble',
        );
      } else {
        await EmergencyService().triggerEmergencyNoTrip(
          userId: uid,
          location: location,
          triggerSource: 'iot_ble',
        );
      }
      if (!_wearableSosController.isClosed) {
        _wearableSosController.add(DateTime.now());
      }
    } catch (e) {
      debugPrint('TripManager: BLE SOS failed — $e');
    }
  }

  Future<GeoPoint> _geoPointForSos() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return GeoPoint(pos.latitude, pos.longitude);
    } catch (e) {
      debugPrint('TripManager: SOS GPS fallback — $e');
      return const GeoPoint(5.6037, -0.1870);
    }
  }

  Stream<Map<String, dynamic>?> escalationStream(String tripId) {
    return _db.collection("trip_escalations").doc(tripId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  }

  Future<void> respondToSafetyCheck({required bool isOk}) async {
    final tripId = _state.tripId;
    if (tripId == null) return;
    await _db.collection("trip_escalations").doc(tripId).set({
      "userResponse": isOk ? "OK" : "NOT_OK",
      "respondedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Starts a GPS position stream to accumulate distance via breadcrumbs.
  /// We use Geolocator's built-in distance calculation (Vincenty formula)
  /// between consecutive points, which is more accurate than Haversine.
  void _startDistanceTracking() {
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5, // only trigger every 5m to avoid GPS jitter
      ),
    ).listen((Position pos) {
      if (_gpsBreadcrumbs.isNotEmpty) {
        final prev = _gpsBreadcrumbs.last;
        final segmentMeters = Geolocator.distanceBetween(
          prev.latitude, prev.longitude,
          pos.latitude, pos.longitude,
        );
        // Ignore tiny movements (GPS noise) and impossibly large jumps
        if (segmentMeters > 3 && segmentMeters < 5000) {
          _totalDistanceKm += segmentMeters / 1000.0;
        }
      }
      _gpsBreadcrumbs.add(pos);
    }, onError: (e) {
      debugPrint('TripManager: Distance tracking GPS error - $e');
    });
  }

  /// Current distance in km (accessible during active trip)
  double get currentDistanceKm => _totalDistanceKm;

  void _updateState(ActiveTripState s) {
    _state = s;
    _stateController.add(_state);
  }

  void dispose() {
    _locationSubscription?.cancel();
    endTrip();
    _stateController.close();
  }
}
