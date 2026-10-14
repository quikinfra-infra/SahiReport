// lib/features/auth/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';
import '../../../core/router/app_router.dart';
import 'package:go_router/go_router.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  late Animation<double> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _slideAnim = Tween<double>(begin: 20, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.2, 0.7, curve: Curves.easeOut),
      ),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2800), () {
      if (mounted) _navigate();
    });
  }

  void _navigate() {
    final authState = ref.read(authProvider);
    if (authState.isOwner) {
      context.go(AppRoutes.ownerDashboard);
    } else if (authState.isFieldUser) {
      context.go(AppRoutes.fieldHome);
    } else {
      context.go(AppRoutes.home);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _fadeAnim.value,
                    child: Transform.scale(
                      scale: _scaleAnim.value,
                      child: Transform.translate(
                        offset: Offset(0, _slideAnim.value),
                        child: child,
                      ),
                    ),
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        color: AppTheme.navyMid,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 16,
                            left: 20,
                            child: _LocationPin(),
                          ),
                          Positioned(
                            bottom: 18,
                            right: 18,
                            child: _DocLines(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // सही Report
                    RichText(
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'सही',
                            style: TextStyle(
                              fontFamily: 'Hind',
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navyAccent,
                            ),
                          ),
                          TextSpan(
                            text: ' Report',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 36,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tagline
                    const Text(
                      'Field Reports. Verified. Instant.',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF7A90B8),
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Bottom — trust badges + version
            Positioned(
              bottom: 24,
              left: 0,
              right: 0,
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) => Opacity(
                  opacity: _fadeAnim.value,
                  child: child,
                ),
                child: const Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _TrustBadge(label: 'GPS Verified'),
                        SizedBox(width: 8),
                        _TrustBadge(label: 'Tamper-proof'),
                        SizedBox(width: 8),
                        _TrustBadge(label: 'Instant'),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'v1.0.0',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 11,
                        color: Color(0xFF3A4A6B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(28, 36),
      painter: _PinPainter(),
    );
  }
}

class _PinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.navyAccent
      ..style = PaintingStyle.fill;

    final path = Path();
    final cx = size.width / 2;

    path.addOval(Rect.fromCircle(center: Offset(cx, cx), radius: cx));
    path.moveTo(cx - cx * 0.5, size.width * 0.8);
    path.lineTo(cx + cx * 0.5, size.width * 0.8);
    path.lineTo(cx, size.height);
    path.close();

    canvas.drawPath(path, paint);

    canvas.drawCircle(
      Offset(cx, cx),
      cx * 0.42,
      Paint()
        ..color = AppTheme.navyMid
        ..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _DocLines extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Line(width: 18),
        SizedBox(height: 3),
        _Line(width: 14),
        SizedBox(height: 3),
        _Line(width: 16),
      ],
    );
  }
}

class _Line extends StatelessWidget {
  final double width;
  const _Line({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 2.5,
      decoration: BoxDecoration(
        color: AppTheme.navyAccent,
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

class _TrustBadge extends StatelessWidget {
  final String label;
  const _TrustBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1E3A6E),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: AppTheme.success,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 10,
              color: Color(0xFF7A90B8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
