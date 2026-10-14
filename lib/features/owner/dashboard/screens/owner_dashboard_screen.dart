// lib/features/owner/dashboard/screens/owner_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/project_user_provider.dart';
import '../../settings/screens/owner_settings_screen.dart';
import '../../../../models/project_user_model.dart';
import '../../../../models/project_model.dart';
import 'package:go_router/go_router.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  int _navIndex = 0; // 0=Home 1=Projects 2=Users 3=Settings
  int _projectFilter = 0; // All/Active/Closed

  @override
  Widget build(BuildContext context) {
    final owner = ref.watch(authProvider).owner;
    final projectState = ref.watch(projectsProvider);
    final statsAsync = ref.watch(dashboardStatsProvider);

    return Scaffold(
      backgroundColor: AppTheme.grayBg,
      appBar: AppBar(
        backgroundColor: AppTheme.navyDark,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.navyLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Center(
                child: Text(
                  (owner?.fullName ?? owner?.email ?? 'O')
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppTheme.navyAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Dashboard',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  owner?.fullName ?? owner?.email ?? '',
                  style: const TextStyle(
                    color: Color(0xFF7A90B8),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Material(
              color: AppTheme.navyLight,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _confirmLogout(context),
                child: const Padding(
                  padding:
                  EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.logout_rounded,
                          color: AppTheme.navyAccent, size: 18),
                      SizedBox(width: 6),
                      Text(
                        'Logout',
                        style: TextStyle(
                          color: AppTheme.navyAccent,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _navIndex,
        children: [
          _buildHomeBody(owner, statsAsync, projectState),
          _buildProjectsBody(projectState),
          _buildUsersBody(),
          _buildSettingsBody(),
        ],
      ),
      floatingActionButton: (_navIndex == 0 || _navIndex == 1)
          ? FloatingActionButton.extended(
        onPressed: () => _showCreateProjectSheet(context),
        backgroundColor: AppTheme.navyMid,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Project',
          style:
          TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _navIndex,
        onTap: (i) => setState(() => _navIndex = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_outlined),
            activeIcon: Icon(Icons.folder),
            label: 'Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_outlined),
            activeIcon: Icon(Icons.people),
            label: 'Users',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  // ── HOME: stats + banner + project list ───────────────────
  Widget _buildHomeBody(
      dynamic owner,
      AsyncValue<dynamic> statsAsync,
      dynamic projectState,
      ) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(projectsProvider);
        ref.invalidate(dashboardStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            statsAsync.when(
              loading: () => _StatsRowSkeleton(),
              error: (_, __) => const SizedBox(),
              data: (stats) => _StatsRow(stats: stats),
            ),
            const SizedBox(height: 20),
            if (owner?.isFree == true) _FreePlanBanner(onUpgrade: () {}),
            Row(
              children: [
                const Text('My Projects', style: AppTheme.sectionTitle),
                const Spacer(),
                _FilterTab(
                  label: 'All',
                  selected: _projectFilter == 0,
                  onTap: () => setState(() => _projectFilter = 0),
                ),
                const SizedBox(width: 6),
                _FilterTab(
                  label: 'Active',
                  selected: _projectFilter == 1,
                  onTap: () => setState(() => _projectFilter = 1),
                ),
                const SizedBox(width: 6),
                _FilterTab(
                  label: 'Closed',
                  selected: _projectFilter == 2,
                  onTap: () => setState(() => _projectFilter = 2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildProjectList(projectState),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── PROJECTS: just the filterable project list ────────────
  Widget _buildProjectsBody(dynamic projectState) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(projectsProvider);
        ref.invalidate(dashboardStatsProvider);
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('All Projects', style: AppTheme.sectionTitle),
                const Spacer(),
                _FilterTab(
                  label: 'All',
                  selected: _projectFilter == 0,
                  onTap: () => setState(() => _projectFilter = 0),
                ),
                const SizedBox(width: 6),
                _FilterTab(
                  label: 'Active',
                  selected: _projectFilter == 1,
                  onTap: () => setState(() => _projectFilter = 1),
                ),
                const SizedBox(width: 6),
                _FilterTab(
                  label: 'Closed',
                  selected: _projectFilter == 2,
                  onTap: () => setState(() => _projectFilter = 2),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _buildProjectList(projectState),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // Shared project-list renderer (used by Home and Projects).
  Widget _buildProjectList(dynamic projectState) {
    if (projectState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(40),
          child: CircularProgressIndicator(color: AppTheme.navyMid),
        ),
      );
    }
    if (projectState.projects.isEmpty) {
      return _EmptyProjects(
        onCreateTap: () => _showCreateProjectSheet(context),
      );
    }
    final projects = _filterProjects(projectState.projects);
    // Sort display oldest-first so Free Tier projects (first 2 created)
    // always appear at the top and Pro projects below — matches the
    // tier structure visually and is consistent with the DB trigger's
    // creation-order logic.
    final sorted = [...projects]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

    // Build index map using ALL projects (unfiltered) sorted by creation
    // date — so the tier index is always correct even when a filter hides
    // some projects.
    final allSorted = [...projectState.projects]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    final indexMap = {
      for (var i = 0; i < allSorted.length; i++) allSorted[i].id: i
    };

    final owner = ref.read(authProvider).owner;
    final isPro = owner?.isPro ?? false;
    final totalAllowed = owner?.totalProjectsAllowed ??
        AppConstants.freePlanMaxProjects;

    return Column(
      children: sorted.map((p) {
        final globalIndex = indexMap[p.id] ?? 0;
        final isFreeTierProject = globalIndex < AppConstants.freePlanMaxProjects;
        return _ProjectCard(
          project: p,
          isFreeTierProject: isFreeTierProject,
          ownerIsPro: isPro,
          onTap: () => context.push('/owner/project/${p.id}', extra: p),
          onToggleStatus: (isActive) {
            ref
                .read(projectsProvider.notifier)
                .toggleProjectStatus(p.id, isActive);
          },
        );
      }).toList(),
    );
  }

  // ── USERS: all users across all projects ──────────────────
  Widget _buildUsersBody() {
    final usersAsync = ref.watch(allUsersProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(allUsersProvider),
      child: usersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.navyMid),
        ),
        error: (_, __) => ListView(
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text('Could not load users.',
                  style: TextStyle(color: AppTheme.error)),
            ),
          ],
        ),
        data: (users) {
          if (users.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 120),
                Center(
                  child: Text('No users yet.',
                      style: TextStyle(color: AppTheme.grayText)),
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text('${users.length} USERS ACROSS ALL PROJECTS',
                  style: AppTheme.sectionTitle),
              const SizedBox(height: 10),
              ...users.map((u) => _AllUserCard(user: u)),
              const SizedBox(height: 80),
            ],
          );
        },
      ),
    );
  }

  // ── SETTINGS: placeholder (to be designed) ────────────────
  Widget _buildSettingsBody() {
    return const OwnerSettingsScreen();
  }

  List<ProjectModel> _filterProjects(List<ProjectModel> projects) {
    switch (_projectFilter) {
      case 1:
        return projects.where((p) => p.isActive).toList();
      case 2:
        return projects.where((p) => !p.isActive).toList();
      default:
        return projects;
    }
  }

  void _showCreateProjectSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CreateProjectSheet(
        onCreate: (name, desc) async {
          final success = await ref
              .read(projectsProvider.notifier)
              .createProject(name: name, description: desc);
          if (success && context.mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project created successfully!'),
                backgroundColor: AppTheme.success,
              ),
            );
            ref.invalidate(dashboardStatsProvider);
          }
        },
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 8),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: const Text(
          'Sign out?',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.navyDark,
          ),
        ),
        content: const Text(
          'You will be returned to the home screen.',
          style: TextStyle(
            fontSize: 13,
            height: 1.4,
            color: AppTheme.grayText,
          ),
        ),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: const BorderSide(color: AppTheme.grayBorder),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: AppTheme.grayDark),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    ref.read(authProvider.notifier).logout();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.navyDark,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Stats Row
class _StatsRow extends StatelessWidget {
  final Map<String, int> stats;
  const _StatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatCard(
              label: 'Active Projects',
              value: '${stats['active_projects'] ?? 0}',
              icon: Icons.folder_outlined,
            )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
              label: 'Total Users',
              value: '${stats['total_users'] ?? 0}',
              icon: Icons.people_outlined,
            )),
        const SizedBox(width: 10),
        Expanded(
            child: _StatCard(
              label: 'Today',
              value: '${stats['today_submissions'] ?? 0}',
              icon: Icons.assignment_outlined,
              valueColor: AppTheme.success,
            )),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color? valueColor;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.grayCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.grayBorder, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppTheme.grayText),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: valueColor ?? AppTheme.navyDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: AppTheme.grayText),
          ),
        ],
      ),
    );
  }
}

class _StatsRowSkeleton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(
          3,
              (i) => Expanded(
            child: Container(
              height: 80,
              margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
              decoration: BoxDecoration(
                color: AppTheme.grayBorder,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          )),
    );
  }
}

// Project Card
class _ProjectCard extends StatelessWidget {
  final ProjectModel project;
  final bool isFreeTierProject;
  final bool ownerIsPro;
  final VoidCallback onTap;
  final Function(bool) onToggleStatus;

  const _ProjectCard({
    required this.project,
    required this.isFreeTierProject,
    required this.ownerIsPro,
    required this.onTap,
    required this.onToggleStatus,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.grayCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: !isFreeTierProject && ownerIsPro
                ? AppTheme.navyAccent.withValues(alpha: 0.4)
                : AppTheme.grayBorder,
            width: 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    project.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.navyDark,
                    ),
                  ),
                ),
                // Tier badge — only show when owner is Pro so free
                // owners don't see a confusing "Free Tier" label on
                // every project.
                if (ownerIsPro) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isFreeTierProject
                          ? AppTheme.grayBorder.withValues(alpha: 0.5)
                          : AppTheme.navyAccent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      isFreeTierProject ? 'Free Tier' : 'Pro',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                        color: isFreeTierProject
                            ? AppTheme.grayDark
                            : AppTheme.navyAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                GestureDetector(
                  onTap: () => onToggleStatus(!project.isActive),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: project.isActive
                        ? AppTheme.activeBadge
                        : AppTheme.inactiveBadge,
                    child: Text(
                      project.isActive ? 'Active' : 'Closed',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: project.isActive
                            ? AppTheme.success
                            : AppTheme.error,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (project.description != null &&
                project.description!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                project.description!,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.grayText,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                _MetaChip(
                  icon: Icons.people_outline,
                  label: '${project.userCount ?? 0} users',
                ),
                const SizedBox(width: 8),
                _MetaChip(
                  icon: Icons.assignment_outlined,
                  label: '${project.submissionCount ?? 0} submissions',
                ),
                const Spacer(),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: AppTheme.grayText,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MetaChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: AppTheme.grayText),
        const SizedBox(width: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppTheme.grayText),
        ),
      ],
    );
  }
}

// Empty state
class _EmptyProjects extends StatelessWidget {
  final VoidCallback onCreateTap;
  const _EmptyProjects({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 60),
        child: Column(
          children: [
            const Icon(
              Icons.folder_open,
              size: 56,
              color: AppTheme.grayBorder,
            ),
            const SizedBox(height: 16),
            const Text(
              'No projects yet',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppTheme.grayDark,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first project to get started.',
              style: TextStyle(fontSize: 13, color: AppTheme.grayText),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onCreateTap,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create Project'),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(160, 44),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Free plan banner
class _FreePlanBanner extends StatelessWidget {
  final VoidCallback onUpgrade;
  const _FreePlanBanner({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.warningLight,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.info_outline, size: 18, color: AppTheme.warning),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Free plan: 2 projects, 5 users per project max.',
              style: TextStyle(fontSize: 12, color: AppTheme.warning),
            ),
          ),
          GestureDetector(
            onTap: onUpgrade,
            child: const Text(
              'Upgrade →',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppTheme.warning,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Create project sheet
class _CreateProjectSheet extends StatefulWidget {
  final Function(String name, String? description) onCreate;
  const _CreateProjectSheet({required this.onCreate});

  @override
  State<_CreateProjectSheet> createState() => _CreateProjectSheetState();
}

class _CreateProjectSheetState extends State<_CreateProjectSheet> {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
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
            const Text(
              'New Project',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.navyDark,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Project name *',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.grayDark,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'e.g. Site Inspection Q3',
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Project name required'
                  : null,
            ),
            const SizedBox(height: 16),
            const Text(
              'Description (optional)',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppTheme.grayDark,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Brief description of this project...',
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () async {
                  if (!_formKey.currentState!.validate()) return;
                  setState(() => _loading = true);
                  try {
                    await widget.onCreate(
                      _nameCtrl.text.trim(),
                      _descCtrl.text.trim().isEmpty
                          ? null
                          : _descCtrl.text.trim(),
                    );
                  } catch (e) {
                    if (context.mounted) {
                      await UpgradeDialog.show(
                        context,
                        message: e
                            .toString()
                            .replaceFirst('Exception: ', ''),
                      );
                    }
                    // Close the form sheet after the dialog is dismissed
                    if (context.mounted) Navigator.pop(context);
                  } finally {
                    if (mounted) setState(() => _loading = false);
                  }
                },
                child: _loading
                    ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2,
                  ),
                )
                    : const Text('Create Project'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Filter tab
class _FilterTab extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? AppTheme.navyMid : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.navyMid : AppTheme.grayBorder,
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppTheme.grayText,
          ),
        ),
      ),
    );
  }
}


// ── User card for the Users tab (shows project + access code) ─
class _AllUserCard extends StatelessWidget {
  final ProjectUserModel user;
  const _AllUserCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.grayCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grayBorder, width: 0.5),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: user.isActive
                ? AppTheme.successLight
                : AppTheme.errorLight,
            child: Text(
              user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
              style: TextStyle(
                color: user.isActive ? AppTheme.success : AppTheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.navyDark)),
                const SizedBox(height: 2),
                Text(
                  user.projectName.isNotEmpty
                      ? user.projectName
                      : 'Unknown project',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppTheme.grayText),
                ),
              ],
            ),
          ),
          Container(
            padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: user.isActive
                ? AppTheme.activeBadge
                : AppTheme.inactiveBadge,
            child: Text(
              user.isActive ? 'Active' : 'Removed',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: user.isActive ? AppTheme.success : AppTheme.error,
              ),
            ),
          ),
        ],
      ),
    );
  }
}