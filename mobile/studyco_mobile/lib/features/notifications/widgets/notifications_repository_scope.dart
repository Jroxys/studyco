import 'package:flutter/widgets.dart';
import '../domain/notifications_repository.dart';

class NotificationsRepositoryScope
    extends InheritedNotifier<NotificationsRepository> {
  const NotificationsRepositoryScope({
    super.key,
    required NotificationsRepository? repository,
    required super.child,
  }) : super(notifier: repository);

  static NotificationsRepository? forUser(
    BuildContext context,
    String? userId,
  ) {
    if (userId == null || userId.trim().isEmpty) return null;
    final source =
        context
            .dependOnInheritedWidgetOfExactType<NotificationsRepositoryScope>()
            ?.notifier;
    return source?.userId == userId ? source : null;
  }
}
