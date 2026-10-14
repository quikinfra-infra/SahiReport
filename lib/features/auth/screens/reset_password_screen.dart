// lib/features/auth/screens/reset_password_screen.dart
//
// Landing screen once a recovery session exists. The router forces
// navigation here whenever AuthSessionState.passwordRecovery is true
// (see app_router.dart's redirect + auth_provider.dart's
// passwordRecoveryStream listener). In practice that session is
// established by verifying the 6-digit code on the forgot-password
// screen — Supabase fires the same AuthChangeEvent.passwordRecovery
// either way, so this screen doesn't need to know or care how the
// user got here.
//
// Uses the same rootNavigatorKey + deferred-dialog pattern as the
// login screen's error dialog (§8.2 in the handoff): once
// updatePassword() succeeds we deliberately do NOT clear
// passwordRecovery yet (see completePasswordReset below), so this
// screen stays mounted long enough to show the confirmation dialog
// before the router redirects away.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final error = await ref
        .read(authProvider.notifier)
        .updatePassword(_passCtrl.text);

    // Same deferral as the login screen's error dialog — give any
    // in-flight rebuild from the isLoading flip a moment to settle
    // before opening a dialog from the global navigator key.
    Future.delayed(const Duration(milliseconds: 150), () {
      if (error != null) {
        _showInfoDialog(
          icon: Icons.error_outline_rounded,
          iconColor: AppTheme.error,
          title: "Couldn't update password",
          message: error,
          buttonLabel: 'Try again',
        );
      } else {
        _showInfoDialog(
          icon: Icons.check_circle_outline_rounded,
          iconColor: AppTheme.success,
          title: 'Password updated',
          message: 'Your password has been changed. Sign in with your new '
              'password to continue.',
          buttonLabel: 'Continue to login',
          onConfirm: () =>
              ref.read(authProvider.notifier).completePasswordReset(),
        );
      }
    });
  }

  void _showInfoDialog({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String message,
    required String buttonLabel,
    VoidCallback? onConfirm,
  }) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    showDialog(
      context: ctx,
      useRootNavigator: true,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppTheme.grayText,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    onConfirm?.call();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      // No back button — the only way out of recovery should be
      // completing it or the router redirecting away, not the user
      // backing out into a half-finished state.
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Set a new password',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Choose a new password for your account.',
                  style: TextStyle(fontSize: 14, color: Color(0xFF7A90B8)),
                ),
                const SizedBox(height: 36),

                _buildLabel('New password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('••••••••').copyWith(
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure ? Icons.visibility_off : Icons.visibility,
                        color: const Color(0xFF7A90B8),
                        size: 20,
                      ),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) =>
                  v == null || v.length < 6 ? 'Password too short' : null,
                ),
                const SizedBox(height: 20),

                _buildLabel('Confirm new password'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _confirmCtrl,
                  obscureText: _obscure,
                  style: const TextStyle(color: Colors.white),
                  decoration: _inputDecoration('••••••••'),
                  validator: (v) => v != _passCtrl.text
                      ? 'Passwords don\'t match'
                      : null,
                ),
                const SizedBox(height: 36),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: authState.isLoading ? null : _submit,
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
                      'Reset password',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
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