import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:studycompete/features/auth/providers/auth_provider.dart';
import 'package:studycompete/shared/theme/app_theme.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.12), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.signInWithGoogle();
      // Router redirect handles navigation after auth state change
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sign-in failed: ${e.toString()}'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Gradient background ───────────────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1E1B4B), // indigo-950
                  Color(0xFF312E81), // indigo-900
                  Color(0xFF4C1D95), // violet-900
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Decorative circles ────────────────────────────────────────────
          Positioned(
            top: -size.height * 0.08,
            right: -size.width * 0.25,
            child: Container(
              width: size.width * 0.7,
              height: size.width * 0.7,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.04),
              ),
            ),
          ),
          Positioned(
            bottom: -size.height * 0.12,
            left: -size.width * 0.3,
            child: Container(
              width: size.width * 0.8,
              height: size.width * 0.8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary.withOpacity(0.12),
              ),
            ),
          ),

          // ── Main content ──────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Spacer(flex: 2),

                      // Logo badge
                      Center(
                        child: Container(
                          width: 90,
                          height: 90,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.45),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Text(
                              '⚡',
                              style: TextStyle(fontSize: 42),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 32),

                      // App name
                      Text(
                        'StudyCompete',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -1.2,
                        ),
                      ),

                      const SizedBox(height: 12),

                      Text(
                        'Study harder. Compete smarter.\nLevel up your academic life.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                          color: Colors.white.withOpacity(0.62),
                          height: 1.55,
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Feature pills
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        alignment: WrapAlignment.center,
                        children: const [
                          _FeaturePill(emoji: '🏆', label: 'Leaderboards'),
                          _FeaturePill(emoji: '📚', label: 'Daily Missions'),
                          _FeaturePill(emoji: '⚔️', label: 'Stat Battles'),
                          _FeaturePill(emoji: '🤖', label: 'AI Verification'),
                        ],
                      ),

                      const Spacer(flex: 3),

                      // Google sign-in button
                      if (_isLoading)
                        const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        )
                      else
                        _GoogleSignInButton(onPressed: _handleGoogleSignIn),

                      const SizedBox(height: 16),

                      Text(
                        'By continuing, you agree to our Terms of Service\nand Privacy Policy.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.38),
                          fontSize: 11.5,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// GOOGLE SIGN-IN BUTTON
// ═════════════════════════════════════════════════════════════════════════════
class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Google G logo (using colored text segments)
            SizedBox(
              width: 24,
              height: 24,
              child: CustomPaint(painter: _GoogleLogoPainter()),
            ),
            const SizedBox(width: 14),
            Text(
              'Continue with Google',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Draws the Google "G" logo with its four official colors.
class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    final strokeWidth = size.width * 0.18;

    // Full circle with gap for the "G" notch
    final sweepAngle = 2 * 3.14159265 * 0.78;
    const startAngle = 0.38; // ~22 degrees

    final paintBlue = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF4285F4)
      ..strokeCap = StrokeCap.round;
    final paintGreen = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFF34A853)
      ..strokeCap = StrokeCap.round;
    final paintYellow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFFBBC05)
      ..strokeCap = StrokeCap.round;
    final paintRed = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = const Color(0xFFEA4335)
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    // Approximate quadrant coloring
    canvas.drawArc(rect, startAngle, sweepAngle * 0.52, false, paintBlue);
    canvas.drawArc(rect, startAngle + sweepAngle * 0.52, sweepAngle * 0.16, false, paintGreen);
    canvas.drawArc(rect, startAngle + sweepAngle * 0.68, sweepAngle * 0.16, false, paintYellow);
    canvas.drawArc(rect, startAngle + sweepAngle * 0.84, sweepAngle * 0.16, false, paintRed);

    // Horizontal bar of the G
    final barY = center.dy;
    final barStart = Offset(center.dx, barY);
    final barEnd = Offset(center.dx + radius * 0.7, barY);
    canvas.drawLine(barStart, barEnd, paintBlue..strokeCap = StrokeCap.butt);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═════════════════════════════════════════════════════════════════════════════
// FEATURE PILL
// ═════════════════════════════════════════════════════════════════════════════
class _FeaturePill extends StatelessWidget {
  final String emoji;
  final String label;

  const _FeaturePill({required this.emoji, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
