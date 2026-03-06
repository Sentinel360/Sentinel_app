import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import 'dart:math' as math;
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/device_service.dart';
import '../services/trip_manager.dart';
import '../models/trip_model.dart';
import '../models/device_model.dart';
import '../models/user_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _glowController;
  final AuthService _authService = AuthService();
  final TripService _tripService = TripService();
  final DeviceService _deviceService = DeviceService();

  UserModel? _currentUser;
  List<TripModel> _recentTrips = [];
  DeviceModel? _device;
  bool _isLoading = true;
  String _firstName = 'there';
  String _initials = '?';

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF050A14) : const Color(0xFFF8FAFC);
  Color get _surface => _isDark ? const Color(0xFF0F172A) : Colors.white;
  Color get _border => _isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _textMuted => _isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
    _loadData();
  }

  Future<void> _loadData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';

    // Fetch user first independently
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();

      if (mounted && userDoc.exists && userDoc.data() != null) {
        final fullName = userDoc.data()!['fullName'] as String? ?? 'there';
        setState(() {
          _firstName = fullName.split(' ').first;
          _initials = fullName
              .split(' ')
              .take(2)
              .map((e) => e.isNotEmpty ? e[0].toUpperCase() : '')
              .join();
        });
      }
    } catch (e) {
      print('DEBUG - User fetch error: $e');
    }

    // Fetch trips and device separately
    try {
      final trips = await _tripService.getRecentTrips(uid);
      final device = await _deviceService.getDeviceByUserId(uid);

      if (mounted) {
        setState(() {
          _recentTrips = trips;
          _device = device;
        });
      }
    } catch (e) {
      print('DEBUG - Trips/device error: $e');
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripState = context.watch<ActiveTripState>();
    final hasActiveTrip = tripState.phase == TripPhase.active;
    final firstName = _firstName;

    final initials = _initials;

    final isOnline = _device?.isActive ?? false;
    final glowColor = isOnline
        ? const Color(0xFF10B981)
        : const Color(0xFFEF4444);

    // Calculate stats
    final totalTrips = _recentTrips.length;
    final safeTrips = _recentTrips.where((t) => t.anomalies.isEmpty).length;
    final safePercent = totalTrips > 0
        ? '${((safeTrips / totalTrips) * 100).toStringAsFixed(0)}%'
        : 'N/A';

    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          AnimatedBackground(isDark: _isDark),
          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF2563EB),
                      backgroundColor: _isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFE2E8F0),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),

                          // Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        'Hi, ',
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      Text(
                                        '$firstName ',
                                        style: GoogleFonts.inter(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: _textPrimary,
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: hasActiveTrip
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        hasActiveTrip
                                            ? 'Trip in progress'
                                            : 'All systems operational',
                                        style: GoogleFonts.inter(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: hasActiveTrip
                                              ? const Color(0xFFF59E0B)
                                              : const Color(0xFF10B981),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/profile'),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [
                                        const Color(
                                          0xFF2563EB,
                                        ).withOpacity(0.2),
                                        const Color(
                                          0xFF1E40AF,
                                        ).withOpacity(0.2),
                                      ],
                                    ),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2563EB,
                                      ).withOpacity(0.3),
                                      width: 1.5,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF2563EB,
                                        ).withOpacity(0.2),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      initials,
                                      style: const TextStyle(
                                        color: Color(0xFF3B82F6),
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          if (hasActiveTrip)
                            GestureDetector(
                              onTap: () =>
                                  Navigator.pushReplacementNamed(context, '/map'),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  color: _surface,
                                  border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 1.5,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.directions_car_filled_outlined,
                                      color: Color(0xFFF59E0B),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Active trip running — tap to return to live map',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: _textPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 16),

                          // Device Status Card
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) {
                              return GestureDetector(
                                onTap: () =>
                                    Navigator.pushNamed(context, '/device'),
                                child: Container(
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(24),
                                    boxShadow: [
                                      BoxShadow(
                                        color: glowColor.withOpacity(
                                          0.2 + (_glowController.value * 0.15),
                                        ),
                                        blurRadius:
                                            20 + (_glowController.value * 10),
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.all(24),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      gradient: LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          glowColor.withOpacity(0.15),
                                          glowColor.withOpacity(0.1),
                                        ],
                                      ),
                                      border: Border.all(
                                        color: glowColor.withOpacity(0.3),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: const Color(
                                                  0xFF2563EB,
                                                ).withOpacity(0.15),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF2563EB,
                                                  ).withOpacity(0.3),
                                                  width: 1,
                                                ),
                                              ),
                                              child: const Icon(
                                                Icons.shield_outlined,
                                                color: Color(0xFF2563EB),
                                                size: 16,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Text(
                                              "Sentinel 360",
                                              style: GoogleFonts.inter(
                                                color: _textSecondary,
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        Row(
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
                                                    glowColor.withOpacity(0.2),
                                                    glowColor.withOpacity(0.15),
                                                  ],
                                                ),
                                              ),
                                              child: Icon(
                                                isOnline
                                                    ? Icons
                                                          .verified_user_outlined
                                                    : Icons.shield_outlined,
                                                color: glowColor,
                                                size: 28,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    _device != null
                                                        ? (_device!.isActive
                                                              ? 'IoT Device Connected'
                                                              : 'IoT Device Offline')
                                                        : 'No Device Paired',
                                                    style: GoogleFonts.inter(
                                                      fontSize: 18,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: _textPrimary,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 6),
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 10,
                                                              vertical: 5,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: glowColor
                                                              .withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Row(
                                                          children: [
                                                            Icon(
                                                              Icons
                                                                  .battery_charging_full,
                                                              color: glowColor,
                                                              size: 14,
                                                            ),
                                                            const SizedBox(
                                                              width: 4,
                                                            ),
                                                            Text(
                                                              _device != null
                                                                  ? '${_device!.batteryLevel}%'
                                                                  : 'N/A',
                                                              style: GoogleFonts.inter(
                                                                fontSize: 12,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color:
                                                                    glowColor,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        _device != null
                                                            ? '• ${_device!.deviceId}'
                                                            : '• Not connected',
                                                        style:
                                                            GoogleFonts.inter(
                                                              fontSize: 12,
                                                              color: _textMuted,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 32),

                          // Recent Trips Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Recent Trips",
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w700,
                                          color: _textPrimary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                              TextButton(
                                onPressed: () {},
                                child: Row(
                                  children: [
                                    Text(
                                      "View All",
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(
                                      Icons.arrow_forward_rounded,
                                      color: Color(0xFF3B82F6),
                                      size: 16,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Recent Trips List
                          _recentTrips.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: _border,
                                      width: 1,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      const Icon(
                                        Icons.route_outlined,
                                        color: Color(0xFF64748B),
                                        size: 40,
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No trips yet',
                                        style: GoogleFonts.inter(
                                          color: _textMuted,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : SizedBox(
                                  height: 200,
                                  child: ListView.separated(
                                    scrollDirection: Axis.horizontal,
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: _recentTrips.length,
                                    separatorBuilder: (context, index) =>
                                        const SizedBox(width: 16),
                                    itemBuilder: (context, index) {
                                      final trip = _recentTrips[index];
                                      final isFirst = index == 0;
                                      final hasAnomalies =
                                          trip.anomalies.isNotEmpty;
                                      final statusColor = hasAnomalies
                                          ? const Color(0xFFF59E0B)
                                          : const Color(0xFF10B981);

                                      return GestureDetector(
                                        onTap: () => Navigator.pushNamed(
                                          context,
                                          '/ride_status',
                                        ),
                                        child: Container(
                                          width: 280,
                                          padding: const EdgeInsets.all(20),
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: isFirst
                                                  ? [
                                                      (_isDark
                                                              ? const Color(0xFF1E293B)
                                                              : Colors.white)
                                                          .withOpacity(_isDark ? 0.6 : 0.95),
                                                      (_isDark
                                                              ? const Color(0xFF0F172A)
                                                              : const Color(0xFFF1F5F9))
                                                          .withOpacity(_isDark ? 0.4 : 0.9),
                                                    ]
                                                  : [
                                                      (_isDark
                                                              ? const Color(0xFF1E293B)
                                                              : Colors.white)
                                                          .withOpacity(_isDark ? 0.4 : 0.9),
                                                      (_isDark
                                                              ? const Color(0xFF0F172A)
                                                              : const Color(0xFFF8FAFC))
                                                          .withOpacity(_isDark ? 0.3 : 0.85),
                                                    ],
                                            ),
                                            border: Border.all(
                                              color: _border.withOpacity(0.7),
                                              width: 1,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF3B82F6,
                                                      ),
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: const Color(
                                                            0xFF3B82F6,
                                                          ).withOpacity(0.5),
                                                          blurRadius: 8,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      'Trip ${index + 1}',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 4),
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  left: 3.5,
                                                ),
                                                child: Container(
                                                  width: 1,
                                                  height: 16,
                                                  decoration: BoxDecoration(
                                                    gradient: LinearGradient(
                                                      begin:
                                                          Alignment.topCenter,
                                                      end: Alignment
                                                          .bottomCenter,
                                                      colors: [
                                                        const Color(
                                                          0xFF3B82F6,
                                                        ).withOpacity(0.5),
                                                        _textMuted.withOpacity(0.3),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Container(
                                                    width: 8,
                                                    height: 8,
                                                    decoration: BoxDecoration(
                                                      color: statusColor,
                                                      shape: BoxShape.circle,
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: statusColor
                                                              .withOpacity(0.5),
                                                          blurRadius: 8,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Expanded(
                                                    child: Text(
                                                      trip.status.toUpperCase(),
                                                      style: GoogleFonts.inter(
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: _textPrimary,
                                                      ),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(height: 20),
                                              Row(
                                                children: [
                                                  _tripStat(
                                                    Icons.timer_outlined,
                                                    '${trip.duration} min',
                                                  ),
                                                  const SizedBox(width: 16),
                                                  _tripStat(
                                                    Icons.straighten,
                                                    '${trip.distance.toStringAsFixed(1)} km',
                                                  ),
                                                ],
                                              ),
                                              const Spacer(),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 12,
                                                      vertical: 8,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: statusColor
                                                      .withOpacity(0.15),
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: statusColor
                                                        .withOpacity(0.3),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      hasAnomalies
                                                          ? Icons
                                                                .warning_amber_rounded
                                                          : Icons
                                                                .check_circle_outline,
                                                      color: statusColor,
                                                      size: 16,
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      hasAnomalies
                                                          ? '${trip.anomalies.length} anomaly'
                                                          : 'Safe trip',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w600,
                                                        color: statusColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                          const SizedBox(height: 32),

                          // Statistics Section
                          Text(
                            "Statistics",
                            style: GoogleFonts.inter(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: _textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  icon: Icons.route_outlined,
                                  label: 'Total Trips',
                                  value: totalTrips.toString(),
                                  color: const Color(0xFF3B82F6),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  icon: Icons.check_circle_outline,
                                  label: 'Safe Trips',
                                  value: safePercent,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: _surface,
          border: Border(
            top: BorderSide(
              color: _border.withOpacity(0.7),
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
                  isActive: true,
                  onTap: () {},
                ),
                _navItem(
                  icon: Icons.explore_outlined,
                  activeIcon: Icons.explore,
                  label: 'Map',
                  isActive: false,
                  onTap: () => Navigator.pushNamed(context, '/map'),
                ),
                _navItem(
                  icon: Icons.router_outlined,
                  activeIcon: Icons.router,
                  label: 'Device',
                  isActive: false,
                  color: const Color(0xFF8B5CF6),
                  onTap: () => Navigator.pushNamed(context, '/device'),
                ),
                _navItem(
                  icon: Icons.emergency_outlined,
                  activeIcon: Icons.emergency,
                  label: 'SOS',
                  isActive: false,
                  color: const Color(0xFFEF4444),
                  onTap: () => Navigator.pushNamed(context, '/emergency'),
                ),
                _navItem(
                  icon: Icons.person_outline,
                  activeIcon: Icons.person,
                  label: 'Profile',
                  isActive: false,
                  onTap: () => Navigator.pushNamed(context, '/profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tripStat(IconData icon, String value) {
    return Row(
      children: [
        Icon(icon, color: _textMuted, size: 14),
        const SizedBox(width: 6),
        Text(
          value,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: _textSecondary,
          ),
        ),
      ],
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
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: _textMuted,
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
        color ?? (isActive ? const Color(0xFF3B82F6) : _textMuted);

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

class AnimatedBackground extends StatefulWidget {
  final bool isDark;
  const AnimatedBackground({super.key, required this.isDark});

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
          painter: BackgroundPainter(_controller.value, widget.isDark),
        );
      },
    );
  }
}

class BackgroundPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;
  BackgroundPainter(this.animationValue, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? const [Color(0xFF050A14), Color(0xFF0A1628), Color(0xFF050A14)]
          : const [Color(0xFFF8FAFC), Color(0xFFEFF6FF), Color(0xFFF8FAFC)],
    );
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = gradient.createShader(
          Rect.fromLTWH(0, 0, size.width, size.height),
        ),
    );
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
    final gridPaint = Paint()
      ..color = (isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1))
          .withOpacity(isDark ? 0.3 : 0.4)
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
