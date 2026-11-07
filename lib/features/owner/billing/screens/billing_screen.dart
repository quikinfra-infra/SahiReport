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
import 'package:supabase_flutter/supabase_flutter.dart';
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

    // Guard: a verified payment always carries all three Razorpay ids.
    if (response.paymentId == null ||
        response.paymentId!.isEmpty ||
        response.orderId == null ||
        response.orderId!.isEmpty ||
        response.signature == null ||
        response.signature!.isEmpty) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = 'Incomplete payment response. Please contact support.';
        });
      }
      return;
    }

    try {
      // Server-side HMAC-SHA256 signature verification.
      // The Edge Function (verify-payment) re-computes the expected
      // signature using RAZORPAY_KEY_SECRET (never shipped in the app),
      // fetches the order/payment from Razorpay, and derives the slot
      // count from the order — never from this request body.
      final result = await Supabase.instance.client.functions.invoke(
        'verify-payment',
        body: {
          'razorpay_payment_id': response.paymentId,
          'razorpay_order_id':   response.orderId,
          'razorpay_signature':  response.signature,
        },
      );

      if (result.status != 200) {
        final errorMsg =
            (result.data as Map<String, dynamic>?)?['error'] as String? ??
                'Payment verification failed. Contact support with ID: ${response.paymentId}';
        if (mounted) {
          setState(() {
            _paying = false;
            _error = errorMsg;
          });
        }
        return;
      }

      final updatedSlots =
          (result.data as Map<String, dynamic>?)?['updatedSlots'] as int? ??
              _extraProjects;

      await ref.read(authProvider.notifier).refreshOwner();

      if (mounted) {
        setState(() => _paying = false);
        _showSuccessDialog(updatedSlots);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _paying = false;
          _error = 'Payment received but verification failed. '
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

  Future<void> _startPayment() async {
    final owner = ref.read(authProvider).owner;
    if (owner == null) return;
    setState(() {
      _paying = true;
      _error = null;
    });

    // The order must be created server-side: verify-payment needs a
    // razorpay_order_id and derives the slot count from the order notes.
    // Never trust a client-supplied amount.
    final Map<String, dynamic> order;
    try {
      final result = await Supabase.instance.client.functions.invoke(
        'create-order',
        body: {'extra_projects': _extraProjects},
      );

      if (result.status != 200) {
        final message =
            (result.data as Map<String, dynamic>?)?['error'] as String? ??
                'Could not start the payment. Please try again.';
        if (mounted) {
          setState(() {
            _paying = false;
            _error = message;
          });
        }
        return;
      }

      final data = result.data;
      if (data is! Map<String, dynamic> ||
          data['order_id'] is! String ||
          data['amount'] is! int) {
        if (mounted) {
          setState(() {
            _paying = false;
            _error = 'Could not start the payment. Please try again.';
          });
        }
        return;
      }
      order = data;
    } catch (e) {
      debugPrint('create-order failed: $e');
      if (mounted) {
        setState(() {
          _paying = false;
          _error = 'Could not reach the payment server. Please try again.';
        });
      }
      return;
    }

    final options = {
      'key': (order['key_id'] as String?) ?? AppConstants.razorpayKeyId,
      'order_id': order['order_id'] as String,
      'amount': order['amount'] as int,
      'currency': (order['currency'] as String?) ?? 'INR',
      'name': AppConstants.appName,
      'description':
      '$_extraProjects Pro project slot${_extraProjects == 1 ? '' : 's'} · 1 year',
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

  void _showSuccessDialog(int totalProSlots) {
    final ctx = rootNavigatorKey.currentContext;
    if (ctx == null) return;
    final totalActiveCapacity =
        AppConstants.freePlanMaxProjects + totalProSlots;

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
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: AppTheme.success.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.workspace_premium_rounded,
                    color: AppTheme.success, size: 32),
              ),
              const SizedBox(height: 18),
              const Text('Project Slots Unlocked!',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark)),
              const SizedBox(height: 10),
              Text(
                'You now have $totalActiveCapacity active project slots '
                    '($totalProSlots Pro + ${AppConstants.freePlanMaxProjects} Free) valid for 1 year.\n\n'
                    'If a project finishes mid-year, permanently close it to immediately reuse its slot for a new project!',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: AppTheme.grayText, height: 1.5),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
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
                      style:
                      TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
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
    final totalWithPurchase =
        AppConstants.freePlanMaxProjects + _extraProjects;

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Add Project Slots',
            style: TextStyle(
                color: Colors.white,
                fontSize: 16,
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
                      const Text('Pro Project Slots',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.navyAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('PER PROJECT / YEAR',
                            style: TextStyle(
                                color: AppTheme.navyAccent,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('₹${_totalRupees.toStringAsFixed(0)}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 34,
                              fontWeight: FontWeight.w700,
                              height: 1)),
                      const Padding(
                        padding: EdgeInsets.only(bottom: 4, left: 4),
                        child: Text('/year',
                            style: TextStyle(
                                color: Color(0xFF7A90B8), fontSize: 14)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                      '₹${(_pricePerProject / 100).toStringAsFixed(0)} × $_extraProjects active project slot'
                          '${_extraProjects == 1 ? '' : 's'}',
                      style: const TextStyle(
                          color: Color(0xFF7A90B8), fontSize: 13)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Project picker
            const Text('How many extra active project slots?',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navyDark)),
            const SizedBox(height: 6),
            Text(
              '${AppConstants.freePlanMaxProjects} active projects (${AppConstants.freePlanMaxUsersPerProject} seats each) are always free. '
                  'Purchase extra annual slots for additional projects.',
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
                        style: const TextStyle(
                            fontSize: 32,
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
              min: 1,
              max: 20,
              divisions: 19,
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
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.navyDark)),
                  const SizedBox(height: 12),
                  ...[
                    '$totalWithPurchase active projects at a time '
                        '(${AppConstants.freePlanMaxProjects} free + '
                        '$_extraProjects Pro)',
                    'Reusable slots: close a completed project mid-year to start a new one on the same annual slot',
                    'Closed projects keep 100% of data & exports forever',
                    '${AppConstants.freePlanMaxUsersPerProject} active field users (seats) per project',
                    'PDF & Excel export on all projects',
                    'GPS-verified photo reports & push notifications',
                  ].map((f) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 2),
                          child: Icon(Icons.check_circle_rounded,
                              color: AppTheme.success, size: 16),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(f,
                              style: const TextStyle(
                                  fontSize: 13,
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
                      label: '$_extraProjects Pro slot'
                          '${_extraProjects == 1 ? '' : 's'} × ₹${(_pricePerProject / 100).toStringAsFixed(0)}',
                      value: '₹${_totalRupees.toStringAsFixed(0)}'),
                  const Divider(height: 20),
                  _PriceLine(
                      label: 'Total due today (1 Year)',
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
                    style:
                    const TextStyle(color: AppTheme.error, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 54,
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
                    ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : Text('Pay ₹${_totalRupees.toStringAsFixed(0)} →',
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w700)),
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
        width: 44,
        height: 44,
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
  const _PriceLine(
      {required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 13,
                color: bold ? AppTheme.navyDark : AppTheme.grayText,
                fontWeight: bold ? FontWeight.w600 : FontWeight.normal)),
        Text(value,
            style: TextStyle(
                fontSize: 13,
                color: AppTheme.navyDark,
                fontWeight: bold ? FontWeight.w700 : FontWeight.normal)),
      ],
    );
  }
}