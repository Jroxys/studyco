import 'package:flutter/widgets.dart';

import 'auth_session.dart';

/// Gives auth screens the app's [AuthSession]. Absent in isolated widget tests.
class AuthSessionScope extends InheritedNotifier<AuthSession> {
  const AuthSessionScope({
    super.key,
    required AuthSession super.notifier,
    required super.child,
  });

  static AuthSession? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AuthSessionScope>()?.notifier;
}
