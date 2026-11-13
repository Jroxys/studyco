import 'package:studyco_mobile/features/assistant/widgets/assistant_sheet.dart';
import 'package:studyco_mobile/features/messages/screens/conversations_screen.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/core/data/departments.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'support/discovery_fixtures.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/widgets/post_card.dart';
import 'package:studyco_mobile/features/home/widgets/home_header.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';

Post extraPost({
  String id = 'extra',
  bool long = false,
  DateTime? createdAt,
  DateTime? startsAt,
  PostSubject subject = PostSubject.coding,
  String? department,
}) => Post(
  id: id,
  authorId: 'fixture-owner',
  department: department,
  topic: 'Ders konusu',
  title:
      long
          ? 'Çok uzun bir Python Programlama ve Algoritma Analizi özel ders ilan başlığı'
          : 'Yeni İlan',
  authorName: long ? 'Çok Uzun Adı ve Soyadı Olan Öğrenci' : 'Öğrenci',
  createdAt: createdAt ?? DateTime.utc(2026, 10, 29, 12),
  startsAt: startsAt ?? DateTime(DateTime.now().year + 1, 11, 3, 9, 5),
  endsAt: (startsAt ?? DateTime(DateTime.now().year + 1, 11, 3, 9, 5)).add(
    const Duration(hours: 1),
  ),
  location:
      long
          ? 'Merkez Kütüphane Çok Uzun Bir Bina Adı ve Kat Bilgisi'
          : 'Kütüphane',
  type: PostType.tutoring,
  subject: subject,
  offer: PostOffer.free,
);

class ControlledPostsRepository extends InMemoryPostsRepository {
  ControlledPostsRepository() : super(initialPosts: activeSamplePosts());
  final refreshes = <Completer<void>>[];

  @override
  Future<void> refresh() {
    final pending = Completer<void>();
    refreshes.add(pending);
    return pending.future;
  }
}

void main() {
  late InMemoryPostsRepository repository;
  setUp(
    () =>
        repository = InMemoryPostsRepository(initialPosts: activeSamplePosts()),
  );
  tearDown(() => repository.dispose());

  Future<void> open(
    WidgetTester tester, {
    ValueChanged<Post>? onOpen,
    ValueChanged<String>? onDestination,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(
          repository: repository,
          user: sampleHomeUser,
          onOpenPost: onOpen,
          onDestination: onDestination,
          isPreview: true,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  int gridCount(WidgetTester tester) =>
      tester
          .widget<SliverGrid>(find.byType(SliverGrid))
          .delegate
          .estimatedChildCount!;

  List<String> gridIds(WidgetTester tester) {
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate = grid.delegate as SliverChildBuilderDelegate;
    final context = tester.element(find.byType(SliverGrid));
    return [
      for (var i = 0; i < gridCount(tester); i++)
        (delegate.builder(context, i)! as PostCard).post.id,
    ];
  }

  Future<void> revealGridItem(WidgetTester tester, Finder finder) async {
    await tester.scrollUntilVisible(
      finder,
      150,
      scrollable:
          find
              .descendant(
                of: find.byType(CustomScrollView),
                matching: find.byType(Scrollable),
              )
              .first,
    );
    await tester.pumpAndSettle();
  }

  Future<void> openControlled(
    WidgetTester tester,
    ControlledPostsRepository source,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: source, user: sampleHomeUser),
      ),
    );
    await tester.pump();
  }

  ControlledPostsRepository controlled(WidgetTester tester) {
    final source = ControlledPostsRepository();
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      source.dispose();
    });
    return source;
  }

  Future<VoidCallback> reachRetry(
    WidgetTester tester,
    ControlledPostsRepository source,
  ) async {
    await openControlled(tester, source);
    source.refreshes.single.completeError(
      StateError('controlled load failure'),
    );
    await tester.pumpAndSettle();
    return tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'Tekrar Dene'))
        .onPressed!;
  }

  testWidgets(
    'Delayed home load shows progress, reports failure, and retry really reloads',
    (tester) async {
      final source = controlled(tester);
      await openControlled(tester, source);
      expect(source.refreshes, hasLength(1));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      source.refreshes.single.completeError(
        StateError('controlled load failure'),
      );
      await tester.pumpAndSettle();
      expect(find.text('İlanlar yüklenemedi. Tekrar deneyin.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      await tester.tap(find.text('Tekrar Dene'));
      await tester.pump();
      expect(source.refreshes, hasLength(2));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('İlanlar yüklenemedi. Tekrar deneyin.'), findsNothing);
      source.refreshes.last.complete();
      await tester.pumpAndSettle();
      expect(gridCount(tester), 4);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Tekrar Dene'), findsNothing);
    },
  );

  testWidgets(
    'An obsolete refresh failure cannot overwrite a newer successful load',
    (tester) async {
      final source = controlled(tester);
      final retry = await reachRetry(tester, source);
      retry();
      retry();
      await tester.pump();
      expect(source.refreshes, hasLength(3));
      source.refreshes[2].complete();
      await tester.pumpAndSettle();
      expect(gridCount(tester), 4);
      source.refreshes[1].completeError(StateError('obsolete load failure'));
      await tester.pumpAndSettle();
      expect(find.text('İlanlar yüklenemedi. Tekrar deneyin.'), findsNothing);
      expect(gridCount(tester), 4);
    },
  );

  testWidgets(
    'An obsolete refresh cannot stop progress for the current pending load',
    (tester) async {
      final source = controlled(tester);
      final retry = await reachRetry(tester, source);
      retry();
      retry();
      await tester.pump();
      source.refreshes[1].complete();
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(PostCard), findsNothing);
      source.refreshes[2].completeError(StateError('current load failure'));
      await tester.pumpAndSettle();
      expect(find.text('İlanlar yüklenemedi. Tekrar deneyin.'), findsOneWidget);
    },
  );

  testWidgets(
    'Returning to a previous repository does not revive its obsolete refresh',
    (tester) async {
      final first = controlled(tester);
      final second = controlled(tester);
      await openControlled(tester, first);
      await openControlled(tester, second);
      await openControlled(tester, first);
      expect(first.refreshes, hasLength(2));
      first.refreshes.last.complete();
      await tester.pumpAndSettle();
      expect(gridCount(tester), 4);
      first.refreshes.first.completeError(
        StateError('obsolete source generation'),
      );
      second.refreshes.single.completeError(StateError('obsolete source'));
      await tester.pumpAndSettle();
      expect(find.text('İlanlar yüklenemedi. Tekrar deneyin.'), findsNothing);
      expect(gridCount(tester), 4);
    },
  );

  testWidgets('Newest six use creation time and retain all repository posts', (
    tester,
  ) async {
    repository.dispose();
    final initial = [
      for (final day in [3, 8, 1, 6, 2, 7, 5, 4])
        extraPost(
          id: 'post-$day',
          createdAt: DateTime.utc(2026, 10, day),
          startsAt: DateTime(DateTime.now().year + 1, 12, 10 - day),
        ),
    ];
    repository = InMemoryPostsRepository(initialPosts: initial);
    await open(tester);
    final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
    final delegate = grid.delegate as SliverChildBuilderDelegate;
    final context = tester.element(find.byType(SliverGrid));
    for (var index = 0; index < gridCount(tester); index++) {
      final card = delegate.builder(context, index)! as PostCard;
      expect(card.post.type, PostType.tutoring);
      expect(card.post.typeLabel, 'Özel Ders');
    }
    expect(gridIds(tester), [
      'post-8',
      'post-7',
      'post-6',
      'post-5',
      'post-4',
      'post-3',
    ]);
    expect(
      repository.posts.map((post) => post.id),
      initial.map((post) => post.id),
    );

    await repository.addPost(extraPost(id: 'newest'));
    await tester.pumpAndSettle();
    expect(gridIds(tester), [
      'newest',
      'post-8',
      'post-7',
      'post-6',
      'post-5',
      'post-4',
    ]);
    expect(repository.posts.length, 9);
    expect(
      repository.posts.map((post) => post.id),
      containsAll(['post-1', 'post-2', 'post-3']),
    );
  });

  testWidgets('Home selects the newest six across departments and categories', (
    tester,
  ) async {
    repository.dispose();
    repository = InMemoryPostsRepository(
      initialPosts: [
        for (final day in [3, 8, 1, 6, 2, 7, 5, 4])
          extraPost(
            id: 'mixed-$day',
            createdAt: DateTime.utc(2026, 10, day),
            department: Departments.values[day - 1],
            subject: PostSubject.values[(day - 1) % PostSubject.values.length],
          ),
      ],
    );
    await open(tester);
    expect(gridIds(tester), [
      'mixed-8',
      'mixed-7',
      'mixed-6',
      'mixed-5',
      'mixed-4',
      'mixed-3',
    ]);
    expect(gridCount(tester), 6);
    final visible = repository.posts.where(
      (post) => gridIds(tester).contains(post.id),
    );
    expect(visible.map((post) => post.department).toSet(), hasLength(6));
    expect(
      visible.map((post) => post.subject).toSet(),
      containsAll(PostSubject.values),
    );
    await repository.addPost(
      extraPost(
        id: 'latest-general',
        subject: PostSubject.general,
        department: 'Diğer',
      ),
    );
    await tester.pumpAndSettle();
    expect(gridIds(tester), [
      'latest-general',
      'mixed-8',
      'mixed-7',
      'mixed-6',
      'mixed-5',
      'mixed-4',
    ]);
    expect(repository.posts.length, 9);
    expect(
      repository.posts.map((post) => post.id),
      containsAll(['mixed-1', 'mixed-2', 'mixed-3']),
    );
  });

  testWidgets(
    'Equal creation times use ascending id at the six post boundary',
    (tester) async {
      repository.dispose();
      repository = InMemoryPostsRepository(
        initialPosts: [
          for (final id in ['g', 'c', 'a', 'f', 'b', 'e', 'd'])
            extraPost(id: id),
        ],
      );
      await open(tester);
      expect(gridIds(tester), ['a', 'b', 'c', 'd', 'e', 'f']);
      await tester.pumpAndSettle();
      expect(gridIds(tester), ['a', 'b', 'c', 'd', 'e', 'f']);
      expect(repository.posts.length, 7);
    },
  );

  testWidgets(
    'Home shows recommendations without category chips or a chip row',
    (tester) async {
      await open(tester);
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.byType(SingleChildScrollView), findsNothing);
      for (final name in ['all', 'coding', 'mathematics', 'together']) {
        expect(find.byKey(ValueKey('filter-$name')), findsNothing);
      }
      expect(find.text('Senin İçin Öneriler'), findsOneWidget);
      expect(find.text('En yeni özel ders ilanları'), findsOneWidget);
      expect(find.byKey(const ValueKey('all-posts')), findsOneWidget);
      expect(gridCount(tester), 4);
    },
  );

  test('Sample listings remain tutoring posts with the existing labels', () {
    expect(PostType.values, [PostType.tutoring]);
    expect(
      repository.posts.map((post) => post.type),
      everyElement(PostType.tutoring),
    );
    expect(
      repository.posts.map((post) => post.typeLabel),
      everyElement('Özel Ders'),
    );
    expect(extraPost().dateLabel, '3 Kas • 09:05');
  });

  test('Shared source publishes additions and protects its snapshot', () async {
    var notifications = 0;
    repository.addListener(() => notifications++);
    await repository.addPost(extraPost());
    expect(repository.posts.length, 5);
    expect(notifications, 1);
    expect(() => repository.posts.clear(), throwsUnsupportedError);
    await expectLater(repository.addPost(extraPost()), throwsArgumentError);
    final fresh = InMemoryPostsRepository(initialPosts: activeSamplePosts());
    fresh.dispose();
  });

  testWidgets(
    'Shared-source additions update the dynamic grid without filters',
    (tester) async {
      await open(tester);
      expect(gridCount(tester), 4);
      await repository.addPost(extraPost());
      await tester.pumpAndSettle();
      expect(gridCount(tester), 5);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('post-extra')),
        200,
        scrollable:
            find
                .descendant(
                  of: find.byType(CustomScrollView),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      expect(find.text('Yeni İlan'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Home cards have no save control and retain detail callback', (
    tester,
  ) async {
    Post? opened;
    await open(tester, onOpen: (post) => opened = post);
    final detail = find.byKey(const ValueKey('open-python'));
    await revealGridItem(tester, detail);
    expect(find.byKey(const ValueKey('save-python')), findsNothing);
    expect(find.byIcon(Icons.bookmark), findsNothing);
    expect(find.byIcon(Icons.bookmark_border), findsNothing);
    await tester.tap(detail);
    expect(opened, same(repository.posts.first));
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Long content fits two columns on 320px phone at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await repository.addPost(extraPost(long: true));
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
            home: HomeScreen(repository: repository, user: sampleHomeUser),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('post-extra')),
          150,
          scrollable:
              find
                  .descendant(
                    of: find.byType(CustomScrollView),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final grid = tester.widget<SliverGrid>(find.byType(SliverGrid));
        expect(
          (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount,
          2,
        );
        final ai = tester.getRect(find.byKey(const ValueKey('home-ai')));
        final viewport = tester.getRect(find.byType(CustomScrollView));
        expect(ai.top, greaterThanOrEqualTo(viewport.bottom));
        expect(find.byType(PostCard), findsWidgets);
      },
    );
  }

  testWidgets(
    'Messages opens its screen and unavailable destinations remain safe',
    (tester) async {
      await open(tester);
      final messages = find.byTooltip('Mesajlar');
      await tester.ensureVisible(messages);
      await tester.tap(messages);
      await tester.pumpAndSettle();
      expect(find.byType(ConversationsScreen), findsOneWidget);
      expect(find.textContaining('doğrulanmış kullanıcı'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Bildirimler'));
      await tester.pumpAndSettle();
      expect(find.text('Henüz bildirimin yok.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      for (final entry in {1: 'İlan Oluştur'}.entries) {
        await tester.tap(find.byKey(ValueKey('home-nav-${entry.key}')));
        await tester.pumpAndSettle();
        expect(
          find.text('${entry.value} ekranı henüz kullanıma açık değil.'),
          findsOneWidget,
        );
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('AI Asistan'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSheet), findsOneWidget);
      await tester.tap(find.byTooltip('Asistanı kapat'));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSheet), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'All link and bottom Search navigation emit the same destination',
    (tester) async {
      final destinations = <String>[];
      await open(tester, onDestination: destinations.add);
      await tester.ensureVisible(find.byKey(const ValueKey('all-posts')));
      await tester.tap(find.byKey(const ValueKey('all-posts')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();
      expect(destinations, ['Ara', 'Ara']);
      expect(gridCount(tester), 4);
    },
  );

  testWidgets('All link opens Search with the shared repository', (
    tester,
  ) async {
    await open(tester);
    await tester.ensureVisible(find.byKey(const ValueKey('all-posts')));
    await tester.tap(find.byKey(const ValueKey('all-posts')));
    await tester.pumpAndSettle();
    expect(find.byType(SearchScreen), findsOneWidget);
    expect(
      identical(
        tester.widget<SearchScreen>(find.byType(SearchScreen)).repository,
        repository,
      ),
      isTrue,
    );
    await tester.tap(find.byKey(const ValueKey('home-nav-0')));
    await tester.pumpAndSettle();
    expect(gridCount(tester), 4);
  });

  testWidgets('Empty repository offers an empty state', (tester) async {
    final empty = InMemoryPostsRepository();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: HomeScreen(repository: empty, user: sampleHomeUser),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Henüz ilan yok.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    empty.dispose();
  });
  testWidgets(
    'Status inset is respected and bottom controls stay fixed while scrolling',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      await open(tester);
      expect(
        tester.getRect(find.byKey(const ValueKey('home-top-bar'))).top,
        24,
      );
      for (final name in ['Mesajlar', 'Bildirimler']) {
        final target = tester.getSize(find.byTooltip(name));
        expect(target.width, greaterThanOrEqualTo(48));
        expect(target.height, greaterThanOrEqualTo(48));
        final button = find.byTooltip(name);
        final badge = find.descendant(of: button, matching: find.byType(Badge));
        // No repository is supplied, so neither icon claims an unread total.
        expect(badge, findsNothing);
      }
      final nav = find.byKey(const ValueKey('home-nav-0'));
      final originalNav = tester.getRect(nav);
      final originalAi = tester.getRect(find.byKey(const ValueKey('home-ai')));
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -450));
      await tester.pumpAndSettle();
      expect(tester.getRect(nav), originalNav);
      expect(tester.getRect(find.byKey(const ValueKey('home-ai'))), originalAi);
      expect(
        originalAi.top,
        greaterThanOrEqualTo(
          tester.getRect(find.byType(CustomScrollView)).bottom,
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Zero unread counts hide badges and preview disclosure stays out of the layout',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: HomeHeader(
              user: const UserProfile(
                firstName: 'Örnek',
                university: 'Üniversite',
                department: 'Bölüm',
                campus: 'Kampüs',
              ),
              onMessages: () {},
              onNotifications: () {},
              onProfile: () {},
              isPreview: true,
            ),
          ),
        ),
      );
      expect(find.byType(Badge), findsNothing);
      expect(find.text('Örnek veriler • Oturum açılmadı'), findsNothing);
      expect(find.byTooltip('Örnek veriler • Oturum açılmadı'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
