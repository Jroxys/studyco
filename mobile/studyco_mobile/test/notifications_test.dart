import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/auth/debug/password_reset_preview.dart';
import 'package:studyco_mobile/features/auth/screens/login_screen.dart';
import 'package:studyco_mobile/features/notifications/data/in_memory_notifications_repository.dart';
import 'package:studyco_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:studyco_mobile/features/notifications/models/study_notification.dart';
import 'package:studyco_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:studyco_mobile/features/notifications/widgets/notifications_repository_scope.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';

final userId = sampleHomeUser.postsOwnerId;
const otherId = 'another-account';
const allRead = 'Tümünü Okundu İşaretle';

StudyNotification item(String id, {String? recipient, int hour = 1}) =>
    StudyNotification(
      id: id,
      recipientId: recipient ?? userId,
      kind: NotificationKind.applicationAccepted,
      title: 'Başvuru bildirimi $id',
      description: 'Örnek başvurunun durumu güncellendi.',
      createdAt: DateTime.utc(2026, 10, 9, hour),
      target: NotificationTarget.outgoingApplication,
      targetId: 'missing-request',
    );

class ControlledNotifications extends InMemoryNotificationsRepository {
  ControlledNotifications()
    : super(
        userId: userId,
        initialNotifications: [item('old'), item('new', hour: 2)],
      );

  final loading = Completer<void>();
  bool failLoad = true;
  bool failRead = true;
  bool failAll = true;

  @override
  Future<void> refresh() async {
    await loading.future;
    if (failLoad) throw StateError('offline');
  }

  @override
  Future<void> markRead(String notificationId) async {
    if (failRead) throw StateError('offline');
    await super.markRead(notificationId);
  }

  @override
  Future<void> markAllRead() async {
    if (failAll) throw StateError('offline');
    await super.markAllRead();
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.pumpAndSettle();
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Finder previewCard(NotificationKind kind) =>
    find.byKey(ValueKey('notification-mock-notification-${kind.name}'));

void main() {
  test(
    'notification mutations are scoped and repeated reads are idempotent',
    () async {
      final seed = [item('first'), item('foreign', recipient: otherId)];
      final first = InMemoryNotificationsRepository(
        userId: userId,
        initialNotifications: seed,
      );
      final other = InMemoryNotificationsRepository(
        userId: otherId,
        initialNotifications: seed,
      );
      addTearDown(first.dispose);
      addTearDown(other.dispose);
      var changes = 0;
      first.addListener(() => changes++);
      expect(first.notifications.single.id, 'first');
      expect(other.notifications.single.id, 'foreign');
      await expectLater(
        first.markRead('foreign'),
        throwsA(isA<NotificationFailure>()),
      );
      await first.markRead('first');
      await first.markRead('first');
      await first.markAllRead();
      expect(changes, 1);
      expect(first.unreadCount, 0);
      expect(other.unreadCount, 1);
    },
  );

  testWidgets(
    'loading, refresh and read failures, order and missing target at 320px',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ControlledNotifications();
      final posts = InMemoryPostsRepository();
      addTearDown(source.dispose);
      addTearDown(posts.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(1.6)),
                child: child!,
              ),
          home: NotificationsScreen(
            user: sampleHomeUser,
            repository: source,
            postsRepository: posts,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.loading.complete();
      await tester.pumpAndSettle();
      expect(find.text('Bildirimler yüklenemedi.'), findsOneWidget);
      source.failLoad = false;
      await tap(tester, find.text('Tekrar Dene'));
      final newest = find.byKey(const ValueKey('notification-new'));
      final oldest = find.byKey(const ValueKey('notification-old'));
      expect(
        tester.getTopLeft(newest).dy,
        lessThan(tester.getTopLeft(oldest).dy),
      );
      expect(
        find.byKey(const ValueKey('notification-unread-new')),
        findsOneWidget,
      );
      await tap(tester, newest);
      expect(
        find.text(
          'Bildirim okundu olarak işaretlenemedi. Tekrar deneyebilirsin.',
        ),
        findsOneWidget,
      );
      expect(source.unreadCount, 2);
      expect(find.byType(ApplicationsScreen), findsNothing);
      await tap(tester, find.text(allRead));
      expect(
        find.text(
          'Bildirimler okundu olarak işaretlenemedi. Tekrar deneyebilirsin.',
        ),
        findsOneWidget,
      );
      expect(source.unreadCount, 2);
      source.failRead = false;
      await tap(tester, newest);
      expect(source.unreadCount, 1);
      expect(find.text('Bildirimdeki başvuru bulunamadı.'), findsOneWidget);
      expect(find.byTooltip('Kapat'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HOME_PREVIEW bell, badge and all existing deep links', (
    tester,
  ) async {
    if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();
    final bell = find.byTooltip('Bildirimler');
    Finder badge() => find.descendant(of: bell, matching: find.byType(Badge));
    expect(
      find.descendant(of: badge(), matching: find.text('5')),
      findsOneWidget,
    );
    await tap(tester, bell);
    expect(find.byType(NotificationsScreen), findsOneWidget);
    for (final (kind, incoming, detailTitle) in [
      (NotificationKind.newApplication, true, 'Algoritma Etüdü (Örnek İlan)'),
      (
        NotificationKind.applicationAccepted,
        false,
        'Tamamlanmış Python Dersi (Örnek)',
      ),
      (NotificationKind.applicationRejected, false, 'Veri Yapıları (Örnek)'),
      (NotificationKind.lessonConfirmation, false, 'Ders Tamamlama (Örnek)'),
    ]) {
      final card = previewCard(kind);
      if (card.evaluate().isEmpty) await tester.scrollUntilVisible(card, 200);
      await tap(tester, card);
      final list = tester.widget<ApplicationsScreen>(
        find.byType(ApplicationsScreen),
      );
      expect(list.incoming, incoming);
      expect(find.byTooltip('Kapat'), findsOneWidget);
      final detail = find.descendant(
        of: find.byType(BottomSheet),
        matching: find.text(detailTitle),
      );
      expect(detail, findsOneWidget);
      if (kind == NotificationKind.lessonConfirmation) {
        expect(
          find.byKey(const ValueKey('confirm-lesson')).hitTestable(),
          findsOneWidget,
        );
      }
      await tap(tester, find.byTooltip('Kapat'));
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey('notification-unread-mock-notification-${kind.name}'),
        ),
        findsNothing,
      );
    }
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: badge(), matching: find.text('1')),
      findsOneWidget,
    );
    await tap(tester, bell);
    await tap(tester, previewCard(NotificationKind.newMessage));
    expect(
      find.text('Sohbet ekranı henüz kullanıma açık değil.'),
      findsOneWidget,
    );
    expect(find.byType(NotificationsScreen), findsOneWidget);
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, allRead))
          .onPressed,
      isNull,
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(badge(), findsNothing);
  });

  testWidgets(
    'HOME_PREVIEW mark all updates the bell and logout clears the snapshot',
    (tester) async {
      if (!HomePreview.enabled || PasswordResetPreview.screen() != null) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      final bell = find.byTooltip('Bildirimler');
      final source =
          NotificationsRepositoryScope.forUser(tester.element(bell), userId)!;
      await tap(tester, bell);
      await tap(tester, find.text(allRead));
      expect(source.unreadCount, 0);
      expect(source.notifications.every((item) => item.isRead), isTrue);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: bell, matching: find.byType(Badge)),
        findsNothing,
      );
      await tap(tester, find.byKey(const ValueKey('home-nav-3')));
      await tap(tester, find.byKey(const ValueKey('profile-logout')));
      await tap(tester, find.widgetWithText(FilledButton, 'Çıkış Yap'));
      final login = find.byType(LoginScreen);
      expect(login, findsOneWidget);
      expect(
        NotificationsRepositoryScope.forUser(tester.element(login), userId),
        isNull,
      );
      expect(source.notifications, isEmpty);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      expect(
        NotificationsRepositoryScope.forUser(
          tester.element(bell),
          userId,
        )?.unreadCount,
        5,
      );
    },
  );
}
