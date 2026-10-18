// lib/models/co_owner_model.dart
class CoOwnerModel {
  final String id;
  final String ownerId;
  final String name;
  final String accessCode;
  final bool isActive;
  final DateTime? lastLoginAt;
  final DateTime createdAt;

  const CoOwnerModel({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.accessCode,
    required this.isActive,
    this.lastLoginAt,
    required this.createdAt,
  });

  factory CoOwnerModel.fromJson(Map<String, dynamic> json) {
    return CoOwnerModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      name: json['name'] as String,
      accessCode: json['access_code'] as String,
      isActive: json['is_active'] as bool? ?? true,
      lastLoginAt: json['last_login_at'] != null
          ? DateTime.tryParse(json['last_login_at'] as String)
          : null,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}