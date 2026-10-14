// lib/features/auth/screens/forgot_password_screen.dart
//
// Two-step password recovery entry point:
//   1. Enter email -> Supabase sends an OTP code by email.
//   2. Enter the code -> exchanged in-app for a recovery session.
//
// Deliberately code-based, not link-based: Gmail's spam/safety
// scanner pre-fetches links in messages it flags as suspicious,
// silently burning the single-use token before the user can tap it
// (otp_expired — handoff §8.6). A code typed in by hand has nothing
// for a scanner to consume.
//
// This screen manages its own local loading/step/error state rather
// than going through AuthSessionState for the email-send step — that
// step can't change anyone's login status, so there's no
// router-rebuild risk (contrast with the login screen's
// rootNavigatorKey dialog workaround, which exists specifically
// because isLoading flips there do rebuild things — see §8.1/§8.2 in
// the handoff). Once the code is verified, AuthNotifier's
// passwordRecoveryStream listener picks up the resulting
// passwordRecovery flag on its own and the router takes the user to
// the reset-password screen — no manual navigation needed here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../providers/auth_provider.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

enum _Step { email, code }

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  _Step _step = _Step.email;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    if (!_emailFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref
        .read(authProvider.notifier)
        .sendPasswordResetEmail(_emailCtrl.text.trim());

    if (!mounted) return;
    setState(() {
      _busy = false;
      if (error != null) {
        _error = error;
      } else {
        _step = _Step.code;
      }
    });
  }

  Future<void> _verifyCode() async {
    if (!_codeFormKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final error = await ref.read(authProvider.notifier).verifyPasswordResetOtp(
      email: _emailCtrl.text.trim(),
      token: _codeCtrl.text.trim(),
    );

    if (!mounted) return;
    if (error != null) {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
    // On success we deliberately leave _busy true and don't touch
    // local state further — the router redirect (driven by the
    // passwordRecovery flag flipping) takes over and replaces this
    // screen on its own.
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
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: _step == _Step.email ? _buildEmailStep() : _buildCodeStep(),
        ),
      ),
    );
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Forgot password?',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter your account email and we'll send you a code "
                'to reset your password.',
            style: TextStyle(fontSize: 14, color: Color(0xFF7A90B8)),
          ),
          const SizedBox(height: 36),

          _buildLabel('Email address'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: Colors.white),
            decoration: _inputDecoration('you@company.com'),
            validator: (v) =>
            v == null || !v.contains('@') ? 'Enter a valid email' : null,
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 32),
          _buildPrimaryButton(
            label: 'Send code',
            onPressed: _busy ? null : _sendCode,
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.success.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_read_outlined,
              color: AppTheme.success,
              size: 30,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Enter your code',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            "If an account exists for ${_emailCtrl.text.trim()}, we've "
                'sent a code. Enter it below — it expires in 60 '
                'minutes.',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF7A90B8),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 32),

          _buildLabel('Verification code'),
          const SizedBox(height: 6),
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 10, // Supabase allows 6–10 digits (dashboard-configurable
            // under Auth > Providers > Email > Email OTP Length —
            // this project currently sends 8, not the common
            // default of 6, so don't hardcode a fixed length here)
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              letterSpacing: 4,
            ),
            decoration:
            _inputDecoration('Enter your code').copyWith(counterText: ''),
            validator: (v) => v == null || v.trim().length < 6
                ? 'Enter the code from your email'
                : null,
          ),

          if (_error != null) ...[
            const SizedBox(height: 14),
            Text(
              _error!,
              style: const TextStyle(color: AppTheme.error, fontSize: 13),
            ),
          ],

          const SizedBox(height: 28),
          _buildPrimaryButton(
            label: 'Verify code',
            onPressed: _busy ? null : _verifyCode,
          ),
          const SizedBox(height: 20),

          Center(
            child: GestureDetector(
              onTap: _busy
                  ? null
                  : () => setState(() {
                _step = _Step.email;
                _error = null;
                _codeCtrl.clear();
              }),
              child: const Text(
                'Use a different email or resend the code',
                style: TextStyle(
                  color: AppTheme.navyAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.navyMid,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _busy
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        )
            : Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) => Text(
    text,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      color: Color(0xFF7A90B8),
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF4A5A7A)),
    filled: true,
    fillColor: const Color(0xFF1E3A6E),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.navyAccent, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.error),
    ),
    errorStyle: const TextStyle(color: AppTheme.error),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
  );
}