import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/app/debug/messages_preview_data.dart';
import 'package:studyco_mobile/features/home/widgets/home_header.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/auth/screens/login_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/messages/data/in_memory_messages_repository.dart';
import 'package:studyco_mobile/features/messages/screens/chat_screen.dart';
import 'package:studyco_mobile/features/messages/screens/conversations_screen.dart';
import 'package:studyco_mobile/features/messages/widgets/message_widgets.dart';
import 'package:studyco_mobile/features/messages/widgets/messages_repository_scope.dart';
import 'package:studyco_mobile/features/notifications/data/in_memory_notifications_repository.dart';
import 'package:studyco_mobile/features/notifications/models/study_notification.dart';
import 'package:studyco_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'support/messages_fixtures.dart';

Widget host(Widget child, {InMemoryMessagesRepository? source}) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (_, child) => MessagesRepositoryScope(repository: source, child: child!),
  home: child,
);
Widget chat(
  ControlledMessages source, {
  String user = 'me',
  String id = 'room',
}) => host(ChatScreen(repository: source, userId: user, conversationId: id));
Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'list preserves server order, opens detail and read updates count',
    (tester) async {
      final source = ControlledMessages(
        rooms: [
          room('new', day: 2),
          room('old', messages: [message('latest', minute: 999)]),
        ],
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(
        host(ConversationsScreen(repository: source, userId: 'me')),
      );
      await tester.pumpAndSettle();
      final cards =
          tester
              .widgetList<ConversationCard>(find.byType(ConversationCard))
              .toList();
      expect(cards.map((c) => c.conversation.id), ['new', 'old']);
      await tap(tester, find.byKey(const ValueKey('conversation-new')));
      expect(find.byType(ChatScreen), findsOneWidget);
      final bubbles =
          tester.widgetList<MessageBubble>(find.byType(MessageBubble)).toList();
      expect(bubbles.any((b) => b.isOwn && b.message.senderId == 'me'), isTrue);
      expect(
        bubbles.any((b) => !b.isOwn && b.message.senderId == 'other'),
        isTrue,
      );
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('message-3'))).dy,
        greaterThan(
          tester.getTopLeft(find.byKey(const ValueKey('message-1'))).dy,
        ),
      );
      expect((await source.findConversation('new')).unreadCount, 0);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final updated = tester.widget<ConversationCard>(
        find.byKey(const ValueKey('conversation-new')),
      );
      expect(updated.conversation.unreadCount, 0);
    },
  );
  testWidgets('send validates, trims, adds once and clears successful draft', (
    tester,
  ) async {
    final source = ControlledMessages();
    addTearDown(source.dispose);
    await tester.pumpWidget(chat(source));
    await tester.pumpAndSettle();
    final draft = find.byKey(const ValueKey('message-draft'));
    final send = find.byKey(const ValueKey('send-message'));
    for (final text in ['   ', 'x' * 2001]) {
      await tester.enterText(draft, text);
      await tester.pump();
      expect(tester.widget<IconButton>(send).onPressed, isNull);
    }
    source.pendingSend = Completer<void>();
    await tester.enterText(draft, '  Yeni mesaj  ');
    await tester.pump();
    await tester.tap(send);
    await tester.pump();
    expect(source.sends, 1);
    expect(tester.widget<IconButton>(send).onPressed, isNull);
    await tester.tap(send);
    expect(source.sends, 1);
    source.pendingSend!.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(draft).controller!.text, isEmpty);
    expect(find.text('Yeni mesaj'), findsOneWidget);
    expect(
      (await source.fetchMessages(
        'room',
      )).items.where((m) => m.body == 'Yeni mesaj'),
      hasLength(1),
    );
  });
  testWidgets(
    'uncertain send preserves draft and never retries automatically',
    (tester) async {
      final source = ControlledMessages()..failSend = true;
      addTearDown(source.dispose);
      await tester.pumpWidget(chat(source));
      await tester.pumpAndSettle();
      final draft = find.byKey(const ValueKey('message-draft'));
      await tester.enterText(draft, 'Kaybolmayan taslak');
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('send-message')));
      expect(
        tester.widget<TextField>(draft).controller!.text,
        'Kaybolmayan taslak',
      );
      expect(find.textContaining('sonucu kontrol et'), findsOneWidget);
      await tester.pump(const Duration(seconds: 30));
      expect(source.sends, 1);
      await tap(tester, find.byTooltip('Mesajları yenile'));
      expect(source.sends, 1);
      expect(
        tester.widget<TextField>(draft).controller!.text,
        'Kaybolmayan taslak',
      );
    },
  );
  testWidgets('read error keeps unread and explicit retry succeeds', (
    tester,
  ) async {
    final source = ControlledMessages()..failRead = true;
    addTearDown(source.dispose);
    await tester.pumpWidget(chat(source));
    await tester.pumpAndSettle();
    expect(source.confirmedUnreadTotal, 2);
    expect(find.text('Okundu işlemi başarısız.'), findsOneWidget);
    source.failRead = false;
    await tap(tester, find.text('Tekrar Dene'));
    expect(source.confirmedUnreadTotal, 0);
    expect(find.text('Okundu işlemi başarısız.'), findsNothing);
  });
  testWidgets(
    'older message pages merge without duplicates and refresh resets page',
    (tester) async {
      final source = ControlledMessages(
        rooms: [
          room(
            'room',
            messages: [
              for (var i = 0; i < 25; i++) message('id-$i', minute: i),
            ],
          ),
        ],
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(chat(source));
      await tester.pumpAndSettle();
      final older = find.text('Eski Mesajları Yükle');
      await tester.scrollUntilVisible(
        older,
        350,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('chat-messages')),
          matching: find.byType(Scrollable),
        ),
      );
      await tap(tester, older);
      expect(find.text('Eski Mesajları Yükle'), findsNothing);
      await tester.scrollUntilVisible(
        find.text('Mesaj id-0'),
        300,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('chat-messages')),
          matching: find.byType(Scrollable),
        ),
      );
      expect(find.text('Mesaj id-0'), findsOneWidget);
      final ids =
          tester
              .widgetList<MessageBubble>(find.byType(MessageBubble))
              .map((b) => b.message.id)
              .toList();
      expect(ids.toSet().length, ids.length);
      await tap(tester, find.byTooltip('Mesajları yenile'));
      expect(source.reads, 3);
    },
  );
  testWidgets(
    'conversation pagination guards repeated taps and load failures retry',
    (tester) async {
      final source = ControlledMessages(
        rooms: [
          for (var i = 0; i < 21; i++) room('room-$i', day: i, messages: []),
        ],
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(
        host(ConversationsScreen(repository: source, userId: 'me')),
      );
      await tester.pumpAndSettle();
      final more = find.text('Daha Fazla Yükle');
      await tester.scrollUntilVisible(more, 600);
      source.pendingLoad = Completer<void>();
      final loadMore =
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Daha Fazla Yükle'),
              )
              .onPressed!;
      loadMore();
      loadMore();
      await tester.pump();
      expect(source.loads, 2);
      source.pendingLoad!.complete();
      await tester.pumpAndSettle();
      expect(more, findsNothing);
      source.failLoad = true;
      await tap(tester, find.byTooltip('Konuşmaları yenile'));
      expect(find.text('Konuşmalar yüklenemedi.'), findsOneWidget);
      source.failLoad = false;
      await tap(tester, find.text('Tekrar Dene'));
      expect(find.text('Konuşmalar yüklenemedi.'), findsNothing);
    },
  );
  testWidgets('empty conversation and empty list have explanatory states', (
    tester,
  ) async {
    final source = ControlledMessages(rooms: [room('room', messages: [])]);
    addTearDown(source.dispose);
    await tester.pumpWidget(chat(source));
    await tester.pumpAndSettle();
    expect(find.text('Henüz mesaj yok. İlk mesajı sen yaz.'), findsOneWidget);
    final empty = ControlledMessages(rooms: []);
    addTearDown(empty.dispose);
    await tester.pumpWidget(
      host(ConversationsScreen(repository: empty, userId: 'me')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Henüz konuşman yok'), findsOneWidget);
  });
  testWidgets(
    'invalid or foreign conversation never exposes messages or composer',
    (tester) async {
      final source = ControlledMessages();
      addTearDown(source.dispose);
      for (final pair in [
        ('me', ''),
        ('stranger', 'room'),
        ('me', 'missing'),
      ]) {
        await tester.pumpWidget(chat(source, user: pair.$1, id: pair.$2));
        await tester.pumpAndSettle();
        expect(find.byType(MessageBubble), findsNothing);
        expect(find.byKey(const ValueKey('message-draft')), findsNothing);
        expect(find.textContaining('erişimin yok'), findsOneWidget);
      }
    },
  );
  testWidgets(
    '320 pixel width and keyboard handle long text without overflow',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final source = ControlledMessages(
        rooms: [
          room('room', messages: [message('long-${'x' * 400}')]),
        ],
      );
      addTearDown(source.dispose);
      await tester.pumpWidget(chat(source));
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.enterText(
        find.byKey(const ValueKey('message-draft')),
        'Uzun taslak ' * 25,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      source.failSend = true;
      await tap(tester, find.byKey(const ValueKey('send-message')));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'notification target ID opens authorized chat without changing other notification semantics',
    (tester) async {
      final messages = ControlledMessages();
      addTearDown(messages.dispose);
      final notifications = InMemoryNotificationsRepository(
        userId: 'me',
        initialNotifications: [
          StudyNotification(
            id: 'notification',
            recipientId: 'me',
            kind: NotificationKind.newMessage,
            title: 'Yeni Mesaj',
            description: 'Yeni mesaj geldi.',
            createdAt: messageEpoch,
            target: NotificationTarget.conversation,
            targetId: 'room',
          ),
        ],
      );
      final posts = InMemoryPostsRepository(initialPosts: []);
      addTearDown(posts.dispose);
      addTearDown(notifications.dispose);
      await tester.pumpWidget(
        host(
          NotificationsScreen(
            user: const UserProfile(
              id: 'me',
              firstName: 'Örnek',
              department: 'Bölüm',
              campus: 'Kampüs',
            ),
            repository: notifications,
            postsRepository: posts,
          ),
          source: messages,
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.text('Yeni Mesaj'));
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(notifications.unreadCount, 0);
      expect(messages.confirmedUnreadTotal, 0);
    },
  );
  testWidgets(
    'accepted outgoing and incoming application details open existing room only',
    (tester) async {
      final posts = HomePreview.createRepository();
      final source = previewMessages(posts.applicationsRepository.applications);
      addTearDown(posts.dispose);
      addTearDown(source.dispose);
      for (final entry in [
        ('mock-completed-outgoing', false, 'mock-conversation-outgoing'),
        ('mock-completed-incoming', true, 'mock-conversation-incoming'),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          host(
            ApplicationsScreen(
              postsRepository: posts,
              repository: posts.applicationsRepository,
              user: sampleHomeUser,
              incoming: entry.$2,
              initialApplicationId: entry.$1,
            ),
            source: source,
          ),
        );
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('application-chat')));
        expect(
          tester.widget<ChatScreen>(find.byType(ChatScreen)).conversationId,
          entry.$3,
        );
      }
    },
  );
  testWidgets(
    'pending application has no chat action and unknown total hides badge',
    (tester) async {
      final posts = HomePreview.createRepository();
      addTearDown(posts.dispose);
      await tester.pumpWidget(
        host(
          ApplicationsScreen(
            postsRepository: posts,
            repository: posts.applicationsRepository,
            user: sampleHomeUser,
            incoming: true,
            initialApplicationId: 'mock-incoming-1',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('application-chat')), findsNothing);
      await tester.pumpWidget(
        host(
          HomeHeader(
            user: sampleHomeUser,
            onMessages: () {},
            onNotifications: () {},
            onProfile: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byTooltip('Mesajlar'),
          matching: find.byType(Badge),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'HOME_PREVIEW icon, badge, application link and logout isolate session',
    (tester) async {
      if (!HomePreview.enabled) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final home = find.byType(HomeScreen);
      final source =
          MessagesRepositoryScope.forUser(
            tester.element(home),
            sampleHomeUser.id,
          )!;
      expect(source.confirmedUnreadTotal, 2);
      await tap(tester, find.byTooltip('Mesajlar'));
      expect(find.byType(ConversationsScreen), findsOneWidget);
      await tap(
        tester,
        find.byKey(const ValueKey('conversation-mock-conversation-outgoing')),
      );
      expect(find.byType(ChatScreen), findsOneWidget);
      expect(source.confirmedUnreadTotal, 1);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byTooltip('Mesajlar'),
          matching: find.text('1'),
        ),
        findsOneWidget,
      );
      await tap(tester, find.byKey(const ValueKey('home-nav-3')));
      await tap(tester, find.byKey(const ValueKey('profile-logout')));
      await tap(tester, find.widgetWithText(FilledButton, 'Çıkış Yap'));
      expect(find.byType(LoginScreen), findsOneWidget);
      expect(source.isActive, isFalse);
      expect(
        MessagesRepositoryScope.forUser(
          tester.element(find.byType(LoginScreen)),
          sampleHomeUser.id,
        ),
        isNull,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final next =
          MessagesRepositoryScope.forUser(
            tester.element(home),
            sampleHomeUser.id,
          )!;
      expect(next, isNot(same(source)));
      expect(next.confirmedUnreadTotal, 2);
    },
  );
}
