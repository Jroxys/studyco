import '../domain/posts_repository.dart';
import '../models/post.dart';

/// Session-only data. No disk, network, authentication or database writes.
class InMemoryPostsRepository extends PostsRepository {
  InMemoryPostsRepository({Iterable<Post> initialPosts = const []})
    : _posts = List.of(initialPosts);
  final List<Post> _posts;
  @override
  List<Post> get posts => List.unmodifiable(_posts);
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
