import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/applications/models/application.dart';
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/reviews/data/in_memory_reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:studyco_mobile/features/reviews/models/review.dart';
import 'package:studyco_mobile/features/reviews/widgets/review_request_action.dart';
import 'package:studyco_mobile/features/reviews/widgets/reviews_repository_scope.dart';
import 'package:studyco_mobile/features/reviews/screens/reviews_screen.dart';

const studentId = '11111111-1111-4111-8111-111111111111';
const teacherId = '22222222-2222-4222-8222-222222222222';
const requestId = '33333333-3333-4333-8333-333333333333';
Application lesson({
  ApplicationStatus status = ApplicationStatus.accepted,
  String? completion = 'COMPLETED',
  String? teacher = teacherId,
}) => Application(
  id: requestId,
  postId: 'post',
  applicantId: studentId,
  teacherId: teacher,
  applicant: const ApplicationPerson(id: studentId, firstName: 'Öğrenci'),
  teacher: const ApplicationPerson(id: teacherId, firstName: 'Öğretmen'),
  status: status,
  completionStatus: completion,
  listing: ApplicationListing(
    id: 'post',
    topic: 'Python',
    startAt: DateTime.utc(2020),
    endAt: DateTime.utc(2020, 1, 1, 1),
  ),
);

class Fixture {
  Fixture({Application? application, String actor = studentId}) {
    posts = InMemoryPostsRepository(
      initialApplications: [application ?? lesson()],
    );
    reviews = InMemoryReviewsRepository(
      applicationsRepository: posts.applicationsRepository,
      authenticatedUser:
          () => ReviewReviewer(id: actor, firstName: 'Katılımcı'),
    );
  }
  late final InMemoryPostsRepository posts;
  late final InMemoryReviewsRepository reviews;
  void dispose() {
    reviews.dispose();
    posts.dispose();
  }

  Future<Review> send({
    String reviewer = studentId,
    String target = teacherId,
    int rating = 5,
    String? comment,
  }) => reviews.submitForRequest(
    requestId: requestId,
    reviewerId: reviewer,
    revieweeId: target,
    rating: rating,
    comment: comment,
  );
}

class ControlledReviews extends ReviewsRepository {
  Completer<Review>? gate;
  bool fail = false;
  int calls = 0;
  @override
  Future<ReviewPage> fetchForUser(
    String userId, {
    int limit = 20,
    String? cursor,
  }) async => ReviewPage(items: [], nextCursor: null);
  @override
  Future<Review> submitForRequest({
    required String requestId,
    required String reviewerId,
    required String revieweeId,
    required int rating,
    String? comment,
  }) async {
    calls++;
    if (fail) throw StateError('failure');
    return gate!.future;
  }
}

Future<void> openForm(WidgetTester tester, ReviewsRepository source) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Builder(
          builder:
              (context) => TextButton(
                onPressed:
                    () => showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      builder:
                          (_) => ReviewFormSheet(
                            repository: source,
                            requestId: requestId,
                            reviewerId: studentId,
                            eligibility: const ReviewEligibility(
                              revieweeId: teacherId,
                              revieweeName: 'Öğretmen',
                            ),
                            lessonTitle: 'Python',
                          ),
                    ),
                child: const Text('Aç'),
              ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Aç'));
  await tester.pumpAndSettle();
}

void main() {
  for (var rating = 1; rating <= 5; rating++) {
    test(
      'rating $rating, empty optional comment and trusted recipient summary',
      () async {
        final f = Fixture();
        addTearDown(f.dispose);
        final saved = await f.send(rating: rating, comment: '  ');
        expect(saved.requestId, requestId);
        expect(saved.reviewer.id, studentId);
        expect(saved.comment, isNull);
        expect(
          (await f.reviews.fetchSummaryForUser(teacherId))!.average,
          rating.toDouble(),
        );
        expect((await f.reviews.fetchForUser(studentId)).items, isEmpty);
      },
    );
  }
  test(
    'opposite participant can review independently, duplicate concurrent submission fails',
    () async {
      var actor = studentId;
      final posts = InMemoryPostsRepository(initialApplications: [lesson()]);
      addTearDown(posts.dispose);
      final source = InMemoryReviewsRepository(
        applicationsRepository: posts.applicationsRepository,
        authenticatedUser: () => ReviewReviewer(id: actor),
      );
      addTearDown(source.dispose);
      Future<Review> send(String who, String target) => source.submitForRequest(
        requestId: requestId,
        reviewerId: who,
        revieweeId: target,
        rating: 4,
      );
      final first = send(studentId, teacherId);
      await expectLater(
        send(studentId, teacherId),
        throwsA(isA<ReviewsFailure>()),
      );
      await first;
      expect(
        (await source.eligibilityForRequest(
          requestId,
          reviewerId: studentId,
        )).alreadyReviewed,
        isTrue,
      );
      actor = teacherId;
      await send(teacherId, studentId);
      expect((await source.fetchSummaryForUser(studentId))!.count, 1);
      expect((await source.fetchSummaryForUser(teacherId))!.count, 1);
    },
  );
  for (final status in ApplicationStatus.values) {
    if (status == ApplicationStatus.accepted) continue;
    test('blocks status $status despite COMPLETED and past date', () async {
      final f = Fixture(application: lesson(status: status));
      addTearDown(f.dispose);
      expect(
        (await f.reviews.eligibilityForRequest(
          requestId,
          reviewerId: studentId,
        )).canReview,
        isFalse,
      );
      await expectLater(f.send(), throwsA(isA<ReviewsFailure>()));
    });
  }
  for (final completion in [null, 'PENDING', 'completed', 'UNKNOWN']) {
    test('blocks unverified completion $completion', () async {
      final f = Fixture(application: lesson(completion: completion));
      addTearDown(f.dispose);
      await expectLater(f.send(), throwsA(isA<ReviewsFailure>()));
    });
  }
  test(
    'rejects actor spoof, outsider, target spoof, absent teacher and invalid payload',
    () async {
      final f = Fixture();
      addTearDown(f.dispose);
      await expectLater(
        f.send(reviewer: teacherId, target: studentId),
        throwsA(isA<ReviewsFailure>()),
      );
      await expectLater(
        f.send(target: studentId),
        throwsA(isA<ReviewsFailure>()),
      );
      for (final rating in [0, 6]) {
        await expectLater(
          f.send(rating: rating),
          throwsA(isA<ReviewsFailure>()),
        );
      }
      await expectLater(
        f.send(comment: 'a' * 1001),
        throwsA(isA<ReviewsFailure>()),
      );
      await f.send(comment: 'a' * 1000);
      final outsider = Fixture(actor: 'outsider');
      addTearDown(outsider.dispose);
      await expectLater(
        outsider.send(reviewer: 'outsider'),
        throwsA(isA<ReviewsFailure>()),
      );
      final missing = Fixture(application: lesson(teacher: null));
      addTearDown(missing.dispose);
      await expectLater(missing.send(), throwsA(isA<ReviewsFailure>()));
    },
  );
  test(
    'trusted full summary updates and recipient cursors invalidate on submission',
    () async {
      final posts = InMemoryPostsRepository(initialApplications: [lesson()]);
      addTearDown(posts.dispose);
      final initial = [
        for (var i = 0; i < 3; i++)
          Review(
            id: 'old-$i',
            requestId: 'old-request-$i',
            reviewer: ReviewReviewer(id: 'reviewer-$i'),
            rating: [5, 4, 5][i],
            createdAt: DateTime.utc(2020),
          ),
      ];
      final source = InMemoryReviewsRepository(
        applicationsRepository: posts.applicationsRepository,
        authenticatedUser: () => const ReviewReviewer(id: studentId),
        initialByUser: {teacherId: initial},
      );
      addTearDown(source.dispose);
      final first = await source.fetchForUser(teacherId, limit: 1);
      expect(first.overall!.count, 3);
      expect(first.overall!.average!.toStringAsFixed(1), '4.7');
      await source.submitForRequest(
        requestId: requestId,
        reviewerId: studentId,
        revieweeId: teacherId,
        rating: 2,
      );
      final summary = (await source.fetchSummaryForUser(teacherId))!;
      expect(summary.count, 4);
      expect(summary.average, 4);
      await expectLater(
        source.fetchForUser(teacherId, cursor: first.nextCursor),
        throwsA(isA<ReviewsFailure>()),
      );
    },
  );
  testWidgets('uncompleted application exposes no review action', (
    tester,
  ) async {
    final application = lesson(completion: null);
    final f = Fixture(application: application);
    addTearDown(f.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ReviewsRepositoryScope(
          repository: f.reviews,
          child: Scaffold(
            body: ReviewRequestAction(
              application: application,
              user: const UserProfile(
                id: studentId,
                firstName: 'A',
                department: 'B',
                campus: 'C',
              ),
              lessonTitle: 'Ders',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Değerlendir'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'form selects all stars, validates 1000 limit and sends empty comment',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await openForm(tester, f.reviews);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Gönder'))
            .onPressed,
        isNull,
      );
      for (var i = 1; i <= 5; i++) {
        await tester.tap(find.byTooltip('$i yıldız'));
        await tester.pump();
      }
      await tester.enterText(find.byType(TextFormField), 'x' * 1001);
      final send = find.widgetWithText(FilledButton, 'Gönder');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        find.text('Yorum en fazla 1000 karakter olabilir.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField), '');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.byType(ReviewFormSheet), findsNothing);
      expect((await f.reviews.fetchForUser(teacherId)).items.single.rating, 5);
    },
  );
  testWidgets(
    'failure keeps form and busy blocks repeated submits on small keyboard screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final source = ControlledReviews()..fail = true;
      addTearDown(source.dispose);
      await openForm(tester, source);
      await tester.tap(find.byTooltip('3 yıldız'));
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.resetViewInsets);
      await tester.pump();
      final send = find.widgetWithText(FilledButton, 'Gönder');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        find.text('Değerlendirme kaydedilemedi. Tekrar deneyebilirsin.'),
        findsOneWidget,
      );
      source.fail = false;
      source.gate = Completer<Review>();
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pump();
      expect(find.text('Gönderiliyor…'), findsOneWidget);
      expect(source.calls, 2);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Gönderiliyor…'),
            )
            .onPressed,
        isNull,
      );
      source.gate!.complete(
        Review(
          id: 'review',
          requestId: requestId,
          reviewer: const ReviewReviewer(id: studentId),
          rating: 3,
          createdAt: DateTime.now(),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
  for (final incoming in [false, true]) {
    testWidgets(
      'application detail shared form for incoming=$incoming updates real source',
      (tester) async {
        final actor = incoming ? teacherId : studentId;
        final target = incoming ? studentId : teacherId;
        final f = Fixture(actor: actor);
        addTearDown(f.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            builder:
                (_, child) => ReviewsRepositoryScope(
                  repository: f.reviews,
                  child: child!,
                ),
            home: ApplicationsScreen(
              postsRepository: f.posts,
              repository: f.posts.applicationsRepository,
              incoming: incoming,
              user: UserProfile(
                id: actor,
                firstName: 'Ad',
                department: 'Bölüm',
                campus: 'Kampüs',
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Python').first);
        await tester.pumpAndSettle();
        final review = find.text('Değerlendir');
        await tester.ensureVisible(review);
        await tester.tap(review);
        await tester.pumpAndSettle();
        expect(
          find.descendant(
            of: find.byType(ReviewFormSheet),
            matching: find.text(incoming ? 'Öğrenci' : 'Öğretmen'),
          ),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('4 yıldız'));
        await tester.pump();
        final send = find.widgetWithText(FilledButton, 'Gönder');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        expect((await f.reviews.fetchSummaryForUser(target))!.count, 1);
        expect(find.byType(ReviewFormSheet), findsNothing);
        expect(find.text('Değerlendirmen kaydedildi.'), findsOneWidget);
        expect((await f.reviews.fetchSummaryForUser(target))!.average, 4);
        expect(find.text('Değerlendir'), findsNothing);
      },
    );
  }
  testWidgets(
    'existing received list observes new review and refreshes trusted score',
    (tester) async {
      final f = Fixture();
      addTearDown(f.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ReviewsScreen(userId: teacherId, repository: f.reviews),
        ),
      );
      await tester.pumpAndSettle();
      await f.send(rating: 3);
      await tester.pumpAndSettle();
      expect(find.text('Toplam 1 değerlendirme'), findsOneWidget);
      expect(find.text('3.0'), findsOneWidget);
    },
  );
}
