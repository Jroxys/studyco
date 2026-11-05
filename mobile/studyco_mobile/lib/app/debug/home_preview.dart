import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../features/home/screens/home_screen.dart';
import '../../features/posts/data/in_memory_posts_repository.dart';
import '../../features/posts/data/sample_posts.dart';
import '../../features/posts/screens/create_post_screen.dart';
import '../../features/posts/screens/post_details_screen.dart';
import 'home_preview_data.dart';

/// Composition root for demo data; no auth session is created.
abstract final class HomePreview {
  static const enabled = bool.fromEnvironment('HOME_PREVIEW');
  static Widget? screen() =>
      kDebugMode && enabled ? const _HomePreviewHost() : null;
}

class _HomePreviewHost extends StatefulWidget {
  const _HomePreviewHost();
  @override
  State<_HomePreviewHost> createState() => _HomePreviewHostState();
}

class _HomePreviewHostState extends State<_HomePreviewHost> {
  late final _repository = InMemoryPostsRepository(initialPosts: samplePosts());

  @override
  void dispose() {
    _repository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => HomeScreen(
    repository: _repository,
    user: sampleHomeUser,
    isPreview: true,
    onOpenPost:
        (post) => Navigator.of(context).push<void>(
          MaterialPageRoute<void>(
            builder:
                (_) => PostDetailsScreen(post: post, repository: _repository),
          ),
        ),
    onCreatePost:
        () => Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            builder:
                (_) => CreatePostScreen(
                  repository: _repository,
                  user: sampleHomeUser,
                ),
          ),
        ),
  );
}
