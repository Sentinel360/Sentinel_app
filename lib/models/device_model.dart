import 'package:cloud_firestore/cloud_firestore.dart';

class DeviceModel {
  final String deviceId;
  final String userId;
  final String name;
  final int batteryLevel;
  final String firmwareVersion;
  final DateTime lastSeen;
  final bool isActive;
  final GeoPoint? location;

  DeviceModel({
    required this.deviceId,
    required this.userId,
    required this.name,
    required this.batteryLevel,
    required this.firmwareVersion,
    required this.lastSeen,
    required this.isActive,
    this.location,
  });

  factory DeviceModel.fromMap(String deviceId, Map<String, dynamic> data) {
    return DeviceModel(
      deviceId: deviceId,
      userId: data['userId'] ?? '',
      name: data['name'] ?? '',
      batteryLevel: data['batteryLevel'] ?? 0,
      firmwareVersion: data['firmwareVersion'] ?? '1.0.0',
      lastSeen: (data['lastSeen'] as Timestamp).toDate(),
      isActive: data['isActive'] ?? false,
      location: data['location'] as GeoPoint?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'batteryLevel': batteryLevel,
      'firmwareVersion': firmwareVersion,
      'lastSeen': Timestamp.fromDate(lastSeen),
      'isActive': isActive,
      'location': location,
    };
  }
}
