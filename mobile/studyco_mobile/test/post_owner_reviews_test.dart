import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/screens/post_details_screen.dart';
import 'package:studyco_mobile/features/posts/widgets/post_owner_card.dart';
import 'package:studyco_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/data/in_memory_reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/widgets/reviews_repository_scope.dart';
import 'package:studyco_mobile/features/reviews/screens/reviews_screen.dart';
import 'package:studyco_mobile/features/reviews/widgets/review_card.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/my_posts_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/search/widgets/search_post_card.dart';
import 'applications_test.dart' as posts;
import 'reviews_test.dart' as reviews;

Finder ownerText(String text) => find.descendant(
  of: find.byKey(const ValueKey('detail-owner')),
  matching: find.text(text),
);
Future<InMemoryPostsRepository> mountDetail(
  WidgetTester tester,
  Post post,
  ReviewsRepository? source, {
  UserProfile? user = posts.user,
}) async {
  final repository = InMemoryPostsRepository(initialPosts: [post]);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder:
          (_, child) =>
              ReviewsRepositoryScope(repository: source, child: child!),
      home: PostDetailsScreen(post: post, repository: repository, user: user),
    ),
  );
  await tester.pumpAndSettle();
  return repository;
}

Future<void> revealOwner(WidgetTester tester) async {
  final target = find.byKey(const ValueKey('detail-owner'));
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      250,
      scrollable:
          find
              .descendant(
                of: find.byKey(const ValueKey('post-details-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
  }
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
}

Future<void> openOwner(WidgetTester tester) async {
  await revealOwner(tester);
  await tester.tapAt(
    tester.getTopLeft(find.byKey(const ValueKey('detail-owner'))) +
        const Offset(20, 20),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'author UUID selects their own average and list regardless of matching display names',
    (tester) async {
      const authorId = '11111111-1111-4111-8111-111111111111';
      final source = InMemoryReviewsRepository(
        initialByUser: {
          authorId: [
            reviews.review(1, rating: 3, comment: 'Sahibin yorumu'),
            reviews.review(2, rating: 4),
          ],
          'student': [
            reviews.review(3, rating: 1, comment: 'Diğer kullanıcı yorumu'),
          ],
        },
      );
      final post = posts.lesson(owner: authorId, author: posts.user.firstName);
      final repository = await mountDetail(tester, post, source);
      await revealOwner(tester);
      expect(ownerText('3.5 · 2 değerlendirme'), findsOneWidget);
      await openOwner(tester);
      final screen = tester.widget<ReviewsScreen>(find.byType(ReviewsScreen));
      expect(screen.userId, authorId);
      expect(screen.ownReviews, isFalse);
      expect(identical(screen.repository, source), isTrue);
      expect(find.text('Değerlendirmeler'), findsOneWidget);
      expect(
        find.text('Bu kullanıcıya verilen puanlar ve yorumlar.'),
        findsOneWidget,
      );
      expect(find.text('Genel Değerlendirme Puanı'), findsOneWidget);
      expect(find.byType(ReviewCard), findsWidgets);
      expect(find.byKey(const ValueKey('review-review-3')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      final detail = tester.widget<PostDetailsScreen>(
        find.byType(PostDetailsScreen),
      );
      expect(identical(detail.post, post), isTrue);
      expect(identical(detail.repository, repository), isTrue);
      expect(find.byKey(const ValueKey('apply-post')), findsOneWidget);
    },
  );
  testWidgets('own listing opens Değerlendirmelerim and keeps Apply hidden', (
    tester,
  ) async {
    final source = InMemoryReviewsRepository(
      initialByUser: {
        'student': [reviews.review(1)],
      },
    );
    await mountDetail(tester, posts.lesson(owner: 'student'), source);
    expect(find.byKey(const ValueKey('apply-post')), findsNothing);
    await openOwner(tester);
    expect(
      tester.widget<ReviewsScreen>(find.byType(ReviewsScreen)).ownReviews,
      isTrue,
    );
    expect(find.text('Değerlendirmelerim'), findsOneWidget);
    expect(find.text('Genel Değerlendirme Puanım'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apply-post')), findsNothing);
  });
  for (final id in <String?>[null, '', '   ']) {
    testWidgets(
      'missing author identity performs no query or fake lookup (${id?.length})',
      (tester) async {
        final source = reviews.ScriptedReviews(
          first: ReviewPage(items: [reviews.review(1)], nextCursor: null),
        );
        await mountDetail(
          tester,
          posts.lesson(owner: id, author: posts.user.firstName),
          source,
        );
        await revealOwner(tester);
        expect(source.calls, isEmpty);
        expect(ownerText('İlan sahibi kimliği mevcut değil.'), findsOneWidget);
        expect(find.byKey(const ValueKey('owner-rating')), findsNothing);
        await openOwner(tester);
        expect(find.byType(ReviewsScreen), findsNothing);
        expect(source.calls, isEmpty);
      },
    );
  }
  testWidgets('no reviews has no zero score or decorative rating star', (
    tester,
  ) async {
    await mountDetail(tester, posts.lesson(), InMemoryReviewsRepository());
    await revealOwner(tester);
    expect(ownerText('Henüz değerlendirme yok'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('detail-owner')),
        matching: find.byIcon(Icons.star_rounded),
      ),
      findsNothing,
    );
    await openOwner(tester);
    expect(
      find.text('Bu kullanıcıya henüz değerlendirme yapılmadı.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Henüz sana değerlendirme yapılmadı. Aldığın puanlar ve yorumlar burada yer alacak.',
      ),
      findsNothing,
    );
  });
  testWidgets(
    'partial page never masquerades as an empty collection or a full average',
    (tester) async {
      final source = reviews.ScriptedReviews(
        first: ReviewPage(items: [reviews.review(1)], nextCursor: 'tail'),
        next: ReviewPage(
          items: [reviews.review(2, rating: 1)],
          nextCursor: null,
        ),
      );
      await mountDetail(tester, posts.lesson(), source);
      await revealOwner(tester);
      expect(ownerText('Puan bilgisi şu anda gösterilemiyor.'), findsOneWidget);
      expect(ownerText('Henüz değerlendirme yok'), findsNothing);
      expect(find.byKey(const ValueKey('owner-rating')), findsNothing);
      await openOwner(tester);
      expect(find.byKey(const ValueKey('review-average')), findsNothing);
      expect(
        find.text('Genel puan için tüm değerlendirmeler yüklenmeli.'),
        findsOneWidget,
      );
      await reviews.tap(
        tester,
        find.byKey(const ValueKey('reviews-load-more')),
      );
      await reviews.top(tester);
      expect(find.text('3.0'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ownerText('Puan bilgisi şu anda gösterilemiyor.'), findsOneWidget);
      expect(source.calls.every((call) => call.userId == 'teacher'), isTrue);
    },
  );
  testWidgets(
    'trusted all-record statistics remain correct beyond the first twenty records',
    (tester) async {
      final source = InMemoryReviewsRepository(
        initialByUser: {
          'teacher': List.generate(
            21,
            (i) => reviews.review(i, rating: i == 20 ? 1 : 5),
          ),
        },
      );
      await mountDetail(tester, posts.lesson(), source);
      await revealOwner(tester);
      expect(ownerText('4.8 · 21 değerlendirme'), findsOneWidget);
    },
  );
  testWidgets(
    'loading, failure and inline retry remain separate from an empty result',
    (tester) async {
      final source =
          reviews.ScriptedReviews(
              first: ReviewPage(
                items: [reviews.review(1, rating: 4)],
                nextCursor: null,
              ),
            )
            ..firstGate = Completer<void>()
            ..failFirst = true;
      await mountDetail(tester, posts.lesson(), source);
      await revealOwner(tester);
      expect(ownerText('Puan bilgisi yükleniyor…'), findsOneWidget);
      source.firstGate!.complete();
      await tester.pumpAndSettle();
      expect(ownerText('Puan bilgisi şu anda gösterilemiyor.'), findsOneWidget);
      expect(ownerText('Henüz değerlendirme yok'), findsNothing);
      source.failFirst = false;
      await tester.tap(find.byKey(const ValueKey('owner-rating-retry')));
      await tester.pumpAndSettle();
      expect(ownerText('4.0 · 1 değerlendirme'), findsOneWidget);
      expect(find.byType(ReviewsScreen), findsNothing);
    },
  );
  testWidgets(
    'returning from author reviews refreshes only the author summary',
    (tester) async {
      final source = reviews.ScriptedReviews(
        first: ReviewPage(
          items: [reviews.review(1, rating: 4)],
          nextCursor: null,
        ),
      );
      await mountDetail(tester, posts.lesson(), source);
      await openOwner(tester);
      source.first = ReviewPage(
        items: [reviews.review(1, rating: 2), reviews.review(2, rating: 4)],
        nextCursor: null,
      );
      await tester.tap(find.byTooltip('Yenile'));
      await tester.pumpAndSettle();
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(ownerText('3.0 · 2 değerlendirme'), findsOneWidget);
      expect(
        tester
            .widget<PostDetailsScreen>(find.byType(PostDetailsScreen))
            .post
            .id,
        'lesson',
      );
    },
  );
  testWidgets('late summary cannot cross over to a different author', (
    tester,
  ) async {
    final source = reviews.DeferredReviews();
    Widget screen(String id) => MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: PostOwnerCard(
          key: const ValueKey('owner'),
          post: posts.lesson(owner: id),
          viewerId: 'student',
          reviewsRepository: source,
        ),
      ),
    );
    await tester.pumpWidget(screen('first'));
    await tester.pump();
    await tester.pumpWidget(screen('second'));
    await tester.pump();
    source.calls[1].response.complete(
      ReviewPage(items: [reviews.review(1, rating: 1)], nextCursor: null),
    );
    await tester.pumpAndSettle();
    source.calls[0].response.complete(
      ReviewPage(items: [reviews.review(2)], nextCursor: null),
    );
    await tester.pumpAndSettle();
    expect(find.text('1.0 · 1 değerlendirme'), findsOneWidget);
    expect(find.text('5.0 · 1 değerlendirme'), findsNothing);
  });
  for (final search in [false, true]) {
    testWidgets(
      '${search ? 'Search' : 'Home'} detail -> owner reviews -> Back -> Apply uses the same repositories',
      (tester) async {
        final post = posts.lesson();
        final repository = InMemoryPostsRepository(initialPosts: [post]);
        final source = InMemoryReviewsRepository(
          initialByUser: {
            'teacher': [reviews.review(1)],
          },
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder:
                (_, child) =>
                    ReviewsRepositoryScope(repository: source, child: child!),
            home: Builder(
              builder:
                  (context) =>
                      search
                          ? SearchScreen(
                            repository: repository,
                            user: posts.user,
                          )
                          : HomeScreen(
                            repository: repository,
                            user: posts.user,
                            onOpenPost:
                                (selected) => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PostDetailsScreen(
                                          post: selected,
                                          repository: repository,
                                          user: posts.user,
                                        ),
                                  ),
                                ),
                          ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final target =
            search
                ? find.byType(SearchPostCard).first
                : find.byKey(const ValueKey('open-card-lesson'));
        await tester.ensureVisible(target);
        await tester.tap(target);
        await tester.pumpAndSettle();
        await openOwner(tester);
        await tester.pageBack();
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('apply-post')));
        await tester.pumpAndSettle();
        expect(
          repository.applicationsRepository.forApplicant('student'),
          hasLength(1),
        );
        expect(find.text('Başvuruldu'), findsOneWidget);
      },
    );
  }
  testWidgets('My Posts -> own detail -> reviews returns with Apply hidden', (
    tester,
  ) async {
    final post = posts.lesson(owner: 'student');
    final repository = InMemoryPostsRepository(initialPosts: [post]);
    final source = InMemoryReviewsRepository(
      initialByUser: {
        'student': [reviews.review(1)],
      },
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder:
            (_, child) =>
                ReviewsRepositoryScope(repository: source, child: child!),
        home: MyPostsScreen(repository: repository, user: posts.user),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(post.title));
    await tester.pumpAndSettle();
    await openOwner(tester);
    expect(find.text('Değerlendirmelerim'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('apply-post')), findsNothing);
    await tester.tap(find.byTooltip('Geri'));
    await tester.pumpAndSettle();
    expect(find.byType(MyPostsScreen), findsOneWidget);
  });
  testWidgets(
    'long author name and owner reviews fit 320px at double text scale',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final post = posts.lesson(
        author: 'Çok uzun isimli bir ilan sahibi ve kullanıcı adı',
      );
      final repository = InMemoryPostsRepository(initialPosts: [post]);
      final source = InMemoryReviewsRepository(
        initialByUser: {
          'teacher': [
            reviews.review(
              1,
              comment: 'Uzun yorum',
              name: 'Çok uzun değerlendiren kullanıcı adı',
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
                child: ReviewsRepositoryScope(
                  repository: source,
                  child: child!,
                ),
              ),
          home: PostDetailsScreen(
            post: post,
            repository: repository,
            user: posts.user,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await revealOwner(tester);
      expect(tester.takeException(), isNull);
      await openOwner(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('Değerlendirmeler'), findsOneWidget);
    },
  );
}
