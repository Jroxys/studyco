import 'registration_validators.dart';

abstract final class PasswordResetValidators {
  static String? email(String? value) => RegistrationValidators.email(value);
  static String? password(String? value) =>
      RegistrationValidators.password(value);
  static String? confirmation(String? value, String password) =>
      RegistrationValidators.confirmPassword(value, password);
  static String? code(String? value) =>
      RegExp(r'^\d{6}$').hasMatch(value ?? '')
          ? null
          : 'Altı haneli doğrulama kodunu girin.';

  static String maskEmail(String email) {
    final parts = email.trim().split('@');
    if (parts.length != 2 || parts.first.isEmpty || parts.last.isEmpty) {
      return '***';
    }
    return '${parts.first.substring(0, 1)}***@${parts.last}';
  }
}
