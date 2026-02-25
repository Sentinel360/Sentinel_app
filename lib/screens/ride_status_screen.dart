import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/trip_service.dart';
import '../services/auth_service.dart';
import '../models/trip_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

class RideStatusScreen extends StatefulWidget {
  const RideStatusScreen({super.key});

  @override
  State<RideStatusScreen> createState() => _RideStatusScreenState();
}

class _RideStatusScreenState extends State<RideStatusScreen>
    with SingleTickerProviderStateMixin {
  final TripService _tripService = TripService();
  final AuthService _authService = AuthService();
  String? _activeTripId;
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _loadActiveTrip();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadActiveTrip() async {
    final user = await _authService.getCurrentUserData();
    if (mounted) {
      setState(() {
        _activeTripId = user?.activeTripId;
        _isLoading = false;
      });
    }
  }

  Future<void> _endTrip(String tripId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    await _tripService.endTrip(
      tripId: tripId,
      userId: uid,
      endLocation: const GeoPoint(5.6037, -0.1870),
      finalDistance: 0,
      finalDuration: 0,
    );
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050A14),
      body: Stack(
        children: [
          // Animated Background
          const AnimatedBackground(),

          // Main Content
          SafeArea(
            child: _isLoading
                ? Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B).withOpacity(0.6),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const CircularProgressIndicator(
                        color: Color(0xFF3B82F6),
                      ),
                    ),
                  )
                : _activeTripId == null
                ? _buildEmptyState()
                : StreamBuilder<TripModel?>(
                    stream: _tripService.streamActiveTrip(_activeTripId!),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B).withOpacity(0.6),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const CircularProgressIndicator(
                              color: Color(0xFF3B82F6),
                            ),
                          ),
                        );
                      }

                      final trip = snapshot.data;
                      if (trip == null) {
                        return _buildEmptyState();
                      }

                      return _buildTripStatus(trip);
                    },
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
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
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home,
                  label: 'Home',
                  isActive: false,
                  onTap: () {
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                ),
                _navItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Map',
                  isActive: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/map');
                  },
                ),
                _navItem(
                  icon: Icons.health_and_safety_outlined,
                  activeIcon: Icons.health_and_safety,
                  label: 'Status',
                  isActive: true,
                  onTap: () {},
                ),
                _navItem(
                  icon: Icons.emergency_outlined,
                  activeIcon: Icons.emergency,
                  label: 'SOS',
                  isActive: false,
                  color: const Color(0xFFEF4444),
                  onTap: () {
                    Navigator.pushNamed(context, '/emergency');
                  },
                ),
                _navItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isActive: false,
                  onTap: () {
                    Navigator.pushNamed(context, '/profile');
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF64748B).withOpacity(0.2),
                  const Color(0xFF475569).withOpacity(0.1),
                ],
              ),
              border: Border.all(
                color: const Color(0xFF64748B).withOpacity(0.3),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.health_and_safety_outlined,
              size: 60,
              color: Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Active Trip',
            style: GoogleFonts.inter(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Start monitoring a trip to see real-time\nsafety status and anomaly detection',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: const Color(0xFF64748B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () => Navigator.pushReplacementNamed(context, '/map'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2563EB),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.add_location_alt_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Start New Trip',
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTripStatus(TripModel trip) {
    final isEmergency = trip.status == 'emergency';
    final statusColor = isEmergency
        ? const Color(0xFFEF4444)
        : trip.anomalies.isNotEmpty
        ? const Color(0xFFF59E0B)
        : const Color(0xFF10B981);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF10B981).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.health_and_safety,
                            color: Color(0xFF10B981),
                            size: 16,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          "Trip Status",
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Active Monitoring',
                      style: GoogleFonts.inter(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFF1F5F9),
                      ),
                    ),
                  ],
                ),
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
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFF1F5F9),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Status Badge
            AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        statusColor.withOpacity(0.15),
                        statusColor.withOpacity(0.05),
                      ],
                    ),
                    border: Border.all(
                      color: statusColor.withOpacity(0.3),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(
                          0.2 + (_pulseController.value * 0.15),
                        ),
                        blurRadius: 20 + (_pulseController.value * 10),
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              statusColor.withOpacity(0.2),
                              statusColor.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Icon(
                          isEmergency
                              ? Icons.emergency
                              : trip.anomalies.isNotEmpty
                              ? Icons.warning_amber_rounded
                              : Icons.check_circle_outline,
                          color: statusColor,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEmergency
                                  ? 'EMERGENCY MODE'
                                  : trip.anomalies.isNotEmpty
                                  ? 'Anomaly Detected'
                                  : 'All Clear',
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEmergency
                                  ? 'Authorities have been notified'
                                  : trip.anomalies.isNotEmpty
                                  ? '${trip.anomalies.length} issue(s) detected'
                                  : 'Trip proceeding normally',
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                color: const Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Trip Stats
            Text(
              'Trip Statistics',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _statCard(
                    icon: Icons.straighten,
                    label: 'Distance',
                    value: '${trip.distance.toStringAsFixed(1)} km',
                    color: const Color(0xFF3B82F6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _statCard(
                    icon: Icons.timer_outlined,
                    label: 'Duration',
                    value: '${trip.duration} min',
                    color: const Color(0xFF8B5CF6),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Anomalies Section
            if (trip.anomalies.isNotEmpty) ...[
              Text(
                'Detected Anomalies',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFF1F5F9),
                ),
              ),
              const SizedBox(height: 12),
              ...trip.anomalies.map((anomaly) {
                final anomalyColor = anomaly.severity == 'high'
                    ? const Color(0xFFEF4444)
                    : anomaly.severity == 'medium'
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF1E293B).withOpacity(0.6),
                        const Color(0xFF0F172A).withOpacity(0.4),
                      ],
                    ),
                    border: Border.all(
                      color: anomalyColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: anomalyColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          color: anomalyColor,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              anomaly.type,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFF1F5F9),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${anomaly.severity.toUpperCase()} severity',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: anomalyColor,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: 24),
            ],

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pushNamed(context, '/emergency'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.emergency, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'SOS',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 56,
                    child: ElevatedButton(
                      onPressed: () => _endTrip(trip.tripId!),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.stop_circle_outlined, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'End Trip',
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
        ),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFF1F5F9),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor =
        color ?? (isActive ? const Color(0xFF3B82F6) : const Color(0xFF64748B));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? itemColor.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isActive ? activeIcon : icon, color: itemColor, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                color: itemColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Animated Background Component (same as other screens)
class AnimatedBackground extends StatefulWidget {
  const AnimatedBackground({super.key});

  @override
  State<AnimatedBackground> createState() => _AnimatedBackgroundState();
}

class _AnimatedBackgroundState extends State<AnimatedBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size.infinite,
          painter: BackgroundPainter(_controller.value),
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;

  BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Base gradient background
    final gradient = const LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF050A14), Color(0xFF0A1628), Color(0xFF050A14)],
    );

    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );

    // Floating ambient orbs
    final orbs = [
      {
        'x': size.width * 0.2,
        'y': size.height * 0.15 + (math.sin(animationValue * 2 * math.pi) * 30),
        'radius': 100.0,
        'color': const Color(0xFF2563EB),
      },
      {
        'x': size.width * 0.8,
        'y': size.height * 0.7 + (math.cos(animationValue * 2 * math.pi) * 40),
        'radius': 120.0,
        'color': const Color(0xFF1E40AF),
      },
      {
        'x': size.width * 0.5,
        'y':
            size.height * 0.45 +
            (math.sin(animationValue * 2 * math.pi + 1) * 25),
        'radius': 80.0,
        'color': const Color(0xFF0EA5E9),
      },
    ];

    for (var orb in orbs) {
      final orbGradient = RadialGradient(
        colors: [
          (orb['color'] as Color).withOpacity(0.15),
          (orb['color'] as Color).withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      );

      paint.shader = orbGradient.createShader(
        Rect.fromCircle(
          center: Offset(orb['x'] as double, orb['y'] as double),
          radius: orb['radius'] as double,
        ),
      );

      canvas.drawCircle(
        Offset(orb['x'] as double, orb['y'] as double),
        orb['radius'] as double,
        paint,
      );
    }

    // Subtle grid pattern
    final gridPaint = Paint()
      ..color = const Color(0xFF1E293B).withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridSpacing = 40.0;
    for (double i = 0; i < size.width; i += gridSpacing) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += gridSpacing) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter oldDelegate) =>
      animationValue != oldDelegate.animationValue;
}
