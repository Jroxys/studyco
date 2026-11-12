import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/reviews/models/review.dart';
import 'package:studyco_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/data/in_memory_reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/data/review_dto.dart';
import 'package:studyco_mobile/features/reviews/screens/reviews_screen.dart';
import 'package:studyco_mobile/features/reviews/widgets/review_card.dart';
import 'package:studyco_mobile/features/reviews/widgets/reviews_repository_scope.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';

const user = UserProfile(
  id: 'recipient',
  firstName: 'Ada',
  department: 'Test',
  campus: 'Test',
);
Review review(int i, {int rating = 5, String? comment, String? name = 'Ece'}) =>
    Review(
      id: 'review-$i',
      requestId: 'request-$i',
      reviewer: ReviewReviewer(
        id: 'reviewer-$i',
        firstName: name,
        lastNameInitial: 'K',
      ),
      rating: rating,
      comment: comment,
      createdAt: DateTime.utc(2030, 1, 20, 10).subtract(Duration(days: i)),
    );

class ScriptedReviews extends ReviewsRepository {
  ScriptedReviews({required this.first, this.next});
  ReviewPage first;
  ReviewPage? next;
  bool failFirst = false;
  bool failMore = false;
  Completer<void>? firstGate;
  Completer<void>? moreGate;
  final calls = <({String userId, String? cursor, int limit})>[];
  @override
  Future<ReviewPage> fetchForUser(
    String userId, {
    int limit = 20,
    String? cursor,
  }) async {
    validateReviewQuery(userId, limit);
    calls.add((userId: userId, cursor: cursor, limit: limit));
    if (cursor == null) {
      await firstGate?.future;
      if (failFirst) throw StateError('offline');
      return first;
    }
    await moreGate?.future;
    if (failMore) throw StateError('offline');
    return next!;
  }
}

class DeferredReviews extends ReviewsRepository {
  final calls = <({String userId, Completer<ReviewPage> response})>[];
  @override
  Future<ReviewPage> fetchForUser(
    String userId, {
    int limit = 20,
    String? cursor,
  }) {
    final completer = Completer<ReviewPage>();
    calls.add((userId: userId, response: completer));
    return completer.future;
  }
}

Future<void> mount(
  WidgetTester tester,
  ReviewsRepository? source, {
  String? userId = 'recipient',
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ReviewsScreen(userId: userId, repository: source),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      finder,
      400,
      maxScrolls: 200,
      scrollable:
          find
              .descendant(
                of: find.byKey(const ValueKey('reviews-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> top(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byKey(const ValueKey('reviews-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  scroll.position.jumpTo(0);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'statistics use unique repository records, empty has no invented average and invalid ratings fail',
    () {
      final stats = ReviewStatistics.fromReviews([
        review(1, rating: 5),
        review(2, rating: 3),
        review(3, rating: 4),
      ]);
      expect(stats.count, 3);
      expect(stats.average, 4);
      expect(ReviewStatistics.fromReviews([]).average, isNull);
      expect(ReviewStatistics.fromReviews([review(1), review(1)]).count, 1);
      expect(() => review(1, rating: 0), throwsRangeError);
      expect(() => review(1, rating: 6), throwsRangeError);
    },
  );
  test(
    'mock queries by recipient ID and computes full statistics beyond the default first 20',
    () async {
      final values = List.generate(
        21,
        (i) => review(i, rating: i == 20 ? 1 : 5),
      );
      final source = InMemoryReviewsRepository(
        initialByUser: {
          'recipient': values,
          'other': [review(99, rating: 2)],
        },
      );
      values.clear();
      final first = await source.fetchForUser('recipient');
      expect(first.items, hasLength(20));
      expect(first.nextCursor, isNotNull);
      expect(first.overall!.count, 21);
      expect(first.overall!.average, closeTo(101 / 21, .0001));
      expect(() => first.items.add(review(100)), throwsUnsupportedError);
      final last = await source.fetchForUser(
        'recipient',
        cursor: first.nextCursor,
      );
      expect(last.items.single.id, 'review-20');
      expect(last.nextCursor, isNull);
      final other = await source.fetchForUser('other');
      expect(other.overall!.average, 2);
      expect((await source.fetchForUser('unknown')).items, isEmpty);
      await expectLater(
        source.fetchForUser('other', cursor: first.nextCursor),
        throwsA(isA<ReviewsFailure>()),
      );
      await expectLater(
        source.fetchForUser('recipient', limit: 51),
        throwsRangeError,
      );
      await expectLater(
        source.fetchForUser('recipient', limit: 0),
        throwsRangeError,
      );
      await expectLater(
        source.fetchForUser(''),
        throwsA(isA<ReviewsFailure>()),
      );
      expect(
        (await source.fetchForUser('recipient', limit: 50)).nextCursor,
        isNull,
      );
    },
  );
  test(
    'DTO preserves UUIDs and nullable comments without inventing lesson, recipient or summary fields',
    () {
      final json = <String, dynamic>{
        'id': '11111111-1111-4111-8111-111111111111',
        'requestId': '22222222-2222-4222-8222-222222222222',
        'rating': 4,
        'comment': null,
        'createdAt': '2030-01-02T10:00:00Z',
        'reviewer': {
          'id': '33333333-3333-4333-8333-333333333333',
          'firstName': 'Ece',
          'lastNameInitial': 'K',
          'departmentId': 'dept-id',
        },
        'lessonTitle': 'Do not display',
        'reviewee': {'id': 'ignored'},
      };
      final item = ReviewDto.fromJson(json);
      expect(item.id, json['id']);
      expect(item.requestId, json['requestId']);
      expect(item.reviewer.displayName, 'Ece K.');
      expect(item.comment, isNull);
      expect(item.createdAt.isUtc, isTrue);
      expect(item.reviewer.departmentId, 'dept-id');
      final page = ReviewDto.pageFromJson({
        'items': [json],
        'nextCursor': 'opaque+/token',
        'average': 4.8,
        'total': 12,
      });
      expect(page.nextCursor, 'opaque+/token');
      expect(page.overall, isNull);
      for (final rating in [0, 6, 4.5, '5']) {
        expect(
          () => ReviewDto.fromJson({...json, 'rating': rating}),
          throwsFormatException,
        );
      }
      expect(
        () => ReviewDto.pageFromJson({
          'items': [json],
        }),
        throwsFormatException,
      );
      expect(
        () => ReviewDto.pageFromJson({
          'items': [json],
          'nextCursor': 3,
        }),
        throwsFormatException,
      );
      expect(
        () => ReviewDto.fromJson({...json, 'createdAt': 'invalid'}),
        throwsFormatException,
      );
    },
  );
  testWidgets('empty received reviews show no fabricated score', (
    tester,
  ) async {
    await mount(tester, InMemoryReviewsRepository());
    expect(find.text('Henüz değerlendirme yok'), findsOneWidget);
    expect(find.byKey(const ValueKey('review-average')), findsNothing);
    expect(find.byType(ReviewCard), findsNothing);
    expect(find.text('İlk yorumun burada görünecek'), findsOneWidget);
  });
  for (final comment in <String?>[null, '', '   ']) {
    testWidgets('blank comment has no placeholder block (${comment?.length})', (
      tester,
    ) async {
      await mount(
        tester,
        InMemoryReviewsRepository(
          initialByUser: {
            'recipient': [review(1, comment: comment)],
          },
        ),
      );
      expect(
        find.byKey(const ValueKey('review-comment-review-1')),
        findsNothing,
      );
      expect(find.text('Ece K.'), findsOneWidget);
      expect(find.text('Toplam 1 değerlendirme'), findsOneWidget);
    });
  }
  testWidgets(
    'first partial page never masquerades as overall score; all loaded pages unlock the real average',
    (tester) async {
      final source = ScriptedReviews(
        first: ReviewPage(items: [review(1)], nextCursor: 'tail'),
        next: ReviewPage(items: [review(2, rating: 1)], nextCursor: null),
      );
      await mount(tester, source);
      expect(find.byKey(const ValueKey('review-average')), findsNothing);
      expect(
        find.text('Genel puan için tüm değerlendirmeler yüklenmeli.'),
        findsOneWidget,
      );
      expect(find.text('Toplam 1 değerlendirme'), findsNothing);
      await tap(tester, find.byKey(const ValueKey('reviews-load-more')));
      await top(tester);
      expect(find.text('3.0'), findsOneWidget);
      expect(find.text('Toplam 2 değerlendirme'), findsOneWidget);
      expect(source.calls.last.cursor, 'tail');
      expect(source.calls.first.limit, 20);
    },
  );
  testWidgets(
    'loading, initial failure and retry are clear; refresh failure does not imply zero reviews',
    (tester) async {
      final source =
          ScriptedReviews(
              first: ReviewPage(
                items: [review(1, rating: 4)],
                nextCursor: null,
              ),
            )
            ..firstGate = Completer<void>()
            ..failFirst = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ReviewsScreen(userId: 'recipient', repository: source),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.firstGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Değerlendirmeler yüklenemedi. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      expect(find.text('Henüz değerlendirme yok'), findsNothing);
      source.failFirst = false;
      await tap(tester, find.text('Tekrar Dene'));
      expect(find.text('4.0'), findsOneWidget);
      source.failFirst = true;
      await tap(tester, find.byTooltip('Yenile'));
      expect(find.byKey(const ValueKey('review-average')), findsNothing);
      expect(
        find.text('Puan bilgisi şu anda görüntülenemiyor.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'more-page failure keeps cards and retries the same cursor, double taps stay coalesced',
    (tester) async {
      final source =
          ScriptedReviews(
              first: ReviewPage(items: [review(1)], nextCursor: 'tail'),
              next: ReviewPage(items: [review(2, rating: 3)], nextCursor: null),
            )
            ..moreGate = Completer<void>()
            ..failMore = true;
      await mount(tester, source);
      await tap(tester, find.byKey(const ValueKey('reviews-load-more')));
      await tester.tap(find.byKey(const ValueKey('reviews-load-more')));
      await tester.pump();
      expect(source.calls, hasLength(2));
      source.moreGate!.complete();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('review-review-1')), findsOneWidget);
      expect(
        find.text('Diğer değerlendirmeler yüklenemedi. Lütfen tekrar dene.'),
        findsOneWidget,
      );
      source.failMore = false;
      await tap(tester, find.byKey(const ValueKey('reviews-load-more')));
      await top(tester);
      expect(source.calls.map((call) => call.cursor), [null, 'tail', 'tail']);
      expect(find.text('Toplam 2 değerlendirme'), findsOneWidget);
    },
  );
  testWidgets(
    'duplicate review IDs cannot inflate the count and repeated cursors stop',
    (tester) async {
      final source = ScriptedReviews(
        first: ReviewPage(items: [review(1)], nextCursor: 'tail'),
        next: ReviewPage(items: [review(1, rating: 3)], nextCursor: 'tail'),
      );
      await mount(tester, source);
      await tap(tester, find.byKey(const ValueKey('reviews-load-more')));
      expect(
        find.text(
          'Diğer değerlendirmeler yüklenemedi. Listeyi yenileyip tekrar dene.',
        ),
        findsOneWidget,
      );
      source.next = ReviewPage(items: [review(1, rating: 3)], nextCursor: null);
      await tap(tester, find.byKey(const ValueKey('reviews-load-more')));
      await top(tester);
      expect(find.text('Toplam 1 değerlendirme'), findsOneWidget);
      expect(find.text('3.0'), findsOneWidget);
    },
  );
  testWidgets('changing recipient ignores stale previous-user responses', (
    tester,
  ) async {
    final source = DeferredReviews();
    Widget screen(String id) => MaterialApp(
      theme: AppTheme.light,
      home: ReviewsScreen(
        key: const ValueKey('recipient-screen'),
        userId: id,
        repository: source,
      ),
    );
    await tester.pumpWidget(screen('first'));
    await tester.pump();
    await tester.pumpWidget(screen('second'));
    await tester.pump();
    source.calls[1].response.complete(
      ReviewPage(
        items: [review(2, comment: 'İkinci kullanıcı')],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
    source.calls[0].response.complete(
      ReviewPage(
        items: [review(1, comment: 'İlk kullanıcı')],
        nextCursor: null,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('review-review-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('review-review-1')), findsNothing);
  });
  testWidgets(
    'missing real user ID is never replaced with a session key for a remote source',
    (tester) async {
      final source = ScriptedReviews(
        first: ReviewPage(items: [review(1)], nextCursor: null),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ProfileScreen(
            user: const UserProfile(
              firstName: 'Ada',
              department: 'Test',
              campus: 'Test',
            ),
            reviewsRepository: source,
            onDestination: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile-reviews')));
      await tester.tap(find.byKey(const ValueKey('profile-reviews')));
      await tester.pumpAndSettle();
      expect(source.calls, isEmpty);
      expect(
        find.text('Değerlendirmeler şu anda görüntülenemiyor.'),
        findsOneWidget,
      );
    },
  );
  testWidgets(
    'Profile rating and menu reuse the app-level repository through Home and Search routes',
    (tester) async {
      final source = InMemoryReviewsRepository(
        initialByUser: {
          'recipient': [review(1)],
          'other': [review(2, rating: 1)],
        },
      );
      final posts = InMemoryPostsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (_, child) =>
                  ReviewsRepositoryScope(repository: source, child: child!),
          home: HomeScreen(repository: posts, user: user),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('profile-rating')));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.widget<ReviewsScreen>(find.byType(ReviewsScreen)).repository,
          source,
        ),
        isTrue,
      );
      expect(find.text('5.0'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-nav-2')));
      await tester.pumpAndSettle();
      expect(find.byType(SearchScreen), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('home-nav-3')));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('profile-reviews')));
      await tester.tap(find.byKey(const ValueKey('profile-reviews')));
      await tester.pumpAndSettle();
      expect(
        identical(
          tester.widget<ReviewsScreen>(find.byType(ReviewsScreen)).repository,
          source,
        ),
        isTrue,
      );
      expect(find.text('5.0'), findsOneWidget);
      expect(find.byKey(const ValueKey('review-review-2')), findsNothing);
    },
  );
  testWidgets('empty intermediate page is not falsely reported as no reviews', (
    tester,
  ) async {
    final source = ScriptedReviews(
      first: ReviewPage(items: [], nextCursor: 'tail'),
      next: ReviewPage(items: [review(1)], nextCursor: null),
    );
    await mount(tester, source);
    expect(find.text('Henüz değerlendirme yok'), findsNothing);
    await tap(tester, find.byKey(const ValueKey('reviews-load-more')));
    await top(tester);
    expect(find.text('Toplam 1 değerlendirme'), findsOneWidget);
  });
  for (final size in [const Size(320, 568), const Size(390, 800)]) {
    testWidgets(
      'long reviewer and comments fit ${size.width}px at double text scale',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final source = InMemoryReviewsRepository(
          initialByUser: {
            'recipient': [
              review(
                1,
                name: 'Çok uzun bir değerlendirme yapan kullanıcının adı',
                comment: List.filled(
                  12,
                  'Uzun ve okunabilir bir değerlendirme yorumu.',
                ).join(' '),
              ),
            ],
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder:
                (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
            home: ReviewsScreen(userId: 'recipient', repository: source),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('review-review-1')),
          250,
          scrollable:
              find
                  .descendant(
                    of: find.byKey(const ValueKey('reviews-scroll')),
                    matching: find.byType(Scrollable),
                  )
                  .first,
        );
        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('review-comment-review-1')),
          findsOneWidget,
        );
      },
    );
  }
}
