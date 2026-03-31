import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../app_keys.dart';
import '../services/trip_manager.dart';

/// Listens for successful wearable-triggered SOS and surfaces a clear in-app ack.
class WearableSosListener extends StatefulWidget {
  const WearableSosListener({super.key, required this.child});

  final Widget child;

  @override
  State<WearableSosListener> createState() => _WearableSosListenerState();
}

class _WearableSosListenerState extends State<WearableSosListener> {
  StreamSubscription<DateTime>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = TripManager().wearableSosAckStream.listen((_) => _showAck());
  }

  void _showAck() {
    final messenger = rootScaffoldMessengerKey.currentState;
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 5),
        backgroundColor: const Color(0xFFB91C1C),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        content: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.sensors, color: Colors.white, size: 28),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'SOS from wearable',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Your Sentinel device triggered an alert. Emergency contacts are being notified.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
