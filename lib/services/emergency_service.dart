import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/emergency_alert_model.dart';
import 'trip_service.dart';

class EmergencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final TripService _tripService = TripService();

  // Trigger emergency during an active trip
  Future<String> triggerEmergency({
    required String userId,
    required String tripId,
    required GeoPoint location,
    String triggerSource = 'manual',
  }) async {
    final alert = EmergencyAlertModel(
      userId: userId,
      tripId: tripId,
      location: location,
      triggeredAt: DateTime.now(),
      resolved: false,
      triggerSource: triggerSource,
    );

    final docRef = await _firestore
        .collection('emergency_alerts')
        .add(alert.toMap());

    // Update trip status to emergency
    await _tripService.updateTripStatus(tripId: tripId, status: 'emergency');

    return docRef.id;
  }

  // Trigger emergency even without an active trip (e.g. from emergency screen)
  Future<String> triggerEmergencyNoTrip({
    required String userId,
    required GeoPoint location,
    String triggerSource = 'manual',
  }) async {
    final data = {
      'userId': userId,
      'tripId': null,
      'location': location,
      'triggeredAt': Timestamp.fromDate(DateTime.now()),
      'resolved': false,
      'triggerSource': triggerSource,
    };

    final docRef = await _firestore.collection('emergency_alerts').add(data);

    return docRef.id;
  }

  // Resolve an emergency alert
  Future<void> resolveEmergency({
    required String alertId,
    required String tripId,
  }) async {
    await _firestore.collection('emergency_alerts').doc(alertId).update({
      'resolved': true,
      'resolvedAt': Timestamp.fromDate(DateTime.now()),
    });

    await _tripService.updateTripStatus(tripId: tripId, status: 'active');
  }

  // Stream active emergency alerts for a user
  Stream<List<EmergencyAlertModel>> streamActiveAlerts(String userId) {
    return _firestore
        .collection('emergency_alerts')
        .where('userId', isEqualTo: userId)
        .where('resolved', isEqualTo: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => EmergencyAlertModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  // Get all emergency alerts for a user
  Future<List<EmergencyAlertModel>> getAlertHistory(String userId) async {
    final snapshot = await _firestore
        .collection('emergency_alerts')
        .where('userId', isEqualTo: userId)
        .orderBy('triggeredAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => EmergencyAlertModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // Get a single alert by ID
  Future<EmergencyAlertModel?> getAlertById(String alertId) async {
    final doc = await _firestore
        .collection('emergency_alerts')
        .doc(alertId)
        .get();
    if (!doc.exists || doc.data() == null) return null;
    return EmergencyAlertModel.fromMap(doc.id, doc.data()!);
  }
}
