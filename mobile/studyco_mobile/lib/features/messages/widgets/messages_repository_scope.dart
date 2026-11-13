import 'package:flutter/widgets.dart';
import '../domain/messages_repository.dart';

class MessagesRepositoryScope extends InheritedNotifier<MessagesRepository> {
  const MessagesRepositoryScope({
    super.key,
    required MessagesRepository? repository,
    required super.child,
  }) : super(notifier: repository);
  static MessagesRepository? forUser(BuildContext context, String? userId) {
    final source =
        context
            .dependOnInheritedWidgetOfExactType<MessagesRepositoryScope>()
            ?.notifier;
    return userId != null &&
            userId.isNotEmpty &&
            source?.userId == userId &&
            source!.isActive
        ? source
        : null;
  }
}
