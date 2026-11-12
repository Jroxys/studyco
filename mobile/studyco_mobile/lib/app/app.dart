import '../features/posts/data/in_memory_posts_repository.dart';
import '../features/profile/data/in_memory_profile_repository.dart';
import '../features/profile/domain/profile_repository.dart';
import '../features/profile/widgets/profile_repository_scope.dart';
import '../features/reviews/models/review.dart';
import 'debug/home_preview_data.dart';
import 'debug/notifications_preview_data.dart';
import '../features/notifications/data/in_memory_notifications_repository.dart';
import '../features/notifications/domain/notifications_repository.dart';
import '../features/notifications/widgets/notifications_repository_scope.dart';
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

import '../core/data/remote_catalog.dart';
import '../core/session/auth_session.dart';
import '../core/session/auth_session_scope.dart';
import '../features/auth/screens/login_screen.dart';
import 'session/signed_in_home.dart';
import 'session/signed_in_services.dart';
import '../features/auth/widgets/session_logout_scope.dart';
import 'theme/app_theme.dart';
import 'debug/home_preview.dart';
import '../features/auth/debug/password_reset_preview.dart';

class MyApp extends StatefulWidget {
  const MyApp({
    super.key,
    this.locationCatalog,
    this.academicCatalog,
    this.reviewsRepository,
    this.profileRepository,
    this.notificationsRepository,
    this.session,
  });
  final LocationCatalog? locationCatalog;
  final AcademicCatalog? academicCatalog;
  final ReviewsRepository? reviewsRepository;
  final ProfileRepository? profileRepository;
  final NotificationsRepository? notificationsRepository;

  /// Login state and API client. Created (with secure token storage) when null.
  final AuthSession? session;
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ReviewsRepository? _previewReviews;
  InMemoryProfileRepository? _previewProfile;
  InMemoryPostsRepository? _previewPosts;
  InMemoryNotificationsRepository? _previewNotifications;
  bool _previewEnded = false;
  late final AuthSession _session = widget.session ?? AuthSession();
  SignedInServices? _services;
  AcademicCatalog? _registrationCatalog;

  Future<void> _endPreview() async {
    if (!mounted || _previewEnded || _previewPosts == null) return;
    final reviews = _previewReviews;
    final profile = _previewProfile;
    final posts = _previewPosts;
    final notifications = _previewNotifications;
    setState(() {
      _previewEnded = true;
      _previewReviews = null;
      _previewProfile = null;
      _previewPosts = null;
      _previewNotifications = null;
    });
    // Let the old Navigator and its listeners unmount before disposing sources.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reviews?.dispose();
      profile?.dispose();
      posts?.dispose();
      notifications?.dispose();
    });
  }

  void _configurePreview() {
    if (_previewEnded ||
        !kDebugMode ||
        !HomePreview.enabled ||
        PasswordResetPreview.screen() != null) {
      return;
    }
    _previewPosts ??= HomePreview.createRepository();
    if (widget.notificationsRepository == null) {
      _previewNotifications ??= InMemoryNotificationsRepository(
        userId: sampleHomeUser.postsOwnerId,
        initialNotifications: previewNotifications(
          _previewPosts!.applicationsRepository.applications,
        ),
      );
    }
    if (widget.profileRepository == null) {
      _previewProfile ??= InMemoryProfileRepository(
        initialProfile: sampleHomeUser,
        academicCatalog: widget.academicCatalog ?? previewProfileCatalog(),
      );
    }
    if (widget.reviewsRepository == null && _previewReviews == null) {
      _previewReviews = InMemoryReviewsRepository(
        applicationsRepository: _previewPosts!.applicationsRepository,
        authenticatedUser: () {
          final current =
              (widget.profileRepository ?? _previewProfile)?.current;
          final user =
              current?.id == sampleHomeUser.id ? current! : sampleHomeUser;
          return ReviewReviewer(
            id: user.postsOwnerId,
            firstName: user.firstName,
          );
        },
        initialByUser: previewReceivedReviews(),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _configurePreview();
    _session.addListener(_onSessionChanged);
    if (_session.status == SessionStatus.restoring) _session.restore();
    _syncServices();
    if (widget.academicCatalog == null && _previewPosts == null) {
      _loadRegistrationDepartments();
    }
  }

  /// Registration needs real department IDs before an account exists.
  Future<void> _loadRegistrationDepartments() async {
    try {
      final catalog = await RemoteCatalog(_session.api).departmentsOnly();
      if (mounted && catalog.departments.isNotEmpty) {
        setState(() => _registrationCatalog = catalog);
      }
    } catch (_) {
      // Registration explains that the list is unavailable and allows retry.
    }
  }

  void _onSessionChanged() {
    _syncServices();
    if (mounted) setState(() {});
  }

  /// One set of remote repositories per signed-in user; none when signed out.
  void _syncServices() {
    final user = _session.user;
    final signedIn = _session.status == SessionStatus.signedIn && user != null;
    final current = _services;
    if (signedIn ? current?.userId == user.id : current == null) return;
    current?.removeListener(_onServicesChanged);
    current?.dispose();
    _services = null;
    if (signedIn) {
      final next = SignedInServices(
        _session,
        initialAcademic: _registrationCatalog,
      );
      next.addListener(_onServicesChanged);
      _services = next;
      next.load();
    }
  }

  void _onServicesChanged() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(covariant MyApp oldWidget) {
    super.didUpdateWidget(oldWidget);
    _configurePreview();
  }

  @override
  void dispose() {
    _session.removeListener(_onSessionChanged);
    _services?.removeListener(_onServicesChanged);
    _services?.dispose();
    if (widget.session == null) _session.dispose();
    _previewReviews?.dispose();
    _previewProfile?.dispose();
    _previewPosts?.dispose();
    _previewNotifications?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final preview =
        _previewEnded
            ? null
            : PasswordResetPreview.screen() ??
                HomePreview.screen(repository: _previewPosts);
    final services = preview == null ? _services : null;
    return AuthSessionScope(
      notifier: _session,
      child: MaterialApp(
        key: ValueKey('$_previewEnded/${services?.userId}'),
        title: 'StudyCo',
        builder:
            (_, child) => LocationCatalogScope(
              catalog:
                  widget.locationCatalog ??
                  services?.locations ??
                  CampusLocations.catalog,
              child: AcademicCatalogScope(
                catalog:
                    widget.academicCatalog ??
                    services?.academic ??
                    _registrationCatalog ??
                    AcademicCatalog.temporary,
                child: ReviewsRepositoryScope(
                  repository:
                      services?.reviews ??
                      (_previewEnded
                          ? null
                          : widget.reviewsRepository ?? _previewReviews),
                  child: ProfileRepositoryScope(
                    repository:
                        services?.profile ??
                        (_previewEnded
                            ? null
                            : widget.profileRepository ?? _previewProfile),
                    child: SessionLogoutScope(
                      userId:
                          services?.userId ??
                          (_previewPosts == null ? null : sampleHomeUser.id),
                      endSession:
                          services != null ? _session.logout : _endPreview,
                      child: NotificationsRepositoryScope(
                        repository:
                            services?.notifications ??
                            (_previewEnded
                                ? null
                                : widget.notificationsRepository ??
                                    _previewNotifications),
                        child: child!,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home:
            preview != null
                ? null
                : services != null
                ? SignedInHome(services: services)
                : const LoginScreen(),
        onGenerateRoute:
            (_) => MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        onGenerateInitialRoutes:
            preview == null
                ? null
                : (_) {
                  return [
                    MaterialPageRoute<void>(
                      builder: (_) => const LoginScreen(),
                    ),
                    MaterialPageRoute<void>(builder: (_) => preview),
                  ];
                },
      ),
    );
  }
}
