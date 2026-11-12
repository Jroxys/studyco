import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/applications/models/application.dart';
import 'package:studyco_mobile/features/applications/domain/applications_repository.dart';
import 'package:studyco_mobile/features/applications/data/in_memory_applications_repository.dart';
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/posts/screens/post_details_screen.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/search/screens/search_screen.dart';
import 'package:studyco_mobile/features/search/widgets/search_post_card.dart';

const user = UserProfile(
  id: 'student',
  firstName: 'Ada',
  department: 'Test',
  campus: 'Test',
);
Post lesson({
  String id = 'lesson',
  String? owner = 'teacher',
  bool past = false,
  String title = 'Ders A',
  String author = 'Öğretmen',
  DateTime? startsAt,
}) {
  final day = DateTime.now().add(Duration(days: past ? -2 : 2));
  final start = startsAt ?? DateTime(day.year, day.month, day.day, 14);
  return Post(
    id: id,
    authorId: owner,
    title: title,
    topic: 'Konu',
    description: 'Ders açıklaması',
    authorName: author,
    createdAt: DateTime.now(),
    startsAt: start,
    endsAt: start.add(const Duration(hours: 1)),
    location: 'Study',
    type: PostType.tutoring,
    subject: PostSubject.general,
    offer: PostOffer.free,
  );
}

Application request(
  String id,
  ApplicationStatus status, {
  String applicant = 'student',
  String postId = 'lesson',
  DateTime? cancelled,
  String? raw,
  String? conversation,
}) => Application(
  id: id,
  postId: postId,
  applicantId: applicant,
  status: status,
  locallyCancelledAt: cancelled,
  rawServerStatus: raw,
  conversationId: conversation,
);

class ControlledApplications extends InMemoryApplicationsRepository {
  ControlledApplications({
    required super.postsRepository,
    super.initialApplications,
  });
  bool openForApplications = true;
  @override
  bool isPostOpenForApplications(Post post) =>
      openForApplications && super.isPostOpenForApplications(post);
  @override
  bool canApply(Post post, {required String applicantId}) =>
      openForApplications && super.canApply(post, applicantId: applicantId);
  bool failLoad = false;
  bool failCancel = false;
  bool failCreate = false;
  Completer<void>? loadGate;
  Completer<void>? cancelGate;
  Completer<void>? createGate;
  int createCalls = 0;
  @override
  Future<void> refresh({required String applicantId}) async {
    await loadGate?.future;
    if (failLoad) throw StateError('offline');
  }

  @override
  Future<void> cancel(
    String applicationId, {
    required String applicantId,
  }) async {
    await cancelGate?.future;
    if (failCancel) throw StateError('offline');
    await super.cancel(applicationId, applicantId: applicantId);
  }

  @override
  Future<Application> create({
    required String postId,
    required String applicantId,
    ApplicationPerson? applicant,
  }) async {
    createCalls++;
    await createGate?.future;
    if (failCreate) throw StateError('offline');
    return super.create(
      postId: postId,
      applicantId: applicantId,
      applicant: applicant,
    );
  }
}

class ControlledPosts extends InMemoryPostsRepository {
  ControlledPosts() : super(initialPosts: [lesson()]);
  ControlledApplications? _source;
  @override
  ControlledApplications get applicationsRepository =>
      _source ??= ControlledApplications(postsRepository: this);
  @override
  void dispose() {
    _source?.dispose();
    super.dispose();
  }
}

Future<void> mount(
  WidgetTester tester,
  InMemoryPostsRepository posts,
  ApplicationsRepository? applications,
) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ApplicationsScreen(
        postsRepository: posts,
        repository: applications,
        user: user,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> openSheet(WidgetTester tester, String id) async {
  final card = find.byKey(ValueKey('application-$id'));
  if (card.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable:
          find
              .descendant(
                of: find.byKey(const ValueKey('applications-scroll')),
                matching: find.byType(Scrollable),
              )
              .first,
    );
  }
  await tap(tester, card);
}

Future<void> confirmCancel(WidgetTester tester) async {
  await tap(tester, find.byKey(const ValueKey('cancel-application')));
  await tap(tester, find.widgetWithText(TextButton, 'Başvurumu İptal Et'));
}

void main() {
  test(
    'shared source creates one request and rejects own, missing, unknown-owner and expired posts',
    () async {
      final posts = InMemoryPostsRepository(
        initialPosts: [
          lesson(),
          lesson(id: 'own', owner: 'student'),
          lesson(id: 'expired', past: true),
          lesson(id: 'legacy', owner: null),
        ],
      );
      final source = posts.applicationsRepository;
      expect(identical(source, posts.applicationsRepository), isTrue);
      final created = await source.create(
        postId: 'lesson',
        applicantId: 'student',
      );
      expect(created.postId, 'lesson');
      expect(created.applicantId, 'student');
      expect(created.status, ApplicationStatus.pending);
      await expectLater(
        source.create(postId: 'lesson', applicantId: 'student'),
        throwsA(isA<ApplicationFailure>()),
      );
      for (final id in ['own', 'missing', 'expired', 'legacy']) {
        await expectLater(
          source.create(postId: id, applicantId: 'student'),
          throwsA(isA<ApplicationFailure>()),
        );
      }
      expect(source.applications, hasLength(1));
      await source.create(postId: 'lesson', applicantId: 'other');
      expect(source.forApplicant('student'), hasLength(1));
    },
  );
  test(
    'filters preserve auto-cancelled, unknown and local cancellation separately',
    () {
      final values = [
        request('p', ApplicationStatus.pending),
        request('a', ApplicationStatus.accepted),
        request('r', ApplicationStatus.rejected),
        request('x', ApplicationStatus.autoCancelled, raw: 'AUTO_CANCELLED'),
        request('u', ApplicationStatus.unknown, raw: 'FUTURE_VALUE'),
        request('c', ApplicationStatus.pending, cancelled: DateTime.now()),
      ];
      expect(values.where(ApplicationFilter.all.matches), hasLength(6));
      expect(values.where(ApplicationFilter.pending.matches).single.id, 'p');
      expect(values.where(ApplicationFilter.accepted.matches).single.id, 'a');
      expect(values.where(ApplicationFilter.rejected.matches).single.id, 'r');
      expect(values[3].statusLabel, 'Otomatik İptal Edildi');
      expect(values[4].rawServerStatus, 'FUTURE_VALUE');
    },
  );
  test(
    'mock cancellation preserves record without inventing server status, validates current ownership and policy',
    () async {
      final posts = InMemoryPostsRepository(
        initialPosts: [lesson(), lesson(id: 'past', past: true)],
      );
      final source = InMemoryApplicationsRepository(
        postsRepository: posts,
        initialApplications: [
          request('p', ApplicationStatus.pending),
          request('a', ApplicationStatus.accepted),
          request('r', ApplicationStatus.rejected),
          request('x', ApplicationStatus.autoCancelled),
          request('u', ApplicationStatus.unknown),
          request('past', ApplicationStatus.pending, postId: 'past'),
        ],
      );
      for (final id in ['a', 'r', 'x', 'u', 'past', 'missing']) {
        await expectLater(
          source.cancel(id, applicantId: 'student'),
          throwsA(isA<ApplicationFailure>()),
        );
      }
      await expectLater(
        source.cancel('p', applicantId: 'other'),
        throwsA(isA<ApplicationFailure>()),
      );
      var notifications = 0;
      source.addListener(() => notifications++);
      await source.cancel('p', applicantId: 'student');
      final cancelled = source.applications.first;
      expect(cancelled.isLocallyCancelled, isTrue);
      expect(cancelled.status, ApplicationStatus.pending);
      expect(cancelled.rawServerStatus, isNull);
      expect(source.applications, hasLength(6));
      expect(notifications, 1);
      await expectLater(
        source.cancel('p', applicantId: 'student'),
        throwsA(isA<ApplicationFailure>()),
      );
      await expectLater(
        source.create(postId: 'lesson', applicantId: 'student'),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(notifications, 1);
    },
  );
  test(
    'deleting a listing keeps request identity and safely disables cancellation',
    () async {
      final posts = InMemoryPostsRepository(initialPosts: [lesson()]);
      final source = posts.applicationsRepository;
      final item = await source.create(
        postId: 'lesson',
        applicantId: 'student',
      );
      await posts.deletePost('lesson', ownerId: 'teacher');
      expect(source.applications.single.postId, 'lesson');
      expect(source.canCancel(item, applicantId: 'student'), isFalse);
    },
  );
  for (final entry in [false, true]) {
    testWidgets(
      'create from ${entry ? 'Search' : 'Home'} appears in Profile Applications and Back restores routes',
      (tester) async {
        final posts = InMemoryPostsRepository(initialPosts: [lesson()]);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder:
                  (context) =>
                      entry
                          ? SearchScreen(repository: posts, user: user)
                          : HomeScreen(
                            repository: posts,
                            user: user,
                            onOpenPost:
                                (post) => Navigator.of(context).push<void>(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => PostDetailsScreen(
                                          post: post,
                                          repository: posts,
                                          user: user,
                                        ),
                                  ),
                                ),
                          ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tap(
          tester,
          entry
              ? find.byType(SearchPostCard).first
              : find.byKey(const ValueKey('open-card-lesson')),
        );
        await tap(tester, find.byKey(const ValueKey('apply-post')));
        expect(
          posts.applicationsRepository.forApplicant('student'),
          hasLength(1),
        );
        expect(find.text('Başvuruldu'), findsOneWidget);
        await tap(tester, find.byTooltip('Geri'));
        await tester.pumpAndSettle();
        await tap(tester, find.byKey(const ValueKey('home-nav-3')));
        await tap(tester, find.byKey(const ValueKey('profile-applications')));
        expect(find.byType(ApplicationsScreen), findsOneWidget);
        expect(find.text('Ders A'), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(ProfileScreen), findsOneWidget);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(find.byType(entry ? SearchScreen : HomeScreen), findsOneWidget);
      },
    );
  }
  testWidgets(
    'all filters work and accepted sheet never offers cancellation or messaging',
    (tester) async {
      final posts = InMemoryPostsRepository(initialPosts: [lesson()]);
      final source = InMemoryApplicationsRepository(
        postsRepository: posts,
        initialApplications: [
          request('p', ApplicationStatus.pending),
          request(
            'a',
            ApplicationStatus.accepted,
            conversation: 'server-value',
          ),
          request('r', ApplicationStatus.rejected),
          request('x', ApplicationStatus.autoCancelled),
          request('u', ApplicationStatus.unknown),
        ],
      );
      await mount(tester, posts, source);
      for (final pair in [
        (ApplicationFilter.pending, 'p'),
        (ApplicationFilter.accepted, 'a'),
        (ApplicationFilter.rejected, 'r'),
      ]) {
        await tap(
          tester,
          find.byKey(ValueKey('application-filter-${pair.$1.name}')),
        );
        expect(find.byKey(ValueKey('application-${pair.$2}')), findsOneWidget);
        expect(find.byKey(const ValueKey('application-x')), findsNothing);
        expect(find.byKey(const ValueKey('application-u')), findsNothing);
      }
      await tap(
        tester,
        find.byKey(const ValueKey('application-filter-accepted')),
      );
      await openSheet(tester, 'a');
      expect(find.text('Başvuru Detayı'), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-application')), findsNothing);
      expect(find.text('Mesaj Gönder'), findsNothing);
      await tap(tester, find.byTooltip('Kapat'));
      await tap(tester, find.byKey(const ValueKey('application-filter-all')));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('application-x')),
        200,
        scrollable:
            find
                .descendant(
                  of: find.byKey(const ValueKey('applications-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      expect(find.text('Otomatik İptal Edildi'), findsOneWidget);
    },
  );
  testWidgets(
    'cancel confirmation can be dismissed; success updates sheet and filters',
    (tester) async {
      final posts = InMemoryPostsRepository(initialPosts: [lesson()]);
      final source = posts.applicationsRepository;
      final item = await source.create(
        postId: 'lesson',
        applicantId: 'student',
      );
      await mount(tester, posts, source);
      await openSheet(tester, item.id);
      await tap(tester, find.byKey(const ValueKey('cancel-application')));
      await tap(tester, find.text('Vazgeç'));
      expect(source.applications.single.isLocallyCancelled, isFalse);
      await confirmCancel(tester);
      expect(source.applications.single.isLocallyCancelled, isTrue);
      expect(find.byKey(const ValueKey('cancel-application')), findsNothing);
      expect(find.text('İptal Edildi'), findsNWidgets(2));
      await tap(tester, find.byTooltip('Kapat'));
      await tap(
        tester,
        find.byKey(const ValueKey('application-filter-pending')),
      );
      expect(find.text('Bu filtrede başvurun bulunmuyor.'), findsOneWidget);
    },
  );
  testWidgets(
    'pending cancel does not mutate until success; failure remains visible inside panel',
    (tester) async {
      final posts = InMemoryPostsRepository(initialPosts: [lesson()]);
      final source =
          ControlledApplications(
              postsRepository: posts,
              initialApplications: [request('p', ApplicationStatus.pending)],
            )
            ..cancelGate = Completer<void>()
            ..failCancel = true;
      await mount(tester, posts, source);
      await openSheet(tester, 'p');
      await confirmCancel(tester);
      expect(source.applications.single.isLocallyCancelled, isFalse);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('cancel-application')),
            )
            .onPressed,
        isNull,
      );
      source.cancelGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Başvuru iptal edilemedi. Lütfen tekrar deneyin.'),
        findsOneWidget,
      );
      expect(source.applications.single.isLocallyCancelled, isFalse);
      source.failCancel = false;
      await confirmCancel(tester);
      expect(source.applications.single.isLocallyCancelled, isTrue);
    },
  );
  testWidgets(
    'loading, error, retry, empty and unavailable API source are explicit',
    (tester) async {
      final posts = InMemoryPostsRepository();
      final source =
          ControlledApplications(postsRepository: posts)
            ..loadGate = Completer<void>()
            ..failLoad = true;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: ApplicationsScreen(
            postsRepository: posts,
            repository: source,
            user: user,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      source.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('Başvurular yüklenemedi. Lütfen tekrar deneyin.'),
        findsOneWidget,
      );
      source.failLoad = false;
      await tap(tester, find.text('Tekrar Dene'));
      expect(
        find.text('İlgini çeken bir ders bul, ilk başvurunu yap.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await mount(tester, posts, null);
      expect(find.text('Başvurular şu anda görüntülenemiyor.'), findsOneWidget);
    },
  );
  testWidgets(
    'missing listing and fields are safe and do not fabricate lesson data',
    (tester) async {
      final posts = InMemoryPostsRepository();
      final source = InMemoryApplicationsRepository(
        postsRepository: posts,
        initialApplications: [request('missing', ApplicationStatus.unknown)],
      );
      await mount(tester, posts, source);
      expect(find.text('İlan artık görüntülenemiyor.'), findsOneWidget);
      expect(find.text('İlan sahibi bilgisi mevcut değil.'), findsOneWidget);
      expect(find.text('Tarih bilgisi mevcut değil.'), findsOneWidget);
      await openSheet(tester, 'missing');
      expect(find.byKey(const ValueKey('cancel-application')), findsNothing);
      expect(find.text('Ders karşılığı bilgisi mevcut değil.'), findsOneWidget);
    },
  );
  testWidgets('create locks double taps, shows errors and supports retry', (
    tester,
  ) async {
    final posts = ControlledPosts();
    final source = posts.applicationsRepository;
    source.createGate = Completer<void>();
    source.failCreate = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: PostDetailsScreen(
          post: posts.posts.single,
          repository: posts,
          user: user,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('apply-post')));
    await tester.tap(find.byKey(const ValueKey('apply-post')));
    await tester.pumpAndSettle();
    expect(source.createCalls, 1);
    expect(source.applications, isEmpty);
    source.createGate!.complete();
    await tester.pumpAndSettle();
    expect(
      find.text('Başvuru gönderilemedi. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    source.failCreate = false;
    await tap(tester, find.byKey(const ValueKey('apply-post')));
    expect(source.applications, hasLength(1));
    expect(find.text('Başvuruldu'), findsOneWidget);
  });
  testWidgets(
    'browse from empty Applications opens Search and Home returns to Home',
    (tester) async {
      final posts = InMemoryPostsRepository();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: posts, user: user),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-nav-3')));
      await tap(tester, find.byKey(const ValueKey('profile-applications')));
      await tap(tester, find.text('İlanlara Göz At'));
      expect(find.byType(SearchScreen), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('home-nav-0')));
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(ApplicationsScreen), findsNothing);
    },
  );
  test(
    'mock eligibility rejects started lessons and invalid owners even before end time',
    () async {
      final started = lesson(
        id: 'started',
        startsAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      final posts = InMemoryPostsRepository(
        initialPosts: [
          started,
          lesson(id: 'legacy', owner: null),
          lesson(id: 'own', owner: 'student'),
          lesson(id: 'same-name', author: 'Ada'),
        ],
      );
      final source = posts.applicationsRepository;
      for (final item in posts.posts.take(3)) {
        expect(source.canApply(item, applicantId: 'student'), isFalse);
        await expectLater(
          source.create(postId: item.id, applicantId: 'student'),
          throwsA(isA<ApplicationFailure>()),
        );
      }
      expect(source.canApply(posts.posts.last, applicantId: 'student'), isTrue);
      await source.create(postId: 'same-name', applicantId: 'student');
      expect(source.applications.single.postId, 'same-name');
    },
  );
  testWidgets(
    'ineligible, own, unidentified and unauthenticated details have no Apply button',
    (tester) async {
      for (final item in [
        lesson(owner: 'student'),
        lesson(owner: null),
        lesson(past: true),
        lesson(startsAt: DateTime.now().subtract(const Duration(minutes: 5))),
      ]) {
        final posts = InMemoryPostsRepository(initialPosts: [item]);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: PostDetailsScreen(
              key: UniqueKey(),
              post: item,
              repository: posts,
              user: user,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('apply-post')), findsNothing);
      }
      final posts = InMemoryPostsRepository(initialPosts: [lesson()]);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PostDetailsScreen(
            key: UniqueKey(),
            post: posts.posts.single,
            repository: posts,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('apply-post')), findsNothing);
    },
  );
  testWidgets(
    'repository-closed listing hides Apply and rejects direct creation',
    (tester) async {
      final posts = ControlledPosts();
      posts.applicationsRepository.openForApplications = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: PostDetailsScreen(
            post: posts.posts.single,
            repository: posts,
            user: user,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('apply-post')), findsNothing);
      await expectLater(
        posts.applicationsRepository.create(
          postId: 'lesson',
          applicantId: 'student',
        ),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(posts.applicationsRepository.applications, isEmpty);
    },
  );
  for (final width in [320.0, 360.0, 390.0, 600.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'all application filters fit ${width}px at scale $scale without clipping',
        (tester) async {
          tester.view.physicalSize = Size(width, 800);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final posts = InMemoryPostsRepository();
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
              home: ApplicationsScreen(
                postsRepository: posts,
                repository: posts.applicationsRepository,
                user: user,
                onBrowse: () {},
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          for (final filter in ApplicationFilter.values) {
            final button = find.byKey(
              ValueKey('application-filter-${filter.name}'),
            );
            final rect = tester.getRect(button);
            expect(rect.left, greaterThanOrEqualTo(16));
            expect(rect.right, lessThanOrEqualTo(width - 16 + .01));
            await tap(tester, button);
          }
          expect(find.textContaining('sunucuya gönderilmez'), findsNothing);
          expect(find.textContaining('oturumda tutulur'), findsNothing);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
  testWidgets(
    'discovery hides expired, started, unknown-owner and closed posts while preserving history',
    (tester) async {
      final posts = ControlledPosts();
      final past = lesson(id: 'expired', past: true);
      final started = lesson(
        id: 'started',
        startsAt: DateTime.now().subtract(const Duration(minutes: 5)),
      );
      await posts.addPost(past);
      await posts.addPost(started);
      await posts.addPost(lesson(id: 'unknown', owner: null));
      expect(posts.discoverablePosts.map((post) => post.id), ['lesson']);
      expect(posts.posts, hasLength(4));
      final item = await posts.applicationsRepository.create(
        postId: 'lesson',
        applicantId: 'student',
      );
      expect(posts.discoverablePosts.map((post) => post.id), ['lesson']);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: posts, user: user),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('open-card-lesson')), findsOneWidget);
      for (final id in ['expired', 'started', 'unknown']) {
        expect(find.byKey(ValueKey('open-card-$id')), findsNothing);
      }
      await tap(tester, find.byKey(const ValueKey('home-nav-2')));
      expect(find.byType(SearchPostCard), findsOneWidget);
      posts.applicationsRepository.openForApplications = false;
      posts.notifyListeners();
      await tester.pumpAndSettle();
      expect(posts.discoverablePosts, isEmpty);
      expect(find.byType(SearchPostCard), findsNothing);
      expect(posts.posts, hasLength(4));
      await tester.pumpWidget(const SizedBox());
      await mount(tester, posts, posts.applicationsRepository);
      await openSheet(tester, item.id);
      expect(find.text('Başvuru Detayı'), findsOneWidget);
    },
  );
  testWidgets(
    '320px large-text list and sheet scroll without overflow or system inset collision',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final posts = InMemoryPostsRepository(
        initialPosts: [
          lesson(title: 'Uzun başlıklı bir ders ilanı', author: ''),
        ],
      );
      final source = posts.applicationsRepository;
      final item = await source.create(
        postId: 'lesson',
        applicantId: 'student',
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder:
              (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: const TextScaler.linear(2),
                  padding: const EdgeInsets.only(bottom: 24),
                ),
                child: child!,
              ),
          home: ApplicationsScreen(
            postsRepository: posts,
            repository: source,
            user: user,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await openSheet(tester, item.id);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.byKey(const ValueKey('cancel-application')),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('cancel-application'))).bottom,
        lessThanOrEqualTo(616),
      );
      expect(tester.takeException(), isNull);
    },
  );
}
