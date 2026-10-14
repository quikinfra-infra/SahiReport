// lib/features/auth/screens/confirm_email_screen.dart
// ─────────────────────────────────────────────────────────────
// Shown right after registration when email confirmation is
// required. Tells the user to check their inbox, lets them resend
// the confirmation email, and return to login once confirmed.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

class ConfirmEmailScreen extends ConsumerStatefulWidget {
  final String email;
  const ConfirmEmailScreen({super.key, required this.email});

  @override
  ConsumerState<ConfirmEmailScreen> createState() =>
      _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends ConsumerState<ConfirmEmailScreen> {
  bool _resending = false;
  int _cooldown = 0; // seconds until resend allowed again

  Future<void> _resend() async {
    if (_resending || _cooldown > 0) return;
    setState(() => _resending = true);
    try {
      await ref.read(authProvider.notifier).resendConfirmation(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmation email sent again.'),
            backgroundColor: AppTheme.success,
          ),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not resend. Please try again shortly.'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  void _startCooldown() {
    setState(() => _cooldown = 30);
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _cooldown--);
      return _cooldown > 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.go(AppRoutes.ownerLogin),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.navyMid,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.mark_email_unread_outlined,
                    color: AppTheme.navyAccent, size: 32),
              ),
              const SizedBox(height: 24),
              const Text(
                'Check your email',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF7A90B8),
                    height: 1.5,
                  ),
                  children: [
                    const TextSpan(
                        text: 'We sent a confirmation link to\n'),
                    TextSpan(
                      text: widget.email,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const TextSpan(
                        text:
                        '.\n\nClick the link in that email to activate your '
                            'account, then come back and sign in.'),
                  ],
                ),
              ),
              const SizedBox(height: 36),

              // Resend
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed:
                  (_resending || _cooldown > 0) ? null : _resend,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppTheme.navyAccent),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _resending
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: AppTheme.navyAccent, strokeWidth: 2),
                  )
                      : Text(
                    _cooldown > 0
                        ? 'Resend in ${_cooldown}s'
                        : 'Resend confirmation email',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navyAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Go to login
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => context.go(AppRoutes.ownerLogin),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyMid,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "I've confirmed — Sign in",
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const Spacer(),
              Center(
                child: Text(
                  "Didn't get it? Check spam, or resend above.",
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}