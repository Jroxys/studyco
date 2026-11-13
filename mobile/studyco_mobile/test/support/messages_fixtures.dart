import 'dart:async';
import 'package:studyco_mobile/features/applications/models/application.dart';
import 'package:studyco_mobile/features/messages/data/in_memory_messages_repository.dart';
import 'package:studyco_mobile/features/messages/domain/messages_repository.dart';
import 'package:studyco_mobile/features/messages/models/conversation.dart';

final messageEpoch = DateTime.utc(2026, 11, 1);
Message message(
  String id, {
  String sender = 'other',
  int minute = 0,
  DateTime? readAt,
}) => Message(
  id: id,
  senderId: sender,
  body: 'Mesaj $id',
  sentAt: messageEpoch.add(Duration(minutes: minute)),
  readAt: readAt,
);
MockConversation room(
  String id, {
  String owner = 'me',
  String other = 'other',
  int day = 0,
  List<Message>? messages,
}) => MockConversation(
  participantIds: {owner, other},
  createdAt: messageEpoch.add(Duration(days: day)),
  conversation: Conversation(
    id: id,
    requestId: 'request-$id',
    listingId: 'listing-$id',
    topic: 'Ders $id',
    counterpart: ApplicationPerson(
      id: other,
      firstName: 'Deniz',
      lastNameInitial: 'Y',
      departmentId: 'department',
    ),
    unreadCount: 0,
  ),
  messages:
      messages ??
      [
        message('1'),
        message('2', sender: owner, minute: 1),
        message('3', minute: 2),
      ],
);

class ControlledMessages extends InMemoryMessagesRepository {
  ControlledMessages({List<MockConversation>? rooms})
    : super(userId: 'me', rooms: rooms ?? [room('room')]);
  bool failRead = false, failSend = false, failLoad = false;
  int sends = 0, loads = 0, reads = 0;
  Completer<void>? pendingSend, pendingLoad;
  @override
  Future<Message> sendMessage(String id, String body) async {
    sends++;
    await pendingSend?.future;
    if (failSend) {
      throw const MessagesFailure(
        'Gönderim sonucu doğrulanamadı.',
        deliveryUncertain: true,
      );
    }
    return super.sendMessage(id, body);
  }

  @override
  Future<void> markRead(String id) async {
    reads++;
    if (failRead) throw const MessagesFailure('Okundu işlemi başarısız.');
    await super.markRead(id);
  }

  @override
  Future<MessagePage<Conversation>> fetchConversations({
    int limit = 20,
    String? cursor,
  }) async {
    loads++;
    await pendingLoad?.future;
    if (failLoad) throw const MessagesFailure('Konuşmalar yüklenemedi.');
    return super.fetchConversations(limit: limit, cursor: cursor);
  }
}
