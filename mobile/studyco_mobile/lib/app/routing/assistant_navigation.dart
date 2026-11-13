import 'package:flutter/material.dart';
import '../../features/assistant/models/assistant_content.dart';
import '../../features/applications/screens/applications_screen.dart';
import '../../features/messages/screens/conversations_screen.dart';
import '../../features/messages/widgets/messages_repository_scope.dart';
import '../../features/notifications/screens/notifications_screen.dart';
import '../../features/notifications/widgets/notifications_repository_scope.dart';
import '../../features/posts/domain/posts_repository.dart';
import '../../features/profile/models/user_profile.dart';
import '../../features/profile/screens/my_posts_screen.dart';
import '../../features/settings/screens/settings_screen.dart';

/// Composes existing routes; content never supplies a URL, widget or executable action.
abstract final class AssistantNavigation {
  static Map<AssistantDestination, VoidCallback> actions(
    BuildContext context, {
    required UserProfile user,
    required PostsRepository posts,
    required VoidCallback onHome,
    required VoidCallback onSearch,
    required VoidCallback onProfile,
    VoidCallback? onCreatePost,
  }) {
    void open(WidgetBuilder builder) =>
        Navigator.of(context).push<void>(MaterialPageRoute(builder: builder));
    final applications = posts.applicationsRepository;
    final messages = MessagesRepositoryScope.forUser(context, user.id);
    final notifications = NotificationsRepositoryScope.forUser(
      context,
      user.id,
    );
    return {
      AssistantDestination.home: onHome,
      AssistantDestination.search: onSearch,
      if (onCreatePost != null) AssistantDestination.createPost: onCreatePost,
      AssistantDestination.profile: onProfile,
      AssistantDestination.myPosts:
          () => open((_) => MyPostsScreen(repository: posts, user: user)),
      if (applications != null) ...{
        AssistantDestination.applications:
            () => open(
              (_) => ApplicationsScreen(
                postsRepository: posts,
                repository: applications,
                user: user,
                onBrowse: onSearch,
              ),
            ),
        AssistantDestination.incomingApplications:
            () => open(
              (_) => ApplicationsScreen(
                postsRepository: posts,
                repository: applications,
                user: user,
                incoming: true,
              ),
            ),
      },
      if (messages != null)
        AssistantDestination.messages:
            () => open(
              (_) => ConversationsScreen(repository: messages, userId: user.id),
            ),
      if (notifications != null)
        AssistantDestination.notifications:
            () => open(
              (_) => NotificationsScreen(
                user: user,
                repository: notifications,
                postsRepository: posts,
              ),
            ),
      AssistantDestination.settings:
          () => open((_) => SettingsScreen(user: user)),
    };
  }
}
