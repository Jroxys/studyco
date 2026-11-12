import 'package:flutter/widgets.dart';

import '../../core/api/api_client.dart';
import '../../core/data/academic_catalog.dart';
import '../../core/data/remote_catalog.dart';
import '../../core/session/auth_session.dart';
import '../../features/notifications/data/request_notifications_repository.dart';
import '../../features/posts/data/campus_locations.dart';
import '../../features/posts/data/remote_posts_repository.dart';
import '../../features/posts/domain/location_catalog.dart';
import '../../features/profile/data/remote_profile_repository.dart';
import '../../features/reviews/data/remote_reviews_repository.dart';

/// Everything the signed-in user's screens share, created once per login.
class SignedInServices extends ChangeNotifier {
  SignedInServices(this.session, {AcademicCatalog? initialAcademic})
    : userId = session.user!.id,
      _academic = initialAcademic ?? AcademicCatalog.temporary {
    posts = RemotePostsRepository(
      api: session.api,
      userId: userId,
      academicCatalog: () => _academic,
      locationCatalog: () => _locations,
    );
    profile = RemoteProfileRepository(
      session: session,
      academicCatalog: () => _academic,
    );
    reviews = RemoteReviewsRepository(
      api: session.api,
      userId: userId,
      applicationsRepository: posts.applicationsRepository,
    );
    notifications = RequestNotificationsRepository(
      userId: userId,
      applications: posts.applicationsRepository,
    );
  }

  final AuthSession session;
  final String userId;
  late final RemotePostsRepository posts;
  late final RemoteProfileRepository profile;
  late final RemoteReviewsRepository reviews;
  late final RequestNotificationsRepository notifications;

  AcademicCatalog _academic;
  LocationCatalog _locations = CampusLocations.catalog;
  String? loadError;
  bool _disposed = false;

  AcademicCatalog get academic => _academic;
  LocationCatalog get locations => _locations;

  /// Loads the real catalogs; listings refresh themselves when Home opens.
  Future<void> load() async {
    final catalog = RemoteCatalog(session.api);
    try {
      final results = await Future.wait([
        catalog.academic(),
        catalog.locations(),
      ]);
      if (_disposed) return;
      _academic = results[0] as AcademicCatalog;
      _locations = results[1] as LocationCatalog;
      loadError = null;
      await profile.fetchProfile().catchError((_) => profile.current);
      if (_disposed) return;
      await posts.refreshQuietly();
    } catch (error) {
      loadError = apiErrorMessage(
        error,
        fallback: 'Ders ve konum listesi yüklenemedi.',
      );
    }
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    // Let routes that listen to these sources unmount first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifications.dispose();
      reviews.dispose();
      profile.dispose();
      posts.dispose();
    });
    super.dispose();
  }
}
