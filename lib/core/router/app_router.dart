// lib/core/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers/auth_provider.dart';
import '../../features/auth/screens/splash_screen.dart';
import '../../features/auth/screens/home_screen.dart';
import '../../features/auth/screens/owner_login_screen.dart';
import '../../features/auth/screens/owner_register_screen.dart';
import '../../features/auth/screens/code_login_screen.dart';
import '../../features/auth/screens/confirm_email_screen.dart';
import '../../features/auth/screens/otp_verification_screen.dart';
import '../../features/auth/screens/forgot_password_screen.dart';
import '../../features/auth/screens/reset_password_screen.dart';
import '../../features/auth/screens/account_pending_deletion_screen.dart';
import '../../features/owner/dashboard/screens/owner_dashboard_screen.dart';
import '../../features/owner/dashboard/screens/profile_edit_screen.dart';
import '../../features/owner/projects/screens/project_detail_screen.dart';
import '../../features/owner/billing/screens/billing_screen.dart';
import '../../features/field_user/screens/field_home_screen.dart';
import '../../features/field_user/screens/field_dashboard_screen.dart';
import '../../models/project_model.dart';

class AppRoutes {
  static const splash                = '/';
  static const home                  = '/home';
  static const ownerLogin            = '/login';
  static const ownerRegister         = '/register';
  static const codeLogin             = '/code-login';
  static const confirmEmail          = '/confirm-email';
  static const otpVerification       = '/otp-verification';
  static const forgotPassword        = '/forgot-password';
  static const resetPassword         = '/reset-password';
  static const accountPendingDeletion = '/account-pending-deletion';
  static const ownerDashboard        = '/owner/dashboard';
  static const profileEdit           = '/owner/profile-edit';
  static const projectDetail         = '/owner/project/:id';
  static const billing               = '/billing';
  static const fieldHome             = '/field/home';
  static const fieldForm             = '/field/form';
}

final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: AppRoutes.splash,
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      final location = state.matchedLocation;

      if (location == AppRoutes.splash) return null;

      final authState    = ref.read(authProvider);
      final isLoading    = authState.isLoading;
      final isOwner      = authState.isOwner;
      final isFieldUser  = authState.isFieldUser;
      final isLoggedIn   = authState.isLoggedIn;
      final inRecovery   = authState.passwordRecovery;
      final isPending    = authState.pendingDeletion;

      if (isLoading) return null;

      if (inRecovery && location != AppRoutes.resetPassword) {
        return AppRoutes.resetPassword;
      }

      if (isPending && location != AppRoutes.accountPendingDeletion) {
        return AppRoutes.accountPendingDeletion;
      }

      final authScreens = [
        AppRoutes.home,
        AppRoutes.ownerLogin,
        AppRoutes.ownerRegister,
        AppRoutes.codeLogin,
        AppRoutes.confirmEmail,
        AppRoutes.otpVerification,
        AppRoutes.forgotPassword,
        AppRoutes.resetPassword,
        AppRoutes.accountPendingDeletion,
      ];

      // Exclude profileEdit from the strict authScreens redirect block
      // so authenticated owners can freely access it from the dashboard.
      if (!isLoggedIn && !authScreens.contains(location)) {
        return AppRoutes.home;
      }
      if (isOwner && authScreens.contains(location)) {
        return AppRoutes.ownerDashboard;
      }
      if (isFieldUser && authScreens.contains(location)) {
        return AppRoutes.fieldHome;
      }

      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerLogin,
        builder: (context, state) => const OwnerLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerRegister,
        builder: (context, state) => const OwnerRegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.codeLogin,
        builder: (context, state) => const CodeLoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.confirmEmail,
        builder: (context, state) =>
            ConfirmEmailScreen(email: state.extra as String? ?? ''),
      ),
      GoRoute(
        path: AppRoutes.otpVerification,
        builder: (context, state) {
          final extras = state.extra as Map<String, dynamic>? ?? {};
          return OtpVerificationScreen(
            email: extras['email'] as String? ?? '',
            phone: extras['phone'] as String? ?? '',
          );
        },
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.accountPendingDeletion,
        builder: (context, state) => const AccountPendingDeletionScreen(),
      ),
      GoRoute(
        path: AppRoutes.ownerDashboard,
        builder: (context, state) => const OwnerDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.profileEdit,
        builder: (context, state) => const ProfileEditScreen(),
      ),
      GoRoute(
        path: AppRoutes.projectDetail,
        builder: (context, state) {
          final project = state.extra as ProjectModel;
          return ProjectDetailScreen(project: project);
        },
      ),
      GoRoute(
        path: AppRoutes.billing,
        builder: (context, state) => const BillingScreen(),
      ),
      GoRoute(
        path: AppRoutes.fieldHome,
        builder: (context, state) => const FieldDashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.fieldForm,
        builder: (context, state) => const FieldHomeScreen(),
      ),
    ],
  );
});

class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(Ref ref) {
    ref.listen(authProvider, (prev, next) {
      final wasOwner      = prev?.isOwner ?? false;
      final wasField      = prev?.isFieldUser ?? false;
      final wasRecovery   = prev?.passwordRecovery ?? false;
      final wasPending    = prev?.pendingDeletion ?? false;
      if (wasOwner    != next.isOwner       ||
          wasField    != next.isFieldUser   ||
          wasRecovery != next.passwordRecovery ||
          wasPending  != next.pendingDeletion) {
        notifyListeners();
      }
    });
  }
}