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
  static const int transmissionIntervalSec = 3;
  static const int batchSize = 3;
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
  final double accelX;
  final double accelY;
  final double accelZ;

  SensorDataPoint({
    required this.timestamp,
    required this.lat,
    required this.lon,
    required this.speedKmh,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
  });

  Map<String, dynamic> toMap() => {
    'timestamp': timestamp,
    'gps': {'lat': lat, 'lon': lon, 'speed': speedKmh},
    'acceleration': {'x': accelX, 'y': accelY, 'z': accelZ},
  };
}

class RiskUpdate {
  final double riskScore;
  final String riskLevel; // "SAFE" | "MEDIUM" | "HIGH RISK"
  final String riskColor; // "green" | "orange" | "red"
  final String explanation;
  final ActiveSensor activeSensor;

  RiskUpdate({
    required this.riskScore,
    required this.riskLevel,
    required this.riskColor,
    required this.explanation,
    required this.activeSensor,
  });

  factory RiskUpdate.safe() => RiskUpdate(
    riskScore: 0.0,
    riskLevel: 'SAFE',
    riskColor: 'green',
    explanation: 'Monitoring active',
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

  Timer? _collectionTimer;
  Timer? _transmissionTimer;
  StreamSubscription? _accelSubscription;
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

    await _ensureLocationPermission();
    _startAccelerometer();

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
        accelX: _accelX,
        accelY: _accelY,
        accelZ: _accelZ,
      );

      _buffer.add(point);
      if (_buffer.length > SensorConfig.dataBufferMaxSize) {
        _buffer.removeAt(0);
      }
    } catch (e) {
      print('[SensorService] GPS error: $e');
    }
  }

  // ── Send batch to Firestore ────────────────────────────────────────────────
  Future<void> _transmitBatch() async {
    if (!_isRunning || _currentTripId == null) return;
    if (_buffer.isEmpty || _activeSensor != ActiveSensor.phone) return;

    final batchData = _buffer
        .take(SensorConfig.batchSize)
        .map((p) => p.toMap())
        .toList();

    try {
      await _db
          .collection('trips')
          .doc(_currentTripId)
          .collection('sensor_data')
          .add({
            'source': 'PHONE',
            'batch': batchData,
            'timestamp': FieldValue.serverTimestamp(),
            'userId': FirebaseAuth.instance.currentUser?.uid ?? '',
          });
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

          _riskController.add(
            RiskUpdate(
              riskScore: (data['risk_score'] as num?)?.toDouble() ?? 0.0,
              riskLevel: data['risk_level'] as String? ?? 'SAFE',
              riskColor: data['risk_color'] as String? ?? 'green',
              explanation: data['explanation'] as String? ?? '',
              activeSensor: (data['active_sensor'] as String?) == 'IOT'
                  ? ActiveSensor.iot
                  : ActiveSensor.phone,
            ),
          );
        }, onError: (e) => print('[SensorService] Risk listener error: $e'));
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
