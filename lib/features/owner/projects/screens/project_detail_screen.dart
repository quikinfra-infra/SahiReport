// lib/features/owner/projects/screens/project_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../models/project_model.dart';
import '../../../../models/project_user_model.dart';
import '../../../../models/submission_model.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/project_user_provider.dart';
import '../../../../providers/submission_provider.dart';
import 'submission_detail_screen.dart';

class ProjectDetailScreen extends ConsumerStatefulWidget {
  final ProjectModel project;
  const ProjectDetailScreen({super.key, required this.project});

  @override
  ConsumerState<ProjectDetailScreen> createState() =>
      _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends ConsumerState<ProjectDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersState = ref.watch(projectUsersProvider(widget.project.id));

    // Watch live project state so closing updates UI immediately
    final currentProject = ref.watch(projectsProvider).projects.firstWhere(
          (p) => p.id == widget.project.id,
      orElse: () => widget.project,
    );

    // Count active users to check against the 5-seat limit
    final activeUserCount = usersState.users.where((u) => u.isActive).length;
    final canAddMoreUsers = currentProject.isActive &&
        activeUserCount < AppConstants.freePlanMaxUsersPerProject;

    ref.listen(projectUsersProvider(widget.project.id), (_, next) {
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: AppTheme.error),
        );
        ref.read(projectUsersProvider(widget.project.id).notifier).clearError();
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            backgroundColor: AppTheme.navyDark,
            foregroundColor: Colors.white,
            pinned: true,
            expandedHeight: 248,
            collapsedHeight: kToolbarHeight,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: EdgeInsets.zero,
              background: SafeArea(
                bottom: false,
                child: Container(
                  color: AppTheme.navyDark,
                  padding: const EdgeInsets.fromLTRB(16, 52, 16, 56),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Status Badges + Close Project Button Row ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: currentProject.isActive
                                      ? AppTheme.successLight
                                      : AppTheme.errorLight,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  currentProject.isActive
                                      ? 'Active'
                                      : 'Closed (Read-Only)',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: currentProject.isActive
                                        ? AppTheme.success
                                        : AppTheme.error,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: currentProject.isPro
                                      ? Colors.blue.shade50
                                      : Colors.white.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  currentProject.isPro ? 'Pro' : 'Free Tier',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: currentProject.isPro
                                        ? Colors.blue.shade700
                                        : const Color(0xFF8BA3CB),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (currentProject.isActive)
                            OutlinedButton.icon(
                              onPressed: () => _showCloseProjectDialog(
                                  context, currentProject),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                    color:
                                    AppTheme.error.withValues(alpha: 0.85)),
                                backgroundColor:
                                AppTheme.error.withValues(alpha: 0.25),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: const Icon(Icons.lock_outline,
                                  size: 14, color: Colors.white),
                              label: const Text(
                                'Close Project',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        currentProject.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          height: 1.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (currentProject.description != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          currentProject.description!,
                          style: const TextStyle(
                              color: Color(0xFF7A90B8), fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: AppTheme.navyAccent,
              labelColor: AppTheme.navyAccent,
              unselectedLabelColor: const Color(0xFF4A5A7A),
              labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
              tabs: [
                Tab(
                    text:
                    'Users ($activeUserCount/${AppConstants.freePlanMaxUsersPerProject})'),
                const Tab(text: 'Submissions'),
              ],
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _UsersTab(project: currentProject),
            _SubmissionsTab(project: currentProject),
          ],
        ),
      ),
      floatingActionButton: canAddMoreUsers
          ? FloatingActionButton.extended(
        onPressed: () => _showAddUserSheet(context),
        backgroundColor: AppTheme.navyMid,
        icon: const Icon(Icons.person_add_outlined, color: Colors.white),
        label: const Text(
          'Add User',
          style:
          TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      )
          : null,
    );
  }

  void _showCloseProjectDialog(BuildContext context, ProjectModel project) {
    bool isConfirmed = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: AppTheme.error, size: 26),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Close Project Permanently?',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyDark,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You are about to permanently close "${project.name}". Please review what happens next:',
                    style: const TextStyle(
                        fontSize: 13, color: AppTheme.grayDark, height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  _buildBulletPoint(
                      'Once closed, this project cannot be made active again.'),
                  _buildBulletPoint(
                      'Field users will no longer be able to log in or submit new reports.'),
                  _buildBulletPoint(
                      'All historical data, submissions, photos, and exports remain 100% accessible to you.'),
                  _buildBulletPoint(
                      'Closing frees up your active project slot so you can create a new project on your current subscription.'),
                  const SizedBox(height: 16),
                  InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: isSubmitting
                        ? null
                        : () =>
                        setDialogState(() => isConfirmed = !isConfirmed),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppTheme.grayBg,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isConfirmed
                              ? AppTheme.navyMid
                              : AppTheme.grayBorder,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: isConfirmed,
                              activeColor: AppTheme.navyMid,
                              onChanged: isSubmitting
                                  ? null
                                  : (val) => setDialogState(
                                      () => isConfirmed = val ?? false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'I understand that once closed, this project cannot be made active again.',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.navyDark,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed:
                  isSubmitting ? null : () => Navigator.pop(dialogContext),
                  child: const Text('Cancel',
                      style: TextStyle(color: AppTheme.grayText)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.error,
                    disabledBackgroundColor: Colors.grey.shade300,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: (!isConfirmed || isSubmitting)
                      ? null
                      : () async {
                    setDialogState(() => isSubmitting = true);
                    final success = await ref
                        .read(projectsProvider.notifier)
                        .toggleProjectStatus(project.id, false);
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                    if (success && mounted) {
                      ref.invalidate(dashboardStatsProvider);
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Project closed permanently. Historical data remains accessible.'),
                          backgroundColor: AppTheme.navyDark,
                        ),
                      );
                    } else if (mounted) {
                      ScaffoldMessenger.of(this.context).showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Failed to close project. Please try again.'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  },
                  child: isSubmitting
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                      : const Text('Close Permanently'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildBulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• ',
              style: TextStyle(
                  fontWeight: FontWeight.bold, color: AppTheme.navyDark)),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12, color: AppTheme.grayText, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  void _showAddUserSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddUserSheet(
        onAdd: (name) async {
          final user = await ref
              .read(projectUsersProvider(widget.project.id).notifier)
              .createUser(name);
          if (user != null && context.mounted) {
            ref.invalidate(allUsersProvider);
            ref.invalidate(dashboardStatsProvider);
            await ref.read(projectsProvider.notifier).loadProjects();
            if (context.mounted) {
              Navigator.pop(context);
              _showCodeDialog(context, user);
            }
          }
        },
      ),
    );
  }

  void _showCodeDialog(BuildContext context, ProjectUserModel user) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CodeGeneratedDialog(user: user),
    );
  }
}

// ── Users Tab ─────────────────────────────────────────────────
class _UsersTab extends ConsumerWidget {
  final ProjectModel project;
  const _UsersTab({required this.project});

  Future<bool> _confirmPermanentUserRemoval(
      BuildContext context,
      String userName,
      ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: AppTheme.error, size: 22),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Remove User Access?',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyDark,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'You can\'t activate the user again.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Removing $userName will permanently revoke their access code (Field User seat) and free up the slot for a new person.\n\nAll past reports and records remain 100% accessible in your database.',
              style: const TextStyle(
                fontSize: 13,
                color: AppTheme.grayDark,
                height: 1.45,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Remove Permanently'),
          ),
        ],
      ),
    );
    return result == true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersState = ref.watch(projectUsersProvider(project.id));

    if (usersState.isLoading) {
      return const Center(
          child: CircularProgressIndicator(color: AppTheme.navyMid));
    }

    if (usersState.users.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.people_outline,
                  size: 56, color: AppTheme.grayBorder),
              const SizedBox(height: 16),
              const Text('No users yet',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.grayDark)),
              const SizedBox(height: 8),
              Text(
                  project.isActive
                      ? 'Tap "Add User" to create a field worker\nand generate their access code.'
                      : 'This project is closed. No new users can be added.',
                  textAlign: TextAlign.center,
                  style:
                  const TextStyle(fontSize: 13, color: AppTheme.grayText)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(projectUsersProvider(project.id).notifier).loadUsers(),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: usersState.users.length + (project.isActive ? 0 : 1),
        itemBuilder: (context, index) {
          if (!project.isActive && index == 0) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.lock_clock_outlined,
                      size: 18, color: Colors.amber.shade900),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This project is closed (Read-Only). Field access is disabled, but all historical records remain available.',
                      style:
                      TextStyle(fontSize: 12, color: Colors.amber.shade900),
                    ),
                  ),
                ],
              ),
            );
          }

          final userIndex = project.isActive ? index : index - 1;
          final user = usersState.users[userIndex];
          return _UserCard(
            user: user,
            isProjectActive: project.isActive,
            onRemovePermanently: () async {
              if (!project.isActive || !user.isActive) return;
              final confirmed =
              await _confirmPermanentUserRemoval(context, user.name);
              if (!confirmed) return;

              await ref
                  .read(projectUsersProvider(project.id).notifier)
                  .toggleUserStatus(user.id, false);
              ref.invalidate(allUsersProvider);
              ref.invalidate(dashboardStatsProvider);
              await ref.read(projectsProvider.notifier).loadProjects();
            },
            onShowCode: () {
              if (!user.isActive) return;
              showDialog(
                context: context,
                builder: (_) => _CodeGeneratedDialog(user: user),
              );
            },
          );
        },
      ),
    );
  }
}

// ── User Card (Two Pills: Active + Remove) ────────────────────
class _UserCard extends StatelessWidget {
  final ProjectUserModel user;
  final bool isProjectActive;
  final VoidCallback onRemovePermanently;
  final VoidCallback onShowCode;

  const _UserCard({
    required this.user,
    required this.isProjectActive,
    required this.onRemovePermanently,
    required this.onShowCode,
  });

  @override
  Widget build(BuildContext context) {
    final initials = user.name.length >= 2
        ? user.name.substring(0, 2).toUpperCase()
        : user.name.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.grayCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grayBorder, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color:
              user.isActive ? AppTheme.successLight : AppTheme.errorLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: user.isActive ? AppTheme.success : AppTheme.error,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: user.isActive
                        ? AppTheme.navyDark
                        : AppTheme.grayText,
                  ),
                ),
                const SizedBox(height: 3),
                GestureDetector(
                  onTap: user.isActive ? onShowCode : null,
                  child: Row(
                    children: [
                      Text(
                        user.accessCode.isNotEmpty
                            ? user.accessCode
                            : 'Tap to view code',
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: user.isActive
                              ? AppTheme.navyMid
                              : AppTheme.grayText,
                          fontWeight: FontWeight.w600,
                          decoration: user.isActive
                              ? null
                              : TextDecoration.lineThrough,
                          letterSpacing: 1,
                        ),
                      ),
                      if (user.isActive) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.copy,
                            size: 12, color: AppTheme.navyMid),
                      ],
                    ],
                  ),
                ),
                if (user.lastLoginAt != null)
                  Text(
                    'Last login: ${user.lastLoginAt!.day}/${user.lastLoginAt!.month}/${user.lastLoginAt!.year}',
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.grayText),
                  ),
              ],
            ),
          ),
          if (user.isActive) ...[
            // Pill 1: Status Pill (Active)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: AppTheme.activeBadge,
              child: const Text(
                'Active',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.success,
                ),
              ),
            ),
            if (isProjectActive) ...[
              const SizedBox(width: 8),
              // Pill 2: Action Pill (Remove)
              GestureDetector(
                onTap: onRemovePermanently,
                child: Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.errorLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.error.withValues(alpha: 0.3),
                    ),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_remove_outlined,
                          size: 11, color: AppTheme.error),
                      SizedBox(width: 4),
                      Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ] else ...[
            // Permanently Removed Badge (Locked)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: AppTheme.inactiveBadge,
              child: const Text(
                'Removed',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Submissions Tab ───────────────────────────────────────────
class _SubmissionsTab extends ConsumerWidget {
  final ProjectModel project;
  const _SubmissionsTab({required this.project});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final submissionsAsync = ref.watch(submissionsProvider(project.id));

    return submissionsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.navyMid),
      ),
      error: (e, _) => Center(
        child: Text('Error: $e', style: const TextStyle(color: AppTheme.error)),
      ),
      data: (submissions) {
        if (submissions.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_outlined,
                      size: 56, color: AppTheme.grayBorder),
                  SizedBox(height: 16),
                  Text('No submissions yet',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.grayDark)),
                  SizedBox(height: 8),
                  Text('Field user submissions will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppTheme.grayText)),
                ],
              ),
            ),
          );
        }

        return RefreshIndicator(
          onRefresh: () async =>
              ref.invalidate(submissionsProvider(project.id)),
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: submissions.length,
            itemBuilder: (context, index) {
              return _SubmissionCard(
                submission: submissions[index],
                project: project,
              );
            },
          ),
        );
      },
    );
  }
}

// ── Submission Card ───────────────────────────────────────────
class _SubmissionCard extends StatelessWidget {
  final SubmissionModel submission;
  final ProjectModel project;
  const _SubmissionCard({
    required this.submission,
    required this.project,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => SubmissionDetailScreen(
            submission: submission,
            project: project,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.grayCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.grayBorder, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(submission.userName ?? 'Field User',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.navyDark)),
                const Spacer(),
                Text(_formatTime(submission.submittedAt),
                    style: const TextStyle(
                        fontSize: 11, color: AppTheme.grayText)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_forward_ios,
                    size: 11, color: AppTheme.grayText),
              ],
            ),
            if (submission.siteName != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.location_on_outlined,
                      size: 13, color: AppTheme.grayText),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(submission.siteName!,
                        style: const TextStyle(
                            fontSize: 12, color: AppTheme.grayText)),
                  ),
                ],
              ),
            ],
            if (submission.formText != null) ...[
              const SizedBox(height: 6),
              Text(submission.formText!,
                  style:
                  const TextStyle(fontSize: 13, color: AppTheme.navyDark),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ],
            if (submission.imageUrls != null &&
                submission.imageUrls!.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: submission.imageUrls!.length,
                  itemBuilder: (context, i) => Container(
                    width: 56,
                    height: 56,
                    margin: const EdgeInsets.only(right: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      border:
                      Border.all(color: AppTheme.grayBorder, width: 0.5),
                      image: DecorationImage(
                        image: NetworkImage(submission.imageUrls![i]),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.gps_fixed, size: 12, color: AppTheme.success),
                const SizedBox(width: 4),
                Text(
                    '${submission.latitude.toStringAsFixed(4)}° N, '
                        '${submission.longitude.toStringAsFixed(4)}° E',
                    style:
                    const TextStyle(fontSize: 11, color: AppTheme.success)),
                const Spacer(),
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: AppTheme.activeBadge,
                  child: const Text('Verified',
                      style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.success,
                          fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

// ── Add User Sheet ────────────────────────────────────────────
class _AddUserSheet extends StatefulWidget {
  final Function(String name) onAdd;
  const _AddUserSheet({required this.onAdd});

  @override
  State<_AddUserSheet> createState() => _AddUserSheetState();
}

class _AddUserSheetState extends State<_AddUserSheet> {
  final _nameCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.grayBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Add Field User',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyDark)),
            const SizedBox(height: 6),
            const Text('An access code will be auto-generated for this user.',
                style: TextStyle(fontSize: 12, color: AppTheme.grayText)),
            const SizedBox(height: 20),
            const Text('Full name *',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grayDark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                hintText: 'e.g. Arjun Mehta',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
              v == null || v.trim().isEmpty ? 'Name is required' : null,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _loading
                    ? null
                    : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    await widget.onAdd(_nameCtrl.text.trim());
                  } catch (e) {
                    if (context.mounted) {
                      await UpgradeDialog.show(
                        context,
                        message: e
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      );
                    }
                    if (context.mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                icon: _loading
                    ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.auto_awesome, size: 18),
                label: Text(_loading
                    ? 'Generating code...'
                    : 'Create User & Generate Code'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Code Generated Dialog ─────────────────────────────────────
class _CodeGeneratedDialog extends StatelessWidget {
  final ProjectUserModel user;
  const _CodeGeneratedDialog({required this.user});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.all(24),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.successLight,
              borderRadius: BorderRadius.circular(28),
            ),
            child: const Icon(Icons.check, color: AppTheme.success, size: 28),
          ),
          const SizedBox(height: 16),
          const Text('User Created!',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyDark)),
          const SizedBox(height: 6),
          Text('${user.name} has been added to the project.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.grayText)),
          const SizedBox(height: 20),
          const Text('ACCESS CODE',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.grayText,
                  letterSpacing: 1.5)),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppTheme.navyDark,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(user.accessCode,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyAccent,
                  letterSpacing: 6,
                  fontFamily: 'monospace',
                )),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: user.accessCode));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Code copied to clipboard!'),
                  backgroundColor: AppTheme.success,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.successLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.copy, size: 16, color: AppTheme.success),
                  SizedBox(width: 8),
                  Text('Copy code',
                      style: TextStyle(
                          color: AppTheme.success,
                          fontWeight: FontWeight.w600,
                          fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
              'Share this code with the field worker.\nThey will use it to sign in.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppTheme.grayText)),
        ],
      ),
      actions: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Done'),
          ),
        ),
      ],
    );
  }
}