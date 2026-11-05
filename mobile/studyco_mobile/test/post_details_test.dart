import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/screens/post_details_screen.dart';

Post fixture({
  String id = 'first',
  String? description =
      'Dersin bütün açıklaması.\nİkinci satır da gösterilmeli.',
  String? department = 'Bilgisayar Mühendisliği',
  String? topic = 'Bağlı Listeler',
}) => Post(
  id: id,
  authorId: 'mock-detail-teacher',
  title: id == 'first' ? 'Veri Yapıları' : 'Lineer Cebir',
  authorName: id == 'first' ? 'Ayşe Demir' : 'Mehmet Kaya',
  department: department,
  topic: topic,
  description: description,
  createdAt: DateTime.utc(2026, 10, id == 'first' ? 28 : 27, 9),
  startsAt: DateTime(
    DateTime.now().year + 1,
    11,
    id == 'first' ? 3 : 4,
    14,
    15,
  ),
  endsAt: DateTime(DateTime.now().year + 1, 11, id == 'first' ? 3 : 4, 15, 45),
  location: id == 'first' ? 'Espressolab' : 'Colombia',
  type: PostType.tutoring,
  subject: id == 'first' ? PostSubject.coding : PostSubject.mathematics,
  offer: id == 'first' ? PostOffer.coffee : PostOffer.free,
  coffeeCount: id == 'first' ? 3 : 0,
);

Future<void> revealDetail(WidgetTester tester, String key) async {
  await tester.scrollUntilVisible(
    find.byKey(ValueKey(key)),
    const [
          'detail-summary',
          'detail-title',
          'detail-offer',
          'detail-topic',
          'detail-department',
        ].contains(key)
        ? -220
        : 220,
    maxScrolls: 200,
    scrollable:
        find
            .descendant(
              of: find.byKey(const ValueKey('post-details-scroll')),
              matching: find.byType(Scrollable),
            )
            .first,
  );
  await tester.pumpAndSettle();
}

void main() {
  for (final id in ['first', 'second']) {
    for (final target in ['card', 'arrow']) {
      testWidgets('$target opens the same $id Post and back restores Home', (
        tester,
      ) async {
        final first = fixture();
        final second = fixture(
          id: 'second',
          department: 'Matematik',
          topic: 'Vektör uzayları',
          description: 'İkinci ilana ait açıklama.',
        );
        final selected = id == 'first' ? first : second;
        final repository = InMemoryPostsRepository(
          initialPosts: [second, first],
        );
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder:
                  (context) => HomeScreen(
                    repository: repository,
                    user: sampleHomeUser,
                    onOpenPost:
                        (post) => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder:
                                (_) => PostDetailsScreen(
                                  user: sampleHomeUser,
                                  post: post,
                                  repository: repository,
                                ),
                          ),
                        ),
                  ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final originalHome = tester.widget<HomeScreen>(find.byType(HomeScreen));
        final finder = find.byKey(
          ValueKey(target == 'card' ? 'post-$id' : 'open-$id'),
        );
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
        if (target == 'card') {
          await tester.tapAt(tester.getTopLeft(finder) + const Offset(4, 4));
        } else {
          await tester.tap(finder);
        }
        await tester.pumpAndSettle();
        final detail = tester.widget<PostDetailsScreen>(
          find.byType(PostDetailsScreen),
        );
        expect(identical(detail.post, selected), isTrue);
        expect(find.byKey(ValueKey('detail-save-$id')), findsNothing);
        expect(find.byIcon(Icons.bookmark), findsNothing);
        expect(find.byIcon(Icons.bookmark_border), findsNothing);
        expect(
          identical(
            detail.post,
            repository.posts.firstWhere((post) => post.id == id),
          ),
          isTrue,
        );
        expect(find.text('İlan Detayları'), findsOneWidget);
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('detail-title'))).data,
          selected.title,
        );
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('detail-author'))).data,
          selected.authorName,
        );
        await revealDetail(tester, 'detail-topic');
        expect(find.text('Konu: ${selected.topic!}'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('detail-department')),
            matching: find.text(selected.department!),
          ),
          findsOneWidget,
        );
        await revealDetail(tester, 'detail-description');
        expect(find.text(selected.description!), findsOneWidget);
        await revealDetail(tester, 'detail-date');
        expect(
          find.text(
            id == 'first'
                ? '3 Kasım ${DateTime.now().year + 1}'
                : '4 Kasım ${DateTime.now().year + 1}',
          ),
          findsOneWidget,
        );
        expect(find.text('14:15–15:45'), findsOneWidget);
        await revealDetail(tester, 'detail-location');
        expect(
          tester
              .widget<Text>(find.byKey(const ValueKey('detail-location')))
              .data,
          selected.location,
        );
        await revealDetail(tester, 'detail-offer');
        expect(
          tester.widget<Text>(find.byKey(const ValueKey('detail-offer'))).data,
          selected.offerLabel,
        );
        expect(find.text('Mesaj Gönder'), findsNothing);
        await tester.tap(find.byKey(const ValueKey('apply-post')));
        await tester.pumpAndSettle();
        expect(find.text('Başvurun kaydedildi.'), findsOneWidget);
        expect(repository.posts, [second, first]);
        expect(find.byType(PostDetailsScreen), findsOneWidget);
        await tester.tap(find.byTooltip('Geri'));
        await tester.pumpAndSettle();
        expect(find.byType(PostDetailsScreen), findsNothing);
        expect(
          identical(
            tester.widget<HomeScreen>(find.byType(HomeScreen)),
            originalHome,
          ),
          isTrue,
        );
        expect(repository.posts.length, 2);
      });
    }
  }

  for (final description in <String?>[null, '', '   ']) {
    testWidgets(
      'Empty description is hidden (${description == null ? 'null' : description.length})',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final post = fixture(
          description: description,
          department: null,
          topic: null,
        );
        final repository = InMemoryPostsRepository(initialPosts: [post]);
        addTearDown(repository.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: PostDetailsScreen(
              post: post,
              repository: repository,
              user: sampleHomeUser,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('detail-location')), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-description')), findsNothing);
        expect(find.text('Ders Açıklaması'), findsNothing);
        expect(find.byKey(const ValueKey('detail-department')), findsNothing);
        expect(find.byKey(const ValueKey('detail-topic')), findsNothing);
        expect(find.byKey(const ValueKey('apply-post')), findsOneWidget);
      },
    );
  }

  testWidgets(
    'Summary contains each value once and date/time share two columns',
    (tester) async {
      tester.view.physicalSize = const Size(487, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final post = fixture();
      final repository = InMemoryPostsRepository(initialPosts: [post]);
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PostDetailsScreen(
            post: post,
            repository: repository,
            user: sampleHomeUser,
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (final key in [
        'detail-title',
        'detail-offer',
        'detail-topic',
        'detail-department',
      ]) {
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('detail-summary')),
            matching: find.byKey(ValueKey(key)),
          ),
          findsOneWidget,
        );
      }
      for (final value in [
        post.title,
        'Konu: ${post.topic!}',
        post.department!,
        post.offerLabel,
        post.location,
      ]) {
        expect(find.text(value), findsOneWidget);
      }
      expect(find.text('Ders ve İçerik Bilgileri'), findsNothing);
      expect(find.text('Ders Karşılığı'), findsNothing);
      expect(find.text('İlan oluşturulma zamanı'), findsNothing);
      expect(find.text('Ders Açıklaması'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('detail-date'))).dy,
        tester.getTopLeft(find.byKey(const ValueKey('detail-time'))).dy,
      );
      expect(find.text('Buluşma Konumu'), findsOneWidget);
      expect(find.byKey(const ValueKey('detail-map')), findsNothing);
      expect(find.byKey(const ValueKey('map-select')), findsNothing);
      expect(find.byIcon(Icons.map_outlined), findsNothing);
      for (final text in [
        'Konum Haritası',
        'Örnek konumlar',
        'Haritada Seç',
        'Görsel yer tutucu • Harita seçimi henüz hazır değil.',
      ]) {
        expect(find.text(text), findsNothing);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Another source route can open details and receive the back action',
    (tester) async {
      final post = fixture();
      final repository = InMemoryPostsRepository(initialPosts: [post]);
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder:
                (context) => Scaffold(
                  body: TextButton(
                    onPressed:
                        () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder:
                                (_) => PostDetailsScreen(
                                  user: sampleHomeUser,
                                  post: post,
                                  repository: repository,
                                ),
                          ),
                        ),
                    child: const Text('Kaynak ekran'),
                  ),
                ),
          ),
        ),
      );
      await tester.tap(find.text('Kaynak ekran'));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.widget<PostDetailsScreen>(find.byType(PostDetailsScreen)).post,
          post,
        ),
        isTrue,
      );
      await tester.tap(find.byTooltip('Geri'));
      await tester.pumpAndSettle();
      expect(find.text('Kaynak ekran'), findsOneWidget);
      expect(find.byType(PostDetailsScreen), findsNothing);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'Long details scroll on 320px at scale $scale with the apply button visible',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final description = List.filled(
          30,
          'Bağlı listeler ve ağaçlar üzerinde örneklerle çalışacağız.',
        ).join('\n');
        final post = fixture(
          description: description,
          department: 'Elektrik-Elektronik Mühendisliği ve Uzun Bölüm Adı',
        );
        final repository = InMemoryPostsRepository(initialPosts: [post]);
        addTearDown(repository.dispose);
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
            home: PostDetailsScreen(
              post: post,
              repository: repository,
              user: sampleHomeUser,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await revealDetail(tester, 'detail-description');
        final text = tester.widget<Text>(find.text(description));
        expect(text.maxLines, isNull);
        expect(text.data, description);
        await revealDetail(tester, 'detail-date');
        expect(
          tester.getTopLeft(find.byKey(const ValueKey('detail-time'))).dy,
          greaterThan(
            tester.getTopLeft(find.byKey(const ValueKey('detail-date'))).dy,
          ),
        );
        await revealDetail(tester, 'detail-location');
        expect(find.text(post.location), findsOneWidget);
        expect(find.byKey(const ValueKey('detail-map')), findsNothing);
        expect(find.text('Konum Haritası'), findsNothing);
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 220);
        addTearDown(tester.view.resetViewInsets);
        await tester.pumpAndSettle();
        final apply = tester.getRect(find.byKey(const ValueKey('apply-post')));
        expect(apply.bottom, lessThanOrEqualTo(420));
        expect(
          find.byKey(const ValueKey('apply-post')).hitTestable(),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
