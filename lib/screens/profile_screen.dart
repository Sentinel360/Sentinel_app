import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/trip_service.dart';
import '../services/device_service.dart';
import '../models/user_model.dart';
import '../models/device_model.dart';
import '../providers/theme_provider.dart';
import 'dart:math' as math;

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with TickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final TripService _tripService = TripService();
  final DeviceService _deviceService = DeviceService();

  UserModel? _user;
  DeviceModel? _device;
  int _totalTrips = 0;
  int _totalAnomalies = 0;
  bool _isLoading = true;

  late AnimationController _glowController;
  late AnimationController _avatarController;
  late AnimationController _bgController;
  late Animation<double> _avatarScale;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);

    _avatarController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _bgController = AnimationController(
      duration: const Duration(seconds: 8),
      vsync: this,
    )..repeat();

    _avatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _avatarController, curve: Curves.elasticOut),
    );

    _loadData();
    _avatarController.forward();
  }

  @override
  void dispose() {
    _glowController.dispose();
    _avatarController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final user = await _authService.getCurrentUserData();
      final device = await _deviceService.getDeviceByUserId(uid);
      final trips = await _tripService.getRecentTrips(uid);
      final anomalyCount = trips.fold<int>(
        0,
        (sum, trip) => sum + trip.anomalies.length,
      );

      if (mounted) {
        setState(() {
          _user = user;
          _device = device;
          _totalTrips = trips.length;
          _totalAnomalies = anomalyCount;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _logout() async {
    await _authService.logout();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDark(context);

    // ── Semantic colour tokens ─────────────────────────────────────────────
    final bgColor = isDark ? const Color(0xFF050A14) : const Color(0xFFF1F5F9);
    final surfaceColor = isDark
        ? const Color(0xFF1E293B).withOpacity(0.8)
        : Colors.white;
    final surfaceBorder = isDark
        ? const Color(0xFF334155).withOpacity(0.5)
        : const Color(0xFFE2E8F0);
    final textPrimary = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF0F172A);
    final textSecondary = isDark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final subtleFill = isDark
        ? const Color(0xFF0F172A).withOpacity(0.6)
        : const Color(0xFFF8FAFC);

    final safetyPercentage = _totalTrips > 0
        ? (((_totalTrips - _totalAnomalies) / _totalTrips) * 100)
              .clamp(0, 100)
              .toInt()
        : 100;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Animated background (only in dark mode)
          if (isDark)
            AnimatedBuilder(
              animation: _bgController,
              builder: (context, child) => CustomPaint(
                size: Size.infinite,
                painter: BackgroundPainter(_bgController.value),
              ),
            ),

          SafeArea(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(
                      color: const Color(0xFF3B82F6),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // ── Header ──────────────────────────────────────
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Profile',
                                style: GoogleFonts.inter(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              GestureDetector(
                                onTap: () {},
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: surfaceColor,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: surfaceBorder,
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.edit_outlined,
                                    color: Color(0xFF3B82F6),
                                    size: 20,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 28),

                          // ── Avatar card ─────────────────────────────────
                          AnimatedBuilder(
                            animation: _glowController,
                            builder: (context, child) => Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(24),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF8B5CF6).withOpacity(
                                      isDark
                                          ? 0.2 + _glowController.value * 0.15
                                          : 0.08,
                                    ),
                                    blurRadius: 20 + _glowController.value * 10,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: surfaceColor,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF8B5CF6,
                                    ).withOpacity(isDark ? 0.3 : 0.2),
                                    width: 1.5,
                                  ),
                                ),
                                child: Column(
                                  children: [
                                    ScaleTransition(
                                      scale: _avatarScale,
                                      child: Container(
                                        width: 100,
                                        height: 100,
                                        decoration: const BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Color(0xFF8B5CF6),
                                              Color(0xFF6366F1),
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Color(0x808B5CF6),
                                              blurRadius: 20,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            _user?.fullName.isNotEmpty == true
                                                ? _user!.fullName[0]
                                                      .toUpperCase()
                                                : '?',
                                            style: GoogleFonts.inter(
                                              fontSize: 40,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Text(
                                      _user?.fullName ?? '—',
                                      style: GoogleFonts.inter(
                                        fontSize: 22,
                                        fontWeight: FontWeight.w700,
                                        color: textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: subtleFill,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: surfaceBorder,
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        _user?.email ?? '',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ),
                                    if (_user?.phoneNumber.isNotEmpty ==
                                        true) ...[
                                      const SizedBox(height: 8),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.phone_outlined,
                                            color: textSecondary,
                                            size: 14,
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            _user!.phoneNumber,
                                            style: GoogleFonts.inter(
                                              fontSize: 13,
                                              color: textSecondary,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          // ── Safety score ─────────────────────────────────
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: surfaceColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(
                                  0xFF10B981,
                                ).withOpacity(isDark ? 0.3 : 0.2),
                                width: 1.5,
                              ),
                              boxShadow: isDark
                                  ? []
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 10,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 60,
                                  height: 60,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF10B981),
                                        Color(0xFF059669),
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF10B981,
                                        ).withOpacity(0.4),
                                        blurRadius: 12,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$safetyPercentage%',
                                      style: GoogleFonts.inter(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Safety Score',
                                        style: GoogleFonts.inter(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$safetyPercentage% of trips completed safely',
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          color: textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // ── Stats ─────────────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _statCard(
                                  icon: Icons.route_outlined,
                                  label: 'Total Trips',
                                  value: _totalTrips.toString(),
                                  color: const Color(0xFF3B82F6),
                                  isDark: isDark,
                                  surfaceColor: surfaceColor,
                                  surfaceBorder: surfaceBorder,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _statCard(
                                  icon: Icons.warning_amber_rounded,
                                  label: 'Anomalies',
                                  value: _totalAnomalies.toString(),
                                  color: const Color(0xFFEF4444),
                                  isDark: isDark,
                                  surfaceColor: surfaceColor,
                                  surfaceBorder: surfaceBorder,
                                  textPrimary: textPrimary,
                                  textSecondary: textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // ── Appearance section ────────────────────────────
                          _sectionLabel('Appearance', textSecondary),
                          const SizedBox(height: 10),
                          _themeToggleCard(
                            themeProvider: themeProvider,
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            surfaceBorder: surfaceBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                          const SizedBox(height: 20),

                          // ── Account section ───────────────────────────────
                          _sectionLabel('Account', textSecondary),
                          const SizedBox(height: 10),

                          _menuItem(
                            icon: Icons.contact_emergency_outlined,
                            label: 'Emergency Contacts',
                            subtitle: 'Manage who gets notified',
                            color: const Color(0xFFEF4444),
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            surfaceBorder: surfaceBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () => Navigator.pushNamed(
                              context,
                              '/emergency_contacts',
                            ),
                          ),
                          const SizedBox(height: 10),
                          _menuItem(
                            icon: Icons.router_outlined,
                            label: 'IoT Device',
                            subtitle: _device == null
                                ? 'No device paired'
                                : '${_device!.name} · ${_device!.isActive ? "Online" : "Offline"}',
                            color: const Color(0xFF8B5CF6),
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            surfaceBorder: surfaceBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () =>
                                Navigator.pushNamed(context, '/device'),
                          ),
                          const SizedBox(height: 10),
                          _menuItem(
                            icon: Icons.password_outlined,
                            label: 'Change Password',
                            subtitle: 'Send reset link to your email',
                            color: const Color(0xFF3B82F6),
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            surfaceBorder: surfaceBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: () async {
                              if (_user?.email != null) {
                                await _authService.sendPasswordResetEmail(
                                  _user!.email,
                                );
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Password reset email sent!',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                        ),
                                      ),
                                      backgroundColor: const Color(0xFF10B981),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                          const SizedBox(height: 20),

                          // ── Danger zone ────────────────────────────────────
                          _sectionLabel('Danger Zone', textSecondary),
                          const SizedBox(height: 10),
                          _menuItem(
                            icon: Icons.logout_rounded,
                            label: 'Logout',
                            subtitle: 'Sign out of your account',
                            color: const Color(0xFFEF4444),
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            surfaceBorder: surfaceBorder,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                            onTap: _logout,
                          ),
                          const SizedBox(height: 100),
                        ],
                      ),
                    ),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _buildNavBar(isDark),
    );
  }

  // ── Theme toggle card ──────────────────────────────────────────────────────
  Widget _themeToggleCard({
    required ThemeProvider themeProvider,
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: surfaceBorder, width: 1),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Row(
        children: [
          _themeOption(
            icon: Icons.dark_mode_outlined,
            label: 'Dark',
            selected: themeProvider.mode == AppThemeMode.dark,
            color: const Color(0xFF6366F1),
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => themeProvider.setMode(AppThemeMode.dark),
          ),
          _themeOption(
            icon: Icons.light_mode_outlined,
            label: 'Light',
            selected: themeProvider.mode == AppThemeMode.light,
            color: const Color(0xFFF59E0B),
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => themeProvider.setMode(AppThemeMode.light),
          ),
          _themeOption(
            icon: Icons.phone_android_outlined,
            label: 'System',
            selected: themeProvider.mode == AppThemeMode.system,
            color: const Color(0xFF10B981),
            isDark: isDark,
            textPrimary: textPrimary,
            onTap: () => themeProvider.setMode(AppThemeMode.system),
          ),
        ],
      ),
    );
  }

  Widget _themeOption({
    required IconData icon,
    required String label,
    required bool selected,
    required Color color,
    required bool isDark,
    required Color textPrimary,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: selected
                ? color.withOpacity(isDark ? 0.2 : 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: selected
                ? Border.all(color: color.withOpacity(0.4), width: 1.5)
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: selected ? color : textPrimary.withOpacity(0.4),
                size: 22,
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? color : textPrimary.withOpacity(0.4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────
  Widget _sectionLabel(String label, Color textSecondary) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _menuItem({
    required IconData icon,
    required String label,
    required String subtitle,
    required Color color,
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceBorder,
    required Color textPrimary,
    required Color textSecondary,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: surfaceBorder, width: 1),
          boxShadow: isDark
              ? []
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: textSecondary.withOpacity(0.5),
              size: 14,
            ),
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
    required bool isDark,
    required Color surfaceColor,
    required Color surfaceBorder,
    required Color textPrimary,
    required Color textSecondary,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(isDark ? 0.3 : 0.2),
          width: 1,
        ),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: GoogleFonts.inter(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavBar(bool isDark) {
    final navBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final navBorder = isDark
        ? const Color(0xFF1E293B).withOpacity(0.5)
        : const Color(0xFFE2E8F0);

    return Container(
      decoration: BoxDecoration(
        color: navBg,
        border: Border(top: BorderSide(color: navBorder, width: 1)),
        boxShadow: isDark
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
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
                isDark: isDark,
                onTap: () => Navigator.pushReplacementNamed(context, '/home'),
              ),
              _navItem(
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore,
                label: 'Map',
                isActive: false,
                isDark: isDark,
                onTap: () => Navigator.pushReplacementNamed(context, '/map'),
              ),
              _navItem(
                icon: Icons.router_outlined,
                activeIcon: Icons.router,
                label: 'Device',
                isActive: false,
                isDark: isDark,
                color: const Color(0xFF8B5CF6),
                onTap: () => Navigator.pushNamed(context, '/device'),
              ),
              _navItem(
                icon: Icons.emergency_outlined,
                activeIcon: Icons.emergency,
                label: 'SOS',
                isActive: false,
                isDark: isDark,
                color: const Color(0xFFEF4444),
                onTap: () => Navigator.pushNamed(context, '/emergency'),
              ),
              _navItem(
                icon: Icons.person_outline,
                activeIcon: Icons.person,
                label: 'Profile',
                isActive: true,
                isDark: isDark,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _navItem({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isActive,
    required bool isDark,
    Color? color,
    required VoidCallback onTap,
  }) {
    final itemColor =
        color ??
        (isActive
            ? const Color(0xFF3B82F6)
            : isDark
            ? const Color(0xFF64748B)
            : const Color(0xFF94A3B8));
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? itemColor.withOpacity(0.12) : Colors.transparent,
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

// ── Background painter (dark mode only) ──────────────────────────────────────
class BackgroundPainter extends CustomPainter {
  final double animationValue;
  BackgroundPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF050A14), Color(0xFF0A1628), Color(0xFF050A14)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );
    final orbs = [
      {
        'x': size.width * 0.2,
        'y': size.height * 0.15 + math.sin(animationValue * 2 * math.pi) * 30,
        'radius': 100.0,
        'color': const Color(0xFF2563EB),
      },
      {
        'x': size.width * 0.8,
        'y': size.height * 0.7 + math.cos(animationValue * 2 * math.pi) * 40,
        'radius': 120.0,
        'color': const Color(0xFF1E40AF),
      },
    ];
    for (var orb in orbs) {
      paint.shader =
          RadialGradient(
            colors: [
              (orb['color'] as Color).withOpacity(0.15),
              (orb['color'] as Color).withOpacity(0.05),
              Colors.transparent,
            ],
            stops: const [0, 0.5, 1],
          ).createShader(
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
      ..color = const Color(0xFF1E293B).withOpacity(0.3)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;
    for (double i = 0; i < size.width; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i, size.height), gridPaint);
    }
    for (double i = 0; i < size.height; i += 40) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i), gridPaint);
    }
  }

  @override
  bool shouldRepaint(BackgroundPainter old) =>
      animationValue != old.animationValue;
}
