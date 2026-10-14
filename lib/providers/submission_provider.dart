// lib/providers/submission_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/submission_repository.dart';
import '../models/submission_model.dart';

final submissionRepositoryProvider = Provider<SubmissionRepository>((ref) {
  return SubmissionRepository();
});

// Fetch submissions per project
final submissionsProvider =
FutureProvider.family<List<SubmissionModel>, String>(
      (ref, projectId) async {
    return ref.watch(submissionRepositoryProvider).getSubmissions(projectId);
  },
);

// ── Field user's OWN submissions (for their dashboard) ────────
final userSubmissionsProvider =
FutureProvider.family<List<SubmissionModel>, String>(
      (ref, accessCode) async {
    return ref
        .watch(submissionRepositoryProvider)
        .getUserSubmissions(accessCode);
  },
);

// ── Simple stats derived from the field user's submissions ────
class FieldStats {
  final int total;
  final int thisWeek;
  const FieldStats({required this.total, required this.thisWeek});
}

final fieldStatsProvider = Provider.family<FieldStats, String>(
      (ref, accessCode) {
    final asyncSubs = ref.watch(userSubmissionsProvider(accessCode));
    final subs = asyncSubs.value ?? const [];

    final now = DateTime.now();
    // Start of the current week (Monday 00:00, local time)
    final startOfWeek = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));

    final weekCount = subs
        .where((s) => s.submittedAt.toLocal().isAfter(startOfWeek))
        .length;

    return FieldStats(total: subs.length, thisWeek: weekCount);
  },
);