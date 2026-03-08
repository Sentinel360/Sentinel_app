import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:battery_plus/battery_plus.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Config
// ─────────────────────────────────────────────────────────────────────────────
class SensorConfig {
  static const bool capstoneMode = true;
  static const int collectionIntervalSec = 1;
  static const int transmissionIntervalSec = 1;
  static const int batchSize = 1;
  static const int phoneLowBatteryThreshold = 15;
  static const int phoneResumeThreshold = 40;
  static const int dataBufferMaxSize = 20;
}

// ─────────────────────────────────────────────────────────────────────────────
// Models
// ─────────────────────────────────────────────────────────────────────────────
enum ActiveSensor { phone, iot }

class SensorDataPoint {
  final int timestamp;
  final double lat;
  final double lon;
  final double speedKmh;
  final double gpsAccuracyMeters;
  final double speedAccuracyKmh;
  final double altitudeMeters;
  final double verticalSpeedMps;
  final double heading;
  final double bearing;
  final double accelX;
  final double accelY;
  final double accelZ;
  final double gyroX;
  final double gyroY;
  final double gyroZ;
  final bool isMoving;
  final String activity;

  SensorDataPoint({
    required this.timestamp,
    required this.lat,
    required this.lon,
    required this.speedKmh,
    required this.gpsAccuracyMeters,
    required this.speedAccuracyKmh,
    required this.altitudeMeters,
    required this.verticalSpeedMps,
    required this.heading,
    required this.bearing,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.gyroX,
    required this.gyroY,
    required this.gyroZ,
    required this.isMoving,
    required this.activity,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp,
    'gps': {
      'lat': lat,
      'lon': lon,
      'speed': speedKmh,
      'accuracy': gpsAccuracyMeters,
      'speed_accuracy': speedAccuracyKmh,
      'heading': heading,
      'bearing': bearing,
      'altitude': altitudeMeters,
      'vertical_speed': verticalSpeedMps,
    },
    'acceleration': {'x': accelX, 'y': accelY, 'z': accelZ},
    'gyro': {'x': gyroX, 'y': gyroY, 'z': gyroZ},
    'is_moving': isMoving,
    'activity': activity,
  };
}

class RiskUpdate {
  final double riskScore;
  final String riskLevel; // "SAFE" | "MEDIUM" | "HIGH RISK"
  final String riskColor; // "green" | "orange" | "red"
  final String overallRiskLevel; // Trip-level trend verdict
  final bool overallUnsafe; // Trip-level unsafe latch
  final String explanation;
  final String policyReason;
  final ActiveSensor activeSensor;

  RiskUpdate({
    required this.riskScore,
    required this.riskLevel,
    required this.riskColor,
    required this.overallRiskLevel,
    required this.overallUnsafe,
    required this.explanation,
    required this.policyReason,
    required this.activeSensor,
  });

  factory RiskUpdate.safe() => RiskUpdate(
    riskScore: 0.0,
    riskLevel: 'SAFE',
    riskColor: 'green',
    overallRiskLevel: 'SAFE',
    overallUnsafe: false,
    explanation: 'Monitoring active',
    policyReason: '',
    activeSensor: ActiveSensor.phone,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SensorService (singleton)
// ─────────────────────────────────────────────────────────────────────────────
class SensorService {
  static final SensorService _instance = SensorService._internal();
  factory SensorService() => _instance;
  SensorService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final Battery _battery = Battery();

  String? _currentTripId;
  ActiveSensor _activeSensor = ActiveSensor.phone;
  bool _isRunning = false;

  final List<SensorDataPoint> _buffer = [];
  double _accelX = 0, _accelY = 0, _accelZ = 0;
  double _gyroX = 0, _gyroY = 0, _gyroZ = 0;
  double? _lastAltitudeMeters;
  int? _lastAltitudeTimestampMs;

  Timer? _collectionTimer;
  Timer? _transmissionTimer;
  StreamSubscription? _accelSubscription;
  StreamSubscription? _gyroSubscription;
  StreamSubscription? _batterySubscription;
  StreamSubscription? _riskSubscription;

  // Risk updates broadcast to the UI
  final StreamController<RiskUpdate> _riskController =
      StreamController<RiskUpdate>.broadcast();
  Stream<RiskUpdate> get riskStream => _riskController.stream;

  ActiveSensor get activeSensor => _activeSensor;
  bool get isRunning => _isRunning;
  String? get currentTripId => _currentTripId;

  // ── Start ──────────────────────────────────────────────────────────────────
  Future<void> startMonitoring(String tripId) async {
    if (_isRunning) await stopMonitoring();

    _currentTripId = tripId;
    _isRunning = true;
    _activeSensor = ActiveSensor.phone;
    _buffer.clear();
    _lastAltitudeMeters = null;
    _lastAltitudeTimestampMs = null;

    await _ensureLocationPermission();
    _startAccelerometer();
    _startGyroscope();

    _collectionTimer = Timer.periodic(
      const Duration(seconds: SensorConfig.collectionIntervalSec),
      (_) => _collectDataPoint(),
    );

    _transmissionTimer = Timer.periodic(
      const Duration(seconds: SensorConfig.transmissionIntervalSec),
      (_) => _transmitBatch(),
    );

    _startBatteryMonitor();
    _startRiskListener(tripId);

    print('[SensorService] Started monitoring for trip $tripId');
  }

  // ── Stop ───────────────────────────────────────────────────────────────────
  Future<void> stopMonitoring() async {
    _isRunning = false;
    _collectionTimer?.cancel();
    _transmissionTimer?.cancel();
    _accelSubscription?.cancel();
    _gyroSubscription?.cancel();
    _batterySubscription?.cancel();
    _riskSubscription?.cancel();
    _buffer.clear();
    _currentTripId = null;
    print('[SensorService] Stopped');
  }

  // ── Collect one GPS + accel point ─────────────────────────────────────────
  Future<void> _collectDataPoint() async {
    if (!_isRunning || _activeSensor != ActiveSensor.phone) return;

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 2),
      );

      final point = SensorDataPoint(
        timestamp: DateTime.now().millisecondsSinceEpoch,
        lat: position.latitude,
        lon: position.longitude,
        speedKmh: (position.speed * 3.6).clamp(0, 300),
        gpsAccuracyMeters: position.accuracy,
        speedAccuracyKmh: (position.speedAccuracy * 3.6).abs(),
        altitudeMeters: position.altitude,
        verticalSpeedMps: _computeVerticalSpeed(
          altitudeMeters: position.altitude,
          timestampMs: DateTime.now().millisecondsSinceEpoch,
        ),
        heading: position.heading,
        bearing: position.heading,
        accelX: _accelX,
        accelY: _accelY,
        accelZ: _accelZ,
        gyroX: _gyroX,
        gyroY: _gyroY,
        gyroZ: _gyroZ,
        isMoving: (position.speed * 3.6) > 2.0,
        activity: (position.speed * 3.6) > 2.0 ? 'in_vehicle' : 'still',
      );

      _buffer.add(point);
      if (_buffer.length > SensorConfig.dataBufferMaxSize) {
        _buffer.removeAt(0);
      }
    } catch (e) {
      print('[SensorService] GPS error: $e');
    }
  }

  // ── Send sensor events to Firestore ────────────────────────────────────────
  Future<void> _transmitBatch() async {
    if (!_isRunning || _currentTripId == null) return;
    if (_buffer.isEmpty || _activeSensor != ActiveSensor.phone) return;

    final events = _buffer.take(SensorConfig.batchSize).toList();

    try {
      final tripId = _currentTripId!;
      for (final event in events) {
        await _db
            .collection('trips')
            .doc(tripId)
            .collection('sensor_data')
            .add({
              'trip_id': tripId,
              ...event.toMap(),
              'source': 'PHONE',
              'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
              'ingested_at': FieldValue.serverTimestamp(),
            });
      }
      _buffer.removeRange(0, events.length);
    } catch (e) {
      print('[SensorService] Transmit error: $e');
    }
  }

  // ── Accelerometer ──────────────────────────────────────────────────────────
  void _startAccelerometer() {
    _accelSubscription =
        accelerometerEventStream(
          samplingPeriod: const Duration(milliseconds: 200),
        ).listen((event) {
          _accelX = event.x;
          _accelY = event.y;
          _accelZ = event.z;
        });
  }

  void _startGyroscope() {
    _gyroSubscription =
        gyroscopeEventStream(
          samplingPeriod: const Duration(milliseconds: 200),
        ).listen((event) {
          _gyroX = event.x;
          _gyroY = event.y;
          _gyroZ = event.z;
        });
  }

  double _computeVerticalSpeed({
    required double altitudeMeters,
    required int timestampMs,
  }) {
    if (_lastAltitudeMeters == null || _lastAltitudeTimestampMs == null) {
      _lastAltitudeMeters = altitudeMeters;
      _lastAltitudeTimestampMs = timestampMs;
      return 0.0;
    }
    final dtSec = (timestampMs - _lastAltitudeTimestampMs!) / 1000.0;
    if (dtSec <= 0) return 0.0;
    final vs = (altitudeMeters - _lastAltitudeMeters!) / dtSec;
    _lastAltitudeMeters = altitudeMeters;
    _lastAltitudeTimestampMs = timestampMs;
    return vs;
  }

  // ── Battery monitor ────────────────────────────────────────────────────────
  void _startBatteryMonitor() {
    _checkBatteryLevel();
    _batterySubscription = _battery.onBatteryStateChanged.listen(
      (_) => _checkBatteryLevel(),
    );
  }

  Future<void> _checkBatteryLevel() async {
    try {
      final level = await _battery.batteryLevel;
      if (level < SensorConfig.phoneLowBatteryThreshold &&
          _activeSensor == ActiveSensor.phone) {
        _switchSensor(ActiveSensor.iot, 'Phone battery low ($level%)');
      } else if (level > SensorConfig.phoneResumeThreshold &&
          _activeSensor == ActiveSensor.iot) {
        _switchSensor(ActiveSensor.phone, 'Phone battery recovered ($level%)');
      }
    } catch (e) {
      print('[SensorService] Battery check error: $e');
    }
  }

  void _switchSensor(ActiveSensor to, String reason) {
    _activeSensor = to;
    print('[SensorService] Switching to ${to.name} — $reason');
    if (_currentTripId != null) {
      // Avoid unhandled async errors crashing the app.
      () async {
        try {
          await _db.collection('trips').doc(_currentTripId).update({
            'active_sensor': to == ActiveSensor.iot ? 'IOT' : 'PHONE',
            'sensor_switch_reason': reason,
            'sensor_switched_at': FieldValue.serverTimestamp(),
          });
        } catch (e) {
          print('[SensorService] Failed to persist sensor switch: $e');
        }
      }();
    }
  }

  // ── Listen for risk updates from ML cloud functions ────────────────────────
  void _startRiskListener(String tripId) {
    _riskSubscription = _db
        .collection('trips')
        .doc(tripId)
        .collection('current_state')
        .doc('latest')
        .snapshots()
        .listen((snapshot) {
          if (!snapshot.exists) return;
          final data = snapshot.data()!;
          final riskLevel =
              (data['riskLevel'] as String?) ??
              (data['risk_level'] as String?) ??
              'SAFE';
          final riskColor =
              (data['riskColor'] as String?) ??
              (data['risk_color'] as String?) ??
              _riskColorFromLevel(riskLevel);
          final activeSensorRaw =
              (data['activeSensor'] as String?) ??
              (data['active_sensor'] as String?) ??
              'PHONE';
          final overallRiskLevel =
              (data['overallRiskLevel'] as String?) ??
              (data['overall_risk_level'] as String?) ??
              riskLevel;
          final overallUnsafe =
              (data['overallUnsafe'] as bool?) ??
              (data['overall_unsafe'] as bool?) ??
              false;
          final policy = data['policy'];
          final policyReason = policy is Map<String, dynamic>
              ? (policy['reason'] as String? ?? '')
              : '';

          _riskController.add(
            RiskUpdate(
              riskScore:
                  (data['riskScore'] as num?)?.toDouble() ??
                  (data['risk_score'] as num?)?.toDouble() ??
                  0.0,
              riskLevel: riskLevel,
              riskColor: riskColor,
              overallRiskLevel: overallRiskLevel,
              overallUnsafe: overallUnsafe,
              explanation: data['explanation'] as String? ?? '',
              policyReason: policyReason,
              activeSensor: activeSensorRaw.toUpperCase() == 'IOT'
                  ? ActiveSensor.iot
                  : ActiveSensor.phone,
            ),
          );
        }, onError: (e) => print('[SensorService] Risk listener error: $e'));
  }

  String _riskColorFromLevel(String level) {
    switch (level.toUpperCase()) {
      case 'HIGH':
      case 'HIGH RISK':
        return 'red';
      case 'MEDIUM':
        return 'orange';
      default:
        return 'green';
    }
  }

  // ── Location permission ────────────────────────────────────────────────────
  Future<void> _ensureLocationPermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Location permission permanently denied. Enable in device settings.',
      );
    }
  }

  // ── Called by BLE service when IoT commands a takeover ────────────────────
  void notifyIoTTakeover() =>
      _switchSensor(ActiveSensor.iot, 'IoT commanded takeover via BLE');
  void notifyPhoneResume() =>
      _switchSensor(ActiveSensor.phone, 'Phone resumed via BLE');

  void dispose() {
    stopMonitoring();
    _riskController.close();
  }
}
