import 'package:flutter/widgets.dart';
import '../domain/reviews_repository.dart';

/// App-level dependency shared above Navigator; owns no repository lifecycle.
class ReviewsRepositoryScope extends InheritedWidget {
  const ReviewsRepositoryScope({
    super.key,
    required this.repository,
    required super.child,
  });
  final ReviewsRepository? repository;
  static ReviewsRepository? maybeOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<ReviewsRepositoryScope>()
          ?.repository;
  @override
  bool updateShouldNotify(ReviewsRepositoryScope oldWidget) =>
      repository != oldWidget.repository;
}
