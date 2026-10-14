// lib/providers/project_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/project_repository.dart';
import '../models/project_model.dart';
import 'auth_provider.dart';

// ── Repository provider ───────────────────────────────────────
final projectRepositoryProvider = Provider<ProjectRepository>((ref) {
  return ProjectRepository();
});

// ── Projects state ────────────────────────────────────────────
class ProjectsState {
  final List<ProjectModel> projects;
  final bool isLoading;
  final String? error;

  const ProjectsState({
    this.projects = const [],
    this.isLoading = false,
    this.error,
  });

  ProjectsState copyWith({
    List<ProjectModel>? projects,
    bool? isLoading,
    String? error,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }
}

// ── Projects notifier ─────────────────────────────────────────
class ProjectsNotifier extends StateNotifier<ProjectsState> {
  final ProjectRepository _repo;
  final String _ownerId;

  ProjectsNotifier(this._repo, this._ownerId)
      : super(const ProjectsState(isLoading: true)) {
    loadProjects();
  }

  Future<void> loadProjects() async {
    state = state.copyWith(isLoading: true);
    try {
      final projects = await _repo.getProjects(_ownerId);
      state = ProjectsState(projects: projects);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load projects.',
      );
    }
  }

  Future<bool> createProject({
    required String name,
    String? description,
  }) async {
    try {
      final project = await _repo.createProject(
        ownerId: _ownerId,
        name: name,
        description: description,
      );
      state = state.copyWith(
        projects: [project, ...state.projects],
      );
      return true;
    } catch (e) {
      // Preserve the real message (e.g. free-plan limit) instead of a
      // generic one, and re-throw so the UI can show it in a snackbar.
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(error: msg);
      rethrow;
    }
  }

  Future<bool> toggleProjectStatus(String projectId, bool isActive) async {
    try {
      final updated = await _repo.updateProject(
        projectId: projectId,
        isActive: isActive,
      );
      state = state.copyWith(
        projects:
        state.projects.map((p) => p.id == projectId ? updated : p).toList(),
      );
      return true;
    } catch (e) {
      return false;
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Provider ──────────────────────────────────────────────────
final projectsProvider =
StateNotifierProvider<ProjectsNotifier, ProjectsState>((ref) {
  final ownerId = ref.watch(authProvider).owner?.id ?? '';
  return ProjectsNotifier(
    ref.watch(projectRepositoryProvider),
    ownerId,
  );
});

// ── Dashboard stats provider ──────────────────────────────────
final dashboardStatsProvider = FutureProvider<Map<String, int>>((ref) async {
  final ownerId = ref.watch(authProvider).owner?.id ?? '';
  if (ownerId.isEmpty) return {};
  return ref.watch(projectRepositoryProvider).getDashboardStats(ownerId);
});