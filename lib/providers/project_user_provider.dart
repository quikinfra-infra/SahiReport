// lib/providers/project_user_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/project_user_repository.dart';
import '../models/project_user_model.dart';
import 'auth_provider.dart';

// ── Repository provider ───────────────────────────────────────
final projectUserRepositoryProvider = Provider<ProjectUserRepository>((ref) {
  return ProjectUserRepository();
});

// ── State ─────────────────────────────────────────────────────
class ProjectUsersState {
  final List<ProjectUserModel> users;
  final bool isLoading;
  final String? error;
  final ProjectUserModel? lastCreated; // Holds newly created user to show code

  const ProjectUsersState({
    this.users = const [],
    this.isLoading = false,
    this.error,
    this.lastCreated,
  });

  ProjectUsersState copyWith({
    List<ProjectUserModel>? users,
    bool? isLoading,
    String? error,
    ProjectUserModel? lastCreated,
  }) {
    return ProjectUsersState(
      users: users ?? this.users,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      lastCreated: lastCreated ?? this.lastCreated,
    );
  }
}

// ── Notifier ──────────────────────────────────────────────────
class ProjectUsersNotifier extends StateNotifier<ProjectUsersState> {
  final ProjectUserRepository _repo;
  final String _projectId;
  final String _ownerId;

  ProjectUsersNotifier(this._repo, this._projectId, this._ownerId)
      : super(const ProjectUsersState(isLoading: true)) {
    loadUsers();
  }

  Future<void> loadUsers() async {
    state = state.copyWith(isLoading: true);
    try {
      final users = await _repo.getProjectUsers(_projectId);
      state = ProjectUsersState(users: users);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to load users.',
      );
    }
  }

  Future<ProjectUserModel?> createUser(String name) async {
    state = state.copyWith(isLoading: true);
    try {
      final user = await _repo.createUser(
        projectId: _projectId,
        ownerId: _ownerId,
        name: name,
      );
      state = ProjectUsersState(
        users: [user, ...state.users],
        lastCreated: user,
      );
      return user;
    } catch (e) {
      // Preserve the real message (e.g. free-plan limit) and re-throw
      // so the Add User sheet can show it in a snackbar.
      final msg = e.toString().replaceFirst('Exception: ', '');
      state = state.copyWith(isLoading: false, error: msg);
      rethrow;
    }
  }

  Future<void> toggleUserStatus(String userId, bool isActive) async {
    try {
      await _repo.toggleUserStatus(userId, isActive);
      state = state.copyWith(
        users: state.users.map((u) {
          if (u.id == userId) {
            return ProjectUserModel(
              id: u.id,
              projectId: u.projectId,
              projectName: u.projectName,
              ownerId: u.ownerId,
              name: u.name,
              accessCode: u.accessCode,
              isActive: isActive,
              lastLoginAt: u.lastLoginAt,
              createdAt: u.createdAt,
            );
          }
          return u;
        }).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to update user.');
    }
  }

  Future<void> deleteUser(String userId) async {
    try {
      await _repo.deleteUser(userId);
      state = state.copyWith(
        users: state.users.where((u) => u.id != userId).toList(),
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete user.');
    }
  }

  void clearError() => state = state.copyWith(error: null);
}

// ── Provider factory (per project) ───────────────────────────
final projectUsersProvider = StateNotifierProvider.family<ProjectUsersNotifier,
    ProjectUsersState, String>((ref, projectId) {
  final ownerId = ref.watch(authProvider).owner?.id ?? '';
  return ProjectUsersNotifier(
    ref.watch(projectUserRepositoryProvider),
    projectId,
    ownerId,
  );
});

// ── All users across ALL of the owner's projects (Users tab) ──
final allUsersProvider =
FutureProvider<List<ProjectUserModel>>((ref) async {
  final ownerId = ref.watch(authProvider).owner?.id;
  if (ownerId == null || ownerId.isEmpty) return [];
  return ref.watch(projectUserRepositoryProvider).getAllUsersForOwner(ownerId);
});