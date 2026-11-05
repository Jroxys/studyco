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
  static Widget? screen({InMemoryPostsRepository? repository}) =>
      kDebugMode && enabled ? _HomePreviewHost(repository: repository) : null;
  static InMemoryPostsRepository createRepository() {
    final ownPost = previewIncomingPost();
    return InMemoryPostsRepository(
      initialPosts: [previewApplicationPost(), ownPost, ...samplePosts()],
      initialApplications: [
        ...previewIncomingApplications(ownPost),
        ...previewCompletedApplications(),
      ],
    );
  }
}

class _HomePreviewHost extends StatefulWidget {
  const _HomePreviewHost({this.repository});
  final InMemoryPostsRepository? repository;
  @override
  State<_HomePreviewHost> createState() => _HomePreviewHostState();
}

class _HomePreviewHostState extends State<_HomePreviewHost> {
  late final _repository = widget.repository ?? HomePreview.createRepository();

  @override
  void dispose() {
    if (widget.repository == null) _repository.dispose();
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
                (_) => PostDetailsScreen(
                  post: post,
                  repository: _repository,
                  user: sampleHomeUser,
                ),
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
