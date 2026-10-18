// lib/models/project_model.dart
class ProjectModel {
  final String id;
  final String ownerId;
  final String name;
  final String? description;
  final bool isActive;
  final String planType; // 'free' or 'pro'
  final DateTime createdAt;
  final DateTime updatedAt;

  // Computed fields from joins (optional)
  final int? userCount;
  final int? submissionCount;
  final int? todayCount;

  bool get isPro => planType.toLowerCase() == 'pro';

  const ProjectModel({
    required this.id,
    required this.ownerId,
    required this.name,
    this.description,
    required this.isActive,
    this.planType = 'free',
    required this.createdAt,
    required this.updatedAt,
    this.userCount,
    this.submissionCount,
    this.todayCount,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      planType: json['plan_type'] as String? ?? 'free',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
      userCount: json['user_count'] as int?,
      submissionCount: json['submission_count'] as int?,
      todayCount: json['today_count'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'owner_id': ownerId,
    'name': name,
    'description': description,
    'is_active': isActive,
    'plan_type': planType,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  ProjectModel copyWith({
    String? name,
    String? description,
    bool? isActive,
    String? planType,
  }) {
    return ProjectModel(
      id: id,
      ownerId: ownerId,
      name: name ?? this.name,
      description: description ?? this.description,
      isActive: isActive ?? this.isActive,
      planType: planType ?? this.planType,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      userCount: userCount,
      submissionCount: submissionCount,
      todayCount: todayCount,
    );
  }
}