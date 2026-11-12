import 'package:flutter/material.dart';

import '../../features/home/screens/home_screen.dart';
import '../../features/posts/screens/create_post_screen.dart';
import '../../features/posts/screens/post_details_screen.dart';
import 'signed_in_services.dart';

/// Home for a real account, wired to the remote repositories.
class SignedInHome extends StatelessWidget {
  const SignedInHome({super.key, required this.services});
  final SignedInServices services;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: services.profile,
    builder: (context, _) {
      final user = services.profile.current;
      return HomeScreen(
        repository: services.posts,
        user: user,
        onOpenPost:
            (post) => Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder:
                    (_) => PostDetailsScreen(
                      post: post,
                      repository: services.posts,
                      user: user,
                    ),
              ),
            ),
        onCreatePost:
            () => Navigator.of(context).push<bool>(
              MaterialPageRoute<bool>(
                builder:
                    (_) => CreatePostScreen(
                      repository: services.posts,
                      user: user,
                    ),
              ),
            ),
      );
    },
  );
}
