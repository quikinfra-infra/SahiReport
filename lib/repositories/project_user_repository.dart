// lib/repositories/project_user_repository.dart
import '../core/constants/app_constants.dart';
import '../models/project_user_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProjectUserRepository {
  // ── Get all users for a project ───────────────────────────
  Future<List<ProjectUserModel>> getProjectUsers(String projectId) async {
    final response = await supabase
        .from('project_users')
        .select()
        .eq('project_id', projectId)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => ProjectUserModel.fromJson(json))
        .toList();
  }

  // ── Get ALL users across all of an owner's projects ───────
  Future<List<ProjectUserModel>> getAllUsersForOwner(String ownerId) async {
    final response = await supabase
        .from('project_users')
        .select('*, projects(name)')
        .eq('owner_id', ownerId)
        .order('created_at', ascending: false);

    return (response as List).map((json) {
      final projectName =
          (json['projects'] as Map<String, dynamic>?)?['name'] as String? ?? '';
      return ProjectUserModel.fromJson({
        ...json as Map<String, dynamic>,
        'project_name': projectName,
      });
    }).toList();
  }

  // ── Create user with auto-generated code ──────────────────
  // 5 ACTIVE users per project — same limit for free and paid projects.
  Future<ProjectUserModel> createUser({
    required String projectId,
    required String ownerId,
    required String name,
  }) async {
    // 1. Ensure the project is not closed
    final projectRow = await supabase
        .from('projects')
        .select('is_active')
        .eq('id', projectId)
        .single();

    if (projectRow['is_active'] == false) {
      throw Exception('Cannot add users to a closed project.');
    }

    // 2. Count only ACTIVE users in this project
    final existingActive = await supabase
        .from('project_users')
        .select('id')
        .eq('project_id', projectId)
        .eq('is_active', true);

    if ((existingActive as List).length >=
        AppConstants.freePlanMaxUsersPerProject) {
      throw Exception(
        'Each project allows up to '
            '${AppConstants.freePlanMaxUsersPerProject} active users.',
      );
    }

    final codeRes = await supabase.rpc('generate_access_code');
    final code = codeRes as String;

    final response = await supabase
        .from('project_users')
        .insert({
      'project_id': projectId,
      'owner_id': ownerId,
      'name': name,
      'access_code': code,
      'is_active': true,
    })
        .select()
        .single();

    return ProjectUserModel.fromJson(response);
  }

  // ── Toggle user active status ─────────────────────────────
  Future<void> toggleUserStatus(String userId, bool isActive) async {
    await supabase
        .from('project_users')
        .update({'is_active': isActive}).eq('id', userId);
  }

  // ── Delete user ───────────────────────────────────────────
  Future<void> deleteUser(String userId) async {
    await supabase.from('project_users').delete().eq('id', userId);
  }
}