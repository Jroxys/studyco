import '../domain/posts_repository.dart';
import '../models/post.dart';
import '../../applications/models/application.dart';
import 'package:flutter/foundation.dart';
import '../../applications/data/in_memory_applications_repository.dart';

/// Session-only data. No disk, network, authentication or database writes.
class InMemoryPostsRepository extends PostsRepository {
  InMemoryPostsRepository({
    Iterable<Post> initialPosts = const [],
    Iterable<Application> initialApplications = const [],
  }) : _posts = List.of(initialPosts),
       _initialApplications = List.of(initialApplications);
  final List<Post> _posts;
  final List<Application> _initialApplications;
  InMemoryApplicationsRepository? _applicationsRepository;
  @override
  InMemoryApplicationsRepository get applicationsRepository =>
      _applicationsRepository ??= InMemoryApplicationsRepository(
        postsRepository: this,
        initialApplications: _initialApplications,
      );
  @override
  void dispose() {
    _applicationsRepository?.dispose();
    super.dispose();
  }

  @override
  List<Post> get posts => List.unmodifiable(_posts);
  @override
  bool get supportsFullPostEditing => true;
  int _ownedIndex(String id, String ownerId) {
    requireMutablePost(id, ownerId: ownerId);
    return _posts.indexWhere((post) => post.id == id);
  }

  @override
  void commitBooking(
    String id, {
    required String ownerId,
    required VoidCallback commitApplications,
  }) {
    final index = _ownedIndex(id, ownerId);
    final original = _posts[index];
    if (!original.startsAt.isAfter(DateTime.now())) {
      throw StateError('Ders başlamış.');
    }
    _posts[index] = original.copyWith(status: PostStatus.booked);
    try {
      commitApplications();
    } catch (_) {
      _posts[index] = original;
      rethrow;
    }
    // Observers see both updated snapshots, never an intermediate application state.
    notifyListeners();
  }

  @override
  Future<void> updatePost(Post post, {required String ownerId}) async {
    final index = _ownedIndex(post.id, ownerId);
    if (post.status != _posts[index].status) {
      throw StateError(
        'İlan durumu yalnızca başvuru işlemiyle değiştirilebilir.',
      );
    }
    if (post.authorId != ownerId) {
      throw StateError('İlan sahibi değiştirilemez.');
    }
    _posts[index] = post;
    notifyListeners();
  }

  @override
  Future<void> deletePost(String id, {required String ownerId}) async {
    _posts.removeAt(_ownedIndex(id, ownerId));
    notifyListeners();
  }

  @override
  Future<void> refresh() async {}
  @override
  Future<void> addPost(Post post) async {
    if (_posts.any((item) => item.id == post.id)) {
      throw ArgumentError.value(
        post.id,
        'id',
        'İlan kimliği benzersiz olmalı.',
      );
    }
    _posts.add(post);
    notifyListeners();
  }
}
