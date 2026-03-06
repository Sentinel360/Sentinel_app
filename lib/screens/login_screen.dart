import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';

// ──────────────────────────────────────────────────────────────────────────────
// Color Palette
// ──────────────────────────────────────────────────────────────────────────────
class _Palette {
  static const Color bg = Color(0xFF050A14);
  static const Color surface = Color(0xFF0A1628);
  static const Color surfaceLight = Color(0xFF111D35);
  static const Color border = Color(0xFF1E293B);
  static const Color borderFocused = Color(0xFF2563EB);
  static const Color primary = Color(0xFF2563EB);
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color textPrimary = Color(0xFFF1F5F9);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
  static const Color success = Color(0xFF059669);
  static const Color error = Color(0xFFEF4444);
}

// ──────────────────────────────────────────────────────────────────────────────
// Floating Orb Painter (background ambient glow)
// ──────────────────────────────────────────────────────────────────────────────
class _OrbPainter extends CustomPainter {
  final double animValue;
  _OrbPainter(this.animValue);

  @override
  void paint(Canvas canvas, Size size) {
    // Top-right orb
    final paint1 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              _Palette.primary.withOpacity(
                0.15 + 0.05 * sin(animValue * pi * 2),
              ),
              _Palette.primary.withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.85, size.height * 0.12),
              radius: 180 + 20 * sin(animValue * pi * 2),
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.85, size.height * 0.12),
      180 + 20 * sin(animValue * pi * 2),
      paint1,
    );

    // Bottom-left orb
    final paint2 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              _Palette.primary.withOpacity(
                0.10 + 0.04 * cos(animValue * pi * 2),
              ),
              _Palette.primary.withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.1, size.height * 0.85),
              radius: 160 + 15 * cos(animValue * pi * 2),
            ),
          );
    canvas.drawCircle(
      Offset(size.width * 0.1, size.height * 0.85),
      160 + 15 * cos(animValue * pi * 2),
      paint2,
    );

    // Center subtle orb
    final paint3 = Paint()
      ..shader =
          RadialGradient(
            colors: [
              const Color(0xFF0EA5E9).withOpacity(0.06),
              const Color(0xFF0EA5E9).withOpacity(0.0),
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.5, size.height * 0.5),
              radius: 220,
            ),
          );
    canvas.drawCircle(Offset(size.width * 0.5, size.height * 0.5), 220, paint3);
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      oldDelegate.animValue != animValue;
}

// ──────────────────────────────────────────────────────────────────────────────
// Grid Painter (subtle background grid)
// ──────────────────────────────────────────────────────────────────────────────
class _GridPainter extends CustomPainter {
  final double opacity;
  final Color lineColor;
  _GridPainter(this.opacity, this.lineColor);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = lineColor.withOpacity(opacity)
      ..strokeWidth = 0.5;

    const step = 40.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _GridPainter old) => old.opacity != opacity;
}

// ──────────────────────────────────────────────────────────────────────────────
// Login Screen
// ──────────────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with TickerProviderStateMixin {
  late TextEditingController emailController;
  late TextEditingController passwordController;
  bool showPassword = false;
  bool isLoading = false;
  bool isGoogleLoading = false;
  final AuthService _authService = AuthService();

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _orbController;
  late AnimationController _gridController;
  late AnimationController _logoGlowController;

  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();
  bool _emailFocused = false;
  bool _passwordFocused = false;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  Color get _bg => _isDark ? const Color(0xFF050A14) : const Color(0xFFF8FAFC);
  Color get _surface => _isDark ? const Color(0xFF0A1628) : Colors.white;
  Color get _border => _isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0);
  Color get _textPrimary => _isDark ? const Color(0xFFF1F5F9) : const Color(0xFF0F172A);
  Color get _textSecondary => _isDark ? const Color(0xFF94A3B8) : const Color(0xFF475569);
  Color get _textMuted => _isDark ? const Color(0xFF64748B) : const Color(0xFF64748B);

  @override
  void initState() {
    super.initState();
    emailController = TextEditingController();
    passwordController = TextEditingController();

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 900),
      vsync: this,
    );
    _orbController = AnimationController(
      duration: const Duration(seconds: 6),
      vsync: this,
    )..repeat();
    _gridController = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat(reverse: true);
    _logoGlowController = AnimationController(
      duration: const Duration(seconds: 3),
      vsync: this,
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic),
        );

    _emailFocus.addListener(() {
      setState(() => _emailFocused = _emailFocus.hasFocus);
    });
    _passwordFocus.addListener(() {
      setState(() => _passwordFocused = _passwordFocus.hasFocus);
    });

    // Stagger the entrance
    Future.delayed(const Duration(milliseconds: 100), () {
      _fadeController.forward();
      _slideController.forward();
    });
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _orbController.dispose();
    _gridController.dispose();
    _logoGlowController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  // ── Backend Logic (untouched) ─────────────────────────────────────────────

  Future<void> _login() async {
    if (emailController.text.trim().isEmpty ||
        passwordController.text.isEmpty) {
      _showError('Please enter your email and password.');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _authService.loginWithEmail(
        email: emailController.text.trim(),
        password: passwordController.text,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Login successful!'),
            backgroundColor: _Palette.success,
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
            content: Text('Welcome, ${user.fullName}!'),
            backgroundColor: _Palette.success,
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

  Future<void> _forgotPassword() async {
    if (emailController.text.trim().isEmpty) {
      _showError('Please enter your email address first.');
      return;
    }
    try {
      await _authService.sendPasswordResetEmail(emailController.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Password reset email sent!'),
            backgroundColor: _Palette.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      _showError(e.toString());
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _Palette.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Stack(
        children: [
          // Animated grid background
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _gridController,
              builder: (_, __) => CustomPaint(
                painter: _GridPainter(
                  0.03 + 0.04 * _gridController.value,
                  _isDark ? const Color(0xFF1E293B) : const Color(0xFFCBD5E1),
                ),
              ),
            ),
          ),

          // Ambient orbs
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _orbController,
              builder: (_, __) =>
                  CustomPaint(painter: _OrbPainter(_orbController.value)),
            ),
          ),

          // Main content
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28.0,
                  vertical: 24,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _buildBackButton(),
                        const SizedBox(height: 36),
                        _buildLogo(),
                        const SizedBox(height: 44),
                        _buildWelcomeText(),
                        const SizedBox(height: 40),
                        _buildEmailField(),
                        const SizedBox(height: 20),
                        _buildPasswordField(),
                        const SizedBox(height: 14),
                        _buildForgotPassword(),
                        const SizedBox(height: 36),
                        _buildSignInButton(),
                        const SizedBox(height: 28),
                        _buildDivider(),
                        const SizedBox(height: 28),
                        _buildGoogleButton(),
                        const SizedBox(height: 32),
                        _buildSignUpLink(),
                        const SizedBox(height: 24),
                        _buildSecurityBadge(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget Builders ───────────────────────────────────────────────────────

  Widget _buildBackButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: GestureDetector(
        onTap: () => Navigator.pushReplacementNamed(context, '/onboarding'),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: _surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border, width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_rounded,
            color: Color(0xFF64748B),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return AnimatedBuilder(
      animation: _logoGlowController,
      builder: (_, child) {
        final glowIntensity = 0.15 + 0.15 * _logoGlowController.value;
        return Container(
          width: 110,
          height: 110,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                _Palette.primary.withOpacity(0.12),
                _Palette.primary.withOpacity(0.04),
                Colors.transparent,
              ],
              stops: const [0.0, 0.6, 1.0],
            ),
            border: Border.all(
              color: _Palette.primary.withOpacity(
                0.3 + 0.1 * _logoGlowController.value,
              ),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: _Palette.primary.withOpacity(glowIntensity),
                blurRadius: 40,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: _Palette.primary.withOpacity(glowIntensity * 0.5),
                blurRadius: 80,
                spreadRadius: 10,
              ),
            ],
          ),
          child: Center(
            child: Image.asset(
              'assets/images/sentinel_logo.png',
              width: 60,
              height: 60,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }

  Widget _buildWelcomeText() {
    return Column(
      children: [
        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: _textPrimary,
            height: 1.2,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to your account and stay protected',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 15,
            color: _textMuted,
            fontWeight: FontWeight.w400,
            height: 1.6,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }

  Widget _buildInputField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required IconData prefixIcon,
    required FocusNode focusNode,
    required bool isFocused,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isFocused ? _Palette.primaryLight : _textSecondary,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFocused ? _Palette.primary : _border,
              width: isFocused ? 1.5 : 1,
            ),
            color: isFocused
                ? _Palette.primary.withOpacity(0.05)
                : _surface,
            boxShadow: isFocused
                ? [
                    BoxShadow(
                      color: _Palette.primary.withOpacity(0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                    BoxShadow(
                      color: _Palette.primary.withOpacity(0.05),
                      blurRadius: 40,
                      spreadRadius: 2,
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            obscureText: obscureText,
            keyboardType: keyboardType,
            cursorColor: _Palette.primary,
            style: GoogleFonts.inter(
              color: _textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.inter(
                color: _textMuted.withOpacity(0.5),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
              filled: false,
              prefixIcon: Padding(
                padding: const EdgeInsets.only(left: 14, right: 10),
                child: Icon(
                  prefixIcon,
                  color: isFocused ? _Palette.primary : _textMuted,
                  size: 20,
                ),
              ),
              prefixIconConstraints: const BoxConstraints(
                minHeight: 20,
                minWidth: 20,
              ),
              suffixIcon: suffixIcon,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
        // Accent line under input when focused
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(1),
            gradient: isFocused
                ? const LinearGradient(
                    colors: [
                      Colors.transparent,
                      _Palette.primary,
                      Colors.transparent,
                    ],
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return _buildInputField(
      label: 'EMAIL ADDRESS',
      hint: 'name@example.com',
      controller: emailController,
      prefixIcon: Icons.email_outlined,
      focusNode: _emailFocus,
      isFocused: _emailFocused,
      keyboardType: TextInputType.emailAddress,
    );
  }

  Widget _buildPasswordField() {
    return _buildInputField(
      label: 'PASSWORD',
      hint: 'Enter your password',
      controller: passwordController,
      prefixIcon: Icons.lock_outline_rounded,
      focusNode: _passwordFocus,
      isFocused: _passwordFocused,
      obscureText: !showPassword,
      suffixIcon: GestureDetector(
        onTap: () => setState(() => showPassword = !showPassword),
        child: Padding(
          padding: const EdgeInsets.only(right: 14),
          child: Icon(
            showPassword
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
            color: _textMuted,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildForgotPassword() {
    return Align(
      alignment: Alignment.centerRight,
      child: GestureDetector(
        onTap: _forgotPassword,
        child: Text(
          'Forgot password?',
          style: GoogleFonts.inter(
            color: _Palette.primaryLight,
            fontWeight: FontWeight.w600,
            fontSize: 13,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
          ),
          boxShadow: [
            BoxShadow(
              color: _Palette.primary.withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
            BoxShadow(
              color: _Palette.primary.withOpacity(0.15),
              blurRadius: 40,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: isLoading ? null : _login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  height: 24,
                  width: 24,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Sign In',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.arrow_forward_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.transparent, _border],
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: _surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _border, width: 1),
            ),
            child: Text(
              'OR',
              style: GoogleFonts.inter(
                color: _textMuted,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.5,
              ),
            ),
          ),
        ),
        Expanded(
          child: Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_border, Colors.transparent],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: isGoogleLoading ? null : _googleSignIn,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: _border, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: _surface,
        ),
        child: isGoogleLoading
            ? SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    _textSecondary,
                  ),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Google "G" logo using a styled container
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: _border, width: 1),
                    ),
                    child: Center(
                      child: Text(
                        'G',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: _textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Continue with Google',
                    style: GoogleFonts.inter(
                      color: _textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                      letterSpacing: 0.1,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSignUpLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: GoogleFonts.inter(
            color: _textMuted,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            letterSpacing: 0.1,
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.pushReplacementNamed(context, '/signup'),
          child: Text(
            "Sign Up",
            style: GoogleFonts.inter(
              color: _Palette.primaryLight,
              fontWeight: FontWeight.w700,
              fontSize: 14,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSecurityBadge() {
    return AnimatedBuilder(
      animation: _logoGlowController,
      builder: (_, __) {
        final pulse = 0.6 + 0.4 * _logoGlowController.value;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: _Palette.success.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _Palette.success.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.verified_user_rounded,
                color: _Palette.success.withOpacity(pulse),
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                'End-to-end encrypted',
                style: GoogleFonts.inter(
                  color: _Palette.success.withOpacity(0.8),
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Helper: AnimatedBuilder alias for readability
// (Flutter already has AnimatedBuilder, this is just for clarity)
// ──────────────────────────────────────────────────────────────────────────────
