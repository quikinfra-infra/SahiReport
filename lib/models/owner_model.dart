// lib/models/owner_model.dart
import '../core/constants/app_constants.dart';

class OwnerModel {
  final String id;
  final String email;
  final String? fullName;
  final String? companyName;
  final String? gstin;
  final String? phone;
  final String? addressLine;
  final String? city;
  final String? state;
  final String? pincode;
  final String planType;
  final int extraProjectsCount; // number of paid extra projects purchased
  final DateTime createdAt;

  const OwnerModel({
    required this.id,
    required this.email,
    this.fullName,
    this.companyName,
    this.gstin,
    this.phone,
    this.addressLine,
    this.city,
    this.state,
    this.pincode,
    required this.planType,
    required this.extraProjectsCount,
    required this.createdAt,
  });

  bool get isPro => planType == 'pro';
  bool get isFree => planType == 'free';
  // Total projects allowed = 2 free + however many were purchased
  int get totalProjectsAllowed =>
      AppConstants.freePlanMaxProjects + extraProjectsCount;

  factory OwnerModel.fromJson(Map<String, dynamic> json) {
    return OwnerModel(
      id: json['id'] as String,
      email: json['email'] as String,
      fullName: json['full_name'] as String?,
      companyName: json['company_name'] as String?,
      gstin: json['gstin'] as String?,
      phone: json['phone'] as String?,
      addressLine: json['address_line'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      pincode: json['pincode'] as String?,
      planType: json['plan_type'] as String? ?? 'free',
      extraProjectsCount: json['extra_projects_count'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'full_name': fullName,
    'company_name': companyName,
    'gstin': gstin,
    'phone': phone,
    'address_line': addressLine,
    'city': city,
    'state': state,
    'pincode': pincode,
    'plan_type': planType,
    'extra_projects_count': extraProjectsCount,
    'created_at': createdAt.toIso8601String(),
  };
}