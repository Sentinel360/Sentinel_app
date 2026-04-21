import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_keys.dart';
import '../services/trip_manager.dart';

/// Wraps the entire app and watches the active trip's escalation document.
/// When the cloud detects an unsafe trip and sends a safety prompt, this widget
/// surfaces an undismissable dialog so the passenger can respond "I'm OK" or
/// "I need help".
///
/// Works in all three app states:
///   • Foreground — Firestore stream fires immediately.
///   • Background — FCM wakes the stream; dialog shows on return to foreground.
///   • Terminated — on restart, falls back to checking users/{uid}.activeTripId
///     in Firestore so the dialog still appears even after a cold start.
class SafetyCheckListener extends StatefulWidget {
  const SafetyCheckListener({super.key, required this.child});

  final Widget child;

  @override
  State<SafetyCheckListener> createState() => _SafetyCheckListenerState();
}

class _SafetyCheckListenerState extends State<SafetyCheckListener> {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<ActiveTripState>? _tripSub;
  StreamSubscription<Map<String, dynamic>?>? _escalationSub;
  String? _monitoredTripId;
  bool _dialogVisible = false;
  int _shownAttempt = 0;

  @override
  void initState() {
    super.initState();

    // 1. Subscribe to live TripManager state changes.
    _tripSub = TripManager().stateStream.listen(_onTripStateChanged);

    // 2. Pick up the trip if TripManager already has one in memory.
    final currentTripId = TripManager().currentState.tripId;
    if (currentTripId != null) {
      _subscribeToEscalation(currentTripId);
    } else {
      // 3. Cold-start fallback: TripManager has no in-memory trip (app was killed).
      //    Read activeTripId from Firestore so we still catch escalations.
      _restoreActiveTripFromFirestore();
    }
  }

  Future<void> _restoreActiveTripFromFirestore() async {
    try {
      // On cold start Firebase Auth restores its session asynchronously —
      // currentUser is briefly null even for a signed-in user. Wait up to
      // 5 seconds for the session to be available before giving up.
      String? uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        final user = await FirebaseAuth.instance
            .authStateChanges()
            .firstWhere((u) => u != null, orElse: () => null)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
        if (!mounted) return;
        uid = user?.uid;
      }
      if (uid == null) return;

      final userSnap = await _db.collection('users').doc(uid).get();
      final activeTripId = userSnap.data()?['activeTripId'] as String?;

      if (activeTripId != null && activeTripId.isNotEmpty) {
        _subscribeToEscalation(activeTripId);
      }
    } catch (e) {
      debugPrint('SafetyCheckListener: cold-start restore failed — $e');
    }
  }

  void _onTripStateChanged(ActiveTripState state) {
    if (state.tripId == _monitoredTripId) return;
    _subscribeToEscalation(state.tripId);
  }

  void _subscribeToEscalation(String? tripId) {
    debugPrint('[SCL] _subscribeToEscalation: tripId=$tripId (was $_monitoredTripId)');
    _escalationSub?.cancel();
    _monitoredTripId = tripId;

    if (tripId == null) {
      _dismissDialog();
      return;
    }

    _escalationSub = _db
        .collection('trip_escalations')
        .doc(tripId)
        .snapshots()
        .map((doc) => doc.exists ? doc.data() : null)
        .listen(_onEscalationUpdate);
  }

  void _onEscalationUpdate(Map<String, dynamic>? data) {
    if (data == null) {
      debugPrint('[SCL] _onEscalationUpdate: no document');
      return;
    }

    final status = data['status'] as String? ?? '';
    final userResponse = data['userResponse'];
    final attemptsSent = (data['attemptsSent'] as int?) ?? 1;
    final maxAttempts = (data['maxAttempts'] as int?) ?? 3;

    debugPrint('[SCL] _onEscalationUpdate: status=$status userResponse=$userResponse attempts=$attemptsSent dialogVisible=$_dialogVisible');

    final shouldShow = status == 'active' && userResponse == null;

    if (shouldShow && !_dialogVisible) {
      _showDialog(attempt: attemptsSent, maxAttempts: maxAttempts);
    } else if (shouldShow && _dialogVisible && attemptsSent != _shownAttempt) {
      _dismissDialog();
      _showDialog(attempt: attemptsSent, maxAttempts: maxAttempts);
    } else if (!shouldShow && _dialogVisible) {
      _dismissDialog();
    }
  }

  void _showDialog({required int attempt, required int maxAttempts}) {
    debugPrint('[SCL] _showDialog: attempt=$attempt');
    _dialogVisible = true;
    _shownAttempt = attempt;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final navigator = rootNavigatorKey.currentState;
      debugPrint('[SCL] postFrameCallback: mounted=$mounted dialogVisible=$_dialogVisible navigatorNull=${navigator == null}');
      if (!mounted || !_dialogVisible) return;
      if (navigator == null) return;

      showDialog<void>(
        context: navigator.context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (_) => _SafetyCheckDialog(
          attempt: attempt,
          maxAttempts: maxAttempts,
          onOk: _respondOk,
          onNotOk: _respondNotOk,
        ),
      ).then((_) {
        if (mounted) _dialogVisible = false;
      });
    });
  }

  void _dismissDialog() {
    if (!_dialogVisible) return;
    rootNavigatorKey.currentState?.maybePop();
    _dialogVisible = false;
  }

  /// Write the user's response directly to Firestore using the tripId we are
  /// already tracking — avoids depending on TripManager's in-memory state,
  /// which is null when the app was killed and restarted via a notification.
  Future<void> _respond({required bool isOk}) async {
    final tripId = _monitoredTripId;
    if (tripId == null) return;

    rootNavigatorKey.currentState?.pop();
    _dialogVisible = false;

    await _db.collection('trip_escalations').doc(tripId).set(
      {
        'userResponse': isOk ? 'OK' : 'NOT_OK',
        'respondedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _respondOk() => _respond(isOk: true);
  Future<void> _respondNotOk() => _respond(isOk: false);

  @override
  void dispose() {
    _tripSub?.cancel();
    _escalationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

// ── Dialog UI ────────────────────────────────────────────────────────────────

class _SafetyCheckDialog extends StatelessWidget {
  const _SafetyCheckDialog({
    required this.attempt,
    required this.maxAttempts,
    required this.onOk,
    required this.onNotOk,
  });

  final int attempt;
  final int maxAttempts;
  final VoidCallback onOk;
  final VoidCallback onNotOk;

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
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: Color(0xFFD97706),
                  size: 36,
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Safety Check',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 8),

              Text(
                'Sentinel 360 has detected an unusual trip pattern.\nAre you okay?',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                'Check $attempt of $maxAttempts — no response will alert your emergency contacts.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: const Color(0xFF9CA3AF),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: onOk,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF16A34A),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    "I'm OK",
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: onNotOk,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(
                        color: Color(0xFFDC2626), width: 1.5),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'I need help',
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
