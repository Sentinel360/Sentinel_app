import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'sensor_service.dart';
import 'wearable_presence_service.dart';

/// GATT IDs matching the ESP32 Sentinel360 wearable firmware.
const String kSentinelBleServiceUuid = '4fafc201-1fb5-459e-8fcc-c5c9c331914b';
const String kSentinelBleNotifyCharUuid = '1c95d5e3-d8f7-413a-bf3d-7a2e5d7be87e';

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

  /// Set to `true` to fake BLE without hardware (UI/dev only).
  static const bool mockMode = false;

  final SensorService _sensorService = SensorService();

  BluetoothDevice? _device;
  BluetoothCharacteristic? _commandChar;
  BluetoothCharacteristic? _notifyChar;

  BLEConnectionState _state = BLEConnectionState.disconnected;
  Timer? _heartbeatTimer;
  StreamSubscription? _scanSub;
  StreamSubscription? _deviceStateSub;
  StreamSubscription? _notifySub;

  /// Wired from [TripManager] so IoT `SOS_TRIGGERED` notifies can open the same
  /// Firestore emergency pipeline as the in-app SOS button.
  Future<void> Function()? _sosFromDeviceHandler;

  void setSosFromDeviceHandler(Future<void> Function()? handler) {
    _sosFromDeviceHandler = handler;
  }

  final StreamController<BLEConnectionState> _stateController =
      StreamController<BLEConnectionState>.broadcast();
  Stream<BLEConnectionState> get stateStream => _stateController.stream;
  BLEConnectionState get state => _state;
  bool get isConnected =>
      _state == BLEConnectionState.connected ||
      _state == BLEConnectionState.mockConnected;

  /// Advertised name when linked (for UI). Null when disconnected.
  String? get connectedPeripheralName {
    if (!isConnected) return null;
    final n = _device?.platformName;
    if (n != null && n.trim().isNotEmpty) return n;
    return mockMode ? 'Sentinel360 (simulated)' : 'Sentinel360';
  }

  // ── Connect ────────────────────────────────────────────────────────────────
  Future<bool> connect() async => mockMode ? _mockConnect() : _realConnect();

  Future<bool> _mockConnect() async {
    if (isConnected) {
      return true;
    }
    _setState(BLEConnectionState.scanning);
    await Future.delayed(const Duration(milliseconds: 800));
    _setState(BLEConnectionState.connecting);
    await Future.delayed(const Duration(milliseconds: 600));
    _setState(BLEConnectionState.mockConnected);
    _startHeartbeat();
    await WearablePresenceService.instance
        .recordConnected(deviceName: 'Sentinel360_MOCK');
    print('[BLE] Mock connected to Sentinel360_MOCK');
    return true;
  }

  Future<bool> _realConnect() async {
    if (isConnected && _device != null) {
      print('[BLE] Already connected to ${_device!.platformName}');
      return true;
    }
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
      final name = _device?.platformName.trim().isNotEmpty == true
          ? _device!.platformName
          : 'Sentinel360';
      await WearablePresenceService.instance.recordConnected(deviceName: name);
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

    bool uuidEquals(Guid u, String canonical) =>
        u.str.toLowerCase() == canonical.toLowerCase();

    BluetoothCharacteristic? notifyChar;
    BluetoothCharacteristic? commandChar;

    for (final svc in services) {
      if (!uuidEquals(svc.uuid, kSentinelBleServiceUuid)) continue;
      for (final char in svc.characteristics) {
        if (uuidEquals(char.uuid, kSentinelBleNotifyCharUuid) &&
            char.properties.notify) {
          notifyChar = char;
        }
        if (char.properties.write || char.properties.writeWithoutResponse) {
          commandChar = char;
        }
      }
    }

    // Fallback: any notify / write (older or custom firmware)
    if (notifyChar == null || commandChar == null) {
      for (final svc in services) {
        for (final char in svc.characteristics) {
          if (notifyChar == null && char.properties.notify) {
            notifyChar = char;
          }
          if (commandChar == null &&
              (char.properties.write || char.properties.writeWithoutResponse)) {
            commandChar = char;
          }
        }
      }
    }

    _notifyChar = notifyChar;
    _commandChar = commandChar;

    _notifySub?.cancel();
    if (_notifyChar != null) {
      await _notifyChar!.setNotifyValue(true);
      _notifySub = _notifyChar!.onValueReceived.listen(_onNotify);
    }
  }

  void _onNotify(List<int> value) {
    final msg = utf8.decode(value);
    print('[BLE] Received: $msg');
    if (msg.contains('TAKEOVER')) _sensorService.notifyIoTTakeover();
    if (msg.contains('STANDBY')) _sensorService.notifyPhoneResume();
    if (msg.contains('SOS_TRIGGERED')) {
      final h = _sosFromDeviceHandler;
      if (h != null) unawaited(h());
    }
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
    await WearablePresenceService.instance.recordDisconnected();
    _device = null;
    _commandChar = null;
    _notifyChar = null;
    _setState(BLEConnectionState.disconnected);
  }

  void _onDisconnected() {
    _heartbeatTimer?.cancel();
    WearablePresenceService.instance.recordDisconnected();
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
