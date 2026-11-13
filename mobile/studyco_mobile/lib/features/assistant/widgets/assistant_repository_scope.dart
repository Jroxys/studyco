import 'package:flutter/widgets.dart';
import '../domain/assistant_repository.dart';

class AssistantRepositoryScope extends InheritedWidget {
  const AssistantRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });
  final AssistantRepository repository;
  static AssistantRepository? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AssistantRepositoryScope>()
          ?.repository;
  @override
  bool updateShouldNotify(AssistantRepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
