import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../screens/password_reset_screens.dart';

/// Remove this file and the app.dart hook after design review.
abstract final class PasswordResetPreview {
  static const selection = String.fromEnvironment('AUTH_PREVIEW');
  static Widget? screen() => screenFor(selection);

  static Widget? screenFor(String selection) {
    if (!kDebugMode) return null;
    return switch (selection) {
      'forgot' => const ForgotPasswordScreen(preview: true),
      'verify' => const EmailVerificationScreen.preview(),
      'reset' => const NewPasswordScreen.preview(),
      _ => null,
    };
  }
}
