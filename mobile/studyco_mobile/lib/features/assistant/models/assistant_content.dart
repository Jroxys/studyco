/// Local navigation keys, not a backend API contract or arbitrary route names.
enum AssistantDestination {
  home,
  search,
  createPost,
  profile,
  myPosts,
  applications,
  incomingApplications,
  messages,
  notifications,
  settings;

  static AssistantDestination? fromKey(String? key) {
    for (final destination in values) {
      if (destination.name == key) return destination;
    }
    return null;
  }
}

class AssistantOption {
  const AssistantOption({
    required this.id,
    required this.title,
    required this.answer,
    this.destination,
  });
  final String id, title, answer;

  /// Unknown content keys remain unsupported; they are never pushed as routes.
  final String? destination;
}

class AssistantContent {
  AssistantContent({
    required this.greeting,
    required Iterable<AssistantOption> options,
    this.isDemo = false,
  }) : options = List.unmodifiable(options);
  final String greeting;
  final List<AssistantOption> options;
  final bool isDemo;
}

/// A single response, independent of a predefined option or any future wire format.
class AssistantReply {
  const AssistantReply({
    required this.answer,
    this.destination,
    this.isDemo = false,
  });
  final String answer;
  final String? destination;
  final bool isDemo;
}
