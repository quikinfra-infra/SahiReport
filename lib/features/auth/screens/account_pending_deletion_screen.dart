// lib/features/auth/screens/account_pending_deletion_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../providers/auth_provider.dart';

class AccountPendingDeletionScreen extends ConsumerStatefulWidget {
  const AccountPendingDeletionScreen({super.key});

  @override
  ConsumerState<AccountPendingDeletionScreen> createState() =>
      _AccountPendingDeletionScreenState();
}

class _AccountPendingDeletionScreenState
    extends ConsumerState<AccountPendingDeletionScreen> {
  bool _reactivating = false;
  String? _error;

  Future<void> _reactivate() async {
    setState(() => _reactivating = true);
    if (mounted) {
      setState(() => _reactivating = false);
      _showReactivateDialog();
    }
  }

  void _showReactivateDialog() {
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    bool loading = false;
    String? err;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setS) {
          return Dialog(
            backgroundColor: Colors.white,
            insetPadding: const EdgeInsets.symmetric(horizontal: 28),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Reactivate account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter your credentials to restore your account.',
                    style: TextStyle(fontSize: 13, color: AppTheme.grayText),
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: _inputDec('Email address'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: passCtrl,
                    obscureText: true,
                    decoration: _inputDec('Password'),
                  ),
                  if (err != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      err!,
                      style: const TextStyle(
                        color: AppTheme.error,
                        fontSize: 12,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.grayDark,
                            side: const BorderSide(color: AppTheme.grayBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: loading
                              ? null
                              : () async {
                            if (emailCtrl.text.trim().isEmpty ||
                                passCtrl.text.isEmpty) {
                              setS(() {
                                err =
                                'Please enter both email and password.';
                              });
                              return;
                            }
                            setS(() {
                              loading = true;
                              err = null;
                            });
                            try {
                              final errorMsg = await ref
                                  .read(authProvider.notifier)
                                  .reactivateWithCredentials(
                                email: emailCtrl.text.trim(),
                                password: passCtrl.text,
                              );
                              if (errorMsg != null) {
                                setS(() {
                                  loading = false;
                                  err = errorMsg;
                                });
                                return;
                              }
                              if (dialogCtx.mounted) {
                                Navigator.pop(dialogCtx);
                              }
                            } catch (e) {
                              setS(() {
                                loading = false;
                                err = e
                                    .toString()
                                    .replaceAll('Exception: ', '');
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.navyDark,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: loading
                              ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                              : const Text(
                            'Reactivate',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  InputDecoration _inputDec(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppTheme.grayText, fontSize: 13),
    filled: true,
    fillColor: AppTheme.grayCard,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.grayBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: AppTheme.navyMid, width: 1.5),
    ),
    contentPadding:
    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(authProvider.select((s) => s.pendingDeletion));

    return Scaffold(
      backgroundColor: AppTheme.navyDark,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  color: AppTheme.error,
                  size: 32,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Account scheduled\nfor deletion',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account will be permanently deleted within 30 days. '
                    'All your projects, users, and submissions will be lost.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A90B8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Changed your mind? Tap Reactivate to restore your '
                    'account and all your data.',
                style: TextStyle(
                  fontSize: 14,
                  color: Color(0xFF7A90B8),
                  height: 1.5,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.error.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13),
                  ),
                ),
              ],
              const Spacer(),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _reactivating ? null : _reactivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.success,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _reactivating
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                      : const Text(
                    'Reactivate my account',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  onPressed: () {
                    ref.read(authProvider.notifier).clearPendingDeletion();
                    context.go(AppRoutes.ownerLogin);
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Color(0xFF3A4A6B)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'No, proceed with deletion',
                    style: TextStyle(fontSize: 15),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}