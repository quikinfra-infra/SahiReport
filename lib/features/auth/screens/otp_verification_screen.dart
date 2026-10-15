// lib/features/auth/screens/otp_verification_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String email;
  final String phone;

  const OtpVerificationScreen({
    super.key,
    required this.email,
    required this.phone,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen> {
  final _otpCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _verifyOtp() async {
    if (!_formKey.currentState!.validate()) return;

    final token = _otpCtrl.text.trim();

    // Call the verifyPhoneOtp method from your updated AuthNotifier
    final error = await ref.read(authProvider.notifier).verifyPhoneOtp(
      phone: widget.phone,
      token: token,
    );

    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: AppTheme.error),
      );
    } else {
      // Verification successful! The auth state will update to 'owner'
      // and GoRouter will automatically redirect to the Dashboard.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number verified successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _resendOtp() async {
    final error = await ref.read(authProvider.notifier).sendPhoneOtp(phone: widget.phone);
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(error ?? 'A new code has been sent to ${widget.phone}'),
        backgroundColor: error == null ? Colors.green : AppTheme.error,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

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
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Verify Your Phone',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We sent a 6-digit code to ${widget.phone}. Enter it below to activate your account.',
                  style: const TextStyle(fontSize: 14, color: Color(0xFF7A90B8)),
                ),
                const SizedBox(height: 36),

                // ── OTP Input ──────────────────────────────
                const Text(
                  '6-Digit Code',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF7A90B8),
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _otpCtrl,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    counterText: '',
                    hintText: '000000',
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
                  ),
                  validator: (v) => v == null || v.trim().length != 6
                      ? 'Enter a valid 6-digit code'
                      : null,
                ),
                const SizedBox(height: 36),

                // ── Verify Button ────────────────────────
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _verifyOtp,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.navyMid,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: authState.isLoading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                        : const Text(
                      'Verify & Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // ── Resend Code ─────────────────────────────
                Center(
                  child: TextButton(
                    onPressed: authState.isLoading ? null : _resendOtp,
                    child: const Text(
                      'Didn\'t receive the code? Resend',
                      style: TextStyle(
                        color: AppTheme.navyAccent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    'A confirmation link was also sent to:\n${widget.email}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF4A5A7A),
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}