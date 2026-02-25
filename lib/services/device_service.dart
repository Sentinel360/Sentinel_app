import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/device_model.dart';

class DeviceService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Get device by ID
  Future<DeviceModel?> getDevice(String deviceId) async {
    final doc = await _firestore.collection('devices').doc(deviceId).get();
    if (!doc.exists || doc.data() == null) return null;
    return DeviceModel.fromMap(doc.id, doc.data()!);
  }

  // Stream device in real time
  Stream<DeviceModel?> streamDevice(String deviceId) {
    return _firestore.collection('devices').doc(deviceId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return DeviceModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  // Get device linked to a user
  Future<DeviceModel?> getDeviceByUserId(String userId) async {
    final snapshot = await _firestore
        .collection('devices')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) return null;
    return DeviceModel.fromMap(
      snapshot.docs.first.id,
      snapshot.docs.first.data(),
    );
  }

  // Stream device linked to a user
  Stream<DeviceModel?> streamDeviceByUserId(String userId) {
    return _firestore
        .collection('devices')
        .where('userId', isEqualTo: userId)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return DeviceModel.fromMap(
            snapshot.docs.first.id,
            snapshot.docs.first.data(),
          );
        });
  }

  // Update device location and last seen
  Future<void> updateDeviceLocation({
    required String deviceId,
    required GeoPoint location,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'location': location,
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Update battery level
  Future<void> updateBatteryLevel({
    required String deviceId,
    required int batteryLevel,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'batteryLevel': batteryLevel,
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Set device active or inactive
  Future<void> setDeviceActive({
    required String deviceId,
    required bool isActive,
  }) async {
    await _firestore.collection('devices').doc(deviceId).update({
      'isActive': isActive,
      'lastSeen': Timestamp.fromDate(DateTime.now()),
    });
  }

  // Register a new device for a user
  Future<void> registerDevice({
    required String deviceId,
    required String userId,
    required String name,
  }) async {
    final device = DeviceModel(
      deviceId: deviceId,
      userId: userId,
      name: name,
      batteryLevel: 100,
      firmwareVersion: '1.0.0',
      lastSeen: DateTime.now(),
      isActive: true,
    );

    await _firestore.collection('devices').doc(deviceId).set(device.toMap());
  }
}
