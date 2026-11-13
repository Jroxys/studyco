import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/features/messages/data/in_memory_messages_repository.dart';
import 'package:studyco_mobile/features/messages/domain/messages_repository.dart';
import 'package:studyco_mobile/features/messages/models/conversation.dart';
import 'support/messages_fixtures.dart';

void main() {
  test('conversation order uses creation and id, never last message', () async {
    final source = InMemoryMessagesRepository(
      userId: 'me',
      rooms: [
        room('a', day: 1),
        room('b', day: 1),
        room('old', messages: [message('recent', minute: 9999)]),
      ],
    );
    addTearDown(source.dispose);
    final first = await source.fetchConversations(limit: 1);
    expect(first.items.single.id, 'b');
    final next = await source.fetchConversations(
      limit: 1,
      cursor: first.nextCursor,
    );
    expect(next.items.single.id, 'a');
    await source.sendMessage('old', 'new');
    expect((await source.fetchConversations()).items.map((c) => c.id), [
      'b',
      'a',
      'old',
    ]);
  });
  test(
    'message pages keep descending timestamp/id, stable across inserts',
    () async {
      final source = InMemoryMessagesRepository(
        userId: 'me',
        rooms: [
          room(
            'room',
            messages: [message('a'), message('b'), message('c'), message('d')],
          ),
        ],
      );
      addTearDown(source.dispose);
      final first = await source.fetchMessages('room', limit: 2);
      expect(first.items.map((m) => m.id), ['d', 'c']);
      await source.sendMessage('room', 'new');
      final second = await source.fetchMessages(
        'room',
        limit: 2,
        cursor: first.nextCursor,
      );
      expect(second.items.map((m) => m.id), ['b', 'a']);
      expect(second.nextCursor, isNull);
      expect(
        mergeMessages(first.items, [...first.items, ...second.items]).length,
        4,
      );
    },
  );
  test('cursor cannot cross repository, conversation or resource', () async {
    final source = InMemoryMessagesRepository(
      userId: 'me',
      rooms: [room('a'), room('b')],
    );
    final other = InMemoryMessagesRepository(userId: 'me', rooms: [room('a')]);
    addTearDown(source.dispose);
    addTearDown(other.dispose);
    final cursor = (await source.fetchMessages('a', limit: 1)).nextCursor;
    for (final call in [
      source.fetchMessages('b', cursor: cursor),
      source.fetchConversations(cursor: cursor),
      other.fetchMessages('a', cursor: cursor),
      source.fetchMessages('a', cursor: 'bad'),
    ]) {
      await expectLater(call, throwsA(isA<MessagesFailure>()));
    }
    for (final size in [0, 51]) {
      await expectLater(
        source.fetchConversations(limit: size),
        throwsA(isA<MessagesFailure>()),
      );
    }
  });
  test(
    'mark read covers every incoming page and leaves own messages unread',
    () async {
      final source = InMemoryMessagesRepository(
        userId: 'me',
        rooms: [
          room(
            'room',
            messages: [
              for (var i = 0; i < 30; i++) message('$i', minute: i),
              message('own', sender: 'me'),
            ],
          ),
        ],
      );
      addTearDown(source.dispose);
      expect(source.confirmedUnreadTotal, 30);
      await source.fetchMessages('room');
      expect(source.confirmedUnreadTotal, 30);
      await source.markRead('room');
      await source.markRead('room');
      expect(source.confirmedUnreadTotal, 0);
      expect((await source.findConversation('room')).unreadCount, 0);
      final page = await source.fetchMessages('room', limit: 50);
      expect(
        page.items
            .where((m) => m.senderId != 'me')
            .every((m) => m.readAt != null),
        isTrue,
      );
      expect(page.items.singleWhere((m) => m.id == 'own').readAt, isNull);
    },
  );
  test('failed read does not mutate unread snapshot', () async {
    final source = ControlledMessages()..failRead = true;
    addTearDown(source.dispose);
    await expectLater(source.markRead('room'), throwsA(isA<MessagesFailure>()));
    expect(source.confirmedUnreadTotal, 2);
  });
  test('send derives identity, trims and validates UTF16 length', () async {
    final source = ControlledMessages();
    addTearDown(source.dispose);
    for (final body in ['', '   ', 'x' * 2001, '😀' * 1001]) {
      await expectLater(
        source.sendMessage('room', body),
        throwsA(isA<MessagesFailure>()),
      );
    }
    final sent = await source.sendMessage('room', '  Merhaba  ');
    expect(sent.senderId, 'me');
    expect(sent.body, 'Merhaba');
    expect(sent.readAt, isNull);
    expect((await source.sendMessage('room', 'x' * 2000)).body.length, 2000);
  });
  test(
    'foreign fixtures are excluded and all access paths reject unknown ids',
    () async {
      final source = InMemoryMessagesRepository(
        userId: 'me',
        rooms: [room('mine'), room('foreign', owner: 'someone')],
      );
      final stranger = InMemoryMessagesRepository(
        userId: 'stranger',
        rooms: [room('mine')],
      );
      addTearDown(source.dispose);
      addTearDown(stranger.dispose);
      expect((await source.fetchConversations()).items.map((c) => c.id), [
        'mine',
      ]);
      expect((await stranger.fetchConversations()).items, isEmpty);
      for (final id in ['', 'foreign', 'unknown']) {
        await expectLater(
          source.findConversation(id),
          throwsA(isA<MessagesFailure>()),
        );
        await expectLater(
          source.fetchMessages(id),
          throwsA(isA<MessagesFailure>()),
        );
        await expectLater(
          source.sendMessage(id, 'hello'),
          throwsA(isA<MessagesFailure>()),
        );
        await expectLater(source.markRead(id), throwsA(isA<MessagesFailure>()));
      }
    },
  );
  test(
    'logout clears rooms, messages and cursor tickets; new instance starts clean',
    () async {
      final source = ControlledMessages();
      addTearDown(source.dispose);
      await source.sendMessage('room', 'secret draft');
      source.clearSession();
      expect(source.isActive, isFalse);
      expect(source.confirmedUnreadTotal, isNull);
      expect(source.cachedConversation('room'), isNull);
      await expectLater(
        source.fetchMessages('room'),
        throwsA(isA<MessagesFailure>()),
      );
      final next = ControlledMessages();
      addTearDown(next.dispose);
      expect(
        (await next.fetchMessages(
          'room',
        )).items.any((m) => m.body == 'secret draft'),
        isFalse,
      );
    },
  );
  test('JSON preserves exact IDs, nullable message and UTC timestamps', () {
    final parsed = Message.fromJson({
      'id': 'uuid-message',
      'senderId': 'uuid-user',
      'body': 'text',
      'sentAt': '2026-11-01T12:00:00+03:00',
      'readAt': null,
    });
    expect(parsed.id, 'uuid-message');
    expect(parsed.sentAt, DateTime.utc(2026, 11, 1, 9));
    final conversation = Conversation.fromJson({
      'id': 'room',
      'requestId': 'request',
      'listing': {'id': 'listing', 'topic': 'Python'},
      'counterpart': {
        'id': 'user',
        'firstName': 'Deniz',
        'lastNameInitial': 'Y',
        'departmentId': 'department',
      },
      'lastMessage': null,
      'unreadCount': 0,
    });
    expect(conversation.counterpart.displayName, 'Deniz Y.');
    expect(conversation.lastMessage, isNull);
    expect(
      () => Message.fromJson({'id': 'id'}),
      throwsA(isA<FormatException>()),
    );
  });
}
