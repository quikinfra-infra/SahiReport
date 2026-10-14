// lib/repositories/auth_repository.dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/owner_model.dart';
import '../models/project_user_model.dart';

final supabase = Supabase.instance.client;

class AuthRepository {
  // ── Owner: Register ───────────────────────────────────────
  Future<bool> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final response = await supabase.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    if (response.user == null) {
      throw Exception('Registration failed. Please try again.');
    }
    return response.session != null;
  }

  // ── Owner: Resend confirmation email ──────────────────────
  Future<void> resendConfirmation(String email) async {
    await supabase.auth.resend(
      type: OtpType.signup,
      email: email,
    );
  }

  // ── Owner: Send password reset code ────────────────────────
  Future<void> sendPasswordResetEmail(String email) async {
    await supabase.auth.resetPasswordForEmail(email);
  }

  // ── Owner: Verify the password-reset OTP ──────────────────
  Future<void> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    await supabase.auth.verifyOTP(
      type: OtpType.recovery,
      email: email,
      token: token,
    );
  }

  // ── Owner: Update password ────────────────────────────────
  Future<void> updatePassword(String newPassword) async {
    try {
      await supabase.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      if (e.code == 'same_password') {
        throw Exception(
          'Your new password must be different from your old password.',
        );
      }
      throw Exception(e.message);
    }
  }

  // ── Password recovery stream ──────────────────────────────
  Stream<void> get passwordRecoveryStream => supabase.auth.onAuthStateChange
      .where((data) => data.event == AuthChangeEvent.passwordRecovery)
      .map((_) {});

  // ── Owner: Login ──────────────────────────────────────────
  Future<void> loginOwner({
    required String email,
    required String password,
  }) async {
    await supabase.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  // ── Owner: Logout ─────────────────────────────────────────
  Future<void> logout() async {
    await supabase.auth.signOut();
  }

  // ── Owner: Get current profile ────────────────────────────
  Future<OwnerModel?> getCurrentOwner() async {
    final user = supabase.auth.currentUser;
    if (user == null) return null;
    final data =
    await supabase.from('owners').select().eq('id', user.id).single();
    return OwnerModel.fromJson(data);
  }

  // ── Owner: Update profile fields ──────────────────────────
  Future<OwnerModel> updateOwnerProfile({
    required String ownerId,
    String? fullName,
    String? companyName,
    String? gstin,
    String? phone,
    String? addressLine,
    String? city,
    String? state,
    String? pincode,
  }) async {
    final data = await supabase
        .from('owners')
        .update({
      'full_name': fullName,
      'company_name': companyName,
      'gstin': gstin,
      'phone': phone,
      'address_line': addressLine,
      'city': city,
      'state': state,
      'pincode': pincode,
    })
        .eq('id', ownerId)
        .select()
        .single();
    return OwnerModel.fromJson(data);
  }

  // ── Owner: Soft delete account ────────────────────────────
  // Sets is_deleted=true and deleted_at=now(). A pg_cron job
  // permanently deletes after 30 days.
  Future<void> softDeleteAccount(String ownerId) async {
    await supabase.from('owners').update({
      'is_deleted': true,
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', ownerId);
  }

  // ── Owner: Reactivate soft-deleted account ────────────────
  Future<void> reactivateAccount() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    await supabase.from('owners').update({
      'is_deleted': false,
      'deleted_at': null,
    }).eq('id', user.id);
  }

  // ── Owner: Get deletion date if account is soft-deleted ───
  // Returns null if account is not deleted.
  Future<DateTime?> getAccountDeletionDate(String ownerId) async {
    final row = await supabase
        .from('owners')
        .select('is_deleted, deleted_at')
        .eq('id', ownerId)
        .single();
    final isDeleted = row['is_deleted'] as bool? ?? false;
    if (!isDeleted) return null;
    final deletedAt = row['deleted_at'] as String?;
    return deletedAt != null ? DateTime.parse(deletedAt) : null;
  }

  // ── Field User: Login via code ────────────────────────────
  Future<ProjectUserModel?> loginWithCode(String code) async {
    final response = await supabase
        .rpc('login_with_code', params: {'p_code': code.toUpperCase().trim()});
    if (response == null || (response as List).isEmpty) {
      throw Exception('Invalid or expired code. Please check and try again.');
    }
    final data = response.first as Map<String, dynamic>;
    return ProjectUserModel.fromCodeLogin(data, code.toUpperCase().trim());
  }

  // ── Auth state stream ─────────────────────────────────────
  Stream<AuthState> get authStateStream => supabase.auth.onAuthStateChange;

  // ── Current session ───────────────────────────────────────
  Session? get currentSession => supabase.auth.currentSession;
  User?    get currentUser    => supabase.auth.currentUser;
}