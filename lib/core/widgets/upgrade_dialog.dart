// lib/core/widgets/upgrade_dialog.dart
// ─────────────────────────────────────────────────────────────
// Reusable popup shown when a free-plan limit is hit.
// Call UpgradeDialog.show(context, message: '...').
// ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_theme.dart';
import '../router/app_router.dart';

class UpgradeDialog {
  static Future<void> show(
      BuildContext context, {
        required String message,
        VoidCallback? onUpgrade,
      }) {
    // Always show via rootNavigatorKey so the dialog sits above
    // every other navigator layer (bottom sheets, nested navigators,
    // tab bars) and the context is stable when we navigate away.
    final ctx = rootNavigatorKey.currentContext ?? context;
    return showDialog(
      context: ctx,
      useRootNavigator: true,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                width: 56,
                height: 56,
                decoration: const BoxDecoration(
                  color: AppTheme.warningLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.workspace_premium_outlined,
                  color: AppTheme.warning,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Upgrade to Pro',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.navyDark,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.grayText,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: AppTheme.grayBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Not now',
                        style: TextStyle(color: AppTheme.grayDark),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Pop the dialog first, then navigate.
                        // Use rootNavigatorKey.currentContext so
                        // go_router's push works regardless of which
                        // navigator layer the caller was on.
                        Navigator.of(dialogContext).pop();
                        if (onUpgrade != null) {
                          onUpgrade();
                        } else {
                          // Default: go straight to billing screen
                          // when no custom callback is provided.
                          rootNavigatorKey.currentContext
                              ?.push(AppRoutes.billing);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyDark,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text(
                        'Upgrade →',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}