import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/trip_model.dart';

class TripService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Create a new trip and return the trip document ID
  Future<String> startTrip({
    required String userId,
    required String deviceId,
    required GeoPoint startLocation,
  }) async {
    final tripData = TripModel(
      userId: userId,
      deviceId: deviceId,
      startLocation: startLocation,
      startedAt: DateTime.now(),
      status: 'active',
    );

    // Create the trip document in Firestore
    final docRef = await _firestore.collection('trips').add(tripData.toMap());

    // Update the user's activeTripId
    await _firestore.collection('users').doc(userId).update({
      'activeTripId': docRef.id,
    });

    return docRef.id;
  }

  // Stream the active trip in real time
  Stream<TripModel?> streamActiveTrip(String tripId) {
    return _firestore.collection('trips').doc(tripId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists || snapshot.data() == null) return null;
      return TripModel.fromMap(snapshot.id, snapshot.data()!);
    });
  }

  // Update live trip data during a ride
  Future<void> updateTripData({
    required String tripId,
    required double distance,
    required int duration,
    required GeoPoint currentLocation,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'distance': distance,
      'duration': duration,
      'currentLocation': currentLocation,
    });
  }

  // Append an anomaly to the trip document
  Future<void> addAnomaly({
    required String tripId,
    required AnomalyEvent anomaly,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'anomalies': FieldValue.arrayUnion([anomaly.toMap()]),
    });
  }

  // Increment escalation attempts counter
  Future<void> incrementEscalation(String tripId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'escalationAttempts': FieldValue.increment(1),
    });
  }

  // Reset escalation counter when user responds they are safe
  Future<void> resetEscalation(String tripId) async {
    await _firestore.collection('trips').doc(tripId).update({
      'escalationAttempts': 0,
    });
  }

  // Update trip status (active, emergency, completed)
  Future<void> updateTripStatus({
    required String tripId,
    required String status,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({'status': status});
  }

  // Update the route polyline once fetched from Google Maps
  Future<void> updateRoutePolyline({
    required String tripId,
    required List<GeoPoint> polyline,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'routePolyline': polyline
          .map((p) => {'lat': p.latitude, 'lng': p.longitude})
          .toList(),
    });
  }

  // End the trip
  Future<void> endTrip({
    required String tripId,
    required String userId,
    required GeoPoint endLocation,
    required double finalDistance,
    required int finalDuration,
  }) async {
    await _firestore.collection('trips').doc(tripId).update({
      'status': 'completed',
      'endLocation': endLocation,
      'distance': finalDistance,
      'duration': finalDuration,
      'endedAt': Timestamp.fromDate(DateTime.now()),
    });

    // Clear the user's activeTripId
    await _firestore.collection('users').doc(userId).update({
      'activeTripId': null,
    });
  }

  // Get recent trips for a user
  Future<List<TripModel>> getRecentTrips(String userId) async {
    final snapshot = await _firestore
        .collection('trips')
        .where('userId', isEqualTo: userId)
        .orderBy('startedAt', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => TripModel.fromMap(doc.id, doc.data()))
        .toList();
  }

  // Get a single trip by ID
  Future<TripModel?> getTripById(String tripId) async {
    final doc = await _firestore.collection('trips').doc(tripId).get();
    if (!doc.exists || doc.data() == null) return null;
    return TripModel.fromMap(doc.id, doc.data()!);
  }
}
