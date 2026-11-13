import '../../features/applications/models/application.dart';
import '../../features/messages/data/in_memory_messages_repository.dart';
import '../../features/messages/models/conversation.dart';
import 'home_preview_data.dart';

InMemoryMessagesRepository previewMessages(List<Application> applications) {
  final now = DateTime.now().toUtc();
  final accepted =
      applications
          .where(
            (a) =>
                a.status == ApplicationStatus.accepted &&
                a.conversationId != null &&
                a.participantFor(sampleHomeUser.id!) != null,
          )
          .toList();
  return InMemoryMessagesRepository(
    userId: sampleHomeUser.id!,
    rooms: [
      for (var i = 0; i < accepted.length; i++) _room(accepted[i], i, now),
    ],
  );
}

MockConversation _room(Application a, int index, DateTime now) {
  final other = a.applicantId == sampleHomeUser.id ? a.teacher! : a.applicant!;
  final messages =
      index == 1
          ? <Message>[]
          : [
            Message(
              id: 'mock-${a.id}-1',
              senderId: other.id,
              body: 'Merhaba, birlikte çalışacağımız konuya hazır mısın?',
              sentAt: now.subtract(const Duration(days: 1)),
              readAt: now.subtract(const Duration(hours: 4)),
            ),
            Message(
              id: 'mock-${a.id}-2',
              senderId: sampleHomeUser.id!,
              body: 'Merhaba! Notlarımı hazırladım, teşekkürler.',
              sentAt: now.subtract(const Duration(hours: 3)),
              readAt: now.subtract(const Duration(hours: 2)),
            ),
            Message(
              id: 'mock-${a.id}-3',
              senderId: other.id,
              body:
                  'Harika! Önce temel örnekleri birlikte inceleyelim. Ardından zorlandığın soruların çözümünü adım adım konuşabiliriz. Notlarını da yanında getirmen iyi olur.',
              sentAt: now.subtract(Duration(minutes: 15 + index)),
            ),
          ];
  return MockConversation(
    participantIds: {a.applicantId, a.teacherId!},
    createdAt: now.subtract(Duration(days: index + 1)),
    conversation: Conversation(
      id: a.conversationId!,
      requestId: a.id,
      listingId: a.postId,
      topic: a.listing?.topic ?? 'Örnek ders',
      counterpart: other,
      unreadCount: 0,
    ),
    messages: messages,
  );
}
