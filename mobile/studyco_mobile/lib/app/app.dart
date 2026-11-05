import '../features/posts/data/in_memory_posts_repository.dart';
import '../features/reviews/models/review.dart';
import 'debug/home_preview_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../features/reviews/domain/reviews_repository.dart';
import '../features/reviews/data/in_memory_reviews_repository.dart';
import '../features/reviews/widgets/reviews_repository_scope.dart';
import 'debug/reviews_preview_data.dart';
import '../core/data/academic_catalog.dart';
import '../core/widgets/academic_catalog_scope.dart';
import '../features/posts/domain/location_catalog.dart';
import '../features/posts/widgets/location_catalog_scope.dart';
import '../features/posts/data/campus_locations.dart';

import '../features/auth/screens/login_screen.dart';
import 'theme/app_theme.dart';
import 'debug/home_preview.dart';
import '../features/auth/debug/password_reset_preview.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.locationCatalog,
    this.academicCatalog,
    this.reviewsRepository,
  });
  final LocationCatalog? locationCatalog;
  final AcademicCatalog? academicCatalog;
  final ReviewsRepository? reviewsRepository;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ReviewsRepository? _previewReviews;
  InMemoryPostsRepository? _previewPosts;
  void _configurePreview() {
    if (widget.reviewsRepository == null &&
        _previewReviews == null &&
        kDebugMode &&
        HomePreview.enabled &&
        PasswordResetPreview.screen() == null) {
      _previewPosts ??= HomePreview.createRepository();
      _previewReviews = InMemoryReviewsRepository(
        applicationsRepository: _previewPosts!.applicationsRepository,
        authenticatedUser:
            () => ReviewReviewer(
              id: sampleHomeUser.postsOwnerId,
              firstName: sampleHomeUser.firstName,
            ),
        initialByUser: previewReceivedReviews(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _configurePreview();
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configurePreview();
  }

  @override
  void dispose() {
    _previewReviews?.dispose();
    _previewPosts?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview =
        PasswordResetPreview.screen() ??
        HomePreview.screen(repository: _previewPosts);
    return MaterialApp(
      title: 'StudyCo',
      builder:
          (_, child) => LocationCatalogScope(
            catalog: widget.locationCatalog ?? CampusLocations.catalog,
            child: AcademicCatalogScope(
              catalog: widget.academicCatalog ?? AcademicCatalog.temporary,
              child: ReviewsRepositoryScope(
                repository: widget.reviewsRepository ?? _previewReviews,
                child: child!,
              ),
            ),
          ),
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: preview == null ? const LoginScreen() : null,
      onGenerateRoute:
          (_) => MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
      onGenerateInitialRoutes:
          preview == null
              ? null
              : (_) {
                return [
                  MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
                  MaterialPageRoute<void>(builder: (_) => preview),
                ];
              },
    );
  }
}
