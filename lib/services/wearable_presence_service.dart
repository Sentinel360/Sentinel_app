import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Persists wearable Bluetooth link state on [users/{uid}] for dashboards and sync.
class WearablePresenceService {
  WearablePresenceService._();
  static final WearablePresenceService instance = WearablePresenceService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String _field = 'wearableBle';

  Future<void> recordConnected({required String deviceName}) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        _field: {
          'connected': true,
          'deviceName': deviceName,
          'lastConnectedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[WearablePresence] recordConnected failed: $e');
    }
  }

  Future<void> recordDisconnected() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await _db.collection('users').doc(uid).set({
        _field: {
          'connected': false,
          'lastDisconnectedAt': FieldValue.serverTimestamp(),
        },
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[WearablePresence] recordDisconnected failed: $e');
    }
  }
}
