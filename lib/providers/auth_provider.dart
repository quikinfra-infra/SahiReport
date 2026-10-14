// lib/providers/auth_provider.dart
import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/auth_repository.dart';
import '../models/owner_model.dart';
import '../models/project_user_model.dart';
import '../core/services/notification_service.dart';

// ── Auth Repository Provider ──────────────────────────────────
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository();
});

// ── Auth State Enum ───────────────────────────────────────────
enum AuthUserType { none, owner, fieldUser }

// ── Auth Session State ────────────────────────────────────────
class AuthSessionState {
  final AuthUserType userType;
  final OwnerModel? owner;
  final ProjectUserModel? fieldUser;
  final bool isLoading;
  final String? error;
  final bool passwordRecovery;
  final bool pendingDeletion;

  const AuthSessionState({
    this.userType = AuthUserType.none,
    this.owner,
    this.fieldUser,
    this.isLoading = false,
    this.error,
    this.passwordRecovery = false,
    this.pendingDeletion = false,
  });

  bool get isOwner     => userType == AuthUserType.owner;
  bool get isFieldUser => userType == AuthUserType.fieldUser;
  bool get isLoggedIn  => userType != AuthUserType.none;
  bool get isFree      => owner?.isFree ?? true;

  AuthSessionState copyWith({
    AuthUserType? userType,
    OwnerModel? owner,
    ProjectUserModel? fieldUser,
    bool? isLoading,
    String? error,
    bool? passwordRecovery,
    bool? pendingDeletion,
  }) {
    return AuthSessionState(
      userType:         userType         ?? this.userType,
      owner:            owner            ?? this.owner,
      fieldUser:        fieldUser        ?? this.fieldUser,
      isLoading:        isLoading        ?? this.isLoading,
      error:            error,
      passwordRecovery: passwordRecovery ?? this.passwordRecovery,
      pendingDeletion:  pendingDeletion  ?? this.pendingDeletion,
    );
  }
}

// ── Auth Notifier ─────────────────────────────────────────────
class AuthNotifier extends StateNotifier<AuthSessionState> {
  final AuthRepository _repo;
  StreamSubscription<void>? _recoverySub;

  AuthNotifier(this._repo) : super(const AuthSessionState(isLoading: true)) {
    _init();
    _recoverySub = _repo.passwordRecoveryStream.listen((_) {
      state = state.copyWith(passwordRecovery: true);
    });
  }

  @override
  void dispose() {
    _recoverySub?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    try {
      final session = _repo.currentSession;
      if (session != null) {
        final owner = await _repo.getCurrentOwner();
        if (owner != null) {
          // Check if account is soft-deleted
          final deletionDate = await _repo.getAccountDeletionDate(owner.id);
          if (deletionDate != null) {
            await _repo.logout();
            state = const AuthSessionState(
              userType: AuthUserType.none,
              isLoading: false,
              pendingDeletion: true,
            );
            return;
          }
          state = AuthSessionState(
            userType: AuthUserType.owner,
            owner: owner,
          );
          NotificationService.getAndSaveFCMToken(owner.id);
          NotificationService.listenTokenRefresh(owner.id);
          return;
        }
      }
      state = const AuthSessionState(
        userType: AuthUserType.none,
        isLoading: false,
      );
    } catch (e) {
      state = const AuthSessionState(
        userType: AuthUserType.none,
        isLoading: false,
      );
    }
  }

  // ── Owner: Register ────────────────────────────────────────
  Future<bool> registerOwner({
    required String email,
    required String password,
    required String fullName,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      final signedIn = await _repo.registerOwner(
        email: email,
        password: password,
        fullName: fullName,
      );
      if (!signedIn) {
        state = const AuthSessionState(
          userType: AuthUserType.none,
          isLoading: false,
        );
        return true; // needs email confirmation
      }
      final owner = await _repo.getCurrentOwner();
      state = AuthSessionState(
        userType: AuthUserType.owner,
        owner: owner,
      );
      if (owner != null) {
        NotificationService.getAndSaveFCMToken(owner.id);
        NotificationService.listenTokenRefresh(owner.id);
      }
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
      rethrow;
    }
  }

  // ── Owner: Resend confirmation email ───────────────────────
  Future<void> resendConfirmation(String email) async {
    await _repo.resendConfirmation(email);
  }

  // ── Owner: Forgot password — send reset code ───────────────
  Future<String?> sendPasswordResetEmail(String email) async {
    try {
      await _repo.sendPasswordResetEmail(email);
      return null;
    } catch (e) {
      return 'Couldn\'t send the reset email. Check the address and try again.';
    }
  }

  // ── Owner: Forgot password — verify OTP code ──────────────
  Future<String?> verifyPasswordResetOtp({
    required String email,
    required String token,
  }) async {
    try {
      await _repo.verifyPasswordResetOtp(email: email, token: token);
      return null;
    } catch (e) {
      return 'That code is invalid or has expired. Please request a new one.';
    }
  }

  // ── Owner: Reset password — set new password ───────────────
  Future<String?> updatePassword(String newPassword) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.updatePassword(newPassword);
      state = state.copyWith(isLoading: false, passwordRecovery: true);
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false, passwordRecovery: true);
      final msg = e.toString().replaceAll('Exception: ', '');
      return msg.isNotEmpty ? msg : 'Couldn\'t update your password. Please try again.';
    }
  }

  // ── Owner: Reset password — finish up ─────────────────────
  Future<void> completePasswordReset() async {
    await _repo.logout();
    state = const AuthSessionState(
      userType: AuthUserType.none,
      passwordRecovery: false,
    );
  }

  // ── Owner: Login ───────────────────────────────────────────
  Future<String?> loginOwner({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.loginOwner(email: email, password: password);
      final owner = await _repo.getCurrentOwner();

      // Block login if account is pending deletion
      if (owner != null) {
        final deletionDate = await _repo.getAccountDeletionDate(owner.id);
        if (deletionDate != null) {
          await _repo.logout();
          state = const AuthSessionState(
            userType: AuthUserType.none,
            isLoading: false,
            pendingDeletion: true,
          );
          return null; // router redirects to accountPendingDeletion
        }
      }

      state = AuthSessionState(
        userType: AuthUserType.owner,
        owner: owner,
      );
      if (owner != null) {
        NotificationService.getAndSaveFCMToken(owner.id);
        NotificationService.listenTokenRefresh(owner.id);
      }
      return null;
    } catch (e) {
      final raw = e.toString().toLowerCase();
      final msg = raw.contains('not confirmed') || raw.contains('email not confirmed')
          ? 'Please confirm your email first. Check your inbox for the link.'
          : 'Couldn\'t sign in. Check your email and password — or register '
          'if you don\'t have an account yet.';
      state = state.copyWith(isLoading: false, error: msg);
      return msg;
    }
  }

  // ── Field User: Code Login ─────────────────────────────────
  Future<void> loginWithCode(String code) async {
    state = state.copyWith(isLoading: true);
    try {
      final fieldUser = await _repo.loginWithCode(code);
      if (fieldUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid code. Please check and try again.',
        );
        return;
      }
      state = AuthSessionState(
        userType: AuthUserType.fieldUser,
        fieldUser: fieldUser,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceAll('Exception: ', ''),
      );
    }
  }

  // ── Logout ─────────────────────────────────────────────────
  Future<void> logout() async {
    if (state.isOwner) {
      await _repo.logout();
    }
    state = const AuthSessionState(userType: AuthUserType.none);
  }

  // ── Owner: Soft-delete account ─────────────────────────────
  Future<void> softDeleteAccount() async {
    final owner = state.owner;
    if (owner == null) return;
    await _repo.softDeleteAccount(owner.id);
    await _repo.logout();
    state = const AuthSessionState(
      userType: AuthUserType.none,
      pendingDeletion: false,
    );
  }

  // ── Owner: Reactivate a soft-deleted account ───────────────
  Future<String?> reactivateWithCredentials({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true);
    try {
      await _repo.loginOwner(email: email, password: password);
      await _repo.reactivateAccount();
      final owner = await _repo.getCurrentOwner();
      state = AuthSessionState(
        userType: AuthUserType.owner,
        owner: owner,
        pendingDeletion: false,
      );
      return null;
    } catch (e) {
      state = state.copyWith(isLoading: false);
      return 'Couldn\'t reactivate. Check your email and password.';
    }
  }

  // ── Clear pending deletion flag ────────────────────────────
  void clearPendingDeletion() {
    state = state.copyWith(pendingDeletion: false);
  }

  // ── Owner: Update profile ──────────────────────────────────
  Future<void> updateProfile({
    required String fullName,
    String? companyName,
    String? gstin,
    String? phone,
    String? addressLine,
    String? city,
    String? state,
    String? pincode,
  }) async {
    final owner = this.state.owner;
    if (owner == null) return;
    final updated = await _repo.updateOwnerProfile(
      ownerId: owner.id,
      fullName: fullName,
      companyName: companyName,
      gstin: gstin,
      phone: phone,
      addressLine: addressLine,
      city: city,
      state: state,
      pincode: pincode,
    );
    this.state = this.state.copyWith(owner: updated);
  }

  // ── Refresh owner after plan upgrade ───────────────────────
  Future<void> refreshOwner() async {
    final owner = await _repo.getCurrentOwner();
    if (owner != null) {
      state = state.copyWith(owner: owner);
    }
  }

  // ── Clear error ────────────────────────────────────────────
  void clearError() => state = state.copyWith(error: null);
}

// ── Provider ──────────────────────────────────────────────────
final authProvider =
StateNotifierProvider<AuthNotifier, AuthSessionState>((ref) {
  return AuthNotifier(ref.watch(authRepositoryProvider));
});