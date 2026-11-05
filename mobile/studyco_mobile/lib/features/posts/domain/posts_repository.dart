import 'package:flutter/foundation.dart';
import '../models/post.dart';

/// Shared source for Home, Create Post and Search. Consumers subscribe
/// to changes; implementations own loading and persistence.
abstract class PostsRepository extends ChangeNotifier {
  List<Post> get posts;
  Future<void> refresh();
  Future<void> addPost(Post post);
}
