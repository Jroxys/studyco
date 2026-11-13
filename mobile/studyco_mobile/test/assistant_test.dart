import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/app/debug/home_preview.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/debug/messages_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/assistant/data/in_memory_assistant_repository.dart';
import 'package:studyco_mobile/features/assistant/domain/assistant_repository.dart';
import 'package:studyco_mobile/features/assistant/models/assistant_content.dart';
import 'package:studyco_mobile/features/assistant/widgets/assistant_repository_scope.dart';
import 'package:studyco_mobile/features/assistant/widgets/assistant_sheet.dart';
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/messages/data/in_memory_messages_repository.dart';
import 'package:studyco_mobile/features/messages/screens/conversations_screen.dart';
import 'package:studyco_mobile/features/messages/widgets/messages_repository_scope.dart';
import 'package:studyco_mobile/features/notifications/data/in_memory_notifications_repository.dart';
import 'package:studyco_mobile/features/notifications/screens/notifications_screen.dart';
import 'package:studyco_mobile/features/notifications/widgets/notifications_repository_scope.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/screens/create_post_screen.dart';
import 'package:studyco_mobile/features/profile/screens/my_posts_screen.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/settings/screens/settings_screen.dart';

AssistantContent content({List<AssistantOption>? options}) => AssistantContent(
  greeting: 'Karşılama metni sağlayıcıdan gelir.',
  options:
      options ??
      const [
        AssistantOption(
          id: 'one',
          title: 'Birinci soru',
          answer: 'Birinci yanıt',
          destination: 'search',
        ),
        AssistantOption(
          id: 'two',
          title: 'İkinci soru',
          answer: 'İkinci yanıt',
        ),
      ],
);

class ControlledAssistant extends AssistantRepository {
  Completer<AssistantContent> pending = Completer<AssistantContent>();
  int calls = 0;
  @override
  Future<AssistantContent> load() {
    calls++;
    return pending.future;
  }
}

class ControlledQuestions extends AssistantRepository {
  final questions = <String>[];
  Completer<AssistantReply> response = Completer<AssistantReply>();
  @override
  bool get supportsQuestions => true;
  @override
  Future<AssistantContent> load() async => content();
  @override
  Future<AssistantReply> ask(String question) {
    questions.add(question);
    return response.future;
  }
}

class Harness {
  Harness() {
    posts = HomePreview.createRepository();
    messages = previewMessages(posts.applicationsRepository.applications);
    notifications = InMemoryNotificationsRepository(userId: sampleHomeUser.id!);
  }
  late final InMemoryPostsRepository posts;
  late final InMemoryMessagesRepository messages;
  late final InMemoryNotificationsRepository notifications;
  Widget build(
    AssistantRepository repository, {
    bool sources = true,
    bool canCreate = true,
    ValueChanged<String>? onDestination,
    double scale = 1,
  }) => MaterialApp(
    theme: AppTheme.light,
    builder:
        (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: AssistantRepositoryScope(
            repository: repository,
            child: MessagesRepositoryScope(
              repository: sources ? messages : null,
              child: NotificationsRepositoryScope(
                repository: sources ? notifications : null,
                child: child!,
              ),
            ),
          ),
        ),
    home: Builder(
      builder:
          (context) => HomeScreen(
            repository: posts,
            user: sampleHomeUser,
            onDestination: onDestination,
            onCreatePost:
                canCreate
                    ? () => Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder:
                            (_) => CreatePostScreen(
                              repository: posts,
                              user: sampleHomeUser,
                            ),
                      ),
                    )
                    : null,
          ),
    ),
  );
  void dispose() {
    posts.dispose();
    messages.dispose();
    notifications.dispose();
  }
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  Harness harness,
  AssistantRepository repository, {
  bool sources = true,
  double scale = 1,
}) async {
  await tester.pumpWidget(
    harness.build(repository, sources: sources, scale: scale),
  );
  await tester.pumpAndSettle();
  await tap(tester, find.byKey(const ValueKey('home-ai')));
}

void main() {
  test(
    'navigation keys are a fixed allowlist, unknown content remains unsupported',
    () {
      for (final destination in AssistantDestination.values) {
        expect(AssistantDestination.fromKey(destination.name), destination);
      }
      for (final key in [
        null,
        '',
        '/profile',
        'https://example.test',
        'SEARCH',
      ]) {
        expect(AssistantDestination.fromKey(key), isNull);
      }
    },
  );
  test(
    'provider snapshot is immutable and preview is explicitly marked demo',
    () async {
      final entries = <AssistantOption>[];
      final snapshot = AssistantContent(greeting: 'Hello', options: entries);
      entries.add(
        const AssistantOption(id: 'late', title: 'Late', answer: 'Late'),
      );
      expect(snapshot.options, isEmpty);
      expect(() => snapshot.options.clear(), throwsUnsupportedError);
      final preview = await InMemoryAssistantRepository.preview.load();
      expect(preview.isDemo, isTrue);
      expect(preview.options.length, lessThanOrEqualTo(4));
    },
  );
  testWidgets(
    'home opens an 80 percent modal, selects answer and returns without a new page',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      await open(tester, h, InMemoryAssistantRepository(content()));
      expect(find.byType(AssistantSheet), findsOneWidget);
      expect(find.text('StudyCo Asistan'), findsOneWidget);
      expect(find.text('Karşılama metni sağlayıcıdan gelir.'), findsOneWidget);
      final height = tester.getSize(find.byType(AssistantSheet)).height;
      expect(
        height,
        closeTo(
          tester.view.physicalSize.height / tester.view.devicePixelRatio * .8,
          24,
        ),
      );
      expect(find.byKey(const ValueKey('assistant-draft')), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('assistant-option-one')));
      expect(find.text('Birinci yanıt'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant-go')), findsOneWidget);
      expect(find.byType(SearchScreen), findsNothing);
      await tap(tester, find.byKey(const ValueKey('assistant-back')));
      await tap(tester, find.byKey(const ValueKey('assistant-option-two')));
      expect(find.text('İkinci yanıt'), findsOneWidget);
      expect(find.byKey(const ValueKey('assistant-go')), findsNothing);
      await tap(tester, find.byTooltip('Asistanı kapat'));
      expect(find.byType(AssistantSheet), findsNothing);
      expect(find.byType(HomeScreen), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('home-ai')));
      expect(find.byKey(const ValueKey('assistant-greeting')), findsOneWidget);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSheet), findsNothing);
    },
  );
  testWidgets(
    'repeated button calls open one panel and navigation waits for dismissal',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      var overlayRemoved = false;
      String? navigationName;
      var navigationCalls = 0;
      await tester.pumpWidget(
        h.build(
          InMemoryAssistantRepository(content()),
          onDestination: (name) {
            navigationName = name;
            navigationCalls++;
            overlayRemoved = find.byType(AssistantSheet).evaluate().isEmpty;
          },
        ),
      );
      await tester.pumpAndSettle();
      final show =
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('home-ai')))
              .onPressed!;
      show();
      show();
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSheet), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('assistant-option-one')));
      final go =
          tester
              .widget<FilledButton>(find.byKey(const ValueKey('assistant-go')))
              .onPressed!;
      go();
      go();
      await tester.pumpAndSettle();
      expect(navigationCalls, 1);
      expect(navigationName, 'Ara');
      expect(overlayRemoved, isTrue);
      expect(find.byType(HomeScreen), findsOneWidget);
    },
  );
  for (final destination in AssistantDestination.values) {
    testWidgets(
      'existing ${destination.name} target opens after the panel closes',
      (tester) async {
        final h = Harness();
        addTearDown(h.dispose);
        await open(
          tester,
          h,
          InMemoryAssistantRepository(
            content(
              options: [
                AssistantOption(
                  id: 'target',
                  title: 'Hedef',
                  answer: 'Yanıt',
                  destination: destination.name,
                ),
              ],
            ),
          ),
        );
        await tap(
          tester,
          find.byKey(const ValueKey('assistant-option-target')),
        );
        await tap(tester, find.byKey(const ValueKey('assistant-go')));
        expect(find.byType(AssistantSheet), findsNothing);
        final type = switch (destination) {
          AssistantDestination.home => HomeScreen,
          AssistantDestination.search => SearchScreen,
          AssistantDestination.createPost => CreatePostScreen,
          AssistantDestination.profile => ProfileScreen,
          AssistantDestination.myPosts => MyPostsScreen,
          AssistantDestination.applications ||
          AssistantDestination.incomingApplications => ApplicationsScreen,
          AssistantDestination.messages => ConversationsScreen,
          AssistantDestination.notifications => NotificationsScreen,
          AssistantDestination.settings => SettingsScreen,
        };
        expect(find.byType(type), findsOneWidget);
        if (type == ApplicationsScreen) {
          expect(
            tester.widget<ApplicationsScreen>(find.byType(type)).incoming,
            destination == AssistantDestination.incomingApplications,
          );
        }
        if (destination != AssistantDestination.home) {
          await tester.binding.handlePopRoute();
          await tester.pumpAndSettle();
          expect(find.byType(HomeScreen), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
  testWidgets(
    'unknown and currently unavailable targets explain the limitation without navigation',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      await tester.pumpWidget(
        h.build(
          InMemoryAssistantRepository(
            content(
              options: const [
                AssistantOption(
                  id: 'bad',
                  title: 'Geçersiz',
                  answer: 'Yanıt',
                  destination: 'unsupported',
                ),
                AssistantOption(
                  id: 'messages',
                  title: 'Mesajlar',
                  answer: 'Yanıt',
                  destination: 'messages',
                ),
                AssistantOption(
                  id: 'create',
                  title: 'İlan',
                  answer: 'Yanıt',
                  destination: 'createPost',
                ),
              ],
            ),
          ),
          sources: false,
          canCreate: false,
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-ai')));
      for (final id in ['bad', 'messages', 'create']) {
        await tap(tester, find.byKey(ValueKey('assistant-option-$id')));
        expect(find.byKey(const ValueKey('assistant-go')), findsNothing);
        expect(
          find.byKey(const ValueKey('assistant-unavailable')),
          findsOneWidget,
        );
        await tap(tester, find.byKey(const ValueKey('assistant-back')));
      }
      expect(find.byType(AssistantSheet), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('loading, error retry and empty content are handled', (
    tester,
  ) async {
    final h = Harness();
    addTearDown(h.dispose);
    final repository = ControlledAssistant();
    await tester.pumpWidget(h.build(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-ai')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    repository.pending.completeError(
      const AssistantFailure('İçerik alınamadı.'),
    );
    await tester.pumpAndSettle();
    expect(find.text('İçerik alınamadı.'), findsOneWidget);
    repository.pending = Completer<AssistantContent>();
    await tester.tap(find.text('Tekrar Dene'));
    await tester.pump();
    repository.pending.complete(content(options: []));
    await tester.pumpAndSettle();
    expect(find.text('Henüz seçenek bulunmuyor.'), findsOneWidget);
    expect(repository.calls, 2);
  });
  testWidgets('closing a pending load ignores its eventual result', (
    tester,
  ) async {
    final h = Harness();
    addTearDown(h.dispose);
    final repository = ControlledAssistant();
    await tester.pumpWidget(h.build(repository));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-ai')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.tap(find.byTooltip('Asistanı kapat'));
    await tester.pumpAndSettle();
    repository.pending.complete(content());
    await tester.pumpAndSettle();
    expect(find.byType(AssistantSheet), findsNothing);
    expect(tester.takeException(), isNull);
  });
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px panel scrolls long options and answers at text scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final h = Harness();
        addTearDown(h.dispose);
        await open(
          tester,
          h,
          InMemoryAssistantRepository(
            content(
              options: [
                AssistantOption(
                  id: 'long',
                  title: 'Uzun soru başlığı ' * 18,
                  answer: 'Uzun yanıt metni. ' * 150,
                  destination: 'search',
                ),
                for (var i = 0; i < 8; i++)
                  AssistantOption(
                    id: 'other-$i',
                    title: 'Başka soru $i',
                    answer: 'Yanıt',
                  ),
              ],
            ),
          ),
          scale: scale,
        );
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('assistant-option-long')),
          150,
          scrollable:
              find
                  .descendant(
                    of: find.byType(AssistantSheet),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        );
        final option = find.byKey(const ValueKey('assistant-option-long'));
        final viewport = find.descendant(
          of: find.byType(AssistantSheet),
          matching: find.byType(ListView),
        );
        final visibleCard = tester
            .getRect(option)
            .intersect(tester.getRect(viewport));
        expect(visibleCard.height, greaterThan(0));
        await tester.tapAt(visibleCard.center);
        await tester.pumpAndSettle();
        final go = find.byKey(const ValueKey('assistant-go'));
        final list = tester.widget<ListView>(
          find.descendant(
            of: find.byType(AssistantSheet),
            matching: find.byType(ListView),
          ),
        );
        for (var i = 0; i < 5 && go.evaluate().isEmpty; i++) {
          list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(go);
        await tester.pumpAndSettle();
        expect(go, findsOneWidget);
        expect(tester.takeException(), isNull);
        await tap(tester, find.byTooltip('Asistanı kapat'));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('HOME_PREVIEW uses the app-injected content provider', (
    tester,
  ) async {
    if (!HomePreview.enabled) return;
    await tester.pumpWidget(
      MyApp(assistantRepository: InMemoryAssistantRepository(content())),
    );
    await tester.pumpAndSettle();
    await tap(tester, find.byKey(const ValueKey('home-ai')));
    expect(find.text('Karşılama metni sağlayıcıdan gelir.'), findsOneWidget);
    expect(find.text('Örnek içerik • Tasarım önizlemesi'), findsNothing);
    await tap(tester, find.byTooltip('Asistanı kapat'));
    expect(find.byType(HomeScreen), findsOneWidget);
  });
  test('free question validation trims input and rejects whitespace', () {
    for (final question in ['', '   ', '\n\t']) {
      expect(
        () => validatedAssistantQuestion(question),
        throwsA(isA<AssistantFailure>()),
      );
    }
    expect(validatedAssistantQuestion('  Bir soru  '), 'Bir soru');
  });
  test(
    'mock equality returns option answer/target and unknown has a demo fallback',
    () async {
      final repository = InMemoryAssistantRepository(
        content(),
        enableQuestions: true,
        responseDelay: Duration.zero,
      );
      final known = await repository.ask('  BIRINCI SORU  ');
      final exact = await repository.ask('  Birinci soru  ');
      expect(known.answer, 'Birinci yanıt');
      expect(exact.answer, 'Birinci yanıt');
      expect(exact.destination, 'search');
      expect(exact.isDemo, isTrue);
      final unknown = await repository.ask('Beklenmeyen bir soru');
      expect(
        unknown.answer,
        'Şu anda bu soruya yanıt veremiyorum. Hazır sorulardan birini seçerek devam edebilirsin.',
      );
      expect(unknown.destination, isNull);
      expect(unknown.isDemo, isTrue);
      await expectLater(
        repository.ask('   '),
        throwsA(isA<AssistantFailure>()),
      );
    },
  );
  test(
    'content-only providers stay compatible; default mock ask follows HOME_PREVIEW',
    () async {
      final repository = InMemoryAssistantRepository(content());
      expect(repository.supportsQuestions, isFalse);
      await expectLater(
        repository.ask('Bir soru'),
        throwsA(isA<AssistantFailure>()),
      );
      expect(
        InMemoryAssistantRepository.preview.supportsQuestions,
        HomePreview.enabled,
      );
    },
  );
  testWidgets(
    'typing a known question shows its answer and reuses existing navigation',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      await open(
        tester,
        h,
        InMemoryAssistantRepository(
          content(),
          enableQuestions: true,
          responseDelay: Duration.zero,
        ),
      );
      final field = find.byKey(const ValueKey('assistant-draft'));
      await tester.enterText(field, '  Birinci soru  ');
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('assistant-send')));
      expect(find.byKey(const ValueKey('assistant-question')), findsOneWidget);
      expect(find.text('Birinci soru'), findsOneWidget);
      expect(find.text('Birinci yanıt'), findsOneWidget);
      expect(find.text('Örnek içerik • Tasarım önizlemesi'), findsOneWidget);
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
      await tap(tester, find.byKey(const ValueKey('assistant-go')));
      expect(find.byType(AssistantSheet), findsNothing);
      expect(find.byType(SearchScreen), findsOneWidget);
    },
  );
  testWidgets(
    'unknown question is a normal answer without target; ready options remain usable',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      await open(
        tester,
        h,
        InMemoryAssistantRepository(
          content(),
          enableQuestions: true,
          responseDelay: Duration.zero,
        ),
      );
      await tester.enterText(
        find.byKey(const ValueKey('assistant-draft')),
        'Bu soruyu tanımıyor',
      );
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('assistant-send')));
      expect(
        find.text(
          'Şu anda bu soruya yanıt veremiyorum. Hazır sorulardan birini seçerek devam edebilirsin.',
        ),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('assistant-go')), findsNothing);
      expect(find.byKey(const ValueKey('assistant-ask-error')), findsNothing);
      await tap(tester, find.byKey(const ValueKey('assistant-back')));
      await tap(tester, find.byKey(const ValueKey('assistant-option-two')));
      expect(find.text('İkinci yanıt'), findsOneWidget);
    },
  );
  testWidgets(
    'blank input and stale rapid button/IME calls cannot submit twice',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      final repository = ControlledQuestions();
      await open(tester, h, repository);
      final field = find.byKey(const ValueKey('assistant-draft'));
      final button = find.byKey(const ValueKey('assistant-send'));
      for (final text in ['', '   ']) {
        await tester.enterText(field, text);
        await tester.pump();
        expect(tester.widget<IconButton>(button).onPressed, isNull);
        tester.widget<TextField>(field).onSubmitted!(text);
        await tester.pump();
      }
      expect(repository.questions, isEmpty);
      await tester.enterText(field, '  Yeni soru  ');
      await tester.pump();
      final send = tester.widget<IconButton>(button).onPressed!;
      final submit = tester.widget<TextField>(field).onSubmitted!;
      send();
      send();
      submit('  Yeni soru  ');
      await tester.pump();
      expect(repository.questions, ['Yeni soru']);
      expect(find.text('Yanıt bekleniyor...'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(tester.widget<IconButton>(button).onPressed, isNull);
      expect(tester.widget<TextField>(field).readOnly, isTrue);
      repository.response.complete(
        const AssistantReply(
          answer: 'Gerçek sağlayıcı sınırı için test yanıtı',
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Gerçek sağlayıcı sınırı için test yanıtı'),
        findsOneWidget,
      );
      expect(tester.widget<TextField>(field).controller!.text, isEmpty);
    },
  );
  testWidgets(
    'ask errors preserve the exact draft and a deliberate retry can succeed',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      final repository = ControlledQuestions();
      await open(tester, h, repository);
      final field = find.byKey(const ValueKey('assistant-draft'));
      await tester.enterText(field, '  Kaybolmayan soru  ');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pump();
      repository.response.completeError(
        StateError('untrusted transport detail'),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Sorun gönderilemedi. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      expect(find.textContaining('untrusted transport'), findsNothing);
      expect(
        tester.widget<TextField>(field).controller!.text,
        '  Kaybolmayan soru  ',
      );
      expect(repository.questions, hasLength(1));
      repository.response = Completer<AssistantReply>();
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pump();
      repository.response.complete(
        const AssistantReply(answer: 'Yanıt', destination: 'unsupported'),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('assistant-go')), findsNothing);
      expect(
        find.byKey(const ValueKey('assistant-unavailable')),
        findsOneWidget,
      );
      expect(repository.questions, hasLength(2));
      expect(find.byKey(const ValueKey('assistant-ask-error')), findsNothing);
    },
  );
  testWidgets(
    'closing a pending question ignores its response and next opening has no question history',
    (tester) async {
      final h = Harness();
      addTearDown(h.dispose);
      final repository = ControlledQuestions();
      await open(tester, h, repository);
      await tester.enterText(
        find.byKey(const ValueKey('assistant-draft')),
        'Geç yanıt',
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('assistant-send')));
      await tester.pump();
      await tester.tap(find.byTooltip('Asistanı kapat'));
      await tester.pumpAndSettle();
      repository.response.complete(const AssistantReply(answer: 'Görünmemeli'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tap(tester, find.byKey(const ValueKey('home-ai')));
      expect(find.text('Görünmemeli'), findsNothing);
      expect(find.byKey(const ValueKey('assistant-greeting')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('assistant-draft')))
            .controller!
            .text,
        isEmpty,
      );
    },
  );
  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px keyboard keeps the question field visible at scale $scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 568);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        final h = Harness();
        addTearDown(h.dispose);
        final repository = ControlledQuestions();
        await open(tester, h, repository, scale: scale);
        final field = find.byKey(const ValueKey('assistant-draft'));
        await tester.showKeyboard(field);
        tester.view.viewInsets = const FakeViewPadding(bottom: 280);
        await tester.enterText(field, 'Uzun bir soru metni ' * 20);
        await tester.pumpAndSettle();
        final rect = tester.getRect(field);
        expect(rect.bottom, lessThanOrEqualTo(288));
        expect(rect.left, greaterThanOrEqualTo(0));
        expect(rect.right, lessThanOrEqualTo(320));
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('assistant-send')));
        await tester.pump();
        expect(tester.takeException(), isNull);
        repository.response.completeError(
          const AssistantFailure('Örnek gönderim hatası.'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(tester.widget<TextField>(field).controller!.text, isNotEmpty);
        await tap(tester, find.byTooltip('Asistanı kapat'));
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'HOME_PREVIEW default provider accepts questions with an explicit demo result',
    (tester) async {
      if (!HomePreview.enabled) return;
      await tester.pumpWidget(const MyApp());
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-ai')));
      await tester.enterText(
        find.byKey(const ValueKey('assistant-draft')),
        'Tanınmayan soru',
      );
      await tester.pump();
      await tap(tester, find.byKey(const ValueKey('assistant-send')));
      expect(
        find.text(
          'Şu anda bu soruya yanıt veremiyorum. Hazır sorulardan birini seçerek devam edebilirsin.',
        ),
        findsOneWidget,
      );
      expect(find.text('Örnek içerik • Tasarım önizlemesi'), findsOneWidget);
    },
  );
}
