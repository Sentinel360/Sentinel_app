import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import 'dart:math' as math;

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen>
    with TickerProviderStateMixin {
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final AuthService _authService = AuthService();
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool isLoading = false;
  bool isGoogleLoading = false;
  late AnimationController _fadeController;
  late AnimationController _glowController;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF050A14) : const Color(0xFFF8FAFC);
  Color get _surface => _isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get _surfaceAlt => _isDark ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9);
  Color get _border => _isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _textMuted => _isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..forward();

    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    fullNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    _fadeController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (fullNameController.text.trim().isEmpty ||
        emailController.text.trim().isEmpty ||
        phoneController.text.trim().isEmpty ||
        passwordController.text.isEmpty ||
        confirmPasswordController.text.isEmpty) {
      _showError('Please fill in all fields.');
      return;
    }

    if (passwordController.text != confirmPasswordController.text) {
      _showError('Passwords do not match.');
      return;
    }

    if (passwordController.text.length < 6) {
      _showError('Password must be at least 6 characters.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.registerWithEmail(
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text,
        phoneNumber: phoneController.text.trim(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Account created successfully!',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() => isGoogleLoading = true);
    try {
      final user = await _authService.signInWithGoogle();
      if (user != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Welcome, ${user.fullName}!',
              style: GoogleFonts.inter(color: Colors.white),
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
        Navigator.pushReplacementNamed(context, '/home');
      }
    } catch (e) {
      _showError(e.toString());
    } finally {
      if (mounted) setState(() => isGoogleLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: GoogleFonts.inter(color: Colors.white)),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Animated Background
          AnimatedBackground(isDark: _isDark),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    FadeTransition(
                      opacity: _fadeController,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                            child: Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: _surface.withOpacity(_isDark ? 0.6 : 0.9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _border.withOpacity(0.7),
                                  width: 1,
                                ),
                              ),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: _textPrimary,
                                size: 20,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: _surface.withOpacity(_isDark ? 0.6 : 0.9),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _border.withOpacity(0.7),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2563EB,
                                    ).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2563EB,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.shield_outlined,
                                    color: Color(0xFF3B82F6),
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Sentinel 360",
                                  style: GoogleFonts.inter(
                                    color: _textPrimary,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 44),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Title
                    FadeTransition(
                      opacity: _fadeController,
                      child: Text(
                        'Create Account',
                        style: GoogleFonts.inter(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FadeTransition(
                      opacity: _fadeController,
                      child: Text(
                        'Join Sentinel 360 to start monitoring\nyour trips with AI-powered safety',
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          color: _textSecondary,
                          height: 1.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Form Container
                    AnimatedBuilder(
                      animation: _glowController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2563EB).withOpacity(
                                  0.1 + (_glowController.value * 0.05),
                                ),
                                blurRadius: 20 + (_glowController.value * 5),
                                spreadRadius: 1,
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
                                  _surface.withOpacity(_isDark ? 0.8 : 0.96),
                                  _surfaceAlt.withOpacity(_isDark ? 0.6 : 0.98),
                                ],
                              ),
                              border: Border.all(
                                color: _border.withOpacity(0.7),
                                width: 1.5,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Full Name
                                _buildField(
                                  label: 'Full Name',
                                  controller: fullNameController,
                                  hint: 'Enter your full name',
                                  icon: Icons.person_outline,
                                ),
                                const SizedBox(height: 16),

                                // Email
                                _buildField(
                                  label: 'Email Address',
                                  controller: emailController,
                                  hint: 'name@example.com',
                                  icon: Icons.email_outlined,
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 16),

                                // Phone
                                _buildField(
                                  label: 'Phone Number',
                                  controller: phoneController,
                                  hint: '+233 XX XXX XXXX',
                                  icon: Icons.phone_outlined,
                                  keyboardType: TextInputType.phone,
                                ),
                                const SizedBox(height: 16),

                                // Password
                                _buildPasswordField(
                                  label: 'Password',
                                  controller: passwordController,
                                  hint: 'At least 6 characters',
                                  showPassword: showPassword,
                                  onToggle: () => setState(
                                    () => showPassword = !showPassword,
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Confirm Password
                                _buildPasswordField(
                                  label: 'Confirm Password',
                                  controller: confirmPasswordController,
                                  hint: 'Re-enter your password',
                                  showPassword: showConfirmPassword,
                                  onToggle: () => setState(
                                    () => showConfirmPassword =
                                        !showConfirmPassword,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 24),

                    // Register Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          disabledBackgroundColor: const Color(
                            0xFF2563EB,
                          ).withOpacity(0.5),
                        ),
                        child: isLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.shield, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Create Account',
                                    style: GoogleFonts.inter(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Divider
                    Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: _border.withOpacity(0.6),
                            thickness: 1,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12.0),
                          child: Text(
                            'OR CONTINUE WITH',
                            style: GoogleFonts.inter(
                              color: _textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: _border.withOpacity(0.6),
                            thickness: 1,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Google Button
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: OutlinedButton(
                        onPressed: isGoogleLoading ? null : _googleSignIn,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: _border.withOpacity(0.7),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          backgroundColor: _surface.withOpacity(_isDark ? 0.4 : 0.75),
                        ),
                        child: isGoogleLoading
                            ? const SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF3B82F6),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.g_translate,
                                      color: Color(0xFF0F172A),
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Continue with Google',
                                    style: GoogleFonts.inter(
                                      color: _textPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Sign In Link
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: GoogleFonts.inter(
                              color: _textSecondary,
                              fontSize: 14,
                            ),
                          ),
                          GestureDetector(
                            onTap: () => Navigator.pushReplacementNamed(
                              context,
                              '/login',
                            ),
                            child: Text(
                              "Sign In",
                              style: GoogleFonts.inter(
                                color: const Color(0xFF3B82F6),
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surfaceAlt.withOpacity(_isDark ? 0.6 : 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _border.withOpacity(0.45),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 14,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: const Color(0xFF3B82F6), size: 18),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField({
    required String label,
    required TextEditingController controller,
    required String hint,
    required bool showPassword,
    required VoidCallback onToggle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _surfaceAlt.withOpacity(_isDark ? 0.6 : 0.95),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _border.withOpacity(0.45),
              width: 1,
            ),
          ),
          child: TextField(
            controller: controller,
            obscureText: !showPassword,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 14,
              ),
              prefixIcon: Container(
                margin: const EdgeInsets.all(10),
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.lock_outline,
                  color: Color(0xFF3B82F6),
                  size: 18,
                ),
              ),
              suffixIcon: GestureDetector(
                onTap: onToggle,
                child: Icon(
                  showPassword
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  color: _textMuted,
                  size: 20,
                ),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Animated Background Component
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
