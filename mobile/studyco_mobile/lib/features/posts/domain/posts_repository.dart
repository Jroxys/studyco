import 'package:flutter/foundation.dart';
import '../models/post.dart';
import '../../applications/domain/applications_repository.dart';

/// Shared source for Home, Create Post and Search. Consumers subscribe
/// to changes; implementations own loading and persistence.
abstract class PostsRepository extends ChangeNotifier {
  /// Complete retained snapshot, including personal history.
  List<Post> get posts;

  /// Public discovery projection. Never discard history from [posts].
  /// Remote adapters must also request only server-authorized open listings.
  List<Post> get discoverablePosts => List.unmodifiable(
    posts.where(
      (post) =>
          applicationsRepository?.isPostOpenForApplications(post) ?? false,
    ),
  );

  /// Shared application source for every route using this listing session.
  /// A real adapter must inject its own implementation; no implicit mock fallback.
  ApplicationsRepository? get applicationsRepository => null;
  Future<void> refresh();
  Future<void> addPost(Post post);

  /// Check the stored snapshot, never the edited payload (which may change dates).
  /// Every writable adapter must call this before mutation. Remote services must
  /// also enforce ownership and expiry atomically using authoritative server time.
  Post requireMutablePost(String id, {required String ownerId}) {
    final matches = posts.where((post) => post.id == id);
    if (matches.isEmpty || matches.first.authorId != ownerId) {
      throw StateError('İlan bulunamadı veya bu işlem için yetkiniz yok.');
    }
    final post = matches.first;
    if (post.status != PostStatus.published) {
      throw StateError('Rezerve edilmiş veya kapalı ilanlar değiştirilemez.');
    }
    if (post.isExpiredAt(DateTime.now())) {
      throw StateError('Geçmiş ilanlar yalnızca görüntülenebilir.');
    }
    return post;
  }

  /// Local unit-of-work seam. Real request adapters use the server transaction
  /// and then refresh both snapshots, never emulate it with this callback.
  void commitBooking(
    String id, {
    required String ownerId,
    required VoidCallback commitApplications,
  }) =>
      throw UnsupportedError(
        'İlan rezervasyonu bu veri kaynağında desteklenmiyor.',
      );

  // Remote adapters must opt in only after verifying their update contract.
  bool get supportsFullPostEditing => false;
  Future<void> updatePost(Post post, {required String ownerId}) =>
      Future.error(UnsupportedError('İlan güncelleme desteklenmiyor.'));
  Future<void> deletePost(String id, {required String ownerId}) =>
      Future.error(UnsupportedError('İlan silme desteklenmiyor.'));
}
