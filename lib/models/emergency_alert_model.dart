import 'package:cloud_firestore/cloud_firestore.dart';

class EmergencyAlertModel {
  final String? alertId;
  final String userId;
  final String tripId;
  final GeoPoint location;
  final DateTime triggeredAt;
  final bool resolved;
  final DateTime? resolvedAt;
  final String triggerSource;

  EmergencyAlertModel({
    this.alertId,
    required this.userId,
    required this.tripId,
    required this.location,
    required this.triggeredAt,
    this.resolved = false,
    this.resolvedAt,
    this.triggerSource = 'manual',
  });

  factory EmergencyAlertModel.fromMap(
    String alertId,
    Map<String, dynamic> data,
  ) {
    return EmergencyAlertModel(
      alertId: alertId,
      userId: data['userId'] ?? '',
      tripId: data['tripId'] ?? '',
      location: data['location'] as GeoPoint,
      triggeredAt: (data['triggeredAt'] as Timestamp).toDate(),
      resolved: data['resolved'] ?? false,
      resolvedAt: data['resolvedAt'] != null
          ? (data['resolvedAt'] as Timestamp).toDate()
          : null,
      triggerSource: data['triggerSource'] ?? 'manual',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'tripId': tripId,
      'location': location,
      'triggeredAt': Timestamp.fromDate(triggeredAt),
      'resolved': resolved,
      'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
      'triggerSource': triggerSource,
    };
  }
}
