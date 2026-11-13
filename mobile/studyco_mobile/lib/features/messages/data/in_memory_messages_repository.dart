import '../domain/messages_repository.dart';
import '../models/conversation.dart';

/// Local fixture authorization, separate from the API conversation projection.
class MockConversation {
  MockConversation({
    required this.conversation,
    required Set<String> participantIds,
    required this.createdAt,
    Iterable<Message> messages = const [],
  }) : participantIds = Set.unmodifiable(participantIds),
       messages = List.unmodifiable(messages);
  final Conversation conversation;
  final Set<String> participantIds;
  final DateTime createdAt;
  final List<Message> messages;
}

class InMemoryMessagesRepository extends MessagesRepository {
  InMemoryMessagesRepository({
    required this.userId,
    Iterable<MockConversation> rooms = const [],
  }) {
    final authorized =
        rooms
            .where(
              (r) =>
                  r.participantIds.contains(userId) &&
                  r.participantIds.length == 2 &&
                  r.participantIds.contains(r.conversation.counterpart.id) &&
                  r.conversation.counterpart.id != userId,
            )
            .toList()
          ..sort((a, b) {
            final time = b.createdAt.compareTo(a.createdAt);
            return time != 0
                ? time
                : b.conversation.id.compareTo(a.conversation.id);
          });
    final requests = <String>{};
    for (final room in authorized) {
      if (_rooms.containsKey(room.conversation.id) ||
          !requests.add(room.conversation.requestId)) {
        throw ArgumentError('Her başvuru için en fazla bir konuşma olabilir.');
      }
      final messages = mergeMessages(const [], room.messages);
      if (messages.any((m) => !room.participantIds.contains(m.senderId))) {
        throw ArgumentError('Mesaj gönderen konuşmanın katılımcısı olmalı.');
      }
      _messages[room.conversation.id] = messages;
      _rooms[room.conversation.id] = room.conversation.withMessages(
        messages,
        userId,
      );
    }
  }
  @override
  final String userId;
  final _rooms = <String, Conversation>{};
  final _messages = <String, List<Message>>{};
  final _cursors = <String, ({String resource, String anchor})>{};
  int _sequence = 0;
  bool _active = true;
  @override
  bool get isActive => _active;
  void _check() {
    if (!_active || userId.trim().isEmpty) {
      throw const MessagesFailure('Oturumun sona erdi.', code: 'UNAUTHORIZED');
    }
  }

  void _authorize(String id) {
    _check();
    if (!_rooms.containsKey(id)) {
      throw const MessagesFailure(
        'Konuşma bulunamadı veya bu konuşmaya erişimin yok.',
        code: 'NOT_A_PARTICIPANT',
      );
    }
  }

  String _id(Object? value) => switch (value) {
    Conversation c => c.id,
    Message m => m.id,
    _ => throw StateError('Geçersiz sayfa'),
  };
  @override
  Conversation? cachedConversation(String id) => _active ? _rooms[id] : null;
  @override
  int? get confirmedUnreadTotal =>
      !_active
          ? null
          : _rooms.values.fold<int>(0, (sum, c) => sum + c.unreadCount);
  MessagePage<T> _page<T>(
    String resource,
    List<T> values,
    int limit,
    String? cursor,
  ) {
    _check();
    validateMessageQuery(limit);
    var offset = 0;
    if (cursor != null) {
      final ticket = _cursors[cursor];
      if (ticket == null || ticket.resource != resource) {
        throw const MessagesFailure(
          'Sayfa bilgisi geçersiz. Listeyi yenile.',
          code: 'BAD_CURSOR',
        );
      }
      offset = values.indexWhere((value) => _id(value) == ticket.anchor) + 1;
      if (offset == 0) {
        throw const MessagesFailure(
          'Sayfa bilgisi geçersiz.',
          code: 'BAD_CURSOR',
        );
      }
    }
    final end = (offset + limit).clamp(0, values.length);
    String? next;
    if (end < values.length) {
      next = 'mock-${identityHashCode(this)}-${_sequence++}';
      _cursors[next] = (resource: resource, anchor: _id(values[end - 1]));
    }
    return MessagePage(
      items: values.sublist(offset.clamp(0, values.length), end),
      nextCursor: next,
    );
  }

  @override
  Future<MessagePage<Conversation>> fetchConversations({
    int limit = 20,
    String? cursor,
  }) async => _page('rooms', _rooms.values.toList(), limit, cursor);
  @override
  Future<Conversation> findConversation(String id) async {
    _authorize(id);
    return _rooms[id]!;
  }

  @override
  Future<MessagePage<Message>> fetchMessages(
    String conversationId, {
    int limit = 20,
    String? cursor,
  }) async {
    _authorize(conversationId);
    return _page(conversationId, _messages[conversationId]!, limit, cursor);
  }

  @override
  Future<Message> sendMessage(String conversationId, String body) async {
    _authorize(conversationId);
    final text = validatedMessage(body);
    final message = Message(
      id: 'mock-message-${identityHashCode(this)}-${_sequence++}',
      senderId: userId,
      body: text,
      sentAt: DateTime.now().toUtc(),
    );
    _messages[conversationId] = mergeMessages(_messages[conversationId]!, [
      message,
    ]);
    _rooms[conversationId] = _rooms[conversationId]!.withMessages(
      _messages[conversationId]!,
      userId,
    );
    notifyListeners();
    return message;
  }

  @override
  Future<void> markRead(String conversationId) async {
    _authorize(conversationId);
    final now = DateTime.now().toUtc();
    _messages[conversationId] = [
      for (final m in _messages[conversationId]!)
        if (m.senderId != userId) m.asRead(now) else m,
    ];
    _rooms[conversationId] = _rooms[conversationId]!.withMessages(
      _messages[conversationId]!,
      userId,
    );
    notifyListeners();
  }

  /// Called by the owner on logout, before sources are disposed after route unmount.
  void clearSession() {
    _rooms.clear();
    _messages.clear();
    _cursors.clear();
    _active = false;
  }

  @override
  void dispose() {
    clearSession();
    super.dispose();
  }
}
