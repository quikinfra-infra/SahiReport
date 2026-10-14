// lib/repositories/project_repository.dart
// ─────────────────────────────────────────────────────────────
// All database operations for projects
// ─────────────────────────────────────────────────────────────

import '../core/constants/app_constants.dart';
import '../models/project_model.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class ProjectRepository {
  // ── Fetch all projects for owner ──────────────────────────
  // Includes user count and submission count via subqueries
  Future<List<ProjectModel>> getProjects(String ownerId) async {
    final response = await supabase.from('projects').select('''
          *,
          user_count:project_users(count),
          submission_count:submissions(count)
        ''').eq('owner_id', ownerId).order('created_at', ascending: false);

    return (response as List).map((json) {
      // Supabase returns count as [{count: n}]
      final userCount =
          (json['user_count'] as List?)?.first['count'] as int? ?? 0;
      final subCount =
          (json['submission_count'] as List?)?.first['count'] as int? ?? 0;

      return ProjectModel.fromJson({
        ...json,
        'user_count': userCount,
        'submission_count': subCount,
      });
    }).toList();
  }

  // ── Fetch single project ──────────────────────────────────
  Future<ProjectModel?> getProject(String projectId) async {
    final response = await supabase.from('projects').select('''
          *,
          user_count:project_users(count),
          submission_count:submissions(count)
        ''').eq('id', projectId).single();

    final userCount =
        (response['user_count'] as List?)?.first['count'] as int? ?? 0;
    final subCount =
        (response['submission_count'] as List?)?.first['count'] as int? ?? 0;

    return ProjectModel.fromJson({
      ...response,
      'user_count': userCount,
      'submission_count': subCount,
    });
  }

  // ── Check if owner is on the free plan ────────────────────
  Future<bool> _isFreeOwner(String ownerId) async {
    final row = await supabase
        .from('owners')
        .select('plan_type')
        .eq('id', ownerId)
        .single();
    // Anything that isn't explicitly 'pro' is treated as free.
    return (row['plan_type'] as String?) != 'pro';
  }

  // ── Create project ────────────────────────────────────────
  // Client-side guard mirrors the DB trigger (enforce_project_limit)
  // so the user gets a friendly message instead of a raw DB error.
  Future<ProjectModel> createProject({
    required String ownerId,
    required String name,
    String? description,
  }) async {
    // Free-plan limit check
    if (await _isFreeOwner(ownerId)) {
      final existing =
      await supabase.from('projects').select('id').eq('owner_id', ownerId);

      if ((existing as List).length >= AppConstants.freePlanMaxProjects) {
        throw Exception(
          'Free plan allows up to ${AppConstants.freePlanMaxProjects} projects. '
              'Upgrade to Pro for unlimited projects.',
        );
      }
    }

    final response = await supabase
        .from('projects')
        .insert({
      'owner_id': ownerId,
      'name': name,
      'description': description,
    })
        .select()
        .single();

    return ProjectModel.fromJson(response);
  }

  // ── Update project ────────────────────────────────────────
  Future<ProjectModel> updateProject({
    required String projectId,
    String? name,
    String? description,
    bool? isActive,
  }) async {
    final updates = <String, dynamic>{};
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;
    if (isActive != null) updates['is_active'] = isActive;

    final response = await supabase
        .from('projects')
        .update(updates)
        .eq('id', projectId)
        .select()
        .single();

    return ProjectModel.fromJson(response);
  }

  // ── Delete project ────────────────────────────────────────
  Future<void> deleteProject(String projectId) async {
    await supabase.from('projects').delete().eq('id', projectId);
  }

  // ── Get dashboard stats ───────────────────────────────────
  Future<Map<String, int>> getDashboardStats(String ownerId) async {
    // Total active projects
    final projectsRes = await supabase
        .from('projects')
        .select()
        .eq('owner_id', ownerId)
        .eq('is_active', true);

    // Total users across all projects
    final usersRes = await supabase
        .from('project_users')
        .select()
        .eq('owner_id', ownerId)
        .eq('is_active', true);

    // Today's submissions
    final today = DateTime.now();
    final todayStart =
    DateTime(today.year, today.month, today.day).toUtc().toIso8601String();

    final todayRes = await supabase
        .from('submissions')
        .select()
        .eq('owner_id', ownerId)
        .gte('submitted_at', todayStart);

    // Total submissions
    final totalSubRes =
    await supabase.from('submissions').select().eq('owner_id', ownerId);

    return {
      'active_projects': (projectsRes as List).length,
      'total_users': (usersRes as List).length,
      'today_submissions': (todayRes as List).length,
      'total_submissions': (totalSubRes as List).length,
    };
  }
}