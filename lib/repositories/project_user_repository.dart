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
  // Joins the project name so the Users tab shows where each
  // user belongs. Flattens the nested projects(name) into the
  // flat project_name key that ProjectUserModel.fromJson expects.
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
  // 5 users per project — same limit for free and paid projects.
  // The distinction between free and paid is at the PROJECT level
  // (how many projects you can create), not at the user level.
  Future<ProjectUserModel> createUser({
    required String projectId,
    required String ownerId,
    required String name,
  }) async {
    final existing = await supabase
        .from('project_users')
        .select('id')
        .eq('project_id', projectId);

    if ((existing as List).length >= AppConstants.freePlanMaxUsersPerProject) {
      throw Exception(
        'Each project allows up to '
            '${AppConstants.freePlanMaxUsersPerProject} users.',
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