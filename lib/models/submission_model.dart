// lib/models/submission_model.dart
class SubmissionModel {
  final String id;
  final String projectUserId;
  final String projectId;
  final String ownerId;
  final String? formText;
  final String? siteName;
  final double latitude;
  final double longitude;
  final DateTime submittedAt;
  final bool isReviewed;
  final List<String>? imageUrls;
  final String? userName;

  const SubmissionModel({
    required this.id,
    required this.projectUserId,
    required this.projectId,
    required this.ownerId,
    this.formText,
    this.siteName,
    required this.latitude,
    required this.longitude,
    required this.submittedAt,
    this.isReviewed = false,
    this.imageUrls,
    this.userName,
  });

  factory SubmissionModel.fromJson(Map<String, dynamic> json) {
    return SubmissionModel(
      id: json['id'] as String,
      projectUserId: json['project_user_id'] as String,
      projectId: json['project_id'] as String,
      ownerId: json['owner_id'] as String,
      formText: json['form_text'] as String?,
      siteName: json['site_name'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      submittedAt: DateTime.parse(json['submitted_at'] as String),
      isReviewed: json['is_reviewed'] as bool? ?? false,
      userName: json['project_users']?['name'] as String?,
      imageUrls: (json['submission_images'] as List?)
          ?.map((e) => e['public_url'] as String)
          .toList(), // ← THIS LINE WAS MISSING
    );
  }
}
