import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:studyco_mobile/app/theme/app_theme.dart';
import 'package:studyco_mobile/features/applications/models/application.dart';
import 'package:studyco_mobile/features/applications/domain/applications_repository.dart';
import 'package:studyco_mobile/features/applications/data/request_dto.dart';
import 'package:studyco_mobile/features/applications/data/in_memory_applications_repository.dart';
import 'package:studyco_mobile/features/applications/screens/applications_screen.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';
import 'package:studyco_mobile/features/posts/data/in_memory_posts_repository.dart';
import 'package:studyco_mobile/features/profile/models/user_profile.dart';
import 'package:studyco_mobile/features/profile/screens/profile_screen.dart';
import 'package:studyco_mobile/features/profile/screens/my_posts_screen.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';

const owner = UserProfile(
  id: 'teacher',
  firstName: 'Ada',
  department: 'Test',
  campus: 'Test',
);
Post lesson(
  String id, {
  String teacher = 'teacher',
  DateTime? start,
  PostStatus status = PostStatus.published,
  String? title,
}) {
  final d = DateTime.now().add(const Duration(days: 2));
  final at = start ?? DateTime(d.year, d.month, d.day, 14);
  return Post(
    id: id,
    authorId: teacher,
    authorName: 'Ada',
    title: title ?? 'Ders $id',
    topic: 'Konu',
    description: 'Açıklama',
    createdAt: DateTime.now(),
    startsAt: at,
    endsAt: at.add(const Duration(hours: 1)),
    location: 'Study',
    type: PostType.tutoring,
    subject: PostSubject.general,
    offer: PostOffer.free,
    status: status,
  );
}

Application request(
  String id, {
  String postId = 'owned',
  String student = 'student',
  String teacher = 'teacher',
  ApplicationStatus status = ApplicationStatus.pending,
  bool cancelled = false,
  String? name,
}) => Application(
  id: id,
  postId: postId,
  applicantId: student,
  teacherId: teacher,
  status: status,
  applicant: ApplicationPerson(
    id: student,
    firstName: name ?? 'Öğrenci $student',
    lastNameInitial: 'K',
  ),
  createdAt: DateTime.now(),
  agreedTokenAmount: 0,
  locallyCancelledAt: cancelled ? DateTime.now() : null,
);
InMemoryPostsRepository fixture() => InMemoryPostsRepository(
  initialPosts: [lesson('owned'), lesson('other', teacher: 'other-teacher')],
  initialApplications: [
    request('p1'),
    request('p2', student: 'second'),
    request('p3', student: 'third'),
    request(
      'other',
      postId: 'other',
      teacher: 'other-teacher',
      student: 'fourth',
    ),
  ],
);

class ControlledIncoming extends InMemoryApplicationsRepository {
  ControlledIncoming({
    required super.postsRepository,
    required super.initialApplications,
  });
  Completer<void>? loadGate;
  Completer<void>? acceptGate;
  bool failLoad = false;
  bool failAccept = false;
  bool failReject = false;
  @override
  Future<void> refreshIncoming({required String ownerId}) async {
    await loadGate?.future;
    if (failLoad) throw StateError('offline');
  }

  @override
  Future<void> accept(String id, {required String ownerId}) async {
    await acceptGate?.future;
    if (failAccept) throw StateError('offline');
    await super.accept(id, ownerId: ownerId);
  }

  @override
  Future<void> reject(String id, {required String ownerId}) async {
    if (failReject) throw StateError('offline');
    await super.reject(id, ownerId: ownerId);
  }
}

class ControlledPosts extends InMemoryPostsRepository {
  ControlledPosts() : super(initialPosts: [lesson('owned')]);
  ControlledIncoming? _source;
  bool failBooking = false;
  @override
  ControlledIncoming get applicationsRepository =>
      _source ??= ControlledIncoming(
        postsRepository: this,
        initialApplications: [request('p1'), request('p2', student: 'second')],
      );
  @override
  void commitBooking(
    String id, {
    required String ownerId,
    required VoidCallback commitApplications,
  }) {
    if (failBooking) throw StateError('booking failed');
    super.commitBooking(
      id,
      ownerId: ownerId,
      commitApplications: commitApplications,
    );
  }

  @override
  void dispose() {
    _source?.dispose();
    super.dispose();
  }
}

Future<void> mount(
  WidgetTester tester,
  InMemoryPostsRepository posts, {
  UserProfile user = owner,
  bool incoming = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      home: ApplicationsScreen(
        incoming: incoming,
        repository: posts.applicationsRepository,
        postsRepository: posts,
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

Future<void> decide(
  WidgetTester tester,
  String id,
  bool accept, {
  String surface = 'card',
}) async {
  await tap(
    tester,
    find.byKey(ValueKey('$surface-${accept ? 'accept' : 'reject'}-$id')),
  );
  await tap(
    tester,
    find.widgetWithText(TextButton, accept ? 'Kabul Et' : 'Reddet'),
  );
}

void main() {
  test(
    'one shared source scopes incoming by owner identity and returns authorized details',
    () {
      final posts = fixture();
      final source = posts.applicationsRepository;
      expect(source.forOwner('teacher').map((a) => a.id), ['p1', 'p2', 'p3']);
      expect(source.forApplicant('student').single.id, 'p1');
      expect(source.getForUser('p1', userId: 'unrelated'), isNull);
      expect(
        source.getForUser('p1', userId: 'teacher')!.applicantId,
        'student',
      );
      expect(source.forOwner('other-teacher').single.id, 'other');
    },
  );
  test(
    'accept updates all related pending requests and booked listing before notifications',
    () async {
      final posts = fixture();
      final source = posts.applicationsRepository;
      final observed = <bool>[];
      void record() => observed.add(
        posts.posts.first.status == PostStatus.booked &&
            source.getForUser('p1', userId: 'teacher')!.status ==
                ApplicationStatus.accepted &&
            source.getForUser('p2', userId: 'teacher')!.status ==
                ApplicationStatus.autoCancelled,
      );
      source.addListener(record);
      posts.addListener(record);
      await source.accept('p1', ownerId: 'teacher');
      expect(observed, [true, true]);
      expect(
        source
            .forOwner('teacher')
            .where((a) => a.status == ApplicationStatus.autoCancelled),
        hasLength(2),
      );
      expect(
        source.forOwner('other-teacher').single.status,
        ApplicationStatus.pending,
      );
      expect(
        source.forApplicant('student').single.status,
        ApplicationStatus.accepted,
      );
      expect(source.forApplicant('student').single.respondedAt, isNotNull);
      expect(source.forApplicant('student').single.conversationId, isNull);
      expect(posts.discoverablePosts.map((p) => p.id), ['other']);
      await expectLater(
        posts.updatePost(lesson('owned'), ownerId: 'teacher'),
        throwsStateError,
      );
      await expectLater(
        posts.deletePost('owned', ownerId: 'teacher'),
        throwsStateError,
      );
    },
  );
  test(
    'reject affects only the chosen request; cancel and previous terminal states stay unchanged on accept',
    () async {
      final posts = InMemoryPostsRepository(
        initialPosts: [lesson('owned')],
        initialApplications: [
          request('p1'),
          request('p2', student: 'second'),
          request('cancelled', student: 'third', cancelled: true),
          request(
            'rejected',
            student: 'fourth',
            status: ApplicationStatus.rejected,
          ),
        ],
      );
      final source = posts.applicationsRepository;
      await source.reject('p2', ownerId: 'teacher');
      expect(source.applications.first.status, ApplicationStatus.pending);
      expect(posts.posts.single.status, PostStatus.published);
      await source.accept('p1', ownerId: 'teacher');
      expect(source.applications[1].status, ApplicationStatus.rejected);
      expect(source.applications[2].isLocallyCancelled, isTrue);
      expect(source.applications[2].status, ApplicationStatus.pending);
      expect(source.applications[3].status, ApplicationStatus.rejected);
    },
  );
  test(
    'unauthorized, repeated, expired and closed acceptance is rejected without mutation',
    () async {
      final posts = fixture();
      final source = posts.applicationsRepository;
      for (final actor in ['student', 'other-teacher', '']) {
        await expectLater(
          source.accept('p1', ownerId: actor),
          throwsA(isA<ApplicationFailure>()),
        );
        await expectLater(
          source.reject('p1', ownerId: actor),
          throwsA(isA<ApplicationFailure>()),
        );
      }
      await expectLater(
        source.accept('missing', ownerId: 'teacher'),
        throwsA(isA<ApplicationFailure>()),
      );
      await source.accept('p1', ownerId: 'teacher');
      for (final id in ['p1', 'p2']) {
        await expectLater(
          source.accept(id, ownerId: 'teacher'),
          throwsA(isA<ApplicationFailure>()),
        );
        await expectLater(
          source.reject(id, ownerId: 'teacher'),
          throwsA(isA<ApplicationFailure>()),
        );
      }
      for (final status in [
        PostStatus.booked,
        PostStatus.unknown,
        PostStatus.published,
      ]) {
        final post = lesson(
          'closed',
          status: status,
          start:
              status == PostStatus.published
                  ? DateTime.now().subtract(const Duration(minutes: 1))
                  : null,
        );
        final closed = InMemoryPostsRepository(
          initialPosts: [post],
          initialApplications: [request('closed', postId: 'closed')],
        );
        await expectLater(
          closed.applicationsRepository.accept('closed', ownerId: 'teacher'),
          throwsA(isA<ApplicationFailure>()),
        );
        expect(
          closed.applicationsRepository.applications.single.status,
          ApplicationStatus.pending,
        );
      }
    },
  );
  for (final sharedRole in ['teacher', 'student', 'cross-role']) {
    test('accepted schedules prevent overlap for $sharedRole', () async {
      final sameTeacher = sharedRole == 'teacher';
      final cross = sharedRole == 'cross-role';
      final posts = InMemoryPostsRepository(
        initialPosts: [
          lesson('first'),
          lesson(
            'second',
            teacher:
                sameTeacher
                    ? 'teacher'
                    : cross
                    ? 'student'
                    : 'other-teacher',
          ),
        ],
        initialApplications: [
          request('a', postId: 'first'),
          request(
            'b',
            postId: 'second',
            teacher:
                sameTeacher
                    ? 'teacher'
                    : cross
                    ? 'student'
                    : 'other-teacher',
            student: sameTeacher || cross ? 'second' : 'student',
          ),
        ],
      );
      await posts.applicationsRepository.accept('a', ownerId: 'teacher');
      await expectLater(
        posts.applicationsRepository.accept(
          'b',
          ownerId:
              sameTeacher
                  ? 'teacher'
                  : cross
                  ? 'student'
                  : 'other-teacher',
        ),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(posts.posts.last.status, PostStatus.published);
      expect(
        posts.applicationsRepository.applications.last.status,
        ApplicationStatus.pending,
      );
    });
  }
  test(
    'back-to-back lessons are allowed and failed booking preserves both snapshots',
    () async {
      final first = lesson('first');
      final posts = InMemoryPostsRepository(
        initialPosts: [first, lesson('second', start: first.endsAt)],
        initialApplications: [
          request('a', postId: 'first'),
          request('b', postId: 'second', student: 'second'),
        ],
      );
      await posts.applicationsRepository.accept('a', ownerId: 'teacher');
      await posts.applicationsRepository.accept('b', ownerId: 'teacher');
      expect(posts.posts.every((p) => p.status == PostStatus.booked), isTrue);
      final failed = ControlledPosts()..failBooking = true;
      final before = failed.applicationsRepository.applications;
      await expectLater(
        failed.applicationsRepository.accept('p1', ownerId: 'teacher'),
        throwsStateError,
      );
      expect(failed.posts.single.status, PostStatus.published);
      expect(failed.applicationsRepository.applications, before);
    },
  );
  test(
    'request DTO preserves UUIDs, roles, unknown statuses and completion metadata without fake Posts',
    () {
      const current = '11111111-1111-4111-8111-111111111111';
      const counterpart = '22222222-2222-4222-8222-222222222222';
      final json = <String, dynamic>{
        'id': '33333333-3333-4333-8333-333333333333',
        'status': 'AUTO_CANCELLED',
        'completionStatus': 'UNVERIFIED_COMPLETION',
        'agreedTokenAmount': 2,
        'createdAt': '2030-01-02T10:00:00Z',
        'respondedAt': null,
        'studentCompletedAt': '2030-01-04T10:00:00Z',
        'teacherCompletedAt': null,
        'confirmationDeadlineAt': '2030-01-05T10:00:00Z',
        'settledAt': null,
        'conversationId': '44444444-4444-4444-8444-444444444444',
        'listing': {
          'id': '55555555-5555-4555-8555-555555555555',
          'topic': 'API konusu',
          'startAt': null,
          'endAt': null,
          'tokenPrice': 3,
        },
        'counterpart': {
          'id': counterpart,
          'firstName': 'Ece',
          'lastNameInitial': 'K',
          'departmentId': 'dept-id',
        },
      };
      final incoming = RequestDto.fromJson(
        json,
      ).toDomain(role: RequestRole.teacher, currentUserId: current);
      expect(incoming.applicantId, counterpart);
      expect(incoming.teacherId, current);
      expect(incoming.applicant!.displayName, 'Ece K.');
      expect(incoming.status, ApplicationStatus.autoCancelled);
      expect(incoming.listing!.startAt, isNull);
      expect(incoming.agreedTokenAmount, 2);
      final copied = incoming.copyWith(status: ApplicationStatus.accepted);
      expect(copied.conversationId, incoming.conversationId);
      expect(copied.studentCompletedAt, incoming.studentCompletedAt);
      expect(copied.completionStatus, 'UNVERIFIED_COMPLETION');
      final outgoing = RequestDto.fromJson(
        json,
      ).toDomain(role: RequestRole.student, currentUserId: current);
      expect(outgoing.applicantId, current);
      expect(outgoing.teacherId, counterpart);
      expect(outgoing.teacher!.id, counterpart);
      final unknown = RequestDto.fromJson({
        ...json,
        'status': 'FUTURE_STATUS',
      }).toDomain(role: RequestRole.teacher, currentUserId: current);
      expect(unknown.status, ApplicationStatus.unknown);
      expect(unknown.rawServerStatus, 'FUTURE_STATUS');
      expect(
        () => RequestDto.fromJson({
          ...json,
          'agreedTokenAmount': -1,
        }).toDomain(role: RequestRole.teacher, currentUserId: current),
        throwsFormatException,
      );
      expect(
        () => RequestDto.fromJson({
          ...json,
          'id': '',
        }).toDomain(role: RequestRole.teacher, currentUserId: current),
        throwsFormatException,
      );
    },
  );
  testWidgets(
    'Profile opens incoming role and Back preserves Profile; outgoing remains separate',
    (tester) async {
      final posts = fixture();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: HomeScreen(repository: posts, user: owner),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, find.byKey(const ValueKey('home-nav-3')));
      await tap(
        tester,
        find.byKey(const ValueKey('profile-incomingApplications')),
      );
      expect(
        tester
            .widget<ApplicationsScreen>(find.byType(ApplicationsScreen))
            .incoming,
        isTrue,
      );
      expect(find.text('Gelen Başvurular'), findsOneWidget);
      expect(find.byKey(const ValueKey('application-p1')), findsOneWidget);
      expect(find.byKey(const ValueKey('application-other')), findsNothing);
      await tester.pageBack();
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('profile-applications')));
      expect(
        tester
            .widget<ApplicationsScreen>(find.byType(ApplicationsScreen))
            .incoming,
        isFalse,
      );
      expect(find.byKey(const ValueKey('application-p1')), findsNothing);
    },
  );
  testWidgets(
    'card accept confirmation can cancel; success auto-cancels peers and updates sent requests and own posts',
    (tester) async {
      final posts = fixture();
      await mount(tester, posts);
      await tap(tester, find.byKey(const ValueKey('card-accept-p1')));
      expect(
        find.text(
          'Bu başvuruyu kabul etmek istiyor musun? Aynı ilana gelen diğer bekleyen başvurular otomatik iptal edilecektir.',
        ),
        findsOneWidget,
      );
      await tap(tester, find.text('Vazgeç'));
      expect(
        posts.applicationsRepository.applications.first.status,
        ApplicationStatus.pending,
      );
      await decide(tester, 'p1', true);
      expect(find.byKey(const ValueKey('card-accept-p1')), findsNothing);
      await tester.drag(
        find.byKey(const ValueKey('applications-scroll')),
        const Offset(0, 1500),
      );
      await tester.pumpAndSettle();
      await tap(
        tester,
        find.byKey(const ValueKey('application-filter-rejected')),
      );
      expect(find.text('Bu filtrede başvurun bulunmuyor.'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('application-filter-all')));
      await tester.pumpWidget(const SizedBox());
      await mount(
        tester,
        posts,
        incoming: false,
        user: const UserProfile(
          id: 'student',
          firstName: 'Ece',
          department: 'Test',
          campus: 'Test',
        ),
      );
      expect(find.text('Kabul Edildi'), findsNWidgets(2));
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MyPostsScreen(repository: posts, user: owner),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rezerve Edildi'), findsOneWidget);
      expect(find.text('İlanı Düzenle'), findsNothing);
      expect(find.text('İlanı Sil'), findsNothing);
    },
  );
  testWidgets(
    'same bottom sheet supports rejection and preserves other applications',
    (tester) async {
      final posts = fixture();
      await mount(tester, posts);
      await tap(tester, find.byKey(const ValueKey('application-p1')));
      expect(find.text('Başvuru Detayı'), findsOneWidget);
      expect(find.text('Öğrenci student K.'), findsNWidgets(2));
      await decide(tester, 'p1', false, surface: 'detail');
      expect(
        posts.applicationsRepository.applications.first.status,
        ApplicationStatus.rejected,
      );
      expect(
        posts.applicationsRepository.applications[1].status,
        ApplicationStatus.pending,
      );
      expect(find.byKey(const ValueKey('detail-reject-p1')), findsNothing);
      expect(find.text('Başvuru reddedildi.'), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-application')), findsNothing);
    },
  );
  testWidgets(
    'pending operation waits for success; failure is visible in panel and retry works',
    (tester) async {
      final posts = ControlledPosts();
      final source =
          posts.applicationsRepository
            ..acceptGate = Completer<void>()
            ..failAccept = true;
      await mount(tester, posts);
      await tap(tester, find.byKey(const ValueKey('application-p1')));
      await decide(tester, 'p1', true, surface: 'detail');
      expect(source.applications.first.status, ApplicationStatus.pending);
      expect(posts.posts.single.status, PostStatus.published);
      expect(
        tester
            .widget<FilledButton>(
              find.byKey(const ValueKey('detail-accept-p1')),
            )
            .onPressed,
        isNull,
      );
      source.acceptGate!.complete();
      await tester.pumpAndSettle();
      expect(
        find.text('İşlem tamamlanamadı. Lütfen tekrar deneyin.'),
        findsOneWidget,
      );
      source.failAccept = false;
      await decide(tester, 'p1', true, surface: 'detail');
      expect(source.applications.first.status, ApplicationStatus.accepted);
    },
  );
  testWidgets(
    'open confirmation revalidates a request changed by another operation',
    (tester) async {
      final posts = fixture();
      await mount(tester, posts);
      await tap(tester, find.byKey(const ValueKey('card-accept-p1')));
      await posts.applicationsRepository.reject('p1', ownerId: 'teacher');
      await tester.pumpAndSettle();
      await tap(tester, find.widgetWithText(TextButton, 'Kabul Et'));
      expect(
        posts.applicationsRepository.applications.first.status,
        ApplicationStatus.rejected,
      );
      expect(posts.posts.first.status, PostStatus.published);
      expect(
        find.text(
          'Başvuru artık kabul edilemiyor. Durumu ve ders tarihini kontrol et.',
        ),
        findsOneWidget,
      );
    },
  );
  testWidgets('load error retry and empty incoming are usable', (tester) async {
    final posts = ControlledPosts();
    final source =
        posts.applicationsRepository
          ..loadGate = Completer<void>()
          ..failLoad = true;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: ApplicationsScreen(
          incoming: true,
          repository: source,
          postsRepository: posts,
          user: owner,
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
    expect(find.byKey(const ValueKey('application-p1')), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await mount(tester, InMemoryPostsRepository());
    expect(
      find.text(
        'İlanlarına henüz başvuru yapılmadı. Başvurular geldiğinde buradan yönetebilirsin.',
      ),
      findsOneWidget,
    );
  });
  testWidgets(
    'partial DTO still renders incoming details without making up missing data or completion',
    (tester) async {
      final item = RequestDto.fromJson({
        'id': 'partial',
        'status': 'ACCEPTED',
        'completionStatus': 'UNVERIFIED',
        'listing': {
          'id': 'unhydrated',
          'topic': 'Backend konusu',
          'startAt': null,
          'endAt': null,
          'tokenPrice': 2,
        },
        'counterpart': {
          'id': 'student',
          'firstName': 'Ece',
          'lastNameInitial': 'K',
        },
      }).toDomain(role: RequestRole.teacher, currentUserId: 'teacher');
      final posts = InMemoryPostsRepository(initialApplications: [item]);
      await mount(tester, posts);
      expect(find.text('Backend konusu'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('application-partial')));
      expect(find.text('Ece K.'), findsNWidgets(2));
      expect(find.text('Konum bilgisi mevcut değil.'), findsNWidgets(2));
      expect(find.text('2 Token'), findsNWidgets(2));
      expect(find.text('Tamamlandı'), findsNothing);
      expect(find.byKey(const ValueKey('detail-accept-partial')), findsNothing);
    },
  );
  test(
    'two competing accepts cannot produce two winners, and missing conflicting schedule is rejected',
    () async {
      final posts = fixture();
      final source = posts.applicationsRepository;
      final result = await Future.wait(
        ['p1', 'p2'].map((id) async {
          try {
            await source.accept(id, ownerId: 'teacher');
            return true;
          } on ApplicationFailure {
            return false;
          }
        }),
      );
      expect(result.where((value) => value), hasLength(1));
      expect(
        source
            .forOwner('teacher')
            .where((a) => a.status == ApplicationStatus.accepted),
        hasLength(1),
      );
      final partial = InMemoryPostsRepository(
        initialPosts: [lesson('owned')],
        initialApplications: [
          request('p1'),
          request(
            'missing',
            postId: 'unavailable',
            status: ApplicationStatus.accepted,
            student: 'second',
          ),
        ],
      );
      await expectLater(
        partial.applicationsRepository.accept('p1', ownerId: 'teacher'),
        throwsA(isA<ApplicationFailure>()),
      );
      expect(partial.posts.single.status, PostStatus.published);
    },
  );
  testWidgets('reject failure preserves states and can be retried', (
    tester,
  ) async {
    final posts = ControlledPosts();
    final source = posts.applicationsRepository..failReject = true;
    await mount(tester, posts);
    await decide(tester, 'p1', false);
    expect(source.applications.first.status, ApplicationStatus.pending);
    expect(posts.posts.single.status, PostStatus.published);
    expect(
      find.text('İşlem tamamlanamadı. Lütfen tekrar deneyin.'),
      findsOneWidget,
    );
    source.failReject = false;
    await decide(tester, 'p1', false);
    expect(source.applications.first.status, ApplicationStatus.rejected);
    expect(source.applications.last.status, ApplicationStatus.pending);
  });
  testWidgets(
    '320px large text, long student/title and decision buttons fit and sheet scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final posts = InMemoryPostsRepository(
        initialPosts: [
          lesson(
            'owned',
            title:
                'Çok uzun başlıklı algoritma ve veri yapıları özel ders ilanı',
          ),
        ],
        initialApplications: [
          request('p1', name: 'Çok uzun bir öğrenci adı ve soyadı baş harfi'),
        ],
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
          home: ApplicationsScreen(
            incoming: true,
            repository: posts.applicationsRepository,
            postsRepository: posts,
            user: owner,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('application-p1')),
        200,
        scrollable:
            find
                .descendant(
                  of: find.byKey(const ValueKey('applications-scroll')),
                  matching: find.byType(Scrollable),
                )
                .first,
      );
      final cardTop = tester.getTopLeft(
        find.byKey(const ValueKey('application-p1')),
      );
      await tester.tapAt(cardTop + const Offset(24, 24));
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('detail-accept-p1')),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(
        tester.getRect(find.byKey(const ValueKey('detail-reject-p1'))).right,
        lessThanOrEqualTo(320),
      );
    },
  );
}
