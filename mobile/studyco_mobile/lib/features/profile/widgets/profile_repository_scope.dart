import 'package:flutter/widgets.dart';
import '../domain/profile_repository.dart';
import '../models/user_profile.dart';

class ProfileRepositoryScope extends InheritedNotifier<ProfileRepository> {
  const ProfileRepositoryScope({
    super.key,
    required ProfileRepository? repository,
    required super.child,
  }) : super(notifier: repository);

  static ProfileRepository? forUser(BuildContext context, UserProfile user) {
    final id = user.id;
    if (id == null || id.trim().isEmpty) return null;
    final source =
        context
            .dependOnInheritedWidgetOfExactType<ProfileRepositoryScope>()
            ?.notifier;
    return source?.userId == id ? source : null;
  }

  static UserProfile currentOf(BuildContext context, UserProfile fallback) {
    final current = forUser(context, fallback)?.current;
    return current != null && current.id == fallback.id ? current : fallback;
  }
}
