import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _textFadeAnim;
  late Animation<double> _glowAnim;
  late Animation<double> _driftAnim;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.65, curve: Curves.easeOutBack),
      ),
    );

    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.5, 1.0, curve: Curves.easeOut),
      ),
    );

    _glowAnim = Tween<double>(begin: 0.35, end: 0.8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );
    _driftAnim = Tween<double>(begin: -8, end: 8).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 1.0, curve: Curves.easeInOut),
      ),
    );

    // Navigate to auth wrapper after splash sequence
    Timer(const Duration(milliseconds: 3200), () {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/auth');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textPrimary = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSecondary = isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
      body: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, _driftAnim.value / 100),
                    radius: 0.95,
                    colors: [
                      const Color(0xFF22D3EE).withOpacity(isDark ? 0.24 : 0.18),
                      isDark ? const Color(0xFF030712) : const Color(0xFFF8FAFC),
                    ],
                  ),
                ),
              );
            },
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) => Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.translate(
                      offset: Offset(0, _driftAnim.value),
                      child: Transform.scale(scale: _scaleAnim.value, child: child),
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF22D3EE).withOpacity(_glowAnim.value),
                          blurRadius: 42,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: Image.asset(
                        'assets/images/sentinel_logo.png',
                        width: 170,
                        height: 170,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) =>
                      Opacity(opacity: _textFadeAnim.value, child: child),
                  child: Column(
                    children: [
                      Text(
                        'SENTINEL 360',
                        style: GoogleFonts.inter(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: textPrimary,
                          letterSpacing: 2.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Intelligent safety for every trip',
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: textSecondary,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 48),
                SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF22D3EE)),
                    backgroundColor:
                        isDark ? const Color(0xFF1E293B) : const Color(0xFFDBEAFE),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
