import 'package:flutter/material.dart';
import '../../posts/domain/posts_repository.dart';
import '../../posts/screens/create_post_screen.dart';
import '../../search/screens/search_screen.dart';
import '../models/user_profile.dart';
import '../screens/profile_screen.dart';

/// Keeps the source route alive so forms and search criteria survive Back.
abstract final class ProfileNavigation {
  static Future<void> open(
    BuildContext context, {
    required UserProfile user,
    required PostsRepository repository,
    required int sourceIndex,
    required VoidCallback onHome,
  }) {
    final navigator = Navigator.of(context);
    return navigator.push<void>(
      MaterialPageRoute(
        builder:
            (_) => ProfileScreen(
              user: user,
              onDestination: (index) {
                if (index == sourceIndex) {
                  navigator.pop();
                  return;
                }
                if (index == 0) {
                  navigator.pop();
                  onHome();
                  return;
                }
                void returnHome() {
                  navigator.pop();
                  navigator.pop();
                  onHome();
                }

                if (index == 1) {
                  navigator.push<bool>(
                    MaterialPageRoute(
                      builder:
                          (_) => CreatePostScreen(
                            repository: repository,
                            user: user,
                            onHome: returnHome,
                          ),
                    ),
                  );
                } else if (index == 2) {
                  navigator.push<void>(
                    MaterialPageRoute(
                      builder:
                          (_) => SearchScreen(
                            repository: repository,
                            user: user,
                            onHome: returnHome,
                          ),
                    ),
                  );
                }
              },
            ),
      ),
    );
  }
}
