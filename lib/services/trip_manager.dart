import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'sensor_service.dart';
import 'ble_service.dart';

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
  TripManager._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final SensorService _sensorService = SensorService();
  final BLEService _bleService = BLEService();

  ActiveTripState _state = ActiveTripState(
    phase: TripPhase.idle,
    elapsed: Duration.zero,
  );

  StreamSubscription? _riskSubscription;
  StreamSubscription? _bleStateSubscription;
  Timer? _elapsedTimer;
  DateTime? _tripStartTime;

  final StreamController<ActiveTripState> _stateController =
      StreamController<ActiveTripState>.broadcast();
  Stream<ActiveTripState> get stateStream => _stateController.stream;
  ActiveTripState get currentState => _state;

  Future<String?> startTrip({
    required double originLat,
    required double originLon,
    required double destLat,
    required double destLon,
    required String destinationName,
  }) async {
    if (_state.phase != TripPhase.idle) return null;
    _updateState(_state.copyWith(phase: TripPhase.starting));

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw Exception('User not authenticated');

      final tripRef = await _db.collection('trips').add({
        'userId': uid,
        'status': 'active',
        'origin': GeoPoint(originLat, originLon),
        'destination': GeoPoint(destLat, destLon),
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
      });

      final tripId = tripRef.id;
      debugPrint('TripManager: Created trip $tripId');

      // Connect BLE — non-blocking, trip proceeds even without IoT
      _bleService.connect().then((connected) {
        if (connected) {
          _bleService.onTripStart();
        } else {
          debugPrint('TripManager: IoT unavailable — phone-only mode');
        }
      });

      await _sensorService.startMonitoring(tripId);

      _bleStateSubscription = _bleService.stateStream.listen((s) {
        _updateState(_state.copyWith(bleState: s));
      });

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
      _bleStateSubscription?.cancel();

      await _sensorService.stopMonitoring();
      await _bleService.onTripEnd();
      await _bleService.disconnect();

      if (tripId != null) {
        await _db.collection('trips').doc(tripId).update({
          'status': 'completed',
          'endedAt': FieldValue.serverTimestamp(),
          'duration': _state.elapsed.inSeconds,
        });
      }

      _tripStartTime = null;
      _updateState(
        ActiveTripState(phase: TripPhase.idle, elapsed: Duration.zero),
      );
    } catch (e) {
      debugPrint('TripManager: Error ending trip - $e');
      _updateState(
        ActiveTripState(phase: TripPhase.idle, elapsed: Duration.zero),
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
    if (uid != null) {
      await _db.collection('emergency_alerts').add({
        'userId': uid,
        'tripId': tripId,
        'type': 'SOS_MANUAL',
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'triggered',
      });
    }
  }

  void _updateState(ActiveTripState s) {
    _state = s;
    _stateController.add(_state);
  }

  void dispose() {
    endTrip();
    _stateController.close();
  }
}
