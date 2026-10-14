// lib/features/owner/settings/screens/owner_settings_screen.dart
// ─────────────────────────────────────────────────────────────
// Owner Settings: account info, plan, legal links, about, and
// the App Store / Play Store-required Delete Account flow.
//
// NOTE: replace the two policy URLs below with your hosted pages.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../providers/auth_provider.dart';
import 'edit_profile_screen.dart';

class OwnerSettingsScreen extends ConsumerWidget {
  const OwnerSettingsScreen({super.key});

  // TODO: replace with your hosted policy URLs.
  static const String privacyPolicyUrl =
      'https://YOUR-SITE.com/privacy-policy';
  static const String termsOfServiceUrl =
      'https://YOUR-SITE.com/terms-of-service';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final owner = ref.watch(authProvider).owner;
    final isPro = owner?.isFree == false;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Account ───────────────────────────────────────
        const _SectionLabel('ACCOUNT'),
        _Card(
          children: [
            _InfoRow(
              icon: Icons.person_outline,
              label: 'Name',
              value: owner?.fullName ?? '—',
            ),
            const Divider(height: 1),
            _InfoRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: owner?.email ?? '—',
            ),
            if ((owner?.companyName ?? '').isNotEmpty) ...[
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.business_outlined,
                label: 'Company',
                value: owner!.companyName!,
              ),
            ],
            if ((owner?.gstin ?? '').isNotEmpty) ...[
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.receipt_long_outlined,
                label: 'GSTIN',
                value: owner!.gstin!,
              ),
            ],
            if ((owner?.phone ?? '').isNotEmpty) ...[
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: owner!.phone!,
              ),
            ],
            if (_hasAddress(owner)) ...[
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.location_on_outlined,
                label: 'Address',
                value: _formatAddress(owner),
              ),
            ],
            const Divider(height: 1),
            _LinkRow(
              icon: Icons.edit_outlined,
              label: 'Edit Profile',
              trailing: Icons.chevron_right,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const EditProfileScreen(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Plan ──────────────────────────────────────────
        const _SectionLabel('PLAN'),
        _Card(
          children: [
            ListTile(
              contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
              leading: const Icon(Icons.workspace_premium_outlined,
                  color: AppTheme.navyMid, size: 20),
              title: Text(isPro ? 'Pro Plan' : 'Free Plan',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navyDark)),
              subtitle: Text(
                isPro
                    ? 'Unlimited projects and users'
                    : 'Up to ${AppConstants.freePlanMaxProjects} projects, '
                    '${AppConstants.freePlanMaxUsersPerProject} users per project',
                style: const TextStyle(fontSize: 12, color: AppTheme.grayText),
              ),
              trailing: isPro
                  ? null
                  : TextButton(
                onPressed: () => context.push(AppRoutes.billing),
                child: const Text('Upgrade'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Legal ─────────────────────────────────────────
        const _SectionLabel('LEGAL'),
        _Card(
          children: [
            _LinkRow(
              icon: Icons.privacy_tip_outlined,
              label: 'Privacy Policy',
              onTap: () => _openUrl(context, privacyPolicyUrl),
            ),
            const Divider(height: 1),
            _LinkRow(
              icon: Icons.description_outlined,
              label: 'Terms of Service',
              onTap: () => _openUrl(context, termsOfServiceUrl),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── About ─────────────────────────────────────────
        const _SectionLabel('ABOUT'),
        _Card(
          children: [
            const _InfoRow(
              icon: Icons.info_outline,
              label: 'Version',
              value: AppConstants.appVersion,
            ),
            const Divider(height: 1),
            _LinkRow(
              icon: Icons.mail_outline,
              label: 'Contact Support',
              onTap: () => _openUrl(
                context,
                'mailto:${AppConstants.supportEmail}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),

        // ── Danger zone ───────────────────────────────────
        OutlinedButton.icon(
          onPressed: () => _confirmDelete(context, ref),
          icon: const Icon(Icons.delete_outline, color: AppTheme.error),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppTheme.error,
            side: const BorderSide(color: AppTheme.error),
            minimumSize: const Size(double.infinity, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          label: const Text('Delete Account'),
        ),
        const SizedBox(height: 8),
        const Text(
          'Deleting your account permanently removes your projects, '
              'users, and submissions. This cannot be undone.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: AppTheme.grayText),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  bool _hasAddress(dynamic owner) {
    return (owner?.addressLine ?? '').isNotEmpty ||
        (owner?.city ?? '').isNotEmpty ||
        (owner?.state ?? '').isNotEmpty ||
        (owner?.pincode ?? '').isNotEmpty;
  }

  String _formatAddress(dynamic owner) {
    final parts = <String>[
      if ((owner?.addressLine ?? '').isNotEmpty) owner.addressLine as String,
      if ((owner?.city ?? '').isNotEmpty) owner.city as String,
      if ((owner?.state ?? '').isNotEmpty) owner.state as String,
      if ((owner?.pincode ?? '').isNotEmpty) owner.pincode as String,
    ];
    return parts.join(', ');
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    final ok = await canLaunchUrl(uri);
    if (ok) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open $url')),
      );
    }
  }

  // ── Delete account: soft delete with 30-day recovery window ──
  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 28),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: AppTheme.error.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: AppTheme.error, size: 28),
              ),
              const SizedBox(height: 18),
              const Text('Delete account?',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark)),
              const SizedBox(height: 10),
              const Text(
                'Your account will be scheduled for deletion. You have '
                    '30 days to log back in and reactivate it.\n\n'
                    'After 30 days, all your projects, field users, submissions, '
                    'and photos will be permanently deleted.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: AppTheme.grayText,
                    height: 1.5),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.grayDark,
                        side: const BorderSide(color: AppTheme.grayBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (confirmed != true) return;
    if (!context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: AppTheme.navyMid),
      ),
    );

    try {
      await ref.read(authProvider.notifier).softDeleteAccount();
      if (context.mounted) {
        Navigator.pop(context); // dismiss progress
        // Router redirects automatically when isOwner is cleared.
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // dismiss progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }
}

// ── Small building blocks ─────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 2, bottom: 8),
    child: Text(text, style: AppTheme.sectionTitle),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppTheme.grayCard,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.grayBorder, width: 0.5),
    ),
    child: Column(children: children),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(icon, size: 18, color: AppTheme.grayText),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.grayText)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.navyDark)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _LinkRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final IconData trailing;
  const _LinkRow(
      {required this.icon,
        required this.label,
        required this.onTap,
        this.trailing = Icons.open_in_new});
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.grayText),
          const SizedBox(width: 12),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.navyDark)),
          const Spacer(),
          Icon(trailing, size: 15, color: AppTheme.grayText),
        ],
      ),
    ),
  );
}