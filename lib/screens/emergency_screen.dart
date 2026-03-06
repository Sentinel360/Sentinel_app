import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '../services/emergency_service.dart';
import '../services/auth_service.dart';

// ── Hold duration ─────────────────────────────────────────────────────────────
const _kHoldDuration = Duration(seconds: 3);

class EmergencyScreen extends StatefulWidget {
  const EmergencyScreen({super.key});
  @override
  State<EmergencyScreen> createState() => _EmergencyScreenState();
}

class _EmergencyScreenState extends State<EmergencyScreen>
    with TickerProviderStateMixin {
  // ── SOS state ──────────────────────────────────────────────────────────────
  bool _isHolding = false;
  bool _isSending = false;
  bool _sosSent = false;
  int _countdown = 3;
  Timer? _holdTimer;
  Timer? _countdownTimer;

  // ── Progress ring controller ───────────────────────────────────────────────
  late AnimationController _holdController; // 0→1 over 3 seconds while held
  late AnimationController _pulseController; // idle pulse
  late AnimationController _rotateController;
  late AnimationController _waveController;
  late Animation<double> _pulseAnimation;

  final EmergencyService _emergencyService = EmergencyService();
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();

    _holdController = AnimationController(
      vsync: this,
      duration: _kHoldDuration,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat();

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.12).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    _holdController.dispose();
    _pulseController.dispose();
    _rotateController.dispose();
    _waveController.dispose();
    super.dispose();
  }

  // ── Hold logic ────────────────────────────────────────────────────────────

  void _onHoldStart() {
    if (_isSending || _sosSent || _isHolding) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _isHolding = true;
      _countdown = 3;
    });
    _holdController.forward(from: 0);

    // Countdown ticks: 3 → 2 → 1
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() => _countdown--);
      HapticFeedback.lightImpact();
      if (_countdown <= 0) t.cancel();
    });

    // Fire after full hold
    _holdTimer = Timer(_kHoldDuration, () {
      if (_isHolding) _triggerSOS();
    });
  }

  void _onHoldEnd() {
    if (_isSending || _sosSent) return;
    if (_isHolding) {
      _holdTimer?.cancel();
      _countdownTimer?.cancel();
      _holdController.reverse();
      HapticFeedback.lightImpact();
      setState(() {
        _isHolding = false;
        _countdown = 3;
      });
    }
  }

  Future<void> _triggerSOS() async {
    _holdTimer?.cancel();
    _countdownTimer?.cancel();
    HapticFeedback.heavyImpact();
    setState(() {
      _isHolding = false;
      _isSending = true;
    });
    _holdController.stop();

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final user = await _authService.getCurrentUserData();
      final activeTripId = user?.activeTripId;

      // Get real GPS location if available
      GeoPoint location = const GeoPoint(5.6037, -0.1870);
      try {
        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 5),
          ),
        );
        location = GeoPoint(pos.latitude, pos.longitude);
      } catch (_) {
        // Use fallback location — don't block SOS for GPS failure
      }

      if (activeTripId == null) {
        // Still trigger alert even without active trip
        await _emergencyService.triggerEmergencyNoTrip(
          userId: uid,
          location: location,
        );
      } else {
        await _emergencyService.triggerEmergency(
          userId: uid,
          tripId: activeTripId,
          location: location,
          triggerSource: 'manual',
        );
      }

      if (mounted) {
        setState(() {
          _isSending = false;
          _sosSent = true;
        });
        HapticFeedback.heavyImpact();
      }
    } catch (e) {
      debugPrint('SOS error: $e');
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        _showMessage(
          'Failed to send SOS. Please call 191 directly.',
          isError: true,
        );
      }
    }
  }

  void _showMessage(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: isError
            ? const Color(0xFFEF4444)
            : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: Stack(
        children: [
          const AnimatedBackground(),
          AnimatedBuilder(
            animation: _waveController,
            builder: (_, __) => CustomPaint(
              size: Size.infinite,
              painter: EmergencyWavePainter(_waveController.value),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: SingleChildScrollView(
                    physics: _isHolding
                        ? const NeverScrollableScrollPhysics()
                        : const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Column(
                        children: [
                          const SizedBox(height: 20),
                          _buildWarningIcon(),
                          const SizedBox(height: 32),
                          _buildTitle(),
                          const SizedBox(height: 32),
                          _buildInfoCard(),
                          const SizedBox(height: 40),
                          _buildSOSButton(),
                          const SizedBox(height: 20),
                          _buildHoldInstruction(),
                          const SizedBox(height: 32),
                          if (!_sosSent) _buildCancelButton(),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(),
    );
  }

  // ── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.6),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFF334155).withOpacity(0.5),
                ),
              ),
              child: const Icon(
                Icons.arrow_back_rounded,
                color: Color(0xFFF1F5F9),
                size: 20,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFEF4444).withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFEF4444).withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.emergency, color: Color(0xFFEF4444), size: 14),
                const SizedBox(width: 8),
                Text(
                  'Emergency',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFEF4444),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 44),
        ],
      ),
    );
  }

  // ── Warning icon ──────────────────────────────────────────────────────────

  Widget _buildWarningIcon() {
    return AnimatedBuilder(
      animation: _rotateController,
      builder: (_, child) => Transform.rotate(
        angle: _rotateController.value * 2 * math.pi,
        child: child,
      ),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [
              const Color(0xFFEF4444).withOpacity(0.2),
              const Color(0xFFDC2626).withOpacity(0.1),
            ],
          ),
          border: Border.all(
            color: const Color(0xFFEF4444).withOpacity(0.3),
            width: 2,
          ),
        ),
        child: const Icon(
          Icons.warning_amber_rounded,
          size: 50,
          color: Color(0xFFEF4444),
        ),
      ),
    );
  }

  // ── Title & description ───────────────────────────────────────────────────

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'Need Immediate Help?',
          style: GoogleFonts.inter(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFF1F5F9),
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Hold the SOS button for 3 seconds to alert your emergency contacts. '
          'Your GPS location will be sent automatically.',
          style: GoogleFonts.inter(
            fontSize: 14,
            color: const Color(0xFF94A3B8),
            height: 1.6,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ── Info card ─────────────────────────────────────────────────────────────

  Widget _buildInfoCard() {
    final items = [
      (Icons.contact_phone, 'Emergency Contacts', 'SMS with your location'),
      (Icons.location_on, 'Live GPS Location', 'Exact coordinates shared'),
      (
        Icons.local_police,
        'Emergency Numbers',
        'Ghana Police 191 • Ambulance 193',
      ),
    ];
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1E293B).withOpacity(0.6),
            const Color(0xFF0F172A).withOpacity(0.4),
          ],
        ),
        border: Border.all(
          color: const Color(0xFF334155).withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Column(
        children: items
            .map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        item.$1,
                        color: const Color(0xFF3B82F6),
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.$2,
                            style: GoogleFonts.inter(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFF1F5F9),
                            ),
                          ),
                          Text(
                            item.$3,
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF10B981),
                      size: 16,
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── SOS Button ────────────────────────────────────────────────────────────

  Widget _buildSOSButton() {
    // Confirmed sent state
    if (_sosSent) {
      return _buildSOSSentState();
    }

    // Sending state
    if (_isSending) {
      return _buildSendingState();
    }

    // Normal / holding state
    return GestureDetector(
      onLongPressStart: (_) => _onHoldStart(),
      onLongPressEnd: (_) => _onHoldEnd(),
      onLongPressCancel: () => _onHoldEnd(),
      child: AnimatedBuilder(
        animation: Listenable.merge([_holdController, _pulseAnimation]),
        builder: (_, __) {
          final holdProgress = _holdController.value;
          final scale = _isHolding
              ? 1.0 + (holdProgress * 0.08)
              : _pulseAnimation.value;

          return Transform.scale(
            scale: scale,
            child: SizedBox(
              width: 200,
              height: 200,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow shadow
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withOpacity(
                            _isHolding
                                ? 0.6
                                : 0.3 + (_pulseController.value * 0.2),
                          ),
                          blurRadius: _isHolding ? 60 : 40,
                          spreadRadius: _isHolding ? 15 : 8,
                        ),
                      ],
                    ),
                  ),
                  // Button body
                  Container(
                    width: 192,
                    height: 192,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _isHolding
                          ? const Color(0xFFDC2626)
                          : const Color(0xFFEF4444),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.emergency,
                          size: 56,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'SOS',
                          style: GoogleFonts.inter(
                            fontSize: 30,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: 2,
                          ),
                        ),
                        if (_isHolding) ...[
                          const SizedBox(height: 4),
                          Text(
                            '$_countdown',
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Progress ring
                  if (_isHolding)
                    SizedBox(
                      width: 200,
                      height: 200,
                      child: CircularProgressIndicator(
                        value: holdProgress,
                        strokeWidth: 6,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSendingState() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 192,
            height: 192,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFFDC2626),
            ),
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Sending...',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSOSSentState() {
    return Column(
      children: [
        Container(
          width: 200,
          height: 200,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF10B981),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withOpacity(0.4),
                blurRadius: 40,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_rounded, size: 64, color: Colors.white),
              const SizedBox(height: 8),
              Text(
                'SOS Sent!',
                style: GoogleFonts.inter(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withOpacity(0.12),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Text(
                'Your emergency contacts have been\nnotified via SMS with your location.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFF6EE7B7),
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                '🚔 Ghana Police: 191  •  🚑 Ambulance: 193',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF1F5F9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              'Return to Home',
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ── Hold instruction ──────────────────────────────────────────────────────

  Widget _buildHoldInstruction() {
    if (_sosSent || _isSending) return const SizedBox.shrink();
    return AnimatedOpacity(
      opacity: _isHolding ? 0.0 : 1.0,
      duration: const Duration(milliseconds: 200),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B).withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF334155).withOpacity(0.4),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.touch_app_outlined,
              color: Color(0xFF94A3B8),
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(
              'Hold for 3 seconds to activate',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFF94A3B8),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Cancel button ─────────────────────────────────────────────────────────

  Widget _buildCancelButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: () => Navigator.pushReplacementNamed(context, '/home'),
        style: OutlinedButton.styleFrom(
          side: BorderSide(
            color: const Color(0xFF334155).withOpacity(0.5),
            width: 1.5,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: const Color(0xFF1E293B).withOpacity(0.4),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.close_rounded, color: Color(0xFF94A3B8), size: 20),
            const SizedBox(width: 8),
            Text(
              'Cancel',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Nav bar ───────────────────────────────────────────────────────────────

  Widget _buildNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        border: Border(
          top: BorderSide(
            color: const Color(0xFF1E293B).withOpacity(0.5),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _navItem(
                Icons.home_outlined,
                Icons.home,
                'Home',
                false,
                () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              _navItem(
                Icons.explore_outlined,
                Icons.explore,
                'Map',
                false,
                () => Navigator.pushNamed(context, '/map'),
              ),
              _navItem(
                Icons.router_outlined,
                Icons.router,
                'Device',
                false,
                () => Navigator.pushNamed(context, '/device'),
              ),
              _navItem(
                Icons.emergency_outlined,
                Icons.emergency,
                'SOS',
                true,
                () {},
                color: const Color(0xFFEF4444),
              ),
              _navItem(
                Icons.person_outline,
                Icons.person,
                'Profile',
                false,
                () => Navigator.pushNamed(context, '/profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem(
    IconData icon,
    IconData activeIcon,
    String label,
    bool isActive,
    VoidCallback onTap, {
    Color? color,
  }) {
    final c =
        color ?? (isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? c.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: c, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: c,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Animated Background ───────────────────────────────────────────────────────
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});
  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (_, __) =>
        CustomPaint(size: Size.infinite, painter: BackgroundPainter(_c.value)),
  );
}

class BackgroundPainter extends CustomPainter {
  final double v;
  BackgroundPainter(this.v);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A14), Color(0xFF0A1628), Color(0xFF050A14)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    final paint = Paint()..style = PaintingStyle.fill;
    final orbs = [
      {
        'x': size.width * 0.2,
        'y': size.height * 0.15 + math.sin(v * 2 * math.pi) * 30,
        'r': 100.0,
        'c': const Color(0xFFEF4444),
      },
      {
        'x': size.width * 0.8,
        'y': size.height * 0.7 + math.cos(v * 2 * math.pi) * 40,
        'r': 120.0,
        'c': const Color(0xFFDC2626),
      },
      {
        'x': size.width * 0.5,
        'y': size.height * 0.45 + math.sin(v * 2 * math.pi + 1) * 25,
        'r': 80.0,
        'c': const Color(0xFFF97316),
      },
    ];
    for (final o in orbs) {
      paint.shader =
          RadialGradient(
            colors: [
              (o['c'] as Color).withOpacity(0.15),
              (o['c'] as Color).withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0, 0.5, 1],
          ).createShader(
            Rect.fromCircle(
              center: Offset(o['x'] as double, o['y'] as double),
              radius: o['r'] as double,
            ),
          );
      canvas.drawCircle(
        Offset(o['x'] as double, o['y'] as double),
        o['r'] as double,
        paint,
      );
    }
    final gp = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (double i = 0; i < size.width; i += 40)
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gp);
    for (double i = 0; i < size.height; i += 40)
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gp);
  }

  @override
  bool shouldRepaint(BackgroundPainter o) => v != o.v;
}

class EmergencyWavePainter extends CustomPainter {
  final double v;
  EmergencyWavePainter(this.v);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, size.height / 2),
      size.width * 0.8 * v,
      Paint()
        ..shader =
            RadialGradient(
              colors: [
                const Color(0xFFEF4444).withOpacity(0.05 * v),
                const Color(0xFFEF4444).withOpacity(0.0),
              ],
            ).createShader(
              Rect.fromCircle(
                center: Offset(size.width / 2, size.height / 2),
                radius: size.width * 0.8 * v,
              ),
            ),
    );
  }

  @override
  bool shouldRepaint(EmergencyWavePainter o) => v != o.v;
}
