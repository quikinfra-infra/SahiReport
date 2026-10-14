// lib/models/project_user_model.dart
class ProjectUserModel {
  final String id;
  final String projectId;
  final String projectName;
  final String ownerId;
  final String name;
  final String accessCode;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const ProjectUserModel({
    required this.id,
    required this.projectId,
    required this.projectName,
    required this.ownerId,
    required this.name,
    required this.accessCode,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
  });

  // Used after code login — response from login_with_code() RPC
  factory ProjectUserModel.fromCodeLogin(
      Map<String, dynamic> json, [
        String code = '',
      ]) {
    return ProjectUserModel(
      id: json['project_user_id'] as String,
      projectId: json['project_id'] as String,
      projectName: json['project_name'] as String,
      ownerId: json['owner_id'] as String,
      name: json['project_user_name'] as String,
      accessCode: code,
      isActive: true,
      createdAt: DateTime.now(),
    );
  }

  factory ProjectUserModel.fromJson(Map<String, dynamic> json) {
    return ProjectUserModel(
      id: json['id'] as String,
      projectId: json['project_id'] as String,
      projectName: json['project_name'] as String? ?? '',
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      accessCode: json['access_code'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.parse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}