import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:studyco_mobile/app/app.dart';
import 'package:studyco_mobile/core/api/api_client.dart';
import 'package:studyco_mobile/core/data/remote_catalog.dart';
import 'package:studyco_mobile/core/session/auth_session.dart';
import 'package:studyco_mobile/features/home/screens/home_screen.dart';
import 'package:studyco_mobile/features/posts/data/remote_posts_repository.dart';
import 'package:studyco_mobile/features/posts/models/post.dart';

import 'support/fake_backend.dart';

void main() {
  group('AuthSession', () {
    test('login stores tokens and logout clears them', () async {
      final backend = FakeBackend();
      final session = backend.session;
      await session.restore();
      expect(session.status, SessionStatus.signedOut);

      await session.login('student@example.com', 'secret123');
      expect(session.status, SessionStatus.signedIn);
      expect(session.user!.id, userId);
      expect(session.accessToken, 'access-token');

      await session.logout();
      expect(session.status, SessionStatus.signedOut);
      expect(session.accessToken, isNull);
      expect(backend.requests.last.url.path, '/api/v1/auth/logout');
    });

    test('wrong password surfaces the backend error code', () async {
      final session = FakeBackend().session;
      await expectLater(
        session.login('student@example.com', 'wrong'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.code,
            'code',
            'INVALID_CREDENTIALS',
          ),
        ),
      );
      expect(session.status, isNot(SessionStatus.signedIn));
    });

    test('a saved refresh token restores the session at startup', () async {
      final store = MemoryRefreshTokenStore();
      await store.write('r' * 40);
      var refreshed = 0;
      final session = AuthSession(
        store: store,
        api: ApiClient(
          baseUrl: 'http://api.test',
          httpClient: MockClient((request) async {
            refreshed++;
            expect(request.url.path, '/api/v1/auth/refresh');
            return _utf8(
              jsonEncode({
                'user': FakeBackend().user,
                'accessToken': 'a',
                'refreshToken': 'n' * 40,
              }),
              200,
            );
          }),
        ),
      );
      await session.restore();
      expect(refreshed, 1);
      expect(session.status, SessionStatus.signedIn);
      expect(await store.read(), 'n' * 40);
    });

    test(
      'an expired access token is refreshed once and the call retried',
      () async {
        var token = 'old';
        final calls = <String>[];
        final session = AuthSession(
          store: MemoryRefreshTokenStore(),
          api: ApiClient(
            baseUrl: 'http://api.test',
            httpClient: MockClient((request) async {
              final path = request.url.path.replaceFirst('/api/v1', '');
              calls.add(path);
              if (path == '/auth/login' || path == '/auth/refresh') {
                final next = path == '/auth/login' ? 'old' : 'new';
                return _utf8(
                  jsonEncode({
                    'user': FakeBackend().user,
                    'accessToken': next,
                    'refreshToken': 'r' * 40,
                  }),
                  200,
                );
              }
              token = request.headers['authorization']!.substring(7);
              return token == 'new'
                  ? _utf8(jsonEncode(FakeBackend().user), 200)
                  : _utf8(
                    jsonEncode({
                      'error': {'code': 'UNAUTHORIZED', 'message': ''},
                    }),
                    401,
                  );
            }),
          ),
        );
        await session.login('student@example.com', 'secret123');
        final me = await session.api.get('/me');
        expect((me as Map)['id'], userId);
        expect(calls, ['/auth/login', '/me', '/auth/refresh', '/me']);
      },
    );

    test('a rejected refresh signs the user out', () async {
      final session = AuthSession(
        store: MemoryRefreshTokenStore(),
        api: ApiClient(
          baseUrl: 'http://api.test',
          httpClient: MockClient((request) async {
            if (request.url.path.endsWith('/auth/login')) {
              return _utf8(
                jsonEncode({
                  'user': FakeBackend().user,
                  'accessToken': 'a',
                  'refreshToken': 'r' * 40,
                }),
                200,
              );
            }
            return _utf8(
              jsonEncode({
                'error': {'code': 'UNAUTHORIZED', 'message': ''},
              }),
              401,
            );
          }),
        ),
      );
      await session.login('student@example.com', 'secret123');
      await expectLater(session.api.get('/me'), throwsA(isA<ApiException>()));
      expect(session.status, SessionStatus.signedOut);
    });

    test('network failures become NETWORK_ERROR', () async {
      final backend = FakeBackend()..online = false;
      await expectLater(
        backend.session.login('student@example.com', 'secret123'),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'code', 'NETWORK_ERROR'),
        ),
      );
      expect(
        apiErrorMessage(const ApiException('NETWORK_ERROR', '')),
        contains('Sunucuya ulaşılamadı'),
      );
    });
  });

  group('Remote repositories', () {
    late FakeBackend backend;
    late RemotePostsRepository posts;

    setUp(() async {
      backend = FakeBackend();
      backend.listings.add(backend.listing());
      await backend.session.login('student@example.com', 'secret123');
      final catalog = RemoteCatalog(backend.session.api);
      final academic = await catalog.academic();
      final locations = await catalog.locations();
      posts = RemotePostsRepository(
        api: backend.session.api,
        userId: userId,
        academicCatalog: () => academic,
        locationCatalog: () => locations,
      );
    });

    tearDown(() => posts.dispose());

    test('listings map to posts with department and token price', () async {
      await posts.refresh();
      final post = posts.posts.single;
      expect(post.id, listingId);
      expect(post.title, 'Algoritma ve Programlama');
      expect(post.department, 'Bilgisayar Mühendisliği');
      expect(post.location, 'Espressolab');
      expect(post.offer, PostOffer.coffee);
      expect(post.coffeeCount, 1);
      expect(post.status, PostStatus.published);
      expect(posts.discoverablePosts, hasLength(1));
    });

    test('creating a post sends catalog IDs, not display names', () async {
      final start = DateTime.now().add(const Duration(days: 3));
      await posts.addPost(
        Post(
          id: 'local',
          title: 'Algoritma ve Programlama',
          department: 'Bilgisayar Mühendisliği',
          topic: 'Özyineleme',
          authorName: 'Ayşe',
          authorId: userId,
          createdAt: DateTime.now(),
          startsAt: start,
          endsAt: start.add(const Duration(hours: 1)),
          location: 'Espressolab',
          type: PostType.tutoring,
          subject: PostSubject.coding,
          offer: PostOffer.free,
        ),
      );
      final sent =
          jsonDecode(backend.requests.last.body) as Map<String, dynamic>;
      expect(sent['courseId'], courseId);
      expect(sent['locationId'], locationId);
      expect(sent['tokenPrice'], 0);
      expect(sent['topic'], 'Özyineleme');
      expect(posts.posts.where((p) => p.authorId == userId), hasLength(1));
    });

    test(
      'applying creates a pending request and blocks a second one',
      () async {
        await posts.refresh();
        final applications = posts.applicationsRepository;
        final post = posts.posts.single;
        expect(applications.canApply(post, applicantId: userId), isTrue);

        final created = await applications.create(
          postId: post.id,
          applicantId: userId,
        );
        expect(created.isPending, isTrue);
        expect(created.teacherId, teacherId);
        expect(applications.canApply(post, applicantId: userId), isFalse);

        await applications.refresh(applicantId: userId);
        expect(applications.forApplicant(userId), hasLength(1));
      },
    );
  });

  testWidgets('Signing in replaces Login with Home, and logout returns', (
    tester,
  ) async {
    final backend = FakeBackend();
    backend.listings.add(backend.listing());
    await tester.pumpWidget(MyApp(session: backend.session));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byType(TextFormField).first,
      'student@example.com',
    );
    await tester.enterText(find.byType(TextFormField).last, 'secret123');
    await tester.ensureVisible(find.text('Giriş Yap'));
    await tester.tap(find.text('Giriş Yap'));
    await tester.pumpAndSettle();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.text('Algoritma ve Programlama'), findsWidgets);
    expect(find.text('Mehmet K.'), findsOneWidget);

    await backend.session.logout();
    await tester.pumpAndSettle();
    expect(find.byType(HomeScreen), findsNothing);
    expect(find.text('Hoş geldin!'), findsOneWidget);
  });
}

http.Response _utf8(String body, int status) => http.Response.bytes(
  utf8.encode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
