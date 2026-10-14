// lib/features/auth/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Spacer(flex: 2),

              // ── Centered branding block (full width, centered) ──
              SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Logo ────────────────────────────────
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppTheme.navyMid,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 8,
                            left: 10,
                            child: CustomPaint(
                              size: const Size(16, 20),
                              painter: _MiniPinPainter(),
                            ),
                          ),
                          const Positioned(
                            bottom: 10,
                            right: 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _MiniLine(width: 10),
                                SizedBox(height: 2),
                                _MiniLine(width: 7),
                                SizedBox(height: 2),
                                _MiniLine(width: 9),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── सही Report ──────────────────────────
                    RichText(
                      textAlign: TextAlign.center,
                      text: const TextSpan(
                        children: [
                          TextSpan(
                            text: 'सही',
                            style: TextStyle(
                              fontFamily: 'Hind',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.navyAccent,
                            ),
                          ),
                          TextSpan(
                            text: ' Report',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 32,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'GPS verified field reporting\nfor every project.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        color: Color(0xFF7A90B8),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(flex: 2),

              // ── Buttons ──────────────────────────────────
              _HomeButton(
                label: 'Sign in as Project Owner',
                icon: Icons.manage_accounts_outlined,
                isPrimary: true,
                onTap: () => context.push(AppRoutes.ownerLogin),
              ),
              const SizedBox(height: 12),
              _HomeButton(
                label: 'Sign in with Access Code',
                icon: Icons.vpn_key_outlined,
                isPrimary: false,
                onTap: () => context.push(AppRoutes.codeLogin),
              ),
              const SizedBox(height: 24),

              // ── Register link ────────────────────────────
              Center(
                child: GestureDetector(
                  onTap: () => context.push(AppRoutes.ownerRegister),
                  child: RichText(
                    text: const TextSpan(
                      text: "Don't have an account? ",
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        color: Color(0xFF7A90B8),
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: 'Register as Owner',
                          style: TextStyle(
                            color: AppTheme.navyAccent,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Trust row ────────────────────────────────
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _TrustItem(label: 'GPS Verified'),
                  _Dot(),
                  _TrustItem(label: 'Tamper-proof'),
                  _Dot(),
                  _TrustItem(label: 'Instant'),
                ],
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isPrimary;
  final VoidCallback onTap;

  const _HomeButton({
    required this.label,
    required this.icon,
    required this.isPrimary,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          color: isPrimary ? AppTheme.navyMid : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isPrimary ? AppTheme.navyMid : const Color(0xFF2A3A5A),
            width: isPrimary ? 0 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: isPrimary ? Colors.white : AppTheme.navyAccent,
              size: 22,
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isPrimary ? Colors.white : AppTheme.navyAccent,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isPrimary ? Colors.white54 : const Color(0xFF4A5A7A),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final String label;
  const _TrustItem({required this.label});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontFamily: 'Poppins',
        fontSize: 11,
        color: Color(0xFF4A5A7A),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1D9E75),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _MiniPinPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.navyAccent
      ..style = PaintingStyle.fill;
    final cx = size.width / 2;
    final path = Path();
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
          ..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _MiniLine extends StatelessWidget {
  final double width;
  const _MiniLine({required this.width});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 1.5,
      decoration: BoxDecoration(
        color: AppTheme.navyAccent,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}