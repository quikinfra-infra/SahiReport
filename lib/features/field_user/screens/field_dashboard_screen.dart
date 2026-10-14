// lib/features/field_user/screens/field_dashboard_screen.dart
// ─────────────────────────────────────────────────────────────
// Landing screen for a logged-in field user.
// Shows simple stats (total / this week) and the user's own
// submission history. The daily report form is opened via the
// floating action button.
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../models/submission_model.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/submission_provider.dart';
import '../../owner/projects/screens/submission_detail_screen.dart';

class FieldDashboardScreen extends ConsumerWidget {
  const FieldDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fieldUser = ref.watch(authProvider).fieldUser;

    if (fieldUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final subsAsync = ref.watch(userSubmissionsProvider(fieldUser.accessCode));
    final stats = ref.watch(fieldStatsProvider(fieldUser.accessCode));

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(userSubmissionsProvider(fieldUser.accessCode)),
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              backgroundColor: AppTheme.navyDark,
              foregroundColor: Colors.white,
              pinned: true,
              expandedHeight: 132,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: EdgeInsets.zero,
                background: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fieldUser.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 20,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(fieldUser.projectName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: Color(0xFF7A90B8), fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  onPressed: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),

            // ── Stats row ──────────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        icon: Icons.assignment_outlined,
                        value: stats.total.toString(),
                        label: 'Total Reports',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatCard(
                        icon: Icons.date_range_outlined,
                        value: stats.thisWeek.toString(),
                        label: 'This Week',
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Section title ──────────────────────────────
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('MY SUBMISSIONS',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.grayDark,
                        letterSpacing: 0.6)),
              ),
            ),

            // ── Submissions list ───────────────────────────
            subsAsync.when(
              loading: () => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: CircularProgressIndicator(color: AppTheme.navyMid),
                ),
              ),
              error: (e, _) => const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text('Could not load your submissions.',
                      style: TextStyle(color: AppTheme.error)),
                ),
              ),
              data: (subs) {
                if (subs.isEmpty) {
                  return const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _EmptyState(),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                          (context, i) => _SubmissionCard(submission: subs[i]),
                      childCount: subs.length,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoutes.fieldForm),
        backgroundColor: AppTheme.navyMid,
        icon: const Icon(Icons.add_a_photo_outlined, color: Colors.white),
        label: const Text('New Report',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const _StatCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.grayCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppTheme.navyMid),
          const SizedBox(height: 10),
          Text(value,
              style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppTheme.grayText)),
        ],
      ),
    );
  }
}

// ── Submission card ───────────────────────────────────────────
class _SubmissionCard extends StatelessWidget {
  final SubmissionModel submission;
  const _SubmissionCard({required this.submission});

  @override
  Widget build(BuildContext context) {
    final thumb = (submission.imageUrls != null &&
        submission.imageUrls!.isNotEmpty)
        ? submission.imageUrls!.first
        : null;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubmissionDetailScreen(submission: submission),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.grayCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.grayBorder, width: 0.5),
        ),
        child: Row(
          children: [
            // Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 56,
                height: 56,
                child: thumb != null
                    ? Image.network(thumb, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.grayBg,
                      child: const Icon(Icons.image_not_supported_outlined,
                          color: AppTheme.grayText, size: 22),
                    ))
                    : Container(
                  color: AppTheme.grayBg,
                  child: const Icon(Icons.description_outlined,
                      color: AppTheme.grayText, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    submission.siteName?.isNotEmpty == true
                        ? submission.siteName!
                        : 'Daily Report',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.navyDark),
                  ),
                  const SizedBox(height: 3),
                  Text(_formatDateTime(submission.submittedAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.grayText)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.grayText),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]} ${local.year}  $h:$m';
  }
}

// ── Empty state ───────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 56, color: AppTheme.grayText),
            SizedBox(height: 12),
            Text('No reports yet',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navyDark)),
            SizedBox(height: 6),
            Text(
              'Tap "New Report" to submit your first\ndaily field report.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppTheme.grayText),
            ),
          ],
        ),
      ),
    );
  }
}