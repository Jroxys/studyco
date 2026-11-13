import '../../applications/models/application.dart';

class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.body,
    required this.sentAt,
    this.readAt,
  });
  final String id, senderId, body;
  final DateTime sentAt;
  final DateTime? readAt;
  factory Message.fromJson(Map<String, dynamic> json) => Message(
    id: _text(json, 'id'),
    senderId: _text(json, 'senderId'),
    body: _text(json, 'body'),
    sentAt: _date(json['sentAt']),
    readAt: json['readAt'] == null ? null : _date(json['readAt']),
  );
  Message asRead(DateTime at) => Message(
    id: id,
    senderId: senderId,
    body: body,
    sentAt: sentAt,
    readAt: readAt ?? at,
  );
}

class Conversation {
  const Conversation({
    required this.id,
    required this.requestId,
    required this.listingId,
    required this.topic,
    required this.counterpart,
    this.lastMessage,
    required this.unreadCount,
  });
  final String id, requestId, listingId, topic;
  final ApplicationPerson counterpart;
  final Message? lastMessage;
  final int unreadCount;
  factory Conversation.fromJson(Map<String, dynamic> json) {
    final listing = json['listing'] as Map<String, dynamic>;
    final person = json['counterpart'] as Map<String, dynamic>;
    final count = json['unreadCount'];
    if (count is! int || count < 0) {
      throw const FormatException('Geçersiz mesaj sayısı');
    }
    return Conversation(
      id: _text(json, 'id'),
      requestId: _text(json, 'requestId'),
      listingId: _text(listing, 'id'),
      topic: _text(listing, 'topic'),
      counterpart: ApplicationPerson(
        id: _text(person, 'id'),
        firstName: _text(person, 'firstName'),
        lastNameInitial: _text(person, 'lastNameInitial'),
        departmentId: _text(person, 'departmentId'),
      ),
      lastMessage:
          json['lastMessage'] == null
              ? null
              : Message.fromJson(json['lastMessage'] as Map<String, dynamic>),
      unreadCount: count,
    );
  }
  Conversation withMessages(List<Message> newestFirst, String userId) =>
      Conversation(
        id: id,
        requestId: requestId,
        listingId: listingId,
        topic: topic,
        counterpart: counterpart,
        lastMessage: newestFirst.firstOrNull,
        unreadCount:
            newestFirst
                .where((m) => m.senderId != userId && m.readAt == null)
                .length,
      );
}

String _text(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('Eksik alan: $key');
  }
  return value;
}

DateTime _date(Object? value) {
  if (value is! String) throw const FormatException('Geçersiz tarih');
  return DateTime.parse(value).toUtc();
}

/// Preserve server conversation order; only messages are merged by their key.
List<Message> mergeMessages(Iterable<Message> old, Iterable<Message> fresh) {
  final byId = {
    for (final message in old) message.id: message,
    for (final message in fresh) message.id: message,
  };
  return byId.values.toList()..sort((a, b) {
    final time = b.sentAt.compareTo(a.sentAt);
    return time != 0 ? time : b.id.compareTo(a.id);
  });
}
