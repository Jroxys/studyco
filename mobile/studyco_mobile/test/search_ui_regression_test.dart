import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/search/widgets/search_post_card.dart';
import 'search_test.dart' as fixtures;

void main() {
  testWidgets(
    'Clear link appears only for active criteria and reset hides it',
    (tester) async {
      final repository = InMemoryPostsRepository(
        initialPosts: [fixtures.listing(0)],
      );
      addTearDown(repository.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: SearchScreen(repository: repository, user: sampleHomeUser),
        ),
      );
      await tester.pumpAndSettle();
      final clear = find.byKey(const ValueKey('clear-search-filters'));
      expect(clear, findsNothing);
      await tester.enterText(
        find.byKey(const ValueKey('search-query')),
        'ışık',
      );
      await tester.pumpAndSettle();
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(clear, findsNothing);
      await fixtures.select<String?>(tester, 'Konum', 'Colombia');
      expect(clear, findsOneWidget);
      await tester.tap(clear);
      await tester.pumpAndSettle();
      expect(clear, findsNothing);
    },
  );

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px $scale: location selection, maximum coffee and all filters reachable',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final repository = InMemoryPostsRepository(
          initialPosts: [fixtures.listing(0), fixtures.listing(1)],
        );
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
            home: SearchScreen(repository: repository, user: sampleHomeUser),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Sıralama'), findsNothing);
        expect(find.text('Konu ara...'), findsOneWidget);
        await tester.tap(fixtures.menu('Konum'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Colombia').hitTestable());
        await tester.pumpAndSettle();
        final strip = find.byType(SingleChildScrollView);
        await tester.drag(strip, const Offset(-1000, 0));
        await tester.pumpAndSettle();
        expect(fixtures.menu('Ders').hitTestable(), findsOneWidget);
        expect(fixtures.menu('Kahve').hitTestable(), findsOneWidget);
        await tester.tap(fixtures.menu('Kahve'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('En fazla 2 Kahve').hitTestable());
        await tester.pumpAndSettle();
        expect(find.text('2 ilan bulundu'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      '320px $scale: equal topic hidden, distinct and long topic visible without overflow',
      (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final topic in [
          'İstatistik',
          'İSTATİSTİK',
          List.filled(10, 'Uzun konu açıklaması').join(' '),
        ]) {
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
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SearchPostCard(
                      post: fixtures.listing(0, topic: topic),
                      onOpen: () {},
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('İstatistik'), findsOneWidget);
          if (topic != 'İstatistik') expect(find.text(topic), findsOneWidget);
          expect(tester.takeException(), isNull);
        }
      },
    );
  }
}
