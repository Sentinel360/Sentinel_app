import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../screens/home_screen.dart';
import '../screens/onboarding_screen.dart';
import '../services/trip_manager.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  String? _tokenSavedForUid;
  String? _resumeCheckedForUid;
  StreamSubscription<String>? _tokenRefreshSub;

  @override
  void dispose() {
    _tokenRefreshSub?.cancel();
    super.dispose();
  }

  Future<void> _onUserAuthenticated(String uid) async {
    await _saveFcmToken(uid);
    await _checkInterruptedTrip(uid);
  }

  Future<void> _saveFcmToken(String uid) async {
    if (_tokenSavedForUid == uid) return;
    _tokenSavedForUid = uid;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await FirebaseFirestore.instance.collection('users').doc(uid).set(
        {'fcmToken': token},
        SetOptions(merge: true),
      );
      await _tokenRefreshSub?.cancel();
      _tokenRefreshSub =
          FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        FirebaseFirestore.instance.collection('users').doc(uid).set(
          {'fcmToken': newToken},
          SetOptions(merge: true),
        );
      });
    } catch (e) {
      debugPrint('FCM token save failed: $e');
    }
  }

  Future<void> _checkInterruptedTrip(String uid) async {
    if (_resumeCheckedForUid == uid) return;
    _resumeCheckedForUid = uid;

    final trip = await TripManager().findInterruptedTrip();
    if (trip == null || !mounted) return;

    final tripId = trip['tripId'] as String;
    final destination = trip['destinationName'] as String;
    final startedAt = trip['startedAt'] as DateTime?;

    _showRecoveryDialog(
      tripId: tripId,
      destination: destination,
      startedAt: startedAt,
    );
  }

  void _showRecoveryDialog({
    required String tripId,
    required String destination,
    required DateTime? startedAt,
  }) {
    final timeAgo = _formatTimeAgo(startedAt);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _TripRecoveryDialog(
        destination: destination,
        timeAgo: timeAgo,
        onStillOnTrip: () async {
          Navigator.of(context).pop();
          await TripManager().resumeTrip(tripId);
          if (mounted) Navigator.of(context).pushReplacementNamed('/map');
        },
        onArrived: () async {
          Navigator.of(context).pop();
          await TripManager().markTripArrived(tripId);
        },
      ),
    );
  }

  String _formatTimeAgo(DateTime? startedAt) {
    if (startedAt == null) return 'some time ago';
    final diff = DateTime.now().difference(startedAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} hr ago';
    return '${diff.inDays} day(s) ago';
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF8FAFC),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF2563EB)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          _onUserAuthenticated(snapshot.data!.uid);
          return const HomeScreen();
        }

        return const OnboardingScreen();
      },
    );
  }
}

// ── Recovery Dialog ───────────────────────────────────────────────────────────

class _TripRecoveryDialog extends StatelessWidget {
  const _TripRecoveryDialog({
    required this.destination,
    required this.timeAgo,
    required this.onStillOnTrip,
    required this.onArrived,
  });

  final String destination;
  final String timeAgo;
  final VoidCallback onStillOnTrip;
  final VoidCallback onArrived;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: Color(0xFF2563EB),
                  size: 34,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Unended Trip Found',
                style: GoogleFonts.inter(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                'You have a trip to $destination that was not ended ($timeAgo). Are you still on this trip, or have you already arrived?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF475569),
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 24),

              // Still on trip
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onStillOnTrip,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "I'm still on this trip",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Already arrived
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onArrived,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF16A34A),
                    side: const BorderSide(
                        color: Color(0xFF16A34A), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    "I've already arrived",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
