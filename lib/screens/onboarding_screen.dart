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
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
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
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            // Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 8,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 50),
                  Text(
                    "Sentinel 360",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF1E293B),
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacementNamed(context, '/login');
                    },
                    child: Text(
                      "Skip",
                      style: GoogleFonts.poppins(
                        color: const Color(0xFF64748B),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
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
                  pageIndex: index,
                  currentPage: currentPage,
                ),
              ),
            ),

            // Page Indicator with enhanced design
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
                  const SizedBox(height: 8),
                  Text(
                    "${currentPage + 1} of ${onboardingData.length}",
                    style: GoogleFonts.poppins(
                      color: const Color(0xFF94A3B8),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),

            // Action Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    if (currentPage == onboardingData.length - 1) {
                      Navigator.pushReplacementNamed(context, '/login');
                    } else {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeInOut,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: currentPage == onboardingData.length - 1
                        ? const Color(0xFFDC2626)
                        : const Color(0xFF2563EB),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    currentPage == onboardingData.length - 1
                        ? "Get Started"
                        : "Continue",
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget buildDot({required int index}) {
    bool isActive = currentPage == index;
    bool isNext = currentPage + 1 == index;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 6),
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
            ? const Color(0xFFCBD5E1)
            : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
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
    required this.pageIndex,
    required this.currentPage,
  });

  @override
  Widget build(BuildContext context) {
    bool isVisible = pageIndex == currentPage;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Animated Icon Container
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
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
                    ),
                    border: Border.all(color: color.withOpacity(0.2), width: 2),
                  ),
                  child: Center(child: Icon(icon, size: 70, color: color)),
                ),
              ),
            ),
            const SizedBox(height: 60),

            // Title
            FadeTransition(
              opacity: isVisible
                  ? fadeAnimation
                  : const AlwaysStoppedAnimation(0.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF1E293B),
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Description
            FadeTransition(
              opacity: isVisible
                  ? fadeAnimation
                  : const AlwaysStoppedAnimation(0.0),
              child: Text(
                description,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  color: const Color(0xFF64748B),
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
