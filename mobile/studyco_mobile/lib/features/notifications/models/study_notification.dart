enum NotificationKind {
  newApplication,
  applicationAccepted,
  applicationRejected,
  newMessage,
  lessonConfirmation,
}

enum NotificationTarget {
  incomingApplication,
  outgoingApplication,
  conversation,
}

class StudyNotification {
  const StudyNotification({
    required this.id,
    required this.recipientId,
    required this.kind,
    required this.title,
    required this.description,
    required this.createdAt,
    required this.target,
    this.targetId,
    this.isRead = false,
  });

  final String id;
  final String recipientId;
  final NotificationKind kind;
  final String title;
  final String description;
  final DateTime createdAt;
  final NotificationTarget target;
  final String? targetId;
  final bool isRead;

  StudyNotification asRead() => StudyNotification(
    id: id,
    recipientId: recipientId,
    kind: kind,
    title: title,
    description: description,
    createdAt: createdAt,
    target: target,
    targetId: targetId,
    isRead: true,
  );
}
