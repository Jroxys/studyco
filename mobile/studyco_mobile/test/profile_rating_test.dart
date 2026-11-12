import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/app/debug/home_preview_data.dart';
import 'package:studyco_mobile/app/debug/reviews_preview_data.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/profile/widgets/profile_widgets.dart';
import 'package:studyco_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/data/in_memory_reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/screens/reviews_screen.dart';
import 'reviews_test.dart' as fixtures;

const user = UserProfile(
  id: 'recipient',
  firstName: 'Ada',
  department: 'Test',
  campus: 'Test',
);
Finder ratingText(String text) => find.descendant(
  of: find.byKey(const ValueKey('profile-rating')),
  matching: find.text(text),
);
Widget profile(
  ReviewsRepository source, {
  UserProfile person = user,
  double scale = 1,
}) => MaterialApp(
  theme: AppTheme.light,
  builder:
      (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
  home: ProfileScreen(
    key: const ValueKey('profile'),
    user: person,
    reviewsRepository: source,
    onDestination: (_) {},
  ),
);
Future<void> mount(
  WidgetTester tester,
  ReviewsRepository source, {
  UserProfile person = user,
  double scale = 1,
}) async {
  await tester.pumpWidget(profile(source, person: person, scale: scale));
  await tester.pumpAndSettle();
}

Future<void> openReviews(WidgetTester tester, {bool menu = false}) async {
  final target = find.byKey(
    ValueKey(menu ? 'profile-reviews' : 'profile-rating'),
  );
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
  expect(find.byType(ReviewsScreen), findsOneWidget);
}

void main() {
  test(
    'shared page/repository summary refuses partial data and trusts only complete statistics',
    () async {
      final source = fixtures.ScriptedReviews(
        first: ReviewPage(items: [fixtures.review(1)], nextCursor: 'more'),
      );
      expect(source.first.statistics, isNull);
      expect(await source.fetchSummaryForUser('recipient'), isNull);
      source.first = ReviewPage(
        items: [fixtures.review(1, rating: 2), fixtures.review(2, rating: 4)],
        nextCursor: null,
      );
      expect((await source.fetchSummaryForUser('recipient'))!.average, 3);
    },
  );
  testWidgets(
    'debug profile card derives 4.7 and three reviews from the same preview records',
    (tester) async {
      final source = InMemoryReviewsRepository(
        initialByUser: previewReceivedReviews(),
      );
      await mount(tester, source, person: sampleHomeUser);
      expect(ratingText('4.7'), findsOneWidget);
      expect(ratingText('Değerlendirme sayısı: 3'), findsOneWidget);
      await openReviews(tester);
      expect(
        identical(
          tester.widget<ReviewsScreen>(find.byType(ReviewsScreen)).repository,
          source,
        ),
        isTrue,
      );
      expect(find.text('4.7'), findsOneWidget);
      expect(find.text('Toplam 3 değerlendirme'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ratingText('4.7'), findsOneWidget);
    },
  );
  testWidgets(
    'empty complete data displays a friendly empty state, not a fabricated zero rating',
    (tester) async {
      await mount(tester, InMemoryReviewsRepository());
      expect(ratingText('Henüz değerlendirme yok'), findsOneWidget);
      expect(ratingText('0.0'), findsNothing);
      expect(ratingText('—'), findsOneWidget);
    },
  );
  testWidgets(
    'partial page has no false overall mean or total; full mock statistics cover all pages',
    (tester) async {
      final source = fixtures.ScriptedReviews(
        first: ReviewPage(items: [fixtures.review(1)], nextCursor: 'more'),
      );
      await mount(tester, source);
      expect(ratingText('Genel puan bekleniyor.'), findsOneWidget);
      expect(ratingText('5.0'), findsNothing);
      expect(ratingText('Değerlendirme sayısı: 1'), findsNothing);
      final mock = InMemoryReviewsRepository(
        initialByUser: {
          'recipient': List.generate(
            21,
            (i) => fixtures.review(i, rating: i == 20 ? 1 : 5),
          ),
        },
      );
      await mount(tester, mock);
      expect(ratingText('4.8'), findsOneWidget);
      expect(ratingText('Değerlendirme sayısı: 21'), findsOneWidget);
    },
  );
  testWidgets(
    'loading and failure preserve the card; navigating and returning retries the source',
    (tester) async {
      final source =
          fixtures.ScriptedReviews(
              first: ReviewPage(
                items: [fixtures.review(1, rating: 4)],
                nextCursor: null,
              ),
            )
            ..firstGate = Completer<void>()
            ..failFirst = true;
      await tester.pumpWidget(profile(source));
      await tester.pump();
      expect(ratingText('Puan yükleniyor…'), findsOneWidget);
      final card = tester.getRect(find.byKey(const ValueKey('profile-rating')));
      source.firstGate!.complete();
      await tester.pumpAndSettle();
      expect(ratingText('Puan bilgisi alınamadı.'), findsOneWidget);
      expect(ratingText('Henüz değerlendirme yok'), findsNothing);
      source.failFirst = false;
      await openReviews(tester);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ratingText('4.0'), findsOneWidget);
      expect(
        tester.getSize(find.byKey(const ValueKey('profile-rating'))),
        card.size,
      );
    },
  );
  testWidgets(
    'both card and menu refresh current values after returning without a second review collection',
    (tester) async {
      final source = fixtures.ScriptedReviews(
        first: ReviewPage(items: [fixtures.review(1)], nextCursor: null),
      );
      await mount(tester, source);
      expect(ratingText('5.0'), findsOneWidget);
      await openReviews(tester);
      source.first = ReviewPage(
        items: [fixtures.review(1, rating: 3), fixtures.review(2, rating: 4)],
        nextCursor: null,
      );
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pumpAndSettle();
      expect(find.text('3.5'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ratingText('3.5'), findsOneWidget);
      expect(ratingText('Değerlendirme sayısı: 2'), findsOneWidget);
      await openReviews(tester, menu: true);
      source.first = ReviewPage(items: [], nextCursor: null);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ratingText('Henüz değerlendirme yok'), findsOneWidget);
      expect(source.calls.every((call) => call.userId == 'recipient'), isTrue);
    },
  );
  testWidgets('same names with different user IDs do not share scores', (
    tester,
  ) async {
    final source = InMemoryReviewsRepository(
      initialByUser: {
        'recipient': [fixtures.review(1, rating: 4)],
        'other': [fixtures.review(2, rating: 1)],
      },
    );
    await mount(tester, source);
    expect(ratingText('4.0'), findsOneWidget);
    await mount(
      tester,
      source,
      person: const UserProfile(
        id: 'other',
        firstName: 'Ada',
        department: 'Test',
        campus: 'Test',
      ),
    );
    expect(ratingText('1.0'), findsOneWidget);
    expect(ratingText('4.0'), findsNothing);
  });
  testWidgets(
    'late response from a previous user cannot replace the current score',
    (tester) async {
      final source = fixtures.DeferredReviews();
      await tester.pumpWidget(profile(source));
      await tester.pump();
      await tester.pumpWidget(
        profile(
          source,
          person: const UserProfile(
            id: 'other',
            firstName: 'Ada',
            department: 'Test',
            campus: 'Test',
          ),
        ),
      );
      await tester.pump();
      source.calls[1].response.complete(
        ReviewPage(items: [fixtures.review(2, rating: 1)], nextCursor: null),
      );
      await tester.pumpAndSettle();
      expect(ratingText('1.0'), findsOneWidget);
      source.calls[0].response.complete(
        ReviewPage(items: [fixtures.review(1)], nextCursor: null),
      );
      await tester.pumpAndSettle();
      expect(ratingText('1.0'), findsOneWidget);
      expect(ratingText('5.0'), findsNothing);
    },
  );
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'rating card fits ${width}px with large text and token card retains its placeholder',
      (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = InMemoryReviewsRepository(
          initialByUser: {
            'recipient': [fixtures.review(1, rating: 4)],
          },
        );
        await mount(tester, source, scale: 2);
        expect(ratingText('4.0'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final rating = tester.getRect(
          find.byKey(const ValueKey('profile-rating')),
        );
        final tokens = tester.getRect(
          find.byKey(const ValueKey('profile-tokens')),
        );
        expect(rating.width, tokens.width);
        final tokenWidget = tester.widget<ProfileStatCard>(
          find.byKey(const ValueKey('profile-tokens')),
        );
        expect(tokenWidget.value, '—');
      },
    );
  }
}
