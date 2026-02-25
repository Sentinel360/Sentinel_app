import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'sensor_service.dart';

class BLECommand {
  static const String heartbeat = 'HEARTBEAT';
  static const String activatePrimary = 'ACTIVATE_PRIMARY_MODE';
  static const String activateStandby = 'ACTIVATE_STANDBY_MODE';
  static const String startTrip = 'START_TRIP';
  static const String endTrip = 'END_TRIP';
}

enum BLEConnectionState {
  disconnected,
  scanning,
  connecting,
  connected,
  mockConnected,
}

class BLEService {
  static final BLEService _instance = BLEService._internal();
  factory BLEService() => _instance;
  BLEService._internal();

  // ── Toggle this to false when real hardware is ready ──────────────────────
  static const bool mockMode = true;

  final SensorService _sensorService = SensorService();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _notifyChar;

  BLEConnectionState _state = BLEConnectionState.disconnected;
  Timer? _heartbeatTimer;
  StreamSubscription? _scanSub;
  StreamSubscription? _deviceStateSub;
  StreamSubscription? _notifySub;

  final StreamController<BLEConnectionState> _stateController =
      StreamController<BLEConnectionState>.broadcast();
  Stream<BLEConnectionState> get stateStream => _stateController.stream;
  BLEConnectionState get state => _state;
  bool get isConnected =>
      _state == BLEConnectionState.connected ||
      _state == BLEConnectionState.mockConnected;

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<bool> connect() async => mockMode ? _mockConnect() : _realConnect();

  Future<bool> _mockConnect() async {
    _setState(BLEConnectionState.scanning);
    await Future.delayed(const Duration(milliseconds: 800));
    _setState(BLEConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 600));
    _setState(BLEConnectionState.mockConnected);
    _startHeartbeat();
    print('[BLE] Mock connected to Sentinel360_MOCK');
    return true;
  }

  Future<bool> _realConnect() async {
    try {
      _setState(BLEConnectionState.scanning);
      BluetoothDevice? found;

      _scanSub = FlutterBluePlus.scanResults.listen((results) {
        for (final r in results) {
          if (r.device.platformName.startsWith('Sentinel360')) {
            found = r.device;
            FlutterBluePlus.stopScan();
          }
        }
      });

      await FlutterBluePlus.startScan(timeout: const Duration(seconds: 6));
      await Future.delayed(const Duration(seconds: 6));
      _scanSub?.cancel();

      if (found == null) {
        _setState(BLEConnectionState.disconnected);
        return false;
      }

      _setState(BLEConnectionState.connecting);
      _device = found;
      await _device!.connect(timeout: const Duration(seconds: 10));

      _deviceStateSub = _device!.connectionState.listen((s) {
        if (s == BluetoothConnectionState.disconnected) {
          _onDisconnected();
        }
      });

      await _discoverChars();
      _setState(BLEConnectionState.connected);
      _startHeartbeat();
      print('[BLE] Connected to ${_device!.platformName}');
      return true;
    } catch (e) {
      print('[BLE] Connection error: $e');
      _setState(BLEConnectionState.disconnected);
      return false;
    }
  }

  Future<void> _discoverChars() async {
    if (_device == null) return;
    final services = await _device!.discoverServices();
    for (final svc in services) {
      for (final char in svc.characteristics) {
        if (char.properties.write || char.properties.writeWithoutResponse) {
          _commandChar = char;
        }
        if (char.properties.notify) {
          _notifyChar = char;
          await char.setNotifyValue(true);
          _notifySub = char.onValueReceived.listen(_onNotify);
        }
      }
    }
  }

  void _onNotify(List<int> value) {
    final msg = utf8.decode(value);
    print('[BLE] Received: $msg');
    if (msg.contains('TAKEOVER')) _sensorService.notifyIoTTakeover();
    if (msg.contains('STANDBY')) _sensorService.notifyPhoneResume();
  }

  // ── Send command ───────────────────────────────────────────────────────────
  Future<void> sendCommand(String command) async {
    if (mockMode) {
      print('[BLE] Mock send: $command');
      return;
    }
    if (_commandChar == null) return;
    try {
      await _commandChar!.write(
        utf8.encode(command),
        withoutResponse: _commandChar!.properties.writeWithoutResponse,
      );
    } catch (e) {
      print('[BLE] Send error: $e');
    }
  }

  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => sendCommand(BLECommand.heartbeat),
    );
  }

  // ── Trip lifecycle ─────────────────────────────────────────────────────────
  Future<void> onTripStart() async {
    await sendCommand(BLECommand.startTrip);
    await sendCommand(BLECommand.activateStandby);
  }

  Future<void> onTripEnd() async {
    await sendCommand(BLECommand.endTrip);
  }

  Future<void> activateIoTPrimary() async {
    await sendCommand(BLECommand.activatePrimary);
    _sensorService.notifyIoTTakeover();
  }

  Future<void> activateIoTStandby() async {
    await sendCommand(BLECommand.activateStandby);
    _sensorService.notifyPhoneResume();
  }

  // ── Disconnect ─────────────────────────────────────────────────────────────
  Future<void> disconnect() async {
    _heartbeatTimer?.cancel();
    _notifySub?.cancel();
    _deviceStateSub?.cancel();
    if (!mockMode) await _device?.disconnect();
    _device = null;
    _commandChar = null;
    _notifyChar = null;
    _setState(BLEConnectionState.disconnected);
  }

  void _onDisconnected() {
    _heartbeatTimer?.cancel();
    _setState(BLEConnectionState.disconnected);
  }

  void _setState(BLEConnectionState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    disconnect();
    _stateController.close();
  }
}
