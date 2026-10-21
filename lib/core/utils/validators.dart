// lib/core/utils/validators.dart

class AppValidators {
  static bool hasMinLength(String value) => value.length >= 8;
  static bool hasUppercase(String value) => RegExp(r'[A-Z]').hasMatch(value);
  static bool hasLowercase(String value) => RegExp(r'[a-z]').hasMatch(value);
  static bool hasDigit(String value) => RegExp(r'[0-9]').hasMatch(value);
  static bool hasSpecialChar(String value) =>
      RegExp(r'[!@#$%^&*(),.?":{}|<>_\-+=/\\[\]~`]').hasMatch(value);

  static String? validateStrictPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required.';
    }
    if (!hasMinLength(value)) {
      return 'Password must be at least 8 characters long.';
    }
    if (!hasUppercase(value)) {
      return 'Password must include at least one uppercase letter (A-Z).';
    }
    if (!hasLowercase(value)) {
      return 'Password must include at least one lowercase letter (a-z).';
    }
    if (!hasDigit(value)) {
      return 'Password must include at least one number (0-9).';
    }
    if (!hasSpecialChar(value)) {
      return 'Password must include at least one special character (!@#\$%^&*).';
    }
    return null;
  }
}