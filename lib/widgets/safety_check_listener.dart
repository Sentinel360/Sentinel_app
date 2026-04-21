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
        .listen(
          _onEscalationUpdate,
          onError: (e) => debugPrint('[SCL] escalation stream error: $e'),
        );
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

class _SafetyCheckDialog extends StatefulWidget {
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
  State<_SafetyCheckDialog> createState() => _SafetyCheckDialogState();
}

class _SafetyCheckDialogState extends State<_SafetyCheckDialog>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseScale;

  static const Color _brand    = Color(0xFF22D3EE);
  static const Color _darkNav  = Color(0xFF0F172A);
  static const Color _danger   = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);
    _pulseScale = Tween<double>(begin: 1.0, end: 1.07).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool isFinal = widget.attempt == widget.maxAttempts;
    final Color ringColor = isFinal ? _danger : _brand;

    return PopScope(
      canPop: false,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.40),
                blurRadius: 48,
                offset: const Offset(0, 20),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Dark header ───────────────────────────────────────
                Container(
                  width: double.infinity,
                  color: _darkNav,
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 28),
                  child: Column(
                    children: [
                      ScaleTransition(
                        scale: _pulseScale,
                        child: SizedBox(
                          width: 92,
                          height: 92,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 92,
                                height: 92,
                                child: CircularProgressIndicator(
                                  value: widget.attempt / widget.maxAttempts,
                                  backgroundColor:
                                      Colors.white.withValues(alpha: 0.10),
                                  color: ringColor,
                                  strokeWidth: 3.5,
                                  strokeCap: StrokeCap.round,
                                ),
                              ),
                              Container(
                                width: 70,
                                height: 70,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: ringColor.withValues(alpha: 0.12),
                                ),
                                child: Icon(
                                  isFinal
                                      ? Icons.warning_rounded
                                      : Icons.shield_outlined,
                                  color: ringColor,
                                  size: 34,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'SAFETY CHECK',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _brand,
                          letterSpacing: 2.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Check ${widget.attempt} of ${widget.maxAttempts}',
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                // ── White body ────────────────────────────────────────
                Container(
                  color: Colors.white,
                  padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
                  child: Column(
                    children: [
                      Text(
                        'Are you okay?',
                        style: GoogleFonts.inter(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: _darkNav,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Sentinel 360 detected an unusual\ntrip pattern.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          color: const Color(0xFF64748B),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attempt progress dots
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(widget.maxAttempts, (i) {
                          final filled = i < widget.attempt;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: filled ? 22 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(4),
                              color: filled
                                  ? (isFinal ? _danger : _brand)
                                  : const Color(0xFFE2E8F0),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isFinal
                            ? 'Last check — no response will immediately\nalert your emergency contacts.'
                            : 'No response after ${widget.maxAttempts} checks will alert\nyour emergency contacts.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: isFinal
                              ? _danger.withValues(alpha: 0.85)
                              : const Color(0xFF94A3B8),
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 22),

                      // I'm OK
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: widget.onOk,
                          icon: const Icon(
                              Icons.check_circle_outline_rounded, size: 19),
                          label: Text(
                            "I'm OK",
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brand,
                            foregroundColor: _darkNav,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),

                      // I need help
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton.icon(
                          onPressed: widget.onNotOk,
                          icon: const Icon(Icons.sos_rounded, size: 19),
                          label: Text(
                            'I need help',
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _danger,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
