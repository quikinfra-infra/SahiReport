// lib/features/owner/billing/screens/billing_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../repositories/auth_repository.dart';

class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  late final Razorpay _razorpay;
  int _extraProjects = 1;
  bool _paying = false;
  String? _error;

  static const int _pricePerProject = AppConstants.proPricePerProjectPaise;

  int get _totalPaise => _extraProjects * _pricePerProject;
  double get _totalRupees => _totalPaise / 100;
  int get _totalProjects =>
      AppConstants.freePlanMaxProjects + _extraProjects;

  @override
  void initState() {
    super.initState();
    _razorpay = Razorpay();
    _razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    _razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    _razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, _onWallet);
  }

  @override
  void dispose() {
    _razorpay.clear();
    super.dispose();
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    final owner = ref.read(authProvider).owner;
    if (owner == null) return;
    try {
      await supabase.from('owners').update({
        'plan_type': 'pro',
        'extra_projects_count': _extraProjects,
      }).eq('id', owner.id);

      await ref.read(authProvider.notifier).refreshOwner();

      if (mounted) _showSuccessDialog();
    } catch (e) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = 'Payment received but plan update failed. '
              'Contact support with payment ID: ${response.paymentId}';
        });
      }
    }
  }

  void _onError(PaymentFailureResponse response) {
    if (!mounted) return;
    setState(() {
      _paying = false;
      _error = response.message ?? 'Payment failed. Please try again.';
    });
  }

  void _onWallet(ExternalWalletResponse response) {
    if (mounted) setState(() => _paying = false);
  }

  void _startPayment() {
    final owner = ref.read(authProvider).owner;
    if (owner == null) return;
    setState(() { _paying = true; _error = null; });

    final options = {
      'key': AppConstants.razorpayKeyId,
      'amount': _totalPaise,
      'name': AppConstants.appName,
      'description':
      '$_extraProjects extra project${_extraProjects == 1 ? '' : 's'} · 1 year',
      'prefill': {
        'contact': owner.phone ?? '',
        'email': owner.email,
      },
      'theme': {'color': '#1A2F5A'},
    };

    try {
      _razorpay.open(options);
    } on PlatformException catch (e) {
      setState(() {
        _paying = false;
        _error = e.message ?? 'Could not open payment screen.';
      });
    }
  }

  void _showSuccessDialog() {
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.success, size: 32),
              ),
              const SizedBox(height: 18),
              const Text('Projects unlocked!',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark)),
              const SizedBox(height: 10),
              Text(
                'You now have $_totalProjects projects available '
                    '($_extraProjects extra + ${AppConstants.freePlanMaxProjects} free). '
                    'Each project supports up to '
                    '${AppConstants.freePlanMaxUsersPerProject} field users.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: AppTheme.grayText,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity, height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop();
                    context.go(AppRoutes.ownerDashboard);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Go to Dashboard',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Projects',
            style: TextStyle(color: Colors.white, fontSize: 16,
                fontWeight: FontWeight.w600)),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Plan card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.navyDark, AppTheme.navyMid],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.folder_special_rounded,
                          color: AppTheme.navyAccent, size: 22),
                      const SizedBox(width: 8),
                      const Text('Extra Projects',
                          style: TextStyle(color: Colors.white, fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.navyAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('YEARLY',
                            style: TextStyle(color: AppTheme.navyAccent,
                                fontSize: 10, fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${_totalRupees.toStringAsFixed(0)}',
                          style: const TextStyle(color: Colors.white,
                              fontSize: 34, fontWeight: FontWeight.w700,
                              height: 1)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 4),
                        child: Text('/year', style: TextStyle(
                            color: Color(0xFF7A90B8), fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text('₹499 × $_extraProjects project'
                      '${_extraProjects == 1 ? '' : 's'}',
                      style: const TextStyle(color: Color(0xFF7A90B8),
                          fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project picker
            const Text('How many extra projects?',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: AppTheme.navyDark)),
            const SizedBox(height: 6),
            Text(
              'You already have ${AppConstants.freePlanMaxProjects} free projects. '
                  'Each extra project holds up to '
                  '${AppConstants.freePlanMaxUsersPerProject} field users.',
              style: const TextStyle(fontSize: 12, color: AppTheme.grayText),
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                _CountButton(
                  icon: Icons.remove,
                  onTap: _extraProjects > 1
                      ? () => setState(() => _extraProjects--)
                      : null,
                ),
                Expanded(
                  child: Center(
                    child: Text('$_extraProjects',
                        style: const TextStyle(fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.navyDark)),
                  ),
                ),
                _CountButton(
                  icon: Icons.add,
                  onTap: () => setState(() => _extraProjects++),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Slider(
              value: _extraProjects.toDouble(),
              min: 1, max: 20, divisions: 19,
              activeColor: AppTheme.navyMid,
              inactiveColor: AppTheme.grayBorder,
              onChanged: (v) => setState(() => _extraProjects = v.round()),
            ),
            const SizedBox(height: 24),

            // What's included
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grayBorder, width: 0.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("What you get",
                      style: TextStyle(fontSize: 14,
                          fontWeight: FontWeight.w600, color: AppTheme.navyDark)),
                  const SizedBox(height: 12),
                  ...[
                    '$_totalProjects total projects '
                        '(${AppConstants.freePlanMaxProjects} free + '
                        '$_extraProjects purchased)',
                    '${AppConstants.freePlanMaxUsersPerProject} field users per project',
                    'PDF & Excel export on all projects',
                    'No ads',
                    'GPS-verified photo reports',
                    'Push notifications',
                  ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppTheme.success, size: 16),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: const TextStyle(fontSize: 13,
                                  color: AppTheme.textPrimary)),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Price summary
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.grayBorder, width: 0.5),
              ),
              child: Column(
                children: [
                  _PriceLine(
                      label: '$_extraProjects project'
                          '${_extraProjects == 1 ? '' : 's'} × ₹499',
                      value: '₹${_totalRupees.toStringAsFixed(0)}'),
                  const Divider(height: 20),
                  _PriceLine(
                      label: 'Total due today',
                      value: '₹${_totalRupees.toStringAsFixed(0)}',
                      bold: true),
                  const SizedBox(height: 4),
                  const Text('GST will be added once registered',
                      style: TextStyle(fontSize: 11, color: AppTheme.grayText)),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity, height: 54,
              child: ElevatedButton(
                onPressed: _paying ? null : _startPayment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.navyDark,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: _paying
                    ? const SizedBox(width: 22, height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text('Pay ₹${_totalRupees.toStringAsFixed(0)} →',
                    style: const TextStyle(fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
            ),
            const SizedBox(height: 12),
            const Center(
              child: Text('Secured by Razorpay · Valid for 1 year',
                  style: TextStyle(fontSize: 11, color: AppTheme.grayText)),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _CountButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  const _CountButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: onTap != null ? AppTheme.navyDark : AppTheme.grayBorder,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

class _PriceLine extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  const _PriceLine({required this.label, required this.value,
    this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: 13,
            color: bold ? AppTheme.navyDark : AppTheme.grayText,
            fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value, style: TextStyle(fontSize: 13, color: AppTheme.navyDark,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      ],
    );
  }
}