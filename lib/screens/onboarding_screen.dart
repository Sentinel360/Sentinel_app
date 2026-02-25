import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int currentPage = 0;
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _glowController;

  final List<Map<String, dynamic>> onboardingData = [
    {
      "title": "Welcome to Sentinel 360",
      "description":
          "Enhancing passenger safety in ride-hailing services using AIoT.",
      "icon": Icons.shield_outlined,
      "color": const Color(0xFF2563EB),
    },
    {
      "title": "Real-Time Route Monitoring",
      "description":
          "Get notified instantly if your trip deviates from the expected route or shows unusual behavior.",
      "icon": Icons.location_on_outlined,
      "color": const Color(0xFF1E40AF),
    },
    {
      "title": "Emergency Alerts & Safety",
      "description":
          "Discreetly send alerts to trusted contacts or authorities, even if you lose access to your phone.",
      "icon": Icons.notifications_active_outlined,
      "color": const Color(0xFFDC2626),
    },
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    )..forward();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _glowController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() {
      currentPage = index;
    });
    _fadeController.forward(from: 0.0);
    _slideController.forward(from: 0.0);
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
            child: Column(
              children: [
                // Header with Skip Button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 16,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const SizedBox(width: 60),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2563EB).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF2563EB).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.shield_outlined,
                              color: Color(0xFF2563EB),
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            "Sentinel 360",
                            style: GoogleFonts.inter(
                              color: const Color(0xFFF1F5F9),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacementNamed(context, '/login');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B).withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: const Color(0xFF334155).withOpacity(0.5),
                              width: 1,
                            ),
                          ),
                          child: Text(
                            "Skip",
                            style: GoogleFonts.inter(
                              color: const Color(0xFF94A3B8),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Page View
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: onboardingData.length,
                    onPageChanged: _onPageChanged,
                    itemBuilder: (context, index) => OnboardingPage(
                      title: onboardingData[index]['title']!,
                      description: onboardingData[index]['description']!,
                      icon: onboardingData[index]['icon'] as IconData,
                      color: onboardingData[index]['color'] as Color,
                      fadeAnimation: _fadeController,
                      slideAnimation: _slideController,
                      glowAnimation: _glowController,
                      pageIndex: index,
                      currentPage: currentPage,
                    ),
                  ),
                ),

                // Page Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          onboardingData.length,
                          (index) => buildDot(index: index),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "${currentPage + 1} of ${onboardingData.length}",
                        style: GoogleFonts.inter(
                          color: const Color(0xFF64748B),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),

                // Action Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: AnimatedBuilder(
                    animation: _glowController,
                    builder: (context, child) {
                      final isLastPage =
                          currentPage == onboardingData.length - 1;
                      final buttonColor = isLastPage
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF2563EB);

                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: buttonColor.withOpacity(
                                0.3 + (_glowController.value * 0.2),
                              ),
                              blurRadius: 20 + (_glowController.value * 8),
                              offset: const Offset(0, 8),
                            ),
                          ],
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: () {
                              if (currentPage == onboardingData.length - 1) {
                                Navigator.pushReplacementNamed(
                                  context,
                                  '/login',
                                );
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeInOut,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: buttonColor,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  currentPage == onboardingData.length - 1
                                      ? "Get Started"
                                      : "Continue",
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildDot({required int index}) {
    bool isActive = currentPage == index;
    bool isNext = currentPage + 1 == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      width: isActive
          ? 32
          : isNext
          ? 12
          : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive
            ? onboardingData[currentPage]['color'] as Color
            : isNext
            ? const Color(0xFF334155)
            : const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isActive
            ? [
                BoxShadow(
                  color: (onboardingData[currentPage]['color'] as Color)
                      .withOpacity(0.5),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
    );
  }
}

class OnboardingPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final Animation<double> fadeAnimation;
  final Animation<double> slideAnimation;
  final Animation<double> glowAnimation;
  final int pageIndex;
  final int currentPage;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.glowAnimation,
    required this.pageIndex,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    bool isVisible = pageIndex == currentPage;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 60),

            // Animated Icon Container with Glassmorphism
            FadeTransition(
              opacity: isVisible
                  ? fadeAnimation
                  : const AlwaysStoppedAnimation(0.0),
              child: SlideTransition(
                position: isVisible
                    ? Tween<Offset>(
                        begin: const Offset(0, 0.3),
                        end: Offset.zero,
                      ).animate(slideAnimation)
                    : const AlwaysStoppedAnimation(Offset.zero),
                child: AnimatedBuilder(
                  animation: glowAnimation,
                  builder: (context, child) {
                    return Container(
                      width: 160,
                      height: 160,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            color.withOpacity(0.15),
                            color.withOpacity(0.05),
                          ],
                        ),
                        border: Border.all(
                          color: color.withOpacity(0.3),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withOpacity(
                              0.2 + (glowAnimation.value * 0.15),
                            ),
                            blurRadius: 30 + (glowAnimation.value * 15),
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: color.withOpacity(0.1),
                            blurRadius: 60,
                            spreadRadius: 10,
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Inner glow circle
                          Container(
                            width: 100,
                            height: 100,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: color.withOpacity(0.1),
                            ),
                          ),
                          // Icon
                          Icon(icon, size: 70, color: color),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 70),

            // Title
            FadeTransition(
              opacity: isVisible
                  ? fadeAnimation
                  : const AlwaysStoppedAnimation(0.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFFF1F5F9),
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Description
            FadeTransition(
              opacity: isVisible
                  ? fadeAnimation
                  : const AlwaysStoppedAnimation(0.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: const Color(0xFF94A3B8),
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.6,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }
}

// Animated Background Component
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
    final gradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        const Color(0xFF050A14),
        const Color(0xFF0A1628),
        const Color(0xFF050A14),
      ],
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
