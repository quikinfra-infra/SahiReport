// lib/features/owner/dashboard/screens/owner_dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/widgets/upgrade_dialog.dart';
import '../../../../providers/auth_provider.dart';
import '../../../../providers/project_provider.dart';
import '../../../../providers/project_user_provider.dart';
import '../../../../models/project_model.dart';
import '../../../../models/project_user_model.dart';

class OwnerDashboardScreen extends ConsumerStatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  ConsumerState<OwnerDashboardScreen> createState() =>
      _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends ConsumerState<OwnerDashboardScreen> {
  int _currentIndex = 0;
  String _selectedFilter = 'All';
  String _projectSearchQuery = '';

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 1:
        return 'Projects';
      case 2:
        return 'Field Users';
      case 3:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final rawName = authState.owner?.fullName?.trim() ?? '';
    final ownerName = rawName.isNotEmpty
        ? rawName
        : (authState.owner?.email?.split('@').first ?? 'Owner');
    final initial = ownerName.isNotEmpty ? ownerName[0].toUpperCase() : 'O';

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F9),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(64),
        child: Container(
          color: AppTheme.navyDark,
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 64,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => context.push(AppRoutes.profileEdit),
                      behavior: HitTestBehavior.opaque,
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: const Color(0xFF2B3F6C),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              initial,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  ownerName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _getAppBarTitle(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF8BA3CB),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () => ref.read(authProvider.notifier).logout(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2B3F6C),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(0, 36),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      elevation: 0,
                    ),
                    icon: const Icon(Icons.logout,
                        size: 15, color: Color(0xFF8BA3CB)),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: Color(0xFF8BA3CB),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildHomeTab(),
          _buildProjectsTab(),
          _buildUsersTab(),
          _buildSettingsTab(),
        ],
      ),
      floatingActionButton: (_currentIndex == 0 || _currentIndex == 1)
          ? FloatingActionButton.extended(
        onPressed: () => _showCreateProjectSheet(context),
        backgroundColor: AppTheme.navyDark,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'New Project',
          style:
          TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
          if (index == 2) {
            ref.invalidate(allUsersProvider);
          }
        },
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppTheme.navyDark,
        selectedItemColor: Colors.white,
        unselectedItemColor: const Color(0xFF7A90B8),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Home'),
          BottomNavigationBarItem(
              icon: Icon(Icons.folder_outlined), label: 'Projects'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_outline), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }

  // ── TAB 0: HOME DASHBOARD ───────────────────────────────────
  Widget _buildHomeTab() {
    final statsAsync = ref.watch(dashboardStatsProvider);
    final projectsState = ref.watch(projectsProvider);

    final activeProjects =
        statsAsync.value?['active_projects']?.toString() ?? '0';
    final totalUsers = statsAsync.value?['total_users']?.toString() ?? '0';
    final todaySubmissions =
        statsAsync.value?['today_submissions']?.toString() ?? '0';

    List<ProjectModel> filteredProjects = projectsState.projects;
    if (_selectedFilter == 'Active') {
      filteredProjects = filteredProjects.where((p) => p.isActive).toList();
    } else if (_selectedFilter == 'Closed') {
      filteredProjects = filteredProjects.where((p) => !p.isActive).toList();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(dashboardStatsProvider);
        ref.invalidate(allUsersProvider);
        await ref.read(projectsProvider.notifier).loadProjects();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Equal-height Stat Cards
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _buildStatCard(
                      Icons.folder_outlined,
                      activeProjects,
                      'Active\nProjects',
                      onTap: () => setState(() {
                        _selectedFilter = 'Active';
                        _currentIndex = 1;
                      }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.people_outline,
                      totalUsers,
                      'Total\nUsers',
                      onTap: () => setState(() => _currentIndex = 2),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildStatCard(
                      Icons.assignment_outlined,
                      todaySubmissions,
                      'Today\nReports',
                      isZero: todaySubmissions == '0',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // My Projects Header & Filter Chips
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Projects',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B3F6C),
                  ),
                ),
                _buildFilterChips(),
              ],
            ),
            const SizedBox(height: 16),

            // Project List
            _buildProjectsList(projectsState, filteredProjects),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── TAB 1: PROJECTS DIRECTORY ───────────────────────────────
  Widget _buildProjectsTab() {
    final projectsState = ref.watch(projectsProvider);

    List<ProjectModel> filteredProjects = projectsState.projects;
    if (_selectedFilter == 'Active') {
      filteredProjects = filteredProjects.where((p) => p.isActive).toList();
    } else if (_selectedFilter == 'Closed') {
      filteredProjects = filteredProjects.where((p) => !p.isActive).toList();
    }

    if (_projectSearchQuery.trim().isNotEmpty) {
      final q = _projectSearchQuery.trim().toLowerCase();
      filteredProjects = filteredProjects
          .where((p) =>
      p.name.toLowerCase().contains(q) ||
          (p.description?.toLowerCase().contains(q) ?? false))
          .toList();
    }

    return RefreshIndicator(
      onRefresh: () async =>
          ref.read(projectsProvider.notifier).loadProjects(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              onChanged: (val) => setState(() => _projectSearchQuery = val),
              decoration: InputDecoration(
                hintText: 'Search projects by name or location...',
                prefixIcon: const Icon(Icons.search, color: Color(0xFF7A90B8)),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${filteredProjects.length} Project${filteredProjects.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2B3F6C),
                  ),
                ),
                _buildFilterChips(),
              ],
            ),
            const SizedBox(height: 16),
            _buildProjectsList(projectsState, filteredProjects),
            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  // ── TAB 2: USERS GROUPED BY PROJECT ─────────────────────────
  Widget _buildUsersTab() {
    final allUsersAsync = ref.watch(allUsersProvider);
    final projectsState = ref.watch(projectsProvider);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(allUsersProvider);
        await ref.read(projectsProvider.notifier).loadProjects();
      },
      child: allUsersAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppTheme.navyDark),
        ),
        error: (e, _) => Center(
          child: Text('Failed to load users: $e',
              style: const TextStyle(color: AppTheme.error)),
        ),
        data: (users) {
          if (users.isEmpty) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(40),
              children: const [
                SizedBox(height: 60),
                Icon(Icons.people_outline,
                    size: 56, color: Color(0xFFCBD5E1)),
                SizedBox(height: 16),
                Text(
                  'No field users yet',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.navyDark,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Open any active project to add field workers and generate their access codes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: Color(0xFF7A90B8)),
                ),
              ],
            );
          }

          // Group users by projectId
          final Map<String, List<ProjectUserModel>> grouped = {};
          for (final u in users) {
            grouped.putIfAbsent(u.projectId, () => []).add(u);
          }

          return ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            itemCount: grouped.keys.length,
            itemBuilder: (context, index) {
              final projectId = grouped.keys.elementAt(index);
              final projectUsers = grouped[projectId]!;
              final firstProjectName = projectUsers.first.projectName;
              final projectName = (firstProjectName != null &&
                  firstProjectName.isNotEmpty)
                  ? firstProjectName
                  : 'Project';

              // Find matching ProjectModel if loaded so owner can tap into it
              final matchingProject = projectsState.projects
                  .where((p) => p.id == projectId)
                  .firstOrNull;

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Project Group Header
                    InkWell(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(12)),
                      onTap: matchingProject != null
                          ? () => context.push(
                          '/owner/project/${matchingProject.id}',
                          extra: matchingProject)
                          : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12)),
                          border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.folder_outlined,
                                size: 18, color: AppTheme.navyDark),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                projectName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.navyDark,
                                ),
                              ),
                            ),
                            Text(
                              '${projectUsers.where((u) => u.isActive).length}/5 Active',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF7A90B8),
                              ),
                            ),
                            if (matchingProject != null) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.chevron_right,
                                  size: 18, color: Color(0xFF7A90B8)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    // Users inside this project
                    ...projectUsers.map((user) {
                      final initials = user.name.length >= 2
                          ? user.name.substring(0, 2).toUpperCase()
                          : user.name.toUpperCase();
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: user.isActive
                                    ? AppTheme.successLight
                                    : AppTheme.errorLight,
                                borderRadius: BorderRadius.circular(18),
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: user.isActive
                                      ? AppTheme.success
                                      : AppTheme.error,
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
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppTheme.navyDark,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  GestureDetector(
                                    onTap: () {
                                      Clipboard.setData(ClipboardData(
                                          text: user.accessCode));
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'Copied code for ${user.name}'),
                                          backgroundColor: AppTheme.success,
                                          duration:
                                          const Duration(seconds: 2),
                                        ),
                                      );
                                    },
                                    child: Row(
                                      children: [
                                        Text(
                                          user.accessCode,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            fontFamily: 'monospace',
                                            color: AppTheme.navyMid,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                        const SizedBox(width: 4),
                                        const Icon(Icons.copy,
                                            size: 12, color: AppTheme.navyMid),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: user.isActive
                                  ? AppTheme.activeBadge
                                  : AppTheme.inactiveBadge,
                              child: Text(
                                user.isActive ? 'Active' : 'Removed',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: user.isActive
                                      ? AppTheme.success
                                      : AppTheme.error,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ── TAB 3: SETTINGS & LEGAL DOCS ────────────────────────────
  Widget _buildSettingsTab() {
    final owner = ref.watch(authProvider).owner;
    final fullName = owner?.fullName ?? '';
    final avatarLetter =
    fullName.isNotEmpty ? fullName[0].toUpperCase() : 'O';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Account Summary Card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.navyDark,
                child: Text(
                  avatarLetter,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fullName.isNotEmpty ? fullName : 'Owner',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.navyDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      owner?.email ?? '',
                      style: const TextStyle(
                          fontSize: 12, color: Color(0xFF7A90B8)),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () => context.push(AppRoutes.profileEdit),
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        const Text(
          'SUBSCRIPTION & ACCOUNT',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A90B8),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.workspace_premium_outlined,
          title: 'Add Pro Project Slots',
          subtitle: '2 active projects free · Purchase extra yearly slots',
          onTap: () => context.push(AppRoutes.billing),
        ),
        _buildSettingsTile(
          icon: Icons.person_outline,
          title: 'Profile & Account Settings',
          subtitle: 'Update name, company details, or password',
          onTap: () => context.push(AppRoutes.profileEdit),
        ),

        const SizedBox(height: 20),
        const Text(
          'LEGAL & INFORMATION',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Color(0xFF7A90B8),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        _buildSettingsTile(
          icon: Icons.info_outline,
          title: 'About Us',
          subtitle: 'Learn about SahiReport and our mission',
          onTap: () => _showLegalDocSheet(
            context,
            title: 'About SahiReport',
            content:
            'SahiReport is a field reporting and Daily Progress Report (DPR) platform designed for construction, infrastructure, and field engineering teams.\n\n'
                '• Verified GPS & Timestamped Site Photos\n'
                '• Instant Field-to-Office Daily Progress Reports\n'
                '• Tamper-proof PDF & Excel Exports\n'
                '• Simple Access Code Login for Site Supervisors\n\n'
                'Version 1.0.0',
          ),
        ),
        _buildSettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: 'Privacy Policy',
          subtitle: 'How we protect your project and location data',
          onTap: () => _showLegalDocSheet(
            context,
            title: 'Privacy Policy',
            content:
            '1. Data Collection\n'
                'SahiReport collects account information (name, email, phone), project records, and GPS-tagged site photographs submitted by authorized field users.\n\n'
                '2. Location & Camera Usage\n'
                'Location coordinates and timestamps are captured strictly at the time of report submission to verify site authenticity.\n\n'
                '3. Data Ownership & Retention\n'
                'All project data, photos, and reports belong solely to the Project Owner. Closed projects remain archived in read-only mode so your historical records and exports remain accessible.\n\n'
                '4. Security\n'
                'All data is encrypted in transit and at rest. We never sell your project or personal data to third parties.',
          ),
        ),
        _buildSettingsTile(
          icon: Icons.description_outlined,
          title: 'Terms & Conditions',
          subtitle: 'Subscription terms, project slots, and usage policies',
          onTap: () => _showLegalDocSheet(
            context,
            title: 'Terms & Conditions',
            content:
            '1. Free & Paid Project Slots\n'
                'Every owner receives 2 active Free Tier projects with up to 5 active field user seats per project. Additional active projects require an annual Pro Project slot.\n\n'
                '2. Closing Projects & Slot Reuse\n'
                'Closing a project permanently locks it in Read-Only mode (preventing new field submissions while preserving full historical export access) and immediately frees up the active project slot for reuse during your active subscription year.\n\n'
                '3. Acceptable Use\n'
                'Account owners are responsible for managing field user access codes and revoking access when personnel leave a project.',
          ),
        ),

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton.icon(
            onPressed: () => ref.read(authProvider.notifier).logout(),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.error),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 40),
      ],
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFFF4F6F9),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: AppTheme.navyDark, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppTheme.navyDark,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF7A90B8)),
        ),
        trailing: const Icon(Icons.chevron_right,
            color: Color(0xFF7A90B8), size: 20),
      ),
    );
  }

  void _showLegalDocSheet(BuildContext context,
      {required String title, required String content}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.65,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.navyDark,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),
              Expanded(
                child: SingleChildScrollView(
                  controller: controller,
                  child: Text(
                    content,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.6,
                      color: AppTheme.grayDark,
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

  // ── SHARED HELPERS ──────────────────────────────────────────
  Widget _buildFilterChips() {
    return Row(
      children: ['All', 'Active', 'Closed'].map((filter) {
        final isSelected = _selectedFilter == filter;
        return Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: ChoiceChip(
            label: Text(filter),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => setState(() => _selectedFilter = filter),
            backgroundColor: Colors.white,
            selectedColor: AppTheme.navyDark,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : const Color(0xFF7A90B8),
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: BorderSide(
                color: isSelected ? AppTheme.navyDark : Colors.grey.shade300,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProjectsList(
      ProjectsState projectsState, List<ProjectModel> filteredProjects) {
    if (projectsState.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: CircularProgressIndicator(),
        ),
      );
    }
    if (projectsState.error != null && projectsState.projects.isEmpty) {
      return Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text(projectsState.error!,
              style: const TextStyle(color: Colors.red)),
        ),
      );
    }
    if (filteredProjects.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32.0),
          child: Text('No projects found.',
              style: TextStyle(color: Color(0xFF7A90B8))),
        ),
      );
    }
    return Column(
      children:
      filteredProjects.map((project) => _buildProjectCard(project)).toList(),
    );
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
        onCreate: (name, description) async {
          final created = await ref
              .read(projectsProvider.notifier)
              .createProject(name: name, description: description);
          if (created && context.mounted) {
            ref.invalidate(dashboardStatsProvider);
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Project created successfully!'),
                backgroundColor: AppTheme.success,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildStatCard(IconData icon, String count, String label,
      {bool isZero = false, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: const Color(0xFF7A90B8), size: 24),
            const SizedBox(height: 12),
            Text(
              count,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isZero ? Colors.green.shade700 : AppTheme.navyDark,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF7A90B8), height: 1.3),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectCard(ProjectModel project) {
    final title = project.name;
    final isPro = project.isPro;
    final tier = isPro ? 'Pro' : 'Free Tier';
    final status = project.isActive ? 'Active' : 'Closed';
    final users = '${project.userCount ?? 0} users';
    final submissions = '${project.submissionCount ?? 0} submissions';

    return GestureDetector(
      onTap: () {
        context.push('/owner/project/${project.id}', extra: project);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyDark),
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color:
                        isPro ? Colors.blue.shade50 : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        tier,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isPro
                                ? Colors.blue.shade700
                                : const Color(0xFF7A90B8)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: project.isActive
                            ? Colors.green.shade50
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        status,
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: project.isActive
                                ? Colors.green.shade700
                                : Colors.grey.shade700),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.people_outline,
                        size: 14, color: Color(0xFF7A90B8)),
                    const SizedBox(width: 4),
                    Text(users,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7A90B8))),
                    const SizedBox(width: 12),
                    const Icon(Icons.assignment_outlined,
                        size: 14, color: Color(0xFF7A90B8)),
                    const SizedBox(width: 4),
                    Text(submissions,
                        style: const TextStyle(
                            fontSize: 12, color: Color(0xFF7A90B8))),
                  ],
                ),
                const Icon(Icons.chevron_right,
                    color: Color(0xFF7A90B8), size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Create Project Bottom Sheet ───────────────────────────────
class _CreateProjectSheet extends StatefulWidget {
  final Future<void> Function(String name, String? description) onCreate;
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
            const Text('Create New Project',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.navyDark)),
            const SizedBox(height: 6),
            const Text(
                'Uses a free active slot (up to 2) or an available annual Pro slot.',
                style: TextStyle(fontSize: 12, color: AppTheme.grayText)),
            const SizedBox(height: 20),
            const Text('Project name *',
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
                hintText: 'e.g. NH-48 Highway Expansion',
                prefixIcon: Icon(Icons.folder_outlined),
              ),
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Project name is required'
                  : null,
            ),
            const SizedBox(height: 16),
            const Text('Description / Location (optional)',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.grayDark)),
            const SizedBox(height: 6),
            TextFormField(
              controller: _descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                hintText: 'e.g. Sector 4 Site Office',
                prefixIcon: Icon(Icons.notes_outlined),
              ),
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
                    final desc = _descCtrl.text.trim();
                    await widget.onCreate(
                      _nameCtrl.text.trim(),
                      desc.isEmpty ? null : desc,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      await UpgradeDialog.show(
                        context,
                        message:
                        e.toString().replaceFirst('Exception: ', ''),
                      );
                    }
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
                    : const Icon(Icons.add_circle_outline, size: 18),
                label: Text(_loading ? 'Creating...' : 'Create Project'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}